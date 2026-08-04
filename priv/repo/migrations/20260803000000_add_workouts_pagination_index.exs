defmodule Whiteboard.Repo.Migrations.AddWorkoutsPaginationIndex do
  @moduledoc false
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create(
      index(:workouts, [:user_id, desc: :inserted_at, desc: :id],
        concurrently: true,
        name: :workouts_user_id_inserted_at_id_index
      )
    )

    drop(index(:workouts, [:user_id], concurrently: true, name: :workouts_user_id_index))
  end
end
