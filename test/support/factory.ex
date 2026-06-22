defmodule Whiteboard.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: Whiteboard.Repo
  use Whiteboard.Factories.Training

  alias Whiteboard.Accounts.User

  @binary_characters Enum.to_list(?a..?z) ++ Enum.to_list(?A..?Z)

  def user_factory do
    %User{
      email: "user#{System.unique_integer([:positive])}@example.com",
      hashed_password: Bcrypt.hash_pwd_salt("hello world!")
    }
  end

  def default_user do
    Process.get(:whiteboard_factory_default_user) || put_default_user()
  end

  def random_number(digits \\ 2) do
    min = 10 |> :math.pow(digits - 1) |> trunc()
    max = trunc(:math.pow(10, digits) - 1)
    :rand.uniform(max - min + 1) + min - 1
  end

  def random_binary(length \\ 10) when is_integer(length) and length > 0 do
    for _ <- 1..length, into: "", do: <<Enum.random(@binary_characters)>>
  end

  defp put_default_user do
    user = insert(:user)
    Process.put(:whiteboard_factory_default_user, user)
    user
  end
end
