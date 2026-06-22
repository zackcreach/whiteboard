defmodule Whiteboard.Repo.Migrations.AddPositionToExercises do
  @moduledoc false
  use Whiteboard.Utils.Migrations

  def up do
    alter table(:exercises) do
      add(:position, :integer)
    end

    execute("""
    WITH ordered_exercises AS (
      SELECT
        id,
        row_number() OVER (PARTITION BY workout_id ORDER BY inserted_at ASC, id ASC) AS position
      FROM exercises
    )
    UPDATE exercises
    SET position = ordered_exercises.position
    FROM ordered_exercises
    WHERE exercises.id = ordered_exercises.id
    """)

    alter table(:exercises) do
      modify(:position, :integer, null: false)
    end

    create(index(:exercises, [:workout_id, :position]))
  end

  def down do
    drop(index(:exercises, [:workout_id, :position]))

    alter table(:exercises) do
      remove(:position)
    end
  end
end
