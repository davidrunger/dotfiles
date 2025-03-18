import { readFileSync } from 'fs';
import ky from 'ky';

import {
  displayRepositories,
  enrichRepositories,
  Repository,
} from './lib/githubReposEnrichedDisplay';

interface StarredRepositoryEdge {
  cursor: string;
  node: Repository;
  starredAt: string; // Provided at the edge level.
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

// Fetch starred repositories with pagination.
async function fetchAllStarredRepos(username: string): Promise<Repository[]> {
  if (process.env.STARS_DATA_FILE_PATH) {
    return JSON.parse(readFileSync(process.env.STARS_DATA_FILE_PATH, 'utf8'));
  }

  let hasNextPage = true;
  let endCursor: string | null = null;
  const allStarredRepos: Repository[] = [];

  console.log(
    `Fetching starred repositories for ${username} (with pagination)...`,
  );

  let pageCount = 0;

  while (hasNextPage) {
    pageCount++;
    console.log(
      `Fetching page ${pageCount}${
        endCursor ? ` (cursor: ${endCursor})` : ''
      }...`,
    );

    // Build GraphQL query with cursor if available.
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

      if (response.errors) {
        console.error(
          'GraphQL errors:',
          JSON.stringify(response.errors, null, 2),
        );
        throw new Error(`GraphQL error: ${response.errors[0].message}`);
      }

      const typedResponse = response as GraphQLResponse;
      const starredData = typedResponse.data.user.starredRepositories;

      // For each edge, merge the starredAt field into the repository.
      starredData.edges.forEach((edge) => {
        const repo = edge.node;
        repo.starredAt = edge.starredAt;
        allStarredRepos.push(repo);
      });

      console.log(
        `Retrieved ${starredData.edges.length} repositories (total so far: ${allStarredRepos.length})`,
      );

      hasNextPage = starredData.pageInfo.hasNextPage;
      endCursor = starredData.pageInfo.endCursor;
    } catch (error) {
      console.error('Error fetching starred repositories:', error);
      if (error instanceof Error) {
        console.error(error.message);
      }
      hasNextPage = false;
    }
  }

  return allStarredRepos;
}

async function main() {
  try {
    const username = 'davidrunger';
    let starredRepos = await fetchAllStarredRepos(username);

    console.log(
      `\nFound a total of ${starredRepos.length} starred repositories.`,
    );

    // Enrich repositories: fetch missing language data, total stars, and starred dates.
    starredRepos = await enrichRepositories(starredRepos, {
      enrichLanguages: true,
      enrichStarredDates: true,
    });

    // Sort by star count (descending).
    const sortedRepos = starredRepos.sort(
      (a, b) => b.stargazerCount - a.stargazerCount,
    );

    console.log('\n=== STARRED REPOSITORIES (Sorted by Stars) ===\n');
    displayRepositories(sortedRepos);
  } catch (error) {
    console.error('An error occurred:', error);
    if (error instanceof Error) {
      console.error(error.message);
    }
  }
}

main();
