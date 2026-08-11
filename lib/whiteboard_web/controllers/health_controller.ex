defmodule WhiteboardWeb.HealthController do
  use WhiteboardWeb, :controller

  def index(conn, _params) do
    case Ecto.Adapters.SQL.query(Whiteboard.Repo, "SELECT 1") do
      {:ok, _result} ->
        json(conn, %{status: "ok"})

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error"})
    end
  end
end
