defmodule Whiteboard.Repo.Migrations.AddInitialTables do
  use Whiteboard.Utils.Migrations

  def change do
    create table(:sessions, primary_key: false) do
      id(:session)
      add :name, :string, null: false
      add :notes, :string
      add :completed_on, :utc_datetime_usec
      timestamps()
    end

    create table(:exercise_types, primary_key: false) do
      id(:exercise_type)
      add :name, :string, null: false
      timestamps()
    end

    create table(:exercises, primary_key: false) do
      id(:exercise)
      add :notes, :string
      add :session_id, references(:sessions, type: :text, on_delete: :delete_all)

      add :exercise_type_id,
          references(:exercise_types, type: :text, on_delete: :delete_all)

      timestamps()
    end

    create table(:sets, primary_key: false) do
      id(:set)
      add :weight, :float, null: false
      add :reps, :integer, null: false
      add :notes, :string
      add :exercise_id, references(:exercises, type: :text, on_delete: :delete_all)
      timestamps()
    end

    create unique_index(:exercise_types, [:name])
  end
end
