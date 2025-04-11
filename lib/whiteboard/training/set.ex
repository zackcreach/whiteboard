defmodule Whiteboard.Training.Set do
  use Whiteboard.Schema, prefix: "set"

  import Ecto.Changeset

  alias Whiteboard.Training

  schema "sets" do
    field :weight, :float
    field :reps, :integer
    field :notes, :string

    belongs_to :exercise, Training.Exercise

    timestamps()
  end

  def changeset(set, params \\ %{}) do
    set
    |> cast(params, [:weight, :reps, :notes])
    |> validate_required([:weight, :reps])
  end
end
