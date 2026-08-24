# Global Guidance

Note: `~/code/dotfiles/GLOBAL_AGENTS.md` is the canonical source for my global Codex instructions and is symlinked to `~/.codex/AGENTS.md`. It is distinct from `~/code/dotfiles/AGENTS.md`, which contains instructions for the `dotfiles` repository itself. When global-instruction work is standalone, edit `GLOBAL_AGENTS.md` in my `dotfiles` repository on a dedicated task branch with a commit, using the `global-agents/` prefix for that branch. When a global-instruction clarification is directly relevant to another requested change, it may be included in that change's existing task branch and commit when explicitly requested. Do not modify a repository-local `AGENTS.md` instead.

## Text and source formatting

- Generally use ASCII characters in code and commit messages.
- Use non-ASCII characters only when there is a specific reason, such as rendering that character to a user.
- Keep code generally hard-wrapped in accordance with repository formatters, linters, and surrounding style.
- Do not hard-wrap prose or template text solely to enforce a fixed line width. Let editors and viewers visually wrap long lines. In particular, keep long text paragraphs in `.vue` and Haml templates on a single source line unless line breaks are semantically or structurally useful. This avoids reflow-only diffs when the text changes.
- Use blank lines to make separate logical steps visually distinct. In particular, separate adjacent guard or conditional blocks when they perform unrelated work, and apply the same principle to other adjacent statements or blocks whose relationship is not obvious.
- Use American English spelling and vocabulary by default.
- When adding an item to a list, check whether the existing list is sorted alphabetically. If it is, try to determine whether alphabetical order is the list's organizing principle; if it appears to be, insert the new item alphabetically as well. When creating a new list, consider using alphabetical order as its organizing principle if no better or clearer organizing rule comes to mind.
- If the user requests non-American English spelling or vocabulary, confirm that this is intentional before starting work.

## Git workflow

- When starting a change that does not already have a designated branch, create a dedicated branch from the latest `origin/main` before editing. When resuming work that already has a task branch, continue using that branch rather than creating another. Treat starting a new branch anywhere other than `origin/main` as a rare exception that requires explicit direction. A typical branch setup is:

  ```sh
  git fetch origin main
  git switch -c <branch-name> origin/main
  ```

- When it makes the branch clearer, prefix the branch name with a short, lowercase form of the anticipated commit subject area and a slash. Prefer matching the subject area after normalizing it for a branch name instead of shortening it to a broader category or changing its established pluralization; for example, `[docker-compose]` should use `docker-compose/...`, not `docker/...`, and `[quizzes]` should use `quizzes/...`, not `quiz/...`. Prefer multiple slashes when they preserve a natural path-like hierarchy instead of flattening the prefix with hyphens; for example, `[spec/features/logs]` should use `spec/features/logs/...`, not `spec-features-logs/...`. Accordingly, `[AGENTS.md] Keep approval requests narrow` could use `agents-md/keep-approval-requests-narrow`. This is a preference rather than a strict mapping; use a different clear name when the subject area is not known up front or would not make a useful branch prefix.
- Generally use dashes to separate words in branch names rather than underscores.
- Do not include Jira issue keys in branch names. Keep the associated Jira key in the first commit title instead.
- After creating the branch, configure it to track `origin/main`:

  ```sh
  git branch --set-upstream-to=origin/main
  ```

  This keeps the branch's ahead/behind counts relative to `origin/main`.

- Do not push branches or otherwise modify remote or GitHub state unless the user explicitly requests it.
- After implementing a requested change, commit the completed work on its task branch before handing it back, unless the user specifically asks not to commit. This makes the agent's responses to review feedback easy to compare as follow-up commits in the Git reflog.
- When explicitly asked to push, send the current branch to the same-named branch on `origin` while preserving `origin/main` as the upstream. Use a command compatible with the machine's Git configuration; do not use `-u` or otherwise change the upstream to `origin/<branch-name>`.
- Before the branch has been pushed to a remote, keep its work in a single commit and amend that commit as needed.
- Never amend a commit on `main`. Check the current branch before amending any commit; if it is `main`, create or switch to a dedicated branch first.
- Before amending, check whether the target commit is reachable from remote refs, particularly `origin/<current-branch>`. Do not rely only on ahead/behind counts against the configured upstream, because a task branch may track `origin/main` even after its commit has been pushed to the same-named remote branch. If the commit has been pushed, make a follow-up commit instead.
- When a relevant code change is amended into a commit, update the commit message as needed so it accurately describes the commit's final contents.
- Do not rewrite a commit after it has been pushed. Make subsequent changes in a new commit. That new commit may itself be amended until it is pushed.

## Changelogs

- If a repository maintains a changelog, any non-trivial, user-facing change must include a corresponding changelog entry on the implementation branch. Follow the repository's convention for the changelog's filename and structure rather than assuming that it is named `CHANGELOG.md`.

## Commit messages

- Format the first commit title on a branch as `[subject area] Imperative title [JIRA-123]`. This title becomes the GitHub pull request title and the eventual commit title on `main`, where the subject area and Jira issue are useful.
- Add a final standalone line to the first commit that the current Codex conversation creates or rewrites on a branch in the form "codex resume [uuid]", replacing `[uuid]` with the current Codex conversation UUID (use `CODEX_THREAD_ID` when it is available). Do this even when earlier commits already exist on the branch. A pre-existing commit may be rewritten to attach the current conversation's UUID when it has not been pushed. If that commit already has one or more "codex resume [uuid]" lines from other conversations, append the current conversation's line after them instead of replacing them; do not duplicate the current conversation's line when it is already present. Do not rewrite a pushed commit; put the line on the conversation's first new commit instead. Keep these lines at the very bottom of the message, after all body paragraphs. Do not surround them with Markdown backticks.
- Format subsequent commit titles as `Imperative title`, omitting both the subject area and Jira suffix.
- For the first commit, choose the narrowest useful subject area that identifies the principal code or concern changed. Consult recent commit history for analogous scopes instead of defaulting to a broad label. When a change spans a named app or feature, use that area's established name, including its exact pluralization, rather than deriving a new name from one model or resource; for example, use `[quizzes]`, not `[quiz]`, for changes across the Quizzes app. Subject areas are not limited to a fixed list and may identify a path, subsystem, class, or file; for example, `[spec/features/logs]` may be more useful than `[specs]`.
- Preserve meaningful capitalization, spacing, punctuation, and word boundaries in subject area names instead of automatically lowercasing or dasherizing them. For example, use `[ClimProgram]` for a class name and `[emoji picker]` for an app name, rather than `[clim-program]` or `[emoji-picker]`.
- In the first commit title, use the subject area to name the area affected and the imperative title to describe the specific change within that area. The two parts should contribute complementary information rather than repeat each other. A filename is a useful subject area when the imperative title does not otherwise identify it, as in `[AGENTS.md] Keep approval requests narrow`. When the imperative title needs to name the file, choose a complementary subject area instead, as in `[docs] Add AGENTS.md` rather than `[AGENTS.md] Add AGENTS.md`.
- When the user associates a Jira issue key, such as `LOG-11`, with the requested change, append `[LOG-11]` to the title of the first commit on the branch even if the user does not separately request that in the commit instructions. Do not repeat the Jira suffix on subsequent commits. Omit it entirely only when no issue key applies.
- A Jira issue key is reasonably associated with a change when it appears in the user request for that change; a ticket key and its copied ticket text in the initial request are sufficient. Do not carry a Jira key into a later, separately requested tooling, maintenance, or side-task change unless that request reasonably relates to the issue.
- Keep the entire commit title at or below 69 characters.
- Prefer clear, direct commit titles. Shorter wording is better when it is equally clear or clearer, but do not sacrifice useful specificity merely to minimize length.
- When a commit bumps a version, name both the prior and new versions in its title, using wording such as `[docker-compose] Bump PostgreSQL from 18.4 to 18.6`, whenever a clear title including both fits within the 69-character limit. If including both would exceed that limit, first shorten the rest of the title; omit either version only when necessary to stay within the limit or when including it would be misleading. If a version is omitted from the title, name both versions in the commit body.
- Do not use backticks in commit titles. GitHub does not render backtick-delimited text in pull request titles, and the missing backticks make those titles harder to search for in git history. When a title needs to set off code-like text, use single quotes instead; they remain visible and make the title easy to copy and search.
- Write a detailed commit message body. Include relevant context, history, documentation links, reasoning and motivation, and consciously chosen tradeoffs where they will help a future reader understand the change.
- Do not mention standard checks or tests run in commit messages when they are expected to run in CI or an equivalent automated workflow. Mention validation only when it was non-standard and will not be covered by CI or an equivalent check.
- When passing a multi-paragraph commit message on the command line, use a separate `-m` option for the title and each body paragraph. Do not embed `\n` escape sequences in a `-m` argument; shells can pass them literally and cause Git to store the backslash characters instead of newlines. After committing or amending, inspect the stored message to confirm that its paragraphs are formatted correctly.
- When a commit message contains Markdown backticks, `$()`, dollar signs, or other shell-sensitive text, never place it in a double-quoted shell argument. Prefer separate single-quoted `-m` arguments when the message does not contain single quotes:

  ```sh
  git commit \
    -m '[release-tasks] Retry migrations' \
    -m 'Re-enable `db:migrate` before retrying it.'
  ```

  If the message contains both single quotes and shell-sensitive text, write it to a temporary file using `apply_patch`, then use `git commit --file <path>`. Do not use an unquoted heredoc. Inspect the stored message after committing or amending.

- Use Markdown code formatting in commit message bodies for code identifiers, commands, file paths, environment variables, literal values, and other code-like text. Use inline backticks for short spans and fenced code blocks for multiline examples when useful. Treat this as a pre-commit gate: before every commit or amend, scan each body paragraph for these terms and add the required formatting. After committing or amending, inspect the stored message and explicitly verify that every such term is formatted before reporting completion or pushing.
- Do not put commit SHAs in backticks in commit messages. GitHub automatically linkifies unformatted SHAs, but does not linkify SHAs enclosed in backticks.
- In commit message bodies, use double quotes rather than backticks for concrete user-facing copy, error messages, labels, and other prose phrases when discussing their wording or presentation, even if the text is implemented as a string literal. Use backticks when discussing the source-level literal or code expression itself.
- When a change is motivated by, follows from, or corrects a specific earlier commit or pull request, reference that change in the commit message body. Include the pull request number or link, the commit hash on `main`, or both, choosing enough detail for a future reader to locate it.
- When referencing a pull request in another repository, include its raw full URL rather than only its number or a Markdown-formatted link. GitHub can present the raw URL appropriately, while the stored Git history remains simple and unambiguous.

## General tooling

- Keep commands that may require elevated permissions separate from sandbox-safe or read-only commands. In particular, do not combine Git state-changing operations with file-inspection commands in the same shell invocation. Run them separately so that any approval request is narrow and transparent.
- Prefer repository-provided wrappers and binstubs over commands that bypass them.
- When linting an entire repository with RuboCop, use `run-rubocop` so that only git-tracked files are linted. Use the repository's RuboCop wrapper or binstub for targeted files.
- Use `pnpm` for JavaScript package management, unless the project is already using a different tool (e.g. as evidenced by a `yarn.lock` file).
- Do not add a dependency in any environment, including development or test, without the user's explicit consent. Dependency additions carry supply-chain, vulnerability, and local-machine risks.

## Persistence and side effects

- Strongly prefer explicit application actions over ActiveRecord lifecycle callbacks (`after_create`, `after_create_commit`, and similar callbacks) for side effects of any kind. This includes enqueuing background jobs, sending mail, broadcasting, invalidating caches, updating related records, and calling external services. Model callbacks hide work from callers and run for every creation or update path, including factories, imports, migrations, and unrelated code paths.
- When a record operation should trigger a side effect, use or create an action that persists the record and explicitly performs or enqueues the side effect after the persistence operation succeeds. Keep the action's transaction boundary clear, and ensure the side effect happens only after the transaction commits. Update every relevant action and test the handoff directly.
- Treat a lifecycle callback as an exception that requires a concrete justification. Do not add `after_create_commit` or another lifecycle hook merely to avoid finding the actions that perform the operation; document why a callback is necessary when one is genuinely required.

## User interface conventions

- Give new user-facing controls and elements deliberate styling so that they look polished and communicate their purpose visually. Prefer existing classes, CSS, components, and presentation patterns when suitable. When the project has no suitable existing pattern, consider adding a reusable one or ask the user for guidance when the appropriate design is unclear.

## Test workflow

- Run targeted tests while developing, and run targeted linters on changed files when they provide useful feedback.
- Use CI as the portable broad-check mechanism. Do not assume that local helper commands are installed, and do not push merely to trigger CI.

## Test design

- When an RSpec example description contains an apostrophe, delimit the string with double quotes rather than escaping the apostrophe in a single-quoted string. RSpec omits the escape character from documentation output, so keeping the source text identical to the rendered description makes the example searchable.
- Prefer reusing fixtures over creating new database records when an appropriate fixture is easy to select and its specific identity is not behaviorally significant. This keeps tests faster without coupling them to incidental fixture details.
- Keep tests focused on the behavior under test. Set up only attributes and conditions that are relevant to that behavior.
- Lean toward hardcoding expected values in specs rather than deriving them from application code or the object under test. An independent expected value helps the spec catch incorrect implementation. Deriving a value is reasonable when the literal would be excessively verbose, brittle, or difficult to maintain, or when the value is explicitly test input, shared by multiple expectations, or otherwise part of setup rather than the expected result.
- Generally test behavior and semantics rather than presentation details such as CSS classes or styling. Assert styling only when the presentation itself is the behavior under test.
- In feature specs and other browser-driven tests, prefer establishing state through real browser actions, such as clicking controls, submitting forms, or navigating, whenever reasonably possible. Avoid artificially manipulating the situation through direct database updates or internal method calls when the browser can perform the same action; use direct setup when browser-driven setup would be impractical or outside the behavior under test.
- Express required relationships directly instead of relying on incidental fixture identities.
- Avoid confounding conditions in regression tests. Construct the example so that the rule under test, not an unrelated validation, privacy setting, authorization rule, or fixture detail, determines the outcome.
- Before adding a test-specific condition, ask whether changing that condition should affect the expected result. If not, omit it.
- Keep example descriptions aligned with the behavior the expectations actually verify. Do not claim that a method was or was not called, state changed, or side effect occurred unless an expectation directly checks it; add the missing expectation or describe only the verified behavior.
- Prefer exercising real application behavior over stubs and mocks when reasonably possible. Treat `instance_double`, `and_return`, and similar constructs as last resorts; prefer `and_call_original` or real objects and deliveries when that keeps the test focused and manageable. This is a preference, not a blanket prohibition.
- When observing a method call, use `and_call_original` whenever reasonably possible rather than a bare stub or `and_return`. Replace the original behavior only when it cannot safely be exercised or isolation genuinely requires replacement; do not rely on a judgment that the original behavior is merely irrelevant.
- When reasonably possible, make each `context` establish the condition described in its own label through immediately scoped `before` setup and/or `let` declarations. Nested contexts should refine that established premise rather than being solely responsible for making an ancestor context true.
- Duplicated setup in adjacent `context` blocks is a smell; consider extracting a shared outer `context` and using nested contexts to make their differing conditions explicit.
- Within a `context`, place any directly nested `context` blocks after the `it` examples that belong to that same `context`.
- Prefer balanced sibling `context` blocks for distinct cases over treating one case as an implicit default. Keep only genuinely shared setup outside those contexts.
- When an example description includes a "when" condition, use a `context` to establish that condition through scoped setup, and keep the example description focused on the behavior it verifies. This makes the premise explicit and keeps sibling cases balanced.
- Prefer declaring a `let` when it is overridden by a nested context, referenced directly by an expectation, or otherwise needed to express setup. Avoid extracting a one-off value into a `let` merely to make another declaration more readable when that extraction would obscure why the `let` exists or make an incidental refactor look behaviorally necessary.
- When a spec checks that a user-facing label, control, or other value is absent or otherwise does not match, share the expected value with positive expectations through a `let` when reasonably possible. This keeps negative expectations from passing falsely when the application changes but the negative expectation is not updated.

## Ruby conventions

- When a computed result is reused, prefer memoizing the method rather than assigning a same-named local variable solely to avoid recomputation. Use the repository's `Memoization` pattern where available.

## Conditional expressions

- Choose between `if` and `unless` based on the expected state, not only on logical equivalence. When the predicate describes the expected or default state, prefer `if !expected_thing_is_true?` for the exceptional path rather than `unless expected_thing_is_true?`. Prefer `unless unexpected_thing_is_true?` when `unexpected_thing_is_true?` describes an unexpected condition. For example, use `if !admin_user_signed_in?` when a signed-in AdminUser is the default assumption, but `unless Flipper.enabled?(:disable_prerendering)` when the disable flag is normally off. When an `else` branch is present, use `if` rather than `unless`.

## Naming

- Name a method or function that is used primarily for its return value as a noun describing what it returns, such as `neutralized_formula`. Use a verb name only when the method or function is used primarily for a side effect.
- Prefer names that communicate a value's type or role at method boundaries. For example, use `recipient_email` rather than `recipient` when a value is an email address, especially when another parameter such as `actor` is an object.

## Generated files

- When a file says that it is generated, find and run its owning generator instead of editing the output.
