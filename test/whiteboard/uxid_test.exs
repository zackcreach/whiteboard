defmodule Whiteboard.UXIDTest do
  use ExUnit.Case, async: true

  alias Whiteboard.Accounts.User
  alias Whiteboard.Accounts.UserToken
  alias Whiteboard.IDs
  alias Whiteboard.Training.Exercise
  alias Whiteboard.Training.ExerciseCategory
  alias Whiteboard.Training.ExerciseName
  alias Whiteboard.Training.Set
  alias Whiteboard.Training.Workout

  @registered_fields [
    {User, :id, :user},
    {UserToken, :id, :user_token},
    {UserToken, :user_id, :user},
    {Workout, :id, :workout},
    {Workout, :user_id, :user},
    {Exercise, :id, :exercise},
    {Exercise, :workout_id, :workout},
    {Exercise, :exercise_name_id, :exercise_name},
    {ExerciseName, :id, :exercise_name},
    {ExerciseName, :user_id, :user},
    {ExerciseName, :exercise_category_id, :exercise_category},
    {ExerciseCategory, :id, :exercise_category},
    {ExerciseCategory, :user_id, :user},
    {Set, :id, :set},
    {Set, :exercise_id, :exercise}
  ]

  test "registry declares every UXID-backed schema and prefix" do
    assert [
             {:user, "user", User},
             {:user_token, "user_token", UserToken},
             {:workout, "wo", Workout},
             {:exercise, "ex", Exercise},
             {:exercise_name, "ex_name", ExerciseName},
             {:exercise_category, "ex_category", ExerciseCategory},
             {:set, "set", Set}
           ] == Enum.map(IDs.all(), &{&1.key, &1.prefix, &1.schema})
  end

  test "every primary and foreign key uses strict registry options" do
    for {schema, field, key} <- @registered_fields do
      assert {:parameterized, {UXID, params}} = schema.__schema__(:type, field)
      assert IDs.prefix(key) == params.prefix
      assert :medium == params.size
      assert true == params.validate
      assert true == params.allow_uuid
    end
  end

  test "schema generation preserves prefixes and uppercase bodies" do
    generated_id = IDs.generate!(:workout)

    assert "wo_" <> body = generated_id
    assert body == String.upcase(body)
    assert Regex.match?(~r/^[0-9A-HJKMNP-TV-Z]+$/, body)
  end

  test "legacy uppercase long-body identifiers remain castable with strict validation" do
    legacy_id = "wo_01JQZ7Q4M0M7R8E6K5P4N3T2V1"

    assert {:ok, ^legacy_id} = IDs.cast(:workout, legacy_id)
  end

  test "strict casting enforces prefixes and retains legacy UUID compatibility" do
    legacy_uuid = "550e8400-e29b-41d4-a716-446655440000"

    assert :error == IDs.cast(:exercise, IDs.generate!(:workout))
    assert :error == IDs.cast(:exercise, "not-an-id")
    assert {:ok, ^legacy_uuid} = IDs.cast(:exercise, legacy_uuid)
  end

  test "application generation defaults to uppercase" do
    generated_id = IDs.generate!(:set)

    assert "set_" <> body = generated_id
    assert body == String.upcase(body)
  end
end
