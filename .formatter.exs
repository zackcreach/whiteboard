[
  import_deps: [:ecto, :phoenix],
  inputs: [
    "*.{heex,ex,exs}",
    "priv/*/seeds.exs",
    "{config,lib,test}/**/*.{heex,ex,exs}"
  ],
  # https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.HTMLFormatter.html
  # VSCode frens might need additional configuration: https://pragmaticstudio.com/tutorials/formatting-heex-templates-in-vscode
  plugins: [Phoenix.LiveView.HTMLFormatter, Styler],
  subdirectories: ["priv/*/migrations"],
  line_length: 120,
  heex_line_length: 300
  # add function names to list below that you don't want parens 
  # (e.g. [maybe_check_price: 2 OR :* for multiple arrities] `maybe_check_price :flat %{id: id}`)
  # locals_without_parens: []
]
