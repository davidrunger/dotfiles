import chalk from 'chalk';
import ky from 'ky';

export interface LanguageEdge {
  node: {
    name: string;
    color: string;
  };
  size: number;
}

export interface Repository {
  name: string;
  nameWithOwner: string;
  description: string;
  stargazerCount: number;
  // Language info may be missing in the initial data.
  languages?: {
    totalSize: number;
    edges: LanguageEdge[];
  };
  // Optionally, if this repo is starred by the authenticated user.
  starredAt?: string;
}

/**
 * Creates a clickable terminal hyperlink.
 */
export function terminalLink(text: string, url: string): string {
  return `\u001b]8;;${url}\u0007${text}\u001b]8;;\u0007`;
}

/**
 * Format the language breakdown as a percentage string.
 */
export function formatLanguageBreakdown(
  languages: LanguageEdge[],
  totalSize: number,
): string {
  if (!languages || languages.length === 0) return 'No language data';
  return languages
    .sort((a, b) => b.size - a.size)
    .map(
      ({ node, size }) =>
        `${chalk.hex(node.color || '#555')('██')} ${node.name} (${(
          (size / totalSize) *
          100
        ).toFixed(1)}%)`,
    )
    .join(', ');
}

/**
 * Enrich an array of repository objects by fetching missing language data, total star counts,
 * and optionally starred dates (if not already provided).
 *
 * This function performs batched GraphQL queries to avoid N+1 API calls.
 *
 * @param repos An array of Repository objects that may be missing some fields.
 * @param options.enrichLanguages If true, fetch missing language data and total star counts.
 * @param options.enrichStarredDates If true, fetch starredAt dates for repositories.
 * @returns The enriched array of Repository objects.
 */
export async function enrichRepositories(
  repos: Repository[],
  options: { enrichLanguages?: boolean; enrichStarredDates?: boolean } = {},
): Promise<Repository[]> {
  const token = process.env.GITHUB_ACCESS_TOKEN;
  if (!token) {
    console.error('GITHUB_ACCESS_TOKEN not set');
    return repos;
  }

  // ------------------------------
  // Batch-enrich language data, stargazerCount, and description
  // ------------------------------
  const reposToEnrich = repos.filter(
    (repo) =>
      options.enrichLanguages &&
      (!repo.languages ||
        !repo.languages.edges ||
        repo.languages.edges.length === 0),
  );

  if (reposToEnrich.length > 0) {
    console.log('Sleeping for 60 seconds...');
    await new Promise((resolve) => setTimeout(resolve, 60000));
    console.log('... done.');

    // Split into batches (e.g. 20 repos per query).
    const batchSize = 20;
    for (let i = 0; i < reposToEnrich.length; i += batchSize) {
      const batch = reposToEnrich.slice(i, i + batchSize);
      // Build a GraphQL query with an alias for each repository.
      const queryParts: string[] = [];
      batch.forEach((repo, idx) => {
        const [owner, name] = repo.nameWithOwner.split('/');
        queryParts.push(`
          repo${idx}: repository(owner: "${owner}", name: "${name}") {
            stargazerCount
            description
            languages(first: 5, orderBy: {field: SIZE, direction: DESC}) {
              totalSize
              edges {
                size
                node {
                  name
                  color
                }
              }
            }
          }
        `);
      });
      const query = `query { ${queryParts.join('\n')} }`;

      try {
        const response = await ky
          .post('https://api.github.com/graphql', {
            headers: {
              Authorization: `token ${token}`,
              'Content-Type': 'application/json',
            },
            json: { query },
          })
          .json<{
            data: Record<
              string,
              {
                stargazerCount: number;
                description: string;
                languages: { totalSize: number; edges: LanguageEdge[] };
              }
            >;
          }>();

        // Update each repository in the batch with its language data, star count, and description.
        batch.forEach((repo, idx) => {
          const key = `repo${idx}`;
          const data = response.data[key];
          if (data) {
            repo.stargazerCount = data.stargazerCount;
            repo.languages = data.languages;
            // Update description if fetched value is present.
            repo.description = data.description || repo.description;
          }
        });
      } catch (error) {
        console.error('Error enriching language data:', error);
      }
    }
  }

  // ------------------------------
  // Enrich starred dates (if desired)
  // ------------------------------
  if (options.enrichStarredDates) {
    console.log('Sleeping for 60 seconds...');
    await new Promise((resolve) => setTimeout(resolve, 60000));
    console.log('... done.');

    // Fetch the authenticated viewer's starred repositories.
    let starredRepos: { node: { nameWithOwner: string }; starredAt: string }[] =
      [];
    let hasNextPage = true;
    let endCursor: string | null = null;
    while (hasNextPage) {
      const query: string = `
        query {
          viewer {
            starredRepositories(first: 100${endCursor ? `, after: "${endCursor}"` : ''}) {
              edges {
                node {
                  nameWithOwner
                }
                starredAt
              }
              pageInfo {
                hasNextPage
                endCursor
              }
            }
          }
        }
      `;
      try {
        const response = await ky
          .post('https://api.github.com/graphql', {
            headers: {
              Authorization: `token ${token}`,
              'Content-Type': 'application/json',
            },
            json: { query },
          })
          .json<{
            data: {
              viewer: {
                starredRepositories: {
                  edges: {
                    node: { nameWithOwner: string };
                    starredAt: string;
                  }[];
                  pageInfo: { hasNextPage: boolean; endCursor: string };
                };
              };
            };
          }>();

        const starredData = response.data.viewer.starredRepositories;
        starredRepos = starredRepos.concat(starredData.edges);
        hasNextPage = starredData.pageInfo.hasNextPage;
        endCursor = starredData.pageInfo.endCursor;
      } catch (error) {
        console.error(
          'Error fetching starred repositories for enrichment:',
          error,
        );
        console.error('------');
        console.error(await (error as any).response.json());
        console.error('======');
        break;
      }
    }
    // Build a lookup from repo full name to starredAt date.
    const starredMap: Record<string, string> = {};
    starredRepos.forEach((edge) => {
      starredMap[edge.node.nameWithOwner] = edge.starredAt;
    });
    // Update any repositories missing starredAt.
    repos.forEach((repo) => {
      if (!repo.starredAt && starredMap[repo.nameWithOwner]) {
        repo.starredAt = starredMap[repo.nameWithOwner];
      }
    });
  }

  return repos;
}

/**
 * Display an array of repositories using a rich, consistent format.
 *
 * @param repos An array of Repository objects (assumed to be enriched if desired).
 * @param extraData Optional mapping from repository nameWithOwner to extra metrics
 *                  (e.g. overlapScore or totalStars).
 */
export function displayRepositories(
  repos: Repository[],
  extraData?: Record<string, { overlapScore?: number; totalStars?: number }>,
): void {
  repos.forEach((repo) => {
    console.log(
      terminalLink(
        chalk.blue.bold(repo.nameWithOwner),
        `https://github.com/${repo.nameWithOwner}`,
      ),
    );
    console.log(repo.description || '[no description]');

    let starLine = chalk.yellow(`Stars: ${repo.stargazerCount}`);
    if (repo.starredAt) {
      const dateStr = new Date(repo.starredAt).toISOString().slice(0, 10);
      starLine += ` ${chalk.gray(`(Starred on: ${dateStr})`)}`;
    }
    if (extraData && extraData[repo.nameWithOwner]) {
      const extra = extraData[repo.nameWithOwner];
      if (extra.overlapScore !== undefined) {
        starLine += ` ${chalk.green(
          `Overlap Score: ${extra.overlapScore.toFixed(3)}`,
        )}`;
      }
      if (extra.totalStars !== undefined) {
        starLine += ` ${chalk.cyan(`Total Stars: ${extra.totalStars}`)}`;
      }
    }
    console.log(starLine);

    if (repo.languages) {
      console.log(
        `${chalk.magenta('Languages:')} ${formatLanguageBreakdown(
          repo.languages.edges,
          repo.languages.totalSize,
        )}`,
      );
    }
    console.log();
  });
}
