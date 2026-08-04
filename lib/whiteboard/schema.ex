defmodule Whiteboard.Schema do
  @moduledoc false
  defmacro __using__(opts) do
    key = Keyword.fetch!(opts, :key)

    quote bind_quoted: [key: key] do
      use Ecto.Schema

      import Whiteboard.Schema, only: [belongs_to_uxid: 3, belongs_to_uxid: 4]

      @primary_key {:id, UXID, [autogenerate: true] ++ Whiteboard.IDs.field_opts(key)}
      @foreign_key_type UXID
      @timestamps_opts [type: :utc_datetime_usec]
    end
  end

  defmacro belongs_to_uxid(name, queryable, key, opts \\ []) do
    foreign_key = Keyword.get(opts, :foreign_key, String.to_atom("#{name}_id"))
    association_opts = Keyword.put(opts, :define_field, false)

    quote do
      field unquote(foreign_key), UXID, Whiteboard.IDs.field_opts(unquote(key))
      belongs_to unquote(name), unquote(queryable), unquote(association_opts)
    end
  end
end
