defmodule Whiteboard.Repo.Migrations.RemoveNotNullFromSets do
  @moduledoc false
  use Whiteboard.Utils.Migrations

  def change do
    alter table(:sets) do
      modify(:weight, :float, null: true)
      modify(:reps, :integer, null: true)
    end
  end
end
