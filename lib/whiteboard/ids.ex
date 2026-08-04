defmodule Whiteboard.IDs do
  @moduledoc false
  use UXID.Registry,
    default_size: :medium,
    default_validate: true,
    prefix_format: ~r/^[a-z][a-z0-9_]*$/

  @type key ::
          :user
          | :user_token
          | :workout
          | :exercise
          | :exercise_name
          | :exercise_category
          | :set
  @type id :: String.t()

  defid(:user, prefix: "user", schema: Whiteboard.Accounts.User, allow_uuid: true)
  defid(:user_token, prefix: "user_token", schema: Whiteboard.Accounts.UserToken, allow_uuid: true)
  defid(:workout, prefix: "wo", schema: Whiteboard.Training.Workout, allow_uuid: true)
  defid(:exercise, prefix: "ex", schema: Whiteboard.Training.Exercise, allow_uuid: true)
  defid(:exercise_name, prefix: "ex_name", schema: Whiteboard.Training.ExerciseName, allow_uuid: true)

  defid(:exercise_category,
    prefix: "ex_category",
    schema: Whiteboard.Training.ExerciseCategory,
    allow_uuid: true
  )

  defid(:set, prefix: "set", schema: Whiteboard.Training.Set, allow_uuid: true)

  @spec cast(key(), term()) :: {:ok, id() | nil} | :error
  def cast(key, value) do
    UXID.cast(value, UXID.init(field_opts(key)))
  end
end
