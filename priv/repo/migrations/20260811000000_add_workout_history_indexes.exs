defmodule Whiteboard.Repo.Migrations.AddWorkoutHistoryIndexes do
  @moduledoc false
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(index(:workouts, [desc: :inserted_at, desc: :id], concurrently: true))
    create(index(:exercises, [:workout_id, :exercise_name_id], concurrently: true))
    create(index(:sets, [:exercise_id], concurrently: true))
  end
end
