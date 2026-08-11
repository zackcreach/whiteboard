defmodule WhiteboardWeb.HealthController do
  use WhiteboardWeb, :controller

  alias Whiteboard.Repo

  def index(conn, _params) do
    case Repo.health_check() do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, :database_unavailable} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error"})
    end
  end
end
