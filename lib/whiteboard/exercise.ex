defmodule Whiteboard.Exercise do
  use Whiteboard.Schema, prefix: "exercise"

  import Ecto.Changeset

  schema "exercises" do
    field :notes, :string

    belongs_to :session, Whiteboard.Session
    belongs_to :exercise_type, Whiteboard.ExerciseType

    has_many :sets, Whiteboard.Set, on_replace: :delete_if_exists

    timestamps()
  end

  def changeset(session, params \\ %{}) do
    session
    |> cast(params, [:notes])
    |> cast_assoc(:sets)
  end
end
