defmodule Whiteboard.AuthRateLimiter do
  @moduledoc false
  use GenServer

  @email_limit 5
  @ip_limit 10
  @window to_timeout(minute: 15)

  def start_link(options) do
    name = Keyword.get(options, :name, __MODULE__)
    clock = Keyword.get(options, :clock, fn -> System.monotonic_time(:millisecond) end)

    GenServer.start_link(__MODULE__, clock, server_options(name))
  end

  def allow?(ip, email, server \\ __MODULE__) do
    GenServer.call(server, {:allow?, ip, normalize_email(email)})
  end

  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  @impl true
  def init(clock) do
    {:ok, %{clock: clock, email_attempts: %{}, ip_attempts: %{}}}
  end

  @impl true
  def handle_call({:allow?, ip, email}, _from, state) do
    now = state.clock.()
    state = prune_expired_attempts(state, now)
    email_attempts = Map.get(state.email_attempts, email, [])
    ip_attempts = Map.get(state.ip_attempts, ip, [])

    if length(email_attempts) < @email_limit and length(ip_attempts) < @ip_limit do
      next_state = %{
        state
        | email_attempts: Map.put(state.email_attempts, email, [now | email_attempts]),
          ip_attempts: Map.put(state.ip_attempts, ip, [now | ip_attempts])
      }

      {:reply, true, next_state}
    else
      {:reply, false, state}
    end
  end

  def handle_call(:reset, _from, state) do
    {:reply, :ok, %{state | email_attempts: %{}, ip_attempts: %{}}}
  end

  defp normalize_email(email) do
    email
    |> String.trim()
    |> String.downcase()
    |> String.slice(0, 160)
  end

  defp server_options(nil), do: []
  defp server_options(name), do: [name: name]

  defp prune_expired_attempts(state, now) do
    %{
      state
      | email_attempts: prune_attempt_map(state.email_attempts, now),
        ip_attempts: prune_attempt_map(state.ip_attempts, now)
    }
  end

  defp prune_attempt_map(attempts_by_key, now) do
    for {key, attempts} <- attempts_by_key,
        active_attempts = Enum.filter(attempts, &(now - &1 < @window)),
        active_attempts != [],
        into: %{},
        do: {key, active_attempts}
  end
end
