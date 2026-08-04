defmodule Mix.Tasks.Assets.SignEsbuild do
  @moduledoc "Ensures the downloaded esbuild binary has a runnable ad-hoc signature on macOS."
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    sign_esbuild(:os.type(), Esbuild.bin_path())
  end

  defp sign_esbuild({:unix, :darwin}, esbuild_path) do
    case System.cmd("/usr/bin/codesign", ["--force", "--sign", "-", esbuild_path], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, status} -> Mix.raise("codesign failed with status #{status}: #{output}")
    end
  end

  defp sign_esbuild(_operating_system, _esbuild_path), do: :ok
end
