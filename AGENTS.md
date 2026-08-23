# Crystal CLI conventions

For command-line programs under `crystal-programs/`:

- Prefer `Clim` for CLI parsing and help generation. Have executable CLI classes inherit from `ClimProgram` in `utils/crystal/clim_program.cr` and invoke their inherited `start!` method for consistent parse-error output and nonzero exit statuses.
- When a command-line tool delegates work to child processes, inherit from `CommandLineTool` in `utils/crystal/command_line_tool.cr` to share command execution and output capture behavior.
- Use typed `Clim` options such as `Bool` and `Int32`, and declare positional arguments with `argument`.
- Mark required positional arguments with `required: true`.
- Use lowercase argument names, such as `argument "file"`, so that the generated help output and the `usage` string can use the same label.
- Keep the `usage` string consistent with the generated argument label. For example, use `usage "ghist file [options]"`, not `usage "ghist FILE [options]"`.
- `usage` controls the help text; it does not constrain parsing order. `Clim` accepts options before or after positional arguments.
- Prefer listing positional arguments before `[options]` in `usage` when both orders are valid, to reflect the preferred invocation style.
- `Clim` permits extra positional arguments by default. When a command requires an exact number, validate `args.all_args` in its `run` block.
