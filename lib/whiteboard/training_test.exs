defmodule Whiteboard.TrainingTest do
  use Whiteboard.DataCase

  alias Whiteboard.Training

  test "list_workouts/0" do
    [older_workout, newer_workout] = Factory.insert_pair(:workout)

    # Confirm both are returned in descending order
    assert [^newer_workout, ^older_workout] = Training.list_workouts()
  end
end
