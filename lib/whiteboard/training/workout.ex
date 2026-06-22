defmodule Whiteboard.Training.Workout do
  @moduledoc false
  use Whiteboard.Schema, prefix: "wo"

  import Ecto.Changeset

  alias Whiteboard.Accounts
  alias Whiteboard.Training

  schema "workouts" do
    field :name, :string
    field :notes, :string

    belongs_to :user, Accounts.User
    has_many :exercises, Training.Exercise, on_replace: :delete_if_exists

    timestamps()
  end

  def changeset(workout, params \\ %{}) do
    workout
    |> cast(params, [:name, :notes, :user_id])
    |> validate_required([:name, :user_id])
    |> cast_assoc(:exercises)
  end
end
