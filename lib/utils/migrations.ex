defmodule Whiteboard.Utils.Migrations do
  @moduledoc """
  Migration helpers.
  """
  use Publicist

  defp gen_fragment(prefix) do
    "('#{prefix}_' || substr(replace(gen_random_uuid()::text, '-', ''), 0, 20))"
  end

  @doc """
   This macro tells Postgres to generate a unique prefixed UXID when a record is
   inserted.
   It's beneficial to perform this at the db level so that we have a
   guarantee that all primary key ids are consistent in format. Therefore we
   should prefer always using this macro to explicitly add an id over using Ecto
   config to generate defaults, as we cannot pass prefixes in dynamically
   otherwise.
  """
  defmacro id(prefix) do
    quote do
      add(:id, :text,
        primary_key: true,
        default:
          unquote(gen_fragment(prefix))
          |> fragment
      )
    end
  end

  defmacro __using__(_opts) do
    quote do
      use Ecto.Migration
      import Whiteboard.Utils.Migrations
    end
  end
end
