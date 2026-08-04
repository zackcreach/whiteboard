defmodule Whiteboard.Accounts.Scope do
  @moduledoc false

  alias Whiteboard.Accounts
  alias Whiteboard.Accounts.User

  @type access :: :read_only | :read_write
  @type t :: %__MODULE__{
          user: User.t() | nil,
          data_owner: User.t(),
          access: access()
        }

  defstruct [:user, :data_owner, :access]

  @spec authenticated(User.t()) :: t()
  def authenticated(%User{} = user) do
    %__MODULE__{user: user, data_owner: user, access: :read_write}
  end

  @spec public() :: {:ok, t()} | {:error, :public_owner_not_found}
  def public do
    case Accounts.get_public_read_only_owner() do
      %User{} = data_owner ->
        {:ok, %__MODULE__{user: nil, data_owner: data_owner, access: :read_only}}

      nil ->
        {:error, :public_owner_not_found}
    end
  end

  @spec read_only?(t()) :: boolean()
  def read_only?(%__MODULE__{access: :read_only}), do: true
  def read_only?(%__MODULE__{access: :read_write}), do: false

  @spec authorized_to_write?(t()) :: boolean()
  def authorized_to_write?(%__MODULE__{access: :read_write, user: %User{id: id}, data_owner: %User{id: id}}), do: true
  def authorized_to_write?(%__MODULE__{}), do: false
end
