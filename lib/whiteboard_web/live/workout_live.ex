defmodule WhiteboardWeb.WorkoutLive do
  use WhiteboardWeb, :live_view

  def render(assigns) do
    ~H"""
    Workout!
    """
  end

  def mount(_params, _session, socket) do
    ok(socket)
  end
end
