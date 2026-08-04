defmodule Whiteboard.Training.Page do
  @moduledoc false

  @enforce_keys [:entries, :current_page, :page_size, :total_entries, :total_pages]
  defstruct @enforce_keys
end
