defmodule Whiteboard.Repo.Migrations.AddInitialTables do
  @moduledoc false
  use Whiteboard.Utils.Migrations

  def change do
    create table(:workouts, primary_key: false) do
      id(:wo)
      add(:name, :string, null: false)
      add(:notes, :string)

      timestamps()
    end

    create table(:exercise_categories, primary_key: false) do
      id(:ex_category)
      add(:name, :string, null: false)

      timestamps()
    end

    create table(:exercise_names, primary_key: false) do
      id(:ex_name)
      add(:name, :string, null: false)
      add(:exercise_category_id, references(:exercise_categories, type: :text, on_delete: :delete_all))

      timestamps()
    end

    create table(:exercises, primary_key: false) do
      id(:ex)
      add(:notes, :string)
      add(:workout_id, references(:workouts, type: :text, on_delete: :delete_all))

      add(
        :exercise_name_id,
        references(:exercise_names, type: :text, on_delete: :delete_all)
      )

      timestamps()
    end

    create table(:sets, primary_key: false) do
      id(:set)
      add(:weight, :float, null: false)
      add(:reps, :integer, null: false)
      add(:notes, :string)
      add(:exercise_id, references(:exercises, type: :text, on_delete: :delete_all))
      timestamps()
    end

    create(unique_index(:exercise_names, [:name]))
    create(unique_index(:exercise_categories, [:name]))
  end
end
