defmodule Whiteboard.Training.ExerciseName do
  @moduledoc false
  use Whiteboard.Schema, key: :exercise_name

  import Ecto.Changeset

  alias Whiteboard.Accounts
  alias Whiteboard.Training

  schema "exercise_names" do
    field :name, :string

    belongs_to_uxid(:user, Accounts.User, :user)
    has_many :exercises, Training.Exercise
    belongs_to_uxid(:exercise_category, Training.ExerciseCategory, :exercise_category)

    timestamps()
  end

  def changeset(exercise_name, params \\ %{}) do
    exercise_name
    |> cast(params, [:name, :exercise_category_id, :user_id])
    |> validate_required([:name, :exercise_category_id, :user_id])
    |> unique_constraint(:name, name: :exercise_names_user_id_name_index)
  end
end
