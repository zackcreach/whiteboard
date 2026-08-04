defmodule Whiteboard.Repo.Migrations.MakeExercisePositionsUnique do
  @moduledoc false
  use Whiteboard.Utils.Migrations

  def up do
    drop(index(:exercises, [:workout_id, :position]))
    create(unique_index(:exercises, [:workout_id, :position]))
  end

  def down do
    drop(index(:exercises, [:workout_id, :position]))
    create(index(:exercises, [:workout_id, :position]))
  end
end
