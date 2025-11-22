defmodule Mix.Tasks.Deploy do
  @moduledoc """
  Automated deployment task for Symphony.

  Checks for new commits on origin/main, runs tests, builds release, and restarts service.
  """
  use Mix.Task

  @repo_dir "/home/zack/dev/whiteboard"
  @service_name "whiteboard"
  @deploy_target "/var/lib/whiteboard"

  def run(args) do
    force = "--force" in args

    log("Starting deployment check...")

    File.cd!(@repo_dir)

    configure_git_credentials()

    log("Fetching from origin...")
    git!(["fetch", "origin"])

    local_commit = git!(["rev-parse", "main"]) |> String.trim()
    remote_commit = git!(["rev-parse", "origin/main"]) |> String.trim()

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

    log("Installing production dependencies...")
    System.put_env("MIX_ENV", "prod")
    mix!(["deps.get", "--only", "prod"])

    log("Compiling application...")
    mix!(["compile"])

    log("Running tests...")
    System.put_env("MIX_ENV", "test")
    mix!(["test"])

    log("Running database migrations...")
    System.put_env("MIX_ENV", "prod")
    mix!(["ecto.migrate"])

    log("Building production assets...")
    setup_asset_tool_wrappers!()
    mix!(["assets.deploy"])

    log("Building release...")
    mix!(["release", "--overwrite"])

    log("Copying release to #{@deploy_target}...")
    rsync_release!()

    log("Restarting #{@service_name} service...")
    systemctl!(["restart", @service_name])

    log("Waiting for service to start...")
    Process.sleep(2000)

    case systemctl(["is-active", @service_name]) do
      {_, 0} ->
        log("Deployment successful! Service is running.")
        log("Deployed commit: #{String.slice(remote_commit, 0..6)}")

      _ ->
        error("Service failed to start after deployment")
    end
  end

  defp log(message) do
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")
    IO.puts("[#{timestamp}] #{message}")
  end

  defp error(message) do
    log("ERROR: #{message}")
    System.halt(1)
  end

  defp setup_asset_tool_wrappers! do
    build_dir = Path.join(@repo_dir, "_build")
    File.mkdir_p!(build_dir)

    tailwind_wrapper = Path.join(build_dir, "tailwind-linux-x64")
    esbuild_wrapper = Path.join(build_dir, "esbuild-linux-x64")

    File.write!(tailwind_wrapper, """
    #!/usr/bin/env bash
    exec tailwindcss "$@"
    """)
    File.chmod!(tailwind_wrapper, 0o755)

    File.write!(esbuild_wrapper, """
    #!/usr/bin/env bash
    exec esbuild "$@"
    """)
    File.chmod!(esbuild_wrapper, 0o755)
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

  defp git!(args) do
    case System.cmd("git", args, stderr_to_stdout: true) do
      {output, 0} -> output
      {output, _} -> error("Git command failed: #{output}")
    end
  end

  defp mix!(args) do
    case System.cmd("mix", args, stderr_to_stdout: true, env: [{"MIX_ENV", System.get_env("MIX_ENV", "prod")}]) do
      {output, 0} ->
        IO.puts(output)
        output

      {output, _} ->
        IO.puts(output)
        error("Mix command failed: mix #{Enum.join(args, " ")}")
    end
  end

  defp rsync_release! do
    source = Path.join(@repo_dir, "_build/prod/rel/whiteboard") <> "/"

    case System.cmd("/run/wrappers/bin/sudo", ["rsync", "-a", "--delete", source, @deploy_target <> "/"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> error("Release copy failed: #{output}")
    end
  end

  defp systemctl(args) do
    System.cmd("/run/wrappers/bin/sudo", ["systemctl"] ++ args, stderr_to_stdout: true)
  end

  defp systemctl!(args) do
    case systemctl(args) do
      {_, 0} -> :ok
      {output, _} -> error("Systemctl command failed: #{output}")
    end
  end
end
