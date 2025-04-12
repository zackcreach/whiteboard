defmodule Whiteboard.Training do
  alias Whiteboard.Training.Repo, as: TrainingRepo

  # Workouts
  def get_workout(id) do
    TrainingRepo.get_workout(id)
  end

  def create_workout(params) do
    TrainingRepo.create_workout(params)
  end

  def update_workout(id, params) do
    TrainingRepo.update_workout(id, params)
  end

  def delete_workout(id) do
    TrainingRepo.delete_workout(id)
  end

  # Exercises
  def create_exercise(params) do
    TrainingRepo.create_exercise(params)
  end

  def update_exercise(id, params) do
    TrainingRepo.update_exercise(id, params)
  end

  def delete_exercise(id) do
    TrainingRepo.delete_exercise(id)
  end

  # Exercise names
  def list_exercise_names() do
    TrainingRepo.list_exercise_names()
  end

  def get_exercise_name(id) do
    TrainingRepo.get_exercise_name(id)
  end

  def create_exercise_name(params) do
    TrainingRepo.create_exercise_name(params)
  end

  def update_exercise_name(id, params) do
    TrainingRepo.update_exercise_name(id, params)
  end

  def delete_exercise_name(id) do
    TrainingRepo.delete_exercise_name(id)
  end

  # Exercise categories
  def create_exercise_category(params) do
    TrainingRepo.create_exercise_category(params)
  end

  def update_exercise_category(id, params) do
    TrainingRepo.update_exercise_category(id, params)
  end

  def delete_exercise_category(id) do
    TrainingRepo.delete_exercise_category(id)
  end
end
