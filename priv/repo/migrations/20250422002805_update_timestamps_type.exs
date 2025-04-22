defmodule Whiteboard.Repo.Migrations.UpdateTimestampsType do
  @moduledoc false
  use Ecto.Migration

  def change do
    alter table(:workouts) do
      modify(:inserted_at, :timestamptz)
      modify(:updated_at, :timestamptz)
    end

    alter table(:exercise_categories) do
      modify(:inserted_at, :timestamptz)
      modify(:updated_at, :timestamptz)
    end

    alter table(:exercise_names) do
      modify(:inserted_at, :timestamptz)
      modify(:updated_at, :timestamptz)
    end

    alter table(:exercises) do
      modify(:inserted_at, :timestamptz)
      modify(:updated_at, :timestamptz)
    end

    alter table(:sets) do
      modify(:inserted_at, :timestamptz)
      modify(:updated_at, :timestamptz)
    end
  end
end
