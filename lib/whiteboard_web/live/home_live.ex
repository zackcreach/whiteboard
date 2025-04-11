defmodule WhiteboardWeb.HomeLive do
  use WhiteboardWeb, :live_view

  def render(assigns) do
    ~H"""
    Hey cool beans
    """
  end

  def mount(_params, _session, socket) do
    ok(socket)
  end
end
