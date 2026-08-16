defmodule Whiteboard.Accounts.ConfirmationDelivery do
  @moduledoc false

  alias Whiteboard.Accounts
  alias Whiteboard.Accounts.User

  require Logger

  def deliver_async(%User{} = user, confirmation_url_fun) when is_function(confirmation_url_fun, 1) do
    case Task.Supervisor.start_child(Whiteboard.TaskSupervisor, fn ->
           case Accounts.deliver_user_confirmation_instructions(user, confirmation_url_fun) do
             {:ok, _email} -> :ok
             {:error, reason} -> Logger.warning("Confirmation email delivery failed: #{inspect(reason)}")
           end
         end) do
      {:ok, _process} -> :ok
      {:error, reason} -> Logger.warning("Confirmation email task failed to start: #{inspect(reason)}")
    end
  end
end
