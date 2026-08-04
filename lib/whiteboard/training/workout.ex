defmodule Whiteboard.Training.Workout do
  @moduledoc false
  use Whiteboard.Schema, key: :workout

  import Ecto.Changeset

  alias Whiteboard.Accounts
  alias Whiteboard.Training

  @display_timezone_offset_seconds -4 * 60 * 60

  schema "workouts" do
    field :name, :string
    field :notes, :string
    field :date, :date, virtual: true

    belongs_to_uxid(:user, Accounts.User, :user)
    has_many :exercises, Training.Exercise, on_replace: :delete_if_exists

    timestamps()
  end

  def changeset(workout, params \\ %{}) do
    workout
    |> cast(params, [:name, :notes, :user_id])
    |> validate_required([:name, :user_id])
    |> cast_assoc(:exercises)
  end

  def aggregate_changeset(workout, params) do
    workout
    |> changeset(params)
    |> force_exercise_positions()
    |> reorder_assoc(:exercises)
  end

  def details_changeset(workout, params \\ %{}) do
    workout
    |> cast(params, [:name, :notes, :date])
    |> validate_required([:name, :date])
    |> put_inserted_at_from_date()
  end

  def local_date(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift(second: @display_timezone_offset_seconds)
    |> DateTime.to_date()
  end

  defp put_inserted_at_from_date(%Ecto.Changeset{} = changeset) do
    case fetch_field(changeset, :date) do
      {_source, %Date{} = date} -> put_change(changeset, :inserted_at, inserted_at_for_local_date(changeset.data, date))
      _field -> changeset
    end
  end

  defp force_exercise_positions(%Ecto.Changeset{} = changeset) do
    exercises =
      changeset
      |> get_change(:exercises, [])
      |> Enum.with_index(1)
      |> Enum.map(fn {exercise_changeset, position} -> put_change(exercise_changeset, :position, position) end)

    %{changeset | changes: Map.put(changeset.changes, :exercises, exercises)}
  end

  defp inserted_at_for_local_date(%__MODULE__{inserted_at: %DateTime{} = inserted_at}, %Date{} = date) do
    inserted_at
    |> local_time()
    |> then(&DateTime.new!(date, &1, "Etc/UTC"))
    |> DateTime.shift(second: -@display_timezone_offset_seconds)
  end

  defp local_time(%DateTime{} = datetime) do
    datetime
    |> DateTime.shift(second: @display_timezone_offset_seconds)
    |> DateTime.to_time()
  end
end
