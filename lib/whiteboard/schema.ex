defmodule Whiteboard.Schema do
  defmacro __using__(opts) do
    quote do
      use Ecto.Schema

      prefix = unquote(if opts[:prefix], do: opts[:prefix], else: nil)

      @primary_key {:id, UXID, autogenerate: true, prefix: prefix, size: :medium}
      @foreign_key_type UXID
      @timestamps_opts [type: :utc_datetime_usec]
    end
  end
end
