defmodule Whiteboard.Repo.Migrations.AddUserOwnershipToTrainingData do
  @moduledoc """
  Adds owners to existing workout data and assigns current rows to
  zackcreach@gmail.com for the public read-only demo.
  """
  use Whiteboard.Utils.Migrations

  import Ecto.Query

  @public_read_only_owner_email "zackcreach@gmail.com"

  def up do
    drop_if_exists(unique_index(:exercise_names, [:name]))
    drop_if_exists(unique_index(:exercise_categories, [:name]))

    alter table(:workouts) do
      add(:user_id, references(:users, type: :text, on_delete: :delete_all))
    end

    alter table(:exercise_categories) do
      add(:user_id, references(:users, type: :text, on_delete: :delete_all))
    end

    alter table(:exercise_names) do
      add(:user_id, references(:users, type: :text, on_delete: :delete_all))
    end

    flush()

    public_owner_id = public_read_only_owner_id()

    public_owner_id
    |> ensure_public_read_only_owner_exists!()
    |> backfill_public_read_only_owner()

    alter table(:workouts) do
      modify(:user_id, :text, null: false)
    end

    alter table(:exercise_categories) do
      modify(:user_id, :text, null: false)
    end

    alter table(:exercise_names) do
      modify(:user_id, :text, null: false)
    end

    create(index(:workouts, [:user_id]))
    create(index(:exercise_categories, [:user_id]))
    create(index(:exercise_names, [:user_id]))
    create(unique_index(:exercise_categories, [:user_id, :name]))
    create(unique_index(:exercise_names, [:user_id, :name]))
  end

  def down do
    drop(unique_index(:exercise_names, [:user_id, :name]))
    drop(unique_index(:exercise_categories, [:user_id, :name]))
    drop(index(:exercise_names, [:user_id]))
    drop(index(:exercise_categories, [:user_id]))
    drop(index(:workouts, [:user_id]))

    alter table(:exercise_names) do
      remove(:user_id)
    end

    alter table(:exercise_categories) do
      remove(:user_id)
    end

    alter table(:workouts) do
      remove(:user_id)
    end

    create(unique_index(:exercise_categories, [:name]))
    create(unique_index(:exercise_names, [:name]))
  end

  defp public_read_only_owner_id do
    repo().one(
      from(u in "users",
        where: u.email == ^@public_read_only_owner_email,
        select: u.id
      )
    )
  end

  defp ensure_public_read_only_owner_exists!(nil) do
    if owned_rows_exist?() do
      raise "Cannot backfill training ownership without public read-only owner #{@public_read_only_owner_email}"
    end

    nil
  end

  defp ensure_public_read_only_owner_exists!(public_owner_id) do
    public_owner_id
  end

  defp owned_rows_exist? do
    Enum.any?(["workouts", "exercise_categories", "exercise_names"], &rows_exist?/1)
  end

  defp rows_exist?(table_name) do
    repo().exists?(from(row in table_name, select: 1))
  end

  defp backfill_public_read_only_owner(nil), do: :ok

  defp backfill_public_read_only_owner(public_owner_id) do
    for table_name <- ["workouts", "exercise_categories", "exercise_names"] do
      repo().update_all(from(row in table_name, where: is_nil(row.user_id)),
        set: [user_id: public_owner_id]
      )
    end

    :ok
  end
end
