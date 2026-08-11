defmodule Mix.Tasks.Reset.Prod do
  @shortdoc "Replaces the local development database with Symphony production data"

  @moduledoc """
  Replaces the configured local development database with a fresh dump of
  `whiteboard_prod` from Symphony.

  The task only runs in the development environment and only restores to a
  loopback PostgreSQL host.
  """

  use Mix.Task

  @impl Mix.Task
  def run([]) do
    ensure_development_environment!()

    repository_config = Application.fetch_env!(:whiteboard, Whiteboard.Repo)
    ensure_local_database!(repository_config)

    dump_path = dump_path()

    try do
      fetch_production_dump!(dump_path)
      restore_local_database!(dump_path, repository_config)
    after
      File.rm(dump_path)
    end
  end

  def run(_arguments) do
    Mix.raise("mix reset.prod does not accept arguments")
  end

  defp ensure_development_environment! do
    case Mix.env() do
      :dev -> :ok
      environment -> Mix.raise("mix reset.prod only runs in development, not #{environment}")
    end
  end

  defp ensure_local_database!(repository_config) do
    case Keyword.fetch!(repository_config, :hostname) do
      hostname when hostname in ["localhost", "127.0.0.1", "::1"] -> :ok
      hostname -> Mix.raise("mix reset.prod requires a local database host, got #{hostname}")
    end
  end

  defp dump_path do
    Path.join(System.tmp_dir!(), "whiteboard-prod-#{System.unique_integer([:positive])}.dump")
  end

  defp fetch_production_dump!(dump_path) do
    stream = File.stream!(dump_path, [:write, :binary])

    run_command!(
      "ssh",
      [
        "symphony",
        "sudo",
        "-n",
        "-u",
        "postgres",
        "pg_dump",
        "--format=custom",
        "--no-owner",
        "--no-privileges",
        "--dbname=whiteboard_prod"
      ],
      into: stream
    )
  end

  defp restore_local_database!(dump_path, repository_config) do
    run_command!(
      "pg_restore",
      [
        "--clean",
        "--if-exists",
        "--no-owner",
        "--no-privileges",
        "--exit-on-error",
        "--dbname",
        Keyword.fetch!(repository_config, :database),
        dump_path
      ],
      env: database_environment(repository_config)
    )
  end

  defp database_environment(repository_config) do
    [
      {"PGHOST", Keyword.fetch!(repository_config, :hostname)},
      {"PGPORT", Integer.to_string(Keyword.get(repository_config, :port, 5432))},
      {"PGUSER", Keyword.fetch!(repository_config, :username)},
      {"PGPASSWORD", Keyword.fetch!(repository_config, :password)}
    ]
  end

  defp run_command!(command, arguments, options) do
    case System.cmd(command, arguments, options) do
      {_output, 0} -> :ok
      {output, status} -> Mix.raise("#{command} failed with status #{status}: #{output}")
    end
  end
end
