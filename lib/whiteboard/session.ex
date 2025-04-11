defmodule Whiteboard.Session do
  use Whiteboard.Schema, prefix: "session"

  import Ecto.Changeset

  schema "sessions" do
    field :name, :string
    field :notes, :string
    field :completed_on, :utc_datetime_usec

    has_many :exercises, Whiteboard.Exercise, on_replace: :delete_if_exists

    timestamps()
  end

  def changeset(session, params \\ %{}) do
    session
    |> cast(params, [:name, :notes, :completed_on])
    |> validate_required([:name])
    |> cast_assoc(:exercises)
  end
end
