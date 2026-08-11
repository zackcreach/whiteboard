defmodule Whiteboard.Repo do
  use Ecto.Repo,
    otp_app: :whiteboard,
    adapter: Ecto.Adapters.Postgres

  def health_check do
    case Ecto.Adapters.SQL.query(__MODULE__, "SELECT 1") do
      {:ok, _result} -> :ok
      {:error, _reason} -> {:error, :database_unavailable}
    end
  end
end
