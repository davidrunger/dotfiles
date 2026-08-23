abstract class CommandLineTool
  protected def capture_command(command : String, arguments : Array(String)) : String
    output = IO::Memory.new
    run_process(command, arguments, output: output)
    output.to_s
  end

  protected def run_command(
    command : String,
    arguments = [] of String,
    *,
    env : Process::Env = nil,
  ) : Process::Status
    run_process(command, arguments, env: env, output: Process::Redirect::Inherit)
  end

  protected def run_command!(command : String, arguments : Array(String))
    status = run_command(command, arguments)
    exit(status.exit_code) if !status.success?
  end

  private def run_process(
    command : String,
    arguments : Array(String),
    *,
    env : Process::Env = nil,
    output : Process::Stdio,
  ) : Process::Status
    Process.run(
      command,
      arguments,
      env: env,
      input: Process::Redirect::Inherit,
      output: output,
      error: Process::Redirect::Inherit,
    )
  end
end
