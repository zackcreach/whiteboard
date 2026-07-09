defmodule Whiteboard.Training.ExerciseCategory do
  @moduledoc false
  use Whiteboard.Schema, prefix: "ex_category"

  import Ecto.Changeset

  alias Whiteboard.Accounts
  alias Whiteboard.Training

  schema "exercise_categories" do
    field :name, :string

    belongs_to :user, Accounts.User
    has_many :exercise_names, Training.ExerciseName

    timestamps()
  end

  def changeset(exercise_category, params \\ %{}) do
    exercise_category
    |> cast(params, [:name, :user_id])
    |> validate_required([:name, :user_id])
    |> unique_constraint(:name, name: :exercise_categories_user_id_name_index)
  end
end
