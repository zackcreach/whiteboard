defmodule Whiteboard.MixProject do
  use Mix.Project

  def project do
    [
      app: :whiteboard,
      version: "0.1.0",
      elixir: "~> 1.20.2",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: ["test", "lib"],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: releases(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Whiteboard.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.3.2"},
      {:bandit, "~> 1.12.4"},
      {:ecto_sql, "~> 3.14.0"},
      {:esbuild, "~> 0.10.0", runtime: Mix.env() == :dev},
      {:ex_machina, "~> 2.8.2", only: :test},
      {:finch, "~> 0.23.0"},
      {:floki, "~> 0.38.4", only: :test},
      {:gettext, "~> 1.0.2"},
      {:heroicons,
       github: "tailwindlabs/heroicons", tag: "v2.2.0", sparse: "optimized", app: false, compile: false, depth: 1},
      {:jason, "~> 1.4.5"},
      {:lazy_html, "~> 0.1.12", only: :test},
      {:phoenix, "~> 1.8.9"},
      {:phoenix_ecto, "~> 4.7.0"},
      {:phoenix_html, "~> 4.3.0"},
      {:phoenix_live_dashboard, "~> 0.8.7"},
      {:phoenix_live_reload, "~> 1.7.0", only: :dev},
      {:phoenix_live_view, "~> 1.2.8"},
      {:postgrex, "~> 0.22.3"},
      {:publicist, "1.1.0"},
      {:styler, "~> 1.12.2", only: [:dev, :test], runtime: false},
      {:swoosh, "~> 1.27.0"},
      {:tailwind, "~> 0.5.1", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.1.0"},
      {:telemetry_poller, "~> 1.3.0"},
      {:uxid, "~> 2.9.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing", "assets.sign_esbuild"],
      "assets.build": ["compile", "tailwind whiteboard", "esbuild whiteboard"],
      "assets.deploy": [
        "tailwind whiteboard --minify",
        "esbuild whiteboard --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  defp releases do
    [
      whiteboard: [
        include_executables_for: [:unix]
      ]
    ]
  end
end
