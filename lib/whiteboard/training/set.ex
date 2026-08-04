defmodule Whiteboard.Training.Set do
  @moduledoc false
  use Whiteboard.Schema, key: :set

  import Ecto.Changeset

  alias Whiteboard.Training

  schema "sets" do
    field :weight, :float
    field :reps, :integer
    field :notes, :string

    belongs_to_uxid(:exercise, Training.Exercise, :exercise)

    timestamps()
  end

  def changeset(set, params \\ %{}) do
    cast(set, params, [:weight, :reps, :notes, :exercise_id])
  end
end
