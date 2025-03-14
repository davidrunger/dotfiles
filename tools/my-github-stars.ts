import ky from 'ky';

interface LanguageEdge {
  node: {
    name: string;
    color: string;
  };
  size: number;
}

interface Repository {
  name: string;
  nameWithOwner: string;
  description: string;
  stargazerCount: number;
  languages: {
    totalSize: number;
    edges: LanguageEdge[];
  };
}

interface StarredRepositoryEdge {
  cursor: string;
  node: Repository;
  starredAt: string; // This is at this level, not inside node.
}

interface PageInfo {
  hasNextPage: boolean;
  endCursor: string;
}

interface StarredRepositoriesResponse {
  edges: StarredRepositoryEdge[];
  pageInfo: PageInfo;
}

interface GraphQLResponse {
  data: {
    user: {
      starredRepositories: StarredRepositoriesResponse;
    };
  };
}

// Format the language breakdown as a percentage string.
function formatLanguageBreakdown(
  languages: LanguageEdge[],
  totalSize: number,
): string {
  if (languages.length === 0) return 'No language data';

  return languages
    .sort((a, b) => b.size - a.size)
    .map(
      ({ node, size }) =>
        `${node.name} (${((size / totalSize) * 100).toFixed(1)}%)`,
    )
    .join(', ');
}

// Fetch starred repositories with pagination.
async function fetchAllStarredRepos(
  username: string,
): Promise<{ repo: Repository; starredAt: string }[]> {
  let hasNextPage = true;
  let endCursor: string | null = null;
  const allStarredRepos: { repo: Repository; starredAt: string }[] = [];

  console.log(
    `Fetching starred repositories for ${username} (with pagination)...`,
  );

  let pageCount = 0;

  while (hasNextPage) {
    pageCount++;
    console.log(
      `Fetching page ${pageCount}${endCursor ? ` (cursor: ${endCursor})` : ''}...`,
    );

    // Build GraphQL query with cursor if we have one
    const afterClause = endCursor ? `, after: "${endCursor}"` : '';

    const query = `
      query {
        user(login: "${username}") {
          starredRepositories(first: 100, orderBy: {field: STARRED_AT, direction: DESC}${afterClause}) {
            edges {
              cursor
              starredAt
              node {
                name
                nameWithOwner
                description
                stargazerCount
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
      // Make the GraphQL request
      const response = await ky
        .post<{ errors?: Array<{ message: string }>; data?: object }>(
          'https://api.github.com/graphql',
          {
            headers: {
              Authorization: `token ${process.env.GITHUB_ACCESS_TOKEN}`,
            },
            json: { query },
          },
        )
        .json();

      // For debugging
      if (response.errors) {
        console.error(
          'GraphQL errors:',
          JSON.stringify(response.errors, null, 2),
        );
        throw new Error(`GraphQL error: ${response.errors[0].message}`);
      }

      const typedResponse = response as GraphQLResponse;
      const starredData = typedResponse.data.user.starredRepositories;

      // Add this page's repositories to our collection
      const pageRepos = starredData.edges.map((edge) => ({
        repo: edge.node,
        starredAt: edge.starredAt,
      }));
      allStarredRepos.push(...pageRepos);

      console.log(
        `Retrieved ${pageRepos.length} repositories (total so far: ${allStarredRepos.length})`,
      );

      // Update pagination info for next iteration
      hasNextPage = starredData.pageInfo.hasNextPage;
      endCursor = starredData.pageInfo.endCursor;
    } catch (error) {
      console.error('Error fetching starred repositories:', error);
      if (error instanceof Error) {
        console.error(error.message);
      }

      // Break the loop on error
      hasNextPage = false;
    }
  }

  return allStarredRepos;
}

// Main function.
async function main() {
  try {
    // Fetch all starred repositories with pagination
    const starredRepos = await fetchAllStarredRepos('davidrunger');

    console.log(
      `\nFound a total of ${starredRepos.length} starred repositories.`,
    );

    // Sort by star count (descending)
    const sortedRepos = starredRepos.sort(
      (a, b) => b.repo.stargazerCount - a.repo.stargazerCount,
    );

    // Display the results
    console.log('\n=== STARRED REPOSITORIES (Sorted by Stars) ===\n');
    sortedRepos.forEach((item) => {
      const repo = item.repo;
      console.log(`Repository: ${repo.nameWithOwner}`);
      console.log(`Stars: ${repo.stargazerCount}`);
      console.log(`Starred At: ${new Date(item.starredAt).toLocaleString()}`);
      console.log(
        `Languages: ${formatLanguageBreakdown(
          repo.languages.edges,
          repo.languages.totalSize,
        )}`,
      );
      console.log(
        `Description: ${repo.description || 'No description provided'}`,
      );
      console.log('-'.repeat(80));
    });
  } catch (error) {
    console.error('An error occurred:', error);
    if (error instanceof Error) {
      console.error(error.message);
    }
  }
}

main();
