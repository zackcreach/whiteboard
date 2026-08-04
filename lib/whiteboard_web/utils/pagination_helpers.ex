defmodule WhiteboardWeb.Utils.PaginationHelpers do
  @moduledoc false

  def parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {page, ""} when page > 0 -> page
      _invalid_page -> 1
    end
  end

  def parse_page(_page), do: 1

  def normalized_page_parameter?(nil, 1), do: true

  def normalized_page_parameter?(parameter, page) when is_binary(parameter) and page > 1 do
    parameter == Integer.to_string(page)
  end

  def normalized_page_parameter?(_parameter, _page), do: false
end
