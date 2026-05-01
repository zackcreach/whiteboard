defmodule Mix.Tasks.Deploy do
  @moduledoc """
  Automated Docker-based deployment task for Whiteboard.

  Checks for new commits on origin/main, builds Docker image, and deploys via Docker Compose.
  """
  use Mix.Task

  @repo_dir "/home/zack/dev/whiteboard"

  def run(args) do
    force = "--force" in args

    log("Starting deployment check...")

    File.cd!(@repo_dir)

    load_dotenv()
    configure_git_credentials()

    log("Fetching from origin...")
    git!(["fetch", "origin"])

    local_commit = ["rev-parse", "main"] |> git!() |> String.trim()
    remote_commit = ["rev-parse", "origin/main"] |> git!() |> String.trim()

    if local_commit == remote_commit and not force do
      log("Already up-to-date (commit: #{String.slice(local_commit, 0..6)})")
      log("Use --force to deploy anyway")
      System.halt(0)
    end

    if force and local_commit == remote_commit do
      log("Force deploying current commit: #{String.slice(local_commit, 0..6)}")
    else
      log("New commits detected (#{String.slice(local_commit, 0..6)} -> #{String.slice(remote_commit, 0..6)})")
      log("Pulling latest changes...")
      git!(["pull", "origin", "main"])
    end

    log("Building Docker image...")
    shell!("./scripts/docker-build.sh")

    log("Deploying with Docker Compose...")
    shell!("./scripts/docker-deploy.sh")

    log("Deployment complete!")
    log("Deployed commit: #{String.slice(remote_commit, 0..6)}")
  end

  defp log(message) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")
    IO.puts("[#{timestamp}] #{message}")
  end

  defp error(message) do
    log("ERROR: #{message}")
    System.halt(1)
  end

  defp configure_git_credentials do
    case System.get_env("GITHUB_TOKEN") do
      nil ->
        log("Warning: GITHUB_TOKEN not set, git operations may fail")

      token ->
        git_credential_helper = """
        #!/bin/sh
        echo "username=git"
        echo "password=#{token}"
        """

        helper_path = Path.join(System.tmp_dir!(), "git-credential-helper")
        File.write!(helper_path, git_credential_helper)
        File.chmod!(helper_path, 0o755)

        System.cmd("git", ["config", "credential.helper", ""], stderr_to_stdout: true)
        System.cmd("git", ["config", "--local", "credential.helper", "!#{helper_path}"], stderr_to_stdout: true)
    end
  end

  defp load_dotenv do
    ".env"
    |> File.read()
    |> case do
      {:ok, contents} ->
        contents
        |> String.split("\n")
        |> Enum.each(&put_dotenv_line/1)

      {:error, :enoent} ->
        log("Warning: .env not found, relying on process environment")

      {:error, reason} ->
        error("Failed to read .env: #{inspect(reason)}")
    end
  end

  defp put_dotenv_line(line) do
    line = String.trim(line)

    cond do
      line == "" ->
        :ok

      String.starts_with?(line, "#") ->
        :ok

      true ->
        put_dotenv_assignment(line)
    end
  end

  defp put_dotenv_assignment("export " <> assignment), do: put_dotenv_assignment(assignment)

  defp put_dotenv_assignment(assignment) do
    case String.split(assignment, "=", parts: 2) do
      [key, value] when key != "" ->
        System.put_env(key, trim_dotenv_value(value))

      _invalid ->
        :ok
    end
  end

  defp trim_dotenv_value(value) do
    value
    |> String.trim()
    |> String.trim_leading("\"")
    |> String.trim_trailing("\"")
    |> String.trim_leading("'")
    |> String.trim_trailing("'")
  end

  defp git!(args) do
    case System.cmd("git", args, stderr_to_stdout: true) do
      {output, 0} -> output
      {output, _} -> error("Git command failed: #{output}")
    end
  end

  defp shell!(command) do
    case System.cmd("sh", ["-c", command], stderr_to_stdout: true, into: IO.stream()) do
      {_, 0} -> :ok
      {_, _} -> error("Command failed: #{command}")
    end
  end
end
