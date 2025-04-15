defmodule WhiteboardWeb.Utils.ExerciseHelpers do
  @moduledoc """
  Exercise name and category helpers
  """

  alias Whiteboard.Training
  alias Whiteboard.Training.Workout

  def list_exercises do
    Enum.map(Training.list_exercise_names(), fn exercise -> {exercise.name, exercise.id} end)
  end

  def list_exercise_categories do
    Enum.map(Training.list_exercise_categories(), fn category -> {category.name, category.id} end)
  end

  def render_exercise_names(%Workout{exercises: exercises}) do
    Enum.map_join(exercises, ", ", & &1.exercise_name.name)
  end
end
