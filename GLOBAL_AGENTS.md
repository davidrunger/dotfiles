# Global Guidance

Note: `GLOBAL_AGENTS.md` in `~/code/dotfiles` is the canonical global instruction file and is symlinked to `~/.codex/AGENTS.md`. `AGENTS.md` in that repository is repository-specific. Make standalone global-instruction changes on a dedicated `global-agents/...` branch and commit them; include a relevant global clarification in another task only when requested. Do not edit a repository-local `AGENTS.md` as a substitute.

## Text and source formatting

- Prefer ASCII in code and commit messages; use non-ASCII when purposeful, such as for user-facing rendering.
- Follow formatters and surrounding style for code. Do not reflow prose or templates just to enforce a line width; keep long text paragraphs in `.vue` files and Haml templates on one source line unless line breaks are semantically or structurally useful. This avoids reflow-only diffs when text changes.
- Use blank lines to separate logical steps and unrelated guards or conditionals.
- Default to American English. If the user requests another variety, confirm that it is intentional.
- Preserve alphabetical ordering when it is clearly a list's organizing principle, and consider it for new lists.

## Git workflow

- Start new work on a dedicated branch from the latest `origin/main`; resume an existing task branch. Branch elsewhere only when explicitly directed. Typical setup:
  ```sh
  git fetch origin main
  git switch -c <branch-name> origin/main
  git branch --set-upstream-to=origin/main
  ```
  This keeps the branch's ahead/behind counts relative to `origin/main`.
- Add a short, lowercase subject-area prefix when useful. Match established names and pluralization (`quizzes/...`, not `quiz/...`), preserve path hierarchy (`spec/features/logs/...`), use dashes rather than underscores, and omit Jira keys.
- Do not push or otherwise change remote or GitHub state without an explicit request. When asked to push, send the current branch to the same-named `origin` branch without changing its `origin/main` upstream; do not use `-u`.
- Commit completed work on its task branch unless asked not to. Before the first push, keep the branch's work in one commit and amend as needed so GitHub can use that commit's title and body as the pull request title and description; multiple initial commits prevent that. After the first push, follow-up commits may be separate.
- Never amend `main` or rewrite a pushed commit. Before amending, check reachability from remote refs, especially `origin/<current-branch>`; a branch tracking `origin/main` may still have a pushed same-named branch, so ahead/behind counts alone are insufficient. If pushed, make a follow-up commit. Update the message when amended code changes require it.

## Changelogs

- If a repository has a changelog, add an entry for each non-trivial user-facing change on the implementation branch, following that repository's filename and format.

## Commit messages

- Use `[subject area] Imperative title [JIRA-123]` for a branch's first commit when a useful area exists, or omit the area otherwise. Add a Jira key when it appears in the request or its copied ticket text; do not carry it into a separate tooling, maintenance, or side task unless relevant. Later titles are imperative and omit the area and Jira suffix. Keep titles within 69 characters and prefer clear, concise wording.
- Choose the narrowest useful area, consulting recent history. Preserve meaningful capitalization, spacing, punctuation, and pluralization. The area and title should usually complement each other; repetition is fine when natural. Examples: `[quizzes]` rather than `[quiz]`, `[ClimProgram]` rather than `[clim-program]`, and `[emoji picker]` rather than `[emoji-picker]`.
- For version bumps, name both versions in the title when possible (for example, `[docker-compose] Bump PostgreSQL from 18.4 to 18.6`). Shorten the rest of the title before omitting a version; omit one only when needed to fit or when including it would mislead. If omitted, state both versions in the body.
- Do not use backticks in titles; use single quotes to set off code-like text.
- Add a final standalone `codex resume UUID` line to the first commit created or rewritten on a branch for each Codex conversation. Use `CODEX_THREAD_ID` when available; retain prior conversation lines, append the current one, and do not duplicate it. If the target commit is pushed, do not rewrite it; add the line to the conversation's first new commit instead. Keep resume lines at the very bottom without backticks.
- Write bodies with enough context, history, evidence, links, reasoning, and tradeoffs for future readers to understand the change without this conversation. Do not mention conversation-only details or routine checks covered by CI. Keep paragraphs unwrapped. Refer to earlier commits or pull requests by number, link, or `main` hash; use the raw full URL for pull requests in another repository.
- In bodies, put code identifiers, commands, paths, environment variables, source-level literals, and similar text in Markdown backticks. Use double quotes for user-facing copy when discussing its wording. Do not backtick SHAs; GitHub auto-links bare SHAs but not backticked ones. Before committing, scan each paragraph for formatting; inspect and verify the stored message afterward.
- Pass each title and body paragraph as a separate `git commit -m` argument; never embed `\n` escapes. For shell-sensitive text, use single-quoted arguments when possible. If the message contains both single quotes and shell-sensitive text, write it with `apply_patch` and pass it using `git commit --file`; do not use an unquoted heredoc. Inspect the stored message. Example:
  ```sh
  git commit -m '[release-tasks] Retry migrations' -m 'Re-enable `db:migrate` before retrying it.'
  ```

## General tooling

- Keep commands needing approval separate from safe reads; run mutations separately from inspection (for example, do not combine Git changes with file reads). Prefer repository wrappers and binstubs.
- Prefer installed JavaScript executables in `./node_modules/.bin/` over `pnpm exec`; use `pnpm exec` when workspace resolution or layout requires it. Use `pnpm` for package management unless the project uses another tool.
- For whole-repository RuboCop runs, use `run-rubocop` so only tracked files are linted; use the repository wrapper or binstub for targeted files.
- Do not add dependencies in any environment without the user's explicit consent.

## Model associations

- Prefer explicit join models and `has_many :through` over `has_and_belongs_to_many`; this leaves room for validations, behavior, and future relationship attributes. Name joins for the domain concept when one exists (for example, `ItemAvailability`); combine model names when that is clearest.

## Persistence and side effects

- Prefer explicit application actions over ActiveRecord lifecycle callbacks for side effects such as jobs, mail, broadcasts, cache invalidation, related-record updates, and external services. Callbacks hide work and run on every persistence path, including factories, imports, migrations, and unrelated calls.
- Actions should persist first, then perform or enqueue the side effect only after persistence succeeds and the transaction commits. Update every relevant action and test the handoff.
- Treat lifecycle callbacks as exceptions requiring a concrete justification. Do not use one just to avoid finding the actions that perform the work; document why a callback is necessary.

## User interface conventions

- Style new controls so they look polished and communicate their purpose, preferring existing classes, components, and patterns. If no suitable pattern exists, add a reusable one or ask when the design is unclear.
- For a single form control, wrap it in its `<label>` when semantically suitable; use explicit `id`/`for` when the label and control need to remain separate.

## Test workflow

- Run targeted tests during development and useful linters on changed files. Use CI for portable broad checks; do not assume local helpers exist or push just to trigger CI.

## Test design

- In RSpec, use `specify` for examples without descriptions, except natural forms such as `it { is_expected.to ... }`. Use double-quoted descriptions when the text contains an apostrophe; RSpec omits escape characters in documentation output, so the source matches the rendered text and stays searchable.
- Reuse suitable fixtures when identity is not behaviorally important. Keep setup focused on relevant conditions. Prefer hardcoded, independent expected values; derive them only when literals are excessively verbose or brittle, or when a value is shared setup or input.
- Test behavior rather than implementation or styling, except when presentation is the behavior. Avoid regression specs for implementation details you would not specify for a feature built from scratch; a migration may warrant one if its path protects meaningful behavior. Merely rendering a native element or library component usually does not.
- In browser-driven specs, establish state through real UI actions when practical. Use direct setup when browser setup is impractical or outside the behavior under test.
- Express required relationships directly and isolate the rule under test from unrelated validations, privacy settings, authorization, or fixture details. Omit setup conditions whose changes should not affect the expected result.
- Keep descriptions aligned with what expectations verify. Do not claim a call or state change without checking it.
- Prefer real application behavior to stubs and mocks. Use `instance_double`, `and_return`, or replacements only when the real behavior is unsafe or isolation requires it. When observing calls, prefer `and_call_original` unless replacement is necessary.
- Make each `context` establish its labeled condition through scoped setup; nested contexts should refine it. Share repeated setup, keep sibling cases balanced, put examples before nested contexts, and use a `context` for a `when` premise with a focused example description.
- Declare `let` when overridden in nested contexts, used by expectations, or needed to express setup; avoid one-off extraction that obscures purpose or makes incidental refactors look required.
- For negative expectations, share expected values with positive checks through a `let` when practical, and make absence/mismatch checks broad unless the test intentionally permits other outcomes.

## Ruby conventions

- When reusing a computed result, prefer memoizing the method over a same-named local variable; use the repository's `Memoization` pattern when available.

## Conditional expressions

- Choose `if` or `unless` based on which state the predicate describes: use `if !expected_thing_is_true?` for an exceptional path when the expected state is the default, and `unless unexpected_thing_is_true?` for an unexpected condition. With an `else`, use `if`. For example, use `if !admin_user_signed_in?` when signed-in is expected, but `unless Flipper.enabled?(:disable_prerendering)` when the flag is normally off.

## Naming

- Name return-value methods as nouns (`neutralized_formula`) and side-effect methods as verbs.
- At method boundaries, name values for their type or role; use `recipient_email` rather than `recipient` when the value is an email address and another argument is an object such as `actor`.

## Generated files

- When a file says it is generated, run its owning generator instead of editing the output.
