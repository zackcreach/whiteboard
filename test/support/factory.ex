defmodule Whiteboard.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: Whiteboard.Repo
  use Whiteboard.Factories.Training

  def random_number(digits \\ 2) do
    min = 10 |> :math.pow(digits - 1) |> trunc()
    max = trunc(:math.pow(10, digits) - 1)
    :rand.uniform(max - min + 1) + min - 1
  end
end
