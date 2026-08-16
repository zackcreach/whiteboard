defmodule Whiteboard.FailingMailerAdapter do
  @moduledoc false
  use Swoosh.Adapter

  @impl true
  def deliver(email, config) do
    send(config[:test_process], {:email_delivery_attempted, email})
    {:error, :delivery_failed}
  end
end
