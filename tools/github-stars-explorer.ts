// Example usage (this will take a long time to run but should stay within the GitHub rate limit and should produce useful results):
// NUMBER_OF_MY_REPOS_TO_LOOK_AT=60 NUMBER_OF_STARGAZERS_PER_REPO=20 MAX_STARRED_REPOS_PER_USER=300 INCLUDE_MY_REPOS=1 tsx --env-file=.env tools/github-stars-explorer.ts

import { Redis } from 'ioredis';
import ky from 'ky';

import {
  displayRepositories,
  enrichRepositories,
  Repository,
} from './lib/githubReposEnrichedDisplay';

const MY_USERNAME = 'davidrunger';

class GitHubCache {
  private redis: Redis;
  private cacheTTL: number;

  constructor() {
    this.redis = new Redis('redis://localhost:6379');
    // Cache for 30 days.
    this.cacheTTL = 60 * 60 * 24 * 30;
  }

  private getKey(endpoint: string): string {
    return `github:cache:${encodeURIComponent(endpoint)}`;
  }

  async get(endpoint: string): Promise<any | null> {
    const key = this.getKey(endpoint);
    const data = await this.redis.get(key);
    return data ? JSON.parse(data) : null;
  }

  async set(endpoint: string, data: any): Promise<void> {
    const key = this.getKey(endpoint);
    await this.redis.setex(key, this.cacheTTL, JSON.stringify(data));
  }

  async quit() {
    await this.redis.quit();
  }
}

class GitHubStarAnalyzer {
  private token: string;
  private headers: Record<string, string>;
  private cache: GitHubCache;
  private allMyStarredReposSet: Set<string>;

  constructor(token: string) {
    this.token = token;
    this.headers = {
      Authorization: `token ${token}`,
      Accept: 'application/vnd.github.v3+json',
    };
    this.cache = new GitHubCache();
    this.allMyStarredReposSet = new Set();
  }

  private async checkRateLimit(response: Response): Promise<void> {
    const remaining = Number(
      response.headers.get('X-RateLimit-Remaining') || 0,
    );
    console.log(`Requests remaining: ${remaining}`);

    if (remaining < 5) {
      const resetTime = new Date(
        Number(
          response.headers.get('X-RateLimit-Reset') || Date.now() / 1000 + 60,
        ) * 1000,
      );
      const waitTime = (resetTime.getTime() - Date.now()) / 1000;
      if (waitTime > 0) {
        console.log(
          `Approaching rate limit. Waiting ${waitTime.toFixed(0)} seconds...`,
        );
        await new Promise((resolve) => setTimeout(resolve, waitTime * 1000));
      }
    }
  }

  async getAllStarredRepos(username: string): Promise<Array<string>> {
    return this.getStarredRepos(username, null);
  }

  async getStarredRepos(
    username: string,
    maxStarredRepos: number | null = null,
  ): Promise<Array<string>> {
    const repos: Array<string> = [];
    let page = 1;

    while (true) {
      if (maxStarredRepos && repos.length >= maxStarredRepos) {
        return repos.slice(0, maxStarredRepos);
      }

      const endpoint = `/users/${username}/starred?page=${page}&per_page=100`;

      const cachedData = await this.cache.get(endpoint);
      if (cachedData) {
        console.log(`Cache hit for ${username}'s stars page ${page}`);
        if (cachedData.length) {
          repos.push(...cachedData);
          page++;
          continue;
        } else {
          break;
        }
      }

      try {
        const response = await ky.get(`https://api.github.com${endpoint}`, {
          headers: this.headers,
        });
        await this.checkRateLimit(response);
        if (!response.ok) {
          throw new Error(
            `GitHub API Error: ${response.status} ${response.statusText}`,
          );
        }
        const data = (await response.json()) as any[];
        const repoNames = data.map((repo) => repo.full_name);
        await this.cache.set(endpoint, repoNames);
        if (!data.length) break;
        repos.push(...repoNames);
        page++;
      } catch (error) {
        console.error(`Error fetching starred repos: ${error}`);
        return [];
      }
    }

    return maxStarredRepos ? repos.slice(0, maxStarredRepos) : repos;
  }

  async getRepoStargazers(
    repo: string,
    numberOfStargazers: number,
  ): Promise<Array<string>> {
    const users: Array<string> = [];
    let page = 1;

    while (users.length <= numberOfStargazers) {
      const endpoint = `/repos/${repo}/stargazers?page=${page}&per_page=100`;

      const cachedData = (await this.cache.get(endpoint)) as Array<string>;
      if (cachedData) {
        console.log(`Cache hit for ${repo}'s stargazers page ${page}`);
        if (!cachedData.length) break;
        users.push(
          ...cachedData.filter((username) => username !== MY_USERNAME),
        );
        page++;
        continue;
      }

      try {
        const response = await ky.get(`https://api.github.com${endpoint}`, {
          headers: this.headers,
        });
        await this.checkRateLimit(response);
        if (!response.ok) {
          throw new Error(
            `GitHub API Error: ${response.status} ${response.statusText}`,
          );
        }
        const data = (await response.json()) as any[];
        const usernames = data.map((user) => user.login);
        await this.cache.set(endpoint, usernames);

        if (!data.length) break;

        users.push(...usernames.filter((username) => username !== MY_USERNAME));
        page++;
      } catch (error) {
        console.error(`Error fetching stargazers: ${error}`);
        return [];
      }
    }

    return users.slice(0, numberOfStargazers);
  }

  async getStarredReposTotalCount(username: string): Promise<number> {
    const endpoint = 'https://api.github.com/graphql';
    const query = `
      query($login: String!) {
        user(login: $login) {
          starredRepositories {
            totalCount
          }
        }
      }
    `;

    const variables = { login: username };
    const cacheKey = JSON.stringify([endpoint, query, variables]);
    const cachedData = await this.cache.get(cacheKey);

    if (cachedData) {
      return cachedData;
    } else {
      try {
        const response = await ky.post<{
          errors?: Array<string>;
          data?: { user: { starredRepositories: { totalCount: number } } };
        }>(endpoint, {
          headers: {
            Authorization: `Bearer ${this.token}`,
            'Content-Type': 'application/json',
          },
          json: { query, variables },
        });

        await this.checkRateLimit(response);

        const result = await response.json();
        if (result.errors) {
          console.error('GraphQL errors:', result.errors);
          throw new Error('Error fetching data from GitHub GraphQL API');
        }

        if (result.data) {
          const totalCount = result.data.user.starredRepositories.totalCount;
          if (Number.isInteger(totalCount)) {
            await this.cache.set(cacheKey, totalCount);
            return totalCount;
          } else {
            throw new Error('totalCount was not an integer');
          }
        } else {
          throw new Error('No data returned from GitHub GraphQL API');
        }
      } catch (error) {
        console.error('Error:', error);
        throw error;
      }
    }
  }

  async analyzeStarPatterns(
    username: string,
    numberOfMyReposToLookAt: number,
    numberOfStargazersPerRepo: number,
    maxStarredReposPerUser: number,
  ): Promise<void> {
    const allMyStarredReposArray = await this.getAllStarredRepos(username);
    this.allMyStarredReposSet = new Set(allMyStarredReposArray);
    let myReposToAnalyze;

    if (process.env.REPOS_TO_EXPLORE) {
      myReposToAnalyze = process.env.REPOS_TO_EXPLORE.split(',');
    } else {
      myReposToAnalyze = allMyStarredReposArray.slice(
        0,
        numberOfMyReposToLookAt,
      );
    }

    console.log(`Found ${allMyStarredReposArray.length} total starred repos.`);
    console.log(
      `Analyzing starred repos: ${JSON.stringify(myReposToAnalyze)}.`,
    );

    const allStargazers = new Set<string>();
    const stargazerRepos: Record<string, Set<string>> = {};

    for (const repo of myReposToAnalyze) {
      console.log(`Adding stargazers for ${repo}...`);
      const stargazers = await this.getRepoStargazers(
        repo,
        numberOfStargazersPerRepo,
      );
      for (const stargazer of stargazers) {
        console.log(`Adding stargazer ${stargazer}`);
        allStargazers.add(stargazer);
      }
    }

    let rank = 1;
    const totalStargazers = allStargazers.size;
    for (const stargazer of allStargazers) {
      const starredReposOfStargazer = await this.getStarredRepos(
        stargazer,
        maxStarredReposPerUser,
      );
      console.log(
        `Found starredReposOfStargazer for ${stargazer} (${rank}/${totalStargazers}): ` +
          JSON.stringify(starredReposOfStargazer),
      );
      stargazerRepos[stargazer] = new Set(starredReposOfStargazer);
      rank++;
    }

    const recommendationsByOverlapWithMe: Record<string, number> = {};
    const recommendationsByPopularity: Record<string, number> = {};

    // Calculate overlap-with-me scores.
    for (const stargazer in stargazerRepos) {
      const stars = stargazerRepos[stargazer];
      const overlapCount = allMyStarredReposArray.filter((x) =>
        stars.has(x),
      ).length;
      if (overlapCount > 0) {
        const potentialRecs = new Set(
          [...stars].filter(
            (x) =>
              process.env.INCLUDE_MY_REPOS || !this.allMyStarredReposSet.has(x),
          ),
        );
        if (potentialRecs.size > 0) {
          const userTotalStars =
            await this.getStarredReposTotalCount(stargazer);
          console.log(`Total stars for ${stargazer}: ${userTotalStars}.`);
          const overlapFraction = overlapCount / userTotalStars;
          console.log(`overlapFraction for ${stargazer}: ${overlapFraction}.`);
          for (const rec of potentialRecs) {
            recommendationsByOverlapWithMe[rec] =
              (recommendationsByOverlapWithMe[rec] || 0) + overlapFraction;
          }
        }
      }
    }

    // Calculate popularity scores.
    for (const stargazer in stargazerRepos) {
      const stars = stargazerRepos[stargazer];
      for (const repo of stars) {
        if (
          process.env.INCLUDE_MY_REPOS ||
          !this.allMyStarredReposSet.has(repo)
        ) {
          recommendationsByPopularity[repo] =
            (recommendationsByPopularity[repo] || 0) + 1;
        }
      }
    }

    // Sort recommendations.
    const sortedByOverlap = Object.entries(recommendationsByOverlapWithMe).sort(
      ([, a], [, b]) => b - a,
    );
    const sortedByPopularity = Object.entries(recommendationsByPopularity).sort(
      ([, a], [, b]) => b - a,
    );

    // Build arrays of minimal repository objects for enrichment.
    const overlapRepoNames = sortedByOverlap
      .slice(0, 500)
      .map(([repo]) => repo);
    const popularityRepoNames = sortedByPopularity
      .slice(0, 500)
      .map(([repo]) => repo);

    const minimalOverlapRepos: Repository[] = overlapRepoNames.map(
      (fullName) => {
        const [_owner, name] = fullName.split('/');
        return {
          name,
          nameWithOwner: fullName,
          description: '',
          stargazerCount: 0,
        };
      },
    );

    const minimalPopularityRepos: Repository[] = popularityRepoNames.map(
      (fullName) => {
        const [_owner, name] = fullName.split('/');
        return {
          name,
          nameWithOwner: fullName,
          description: '',
          stargazerCount: 0,
        };
      },
    );

    // Enrich repository details for display (this will now include total star counts).
    const enrichedOverlapRepos = await enrichRepositories(minimalOverlapRepos, {
      enrichLanguages: true,
    });
    const enrichedPopularityRepos = await enrichRepositories(
      minimalPopularityRepos,
      { enrichLanguages: true },
    );

    // Build extra data mappings.
    const overlapExtraData: Record<string, { overlapScore?: number }> = {};
    sortedByOverlap.slice(0, 500).forEach(([repo, score]) => {
      overlapExtraData[repo] = { overlapScore: score };
    });

    const popularityExtraData: Record<string, { totalStars?: number }> = {};
    sortedByPopularity.slice(0, 500).forEach(([repo, score]) => {
      popularityExtraData[repo] = { totalStars: score };
    });

    console.log('\n=== Top Recommendations by Overlap ===\n');
    displayRepositories(enrichedOverlapRepos, overlapExtraData);

    console.log('\n=== Top Recommendations by Popularity ===\n');
    displayRepositories(enrichedPopularityRepos, popularityExtraData);

    await this.cache.quit();
  }
}

async function main() {
  const myUsername = process.env.GITHUB_USERNAME;
  const token = process.env.GITHUB_ACCESS_TOKEN;

  if (!myUsername || !token) {
    console.error(
      'GITHUB_USERNAME and GITHUB_ACCESS_TOKEN environment variables must be set.',
    );
    return;
  }

  const analyzer = new GitHubStarAnalyzer(token);

  if (
    process.env.NUMBER_OF_MY_REPOS_TO_LOOK_AT &&
    process.env.REPOS_TO_EXPLORE
  ) {
    console.warn(
      'Warning: NUMBER_OF_MY_REPOS_TO_LOOK_AT is ignored when REPOS_TO_EXPLORE is present.',
    );
  }

  const numberOfMyReposToLookAt = parseInt(
    process.env.NUMBER_OF_MY_REPOS_TO_LOOK_AT || '2',
    10,
  );
  const numberOfStargazersPerRepo = parseInt(
    process.env.NUMBER_OF_STARGAZERS_PER_REPO || '2',
    10,
  );
  const maxStarredReposPerUser = parseInt(
    process.env.MAX_STARRED_REPOS_PER_USER || '100',
    10,
  );

  await analyzer.analyzeStarPatterns(
    myUsername,
    numberOfMyReposToLookAt,
    numberOfStargazersPerRepo,
    maxStarredReposPerUser,
  );
}

main();
