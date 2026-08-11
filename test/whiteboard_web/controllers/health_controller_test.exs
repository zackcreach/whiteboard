defmodule WhiteboardWeb.HealthControllerTest do
  use WhiteboardWeb.ConnCase

  test "GET /health returns a successful database status", %{conn: conn} do
    response =
      conn
      |> get(~p"/health")
      |> json_response(200)

    assert %{"status" => "ok"} == response
  end
end
