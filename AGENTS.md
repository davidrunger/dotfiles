# Global Guidance

## Text and source formatting

- Generally use ASCII characters in code and commit messages.
- Use non-ASCII characters only when there is a specific reason, such as rendering that character to a user.
- Keep code generally hard-wrapped in accordance with repository formatters, linters, and surrounding style.
- Do not hard-wrap prose or template text solely to enforce a fixed line width. Let editors and viewers visually wrap long lines. In particular, keep long text paragraphs in `.vue` and Haml templates on a single source line unless line breaks are semantically or structurally useful. This avoids reflow-only diffs when the text changes.

## Git workflow

- When starting a change that does not already have a designated branch, create a dedicated branch from the latest `origin/main` before editing. When resuming work that already has a task branch, continue using that branch rather than creating another. Treat starting a new branch anywhere other than `origin/main` as a rare exception that requires explicit direction. A typical branch setup is:

  ```sh
  git fetch origin main
  git switch -c <branch-name> origin/main
  ```

- When it makes the branch clearer, prefix the branch name with a short, lowercase form of the anticipated commit subject area and a slash. Prefer matching the subject area after normalizing it for a branch name instead of shortening it to a broader category or changing its established pluralization; for example, `[docker-compose]` should use `docker-compose/...`, not `docker/...`, and `[quizzes]` should use `quizzes/...`, not `quiz/...`. Accordingly, `[AGENTS.md] Keep approval requests narrow` could use `agents-md/keep-approval-requests-narrow`. This is a preference rather than a strict mapping; use a different clear name when the subject area is not known up front or would not make a useful branch prefix.
- After creating the branch, configure it to track `origin/main`:

  ```sh
  git branch --set-upstream-to=origin/main
  ```

  This keeps the branch's ahead/behind counts relative to `origin/main`.

- Do not push branches or otherwise modify remote or GitHub state unless the user explicitly requests it.
- When explicitly asked to push, send the current branch to the same-named branch on `origin` while preserving `origin/main` as the upstream. Use a command compatible with the machine's Git configuration; do not use `-u` or otherwise change the upstream to `origin/<branch-name>`.
- Before the branch has been pushed to a remote, keep its work in a single commit and amend that commit as needed.
- When a relevant code change is amended into a commit, update the commit message as needed so it accurately describes the commit's final contents.
- Do not rewrite a commit after it has been pushed. Make subsequent changes in a new commit. That new commit may itself be amended until it is pushed.

## Commit messages

- Format the first commit title on a branch as `[subject area] Imperative title [JIRA-123]`. This title becomes the GitHub pull request title and the eventual commit title on `main`, where the subject area and Jira issue are useful.
- Format subsequent commit titles as `Imperative title`, omitting both the subject area and Jira suffix.
- For the first commit, choose the narrowest useful subject area that identifies the principal code or concern changed. Consult recent commit history for analogous scopes instead of defaulting to a broad label. When a change spans a named app or feature, use that area's established name, including its exact pluralization, rather than deriving a new name from one model or resource; for example, use `[quizzes]`, not `[quiz]`, for changes across the Quizzes app. Subject areas are not limited to a fixed list and may identify a path, subsystem, class, or file; for example, `[spec/features/logs]` may be more useful than `[specs]`.
- In the first commit title, use the subject area to name the area affected and the imperative title to describe the specific change within that area. The two parts should contribute complementary information rather than repeat each other. A filename is a useful subject area when the imperative title does not otherwise identify it, as in `[AGENTS.md] Keep approval requests narrow`. When the imperative title needs to name the file, choose a complementary subject area instead, as in `[docs] Add AGENTS.md` rather than `[AGENTS.md] Add AGENTS.md`.
- When the user associates a Jira issue key, such as `LOG-11`, with the requested change, append `[LOG-11]` to the title of the first commit on the branch even if the user does not separately request that in the commit instructions. Do not repeat the Jira suffix on subsequent commits. Omit it entirely only when no issue key applies.
- Keep the entire commit title at or below 69 characters.
- Prefer clear, direct commit titles. Shorter wording is better when it is equally clear or clearer, but do not sacrifice useful specificity merely to minimize length.
- Do not use backticks in commit titles. Keep titles as plain text because GitHub's special rendering of backtick-delimited text hurts the searchability of commit and pull request titles.
- Write a detailed commit message body. Include relevant context, history, documentation links, reasoning and motivation, and consciously chosen tradeoffs where they will help a future reader understand the change.
- Use Markdown code formatting in commit message bodies for code identifiers, commands, file paths, environment variables, literal values, and other code-like text. Use inline backticks for short spans and fenced code blocks for multiline examples when useful.
- In commit message bodies, use double quotes rather than backticks for concrete user-facing copy, error messages, labels, and other prose phrases when discussing their wording or presentation, even if the text is implemented as a string literal. Use backticks when discussing the source-level literal or code expression itself.
- When a change is motivated by, follows from, or corrects a specific earlier commit or pull request, reference that change in the commit message body. Include the pull request number or link, the commit hash on `main`, or both, choosing enough detail for a future reader to locate it.

## General tooling

- Keep commands that may require elevated permissions separate from sandbox-safe or read-only commands. In particular, do not combine Git state-changing operations with file-inspection commands in the same shell invocation. Run them separately so that any approval request is narrow and transparent.
- Prefer repository-provided wrappers and binstubs over commands that bypass them.
- Use `pnpm` for JavaScript package management, unless the project is already using a different tool (e.g. as evidenced by a `yarn.lock` file).
- Do not add a dependency in any environment, including development or test, without the user's explicit consent. Dependency additions carry supply-chain, vulnerability, and local-machine risks.

## Test workflow

- Run targeted tests while developing, and run targeted linters on changed files when they provide useful feedback.
- Use CI as the portable broad-check mechanism. Do not assume that local helper commands are installed, and do not push merely to trigger CI.

## Test design

- When an RSpec example description contains an apostrophe, delimit the string with double quotes rather than escaping the apostrophe in a single-quoted string. RSpec omits the escape character from documentation output, so keeping the source text identical to the rendered description makes the example searchable.
- Prefer reusing fixtures over creating new database records when an appropriate fixture is easy to select and its specific identity is not behaviorally significant. This keeps tests faster without coupling them to incidental fixture details.
- Keep tests focused on the behavior under test. Set up only attributes and conditions that are relevant to that behavior.
- Express required relationships directly instead of relying on incidental fixture identities.
- Avoid confounding conditions in regression tests. Construct the example so that the rule under test, not an unrelated validation, privacy setting, authorization rule, or fixture detail, determines the outcome.
- Before adding a test-specific condition, ask whether changing that condition should affect the expected result. If not, omit it.
- Keep example descriptions aligned with the behavior the expectations actually verify. Do not claim that a method was or was not called, state changed, or side effect occurred unless an expectation directly checks it; add the missing expectation or describe only the verified behavior.
- Prefer exercising real application behavior over stubs and mocks when reasonably possible. Treat `instance_double`, `and_return`, and similar constructs as last resorts; prefer `and_call_original` or real objects and deliveries when that keeps the test focused and manageable. This is a preference, not a blanket prohibition.
- When observing a method call, use `and_call_original` whenever reasonably possible rather than a bare stub or `and_return`. Replace the original behavior only when it cannot safely be exercised or isolation genuinely requires replacement; do not rely on a judgment that the original behavior is merely irrelevant.
- When reasonably possible, make each `context` establish the condition described in its own label through immediately scoped `before` setup and/or `let` declarations. Nested contexts should refine that established premise rather than being solely responsible for making an ancestor context true.
- Prefer declaring a `let` when it is overridden by a nested context, referenced directly by an expectation, or otherwise needed to express setup. Avoid extracting a one-off value into a `let` merely to make another declaration more readable when that extraction would obscure why the `let` exists or make an incidental refactor look behaviorally necessary.

## Ruby conventions

- When a computed result is reused, prefer memoizing the method rather than assigning a same-named local variable solely to avoid recomputation. Use the repository's `Memoization` pattern where available.

## Naming

- Prefer names that communicate a value's type or role at method boundaries. For example, use `recipient_email` rather than `recipient` when a value is an email address, especially when another parameter such as `actor` is an object.

## Generated files

- When a file says that it is generated, find and run its owning generator instead of editing the output.
