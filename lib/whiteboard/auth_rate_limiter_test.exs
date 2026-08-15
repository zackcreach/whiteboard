defmodule Whiteboard.AuthRateLimiterTest do
  use ExUnit.Case, async: true

  alias Whiteboard.AuthRateLimiter

  test "allows the first five attempts for an email" do
    {limiter, _clock} = start_limiter()

    for _attempt <- 1..5 do
      assert AuthRateLimiter.allow?({192, 0, 2, 1}, "user@example.com", limiter)
    end

    refute AuthRateLimiter.allow?({192, 0, 2, 2}, "user@example.com", limiter)
  end

  test "enforces the email limit across IP addresses and normalized forms" do
    {limiter, _clock} = start_limiter()

    for last_octet <- 1..5 do
      assert AuthRateLimiter.allow?(
               {192, 0, 2, last_octet},
               " USER@Example.COM ",
               limiter
             )
    end

    refute AuthRateLimiter.allow?({198, 51, 100, 1}, "user@example.com", limiter)
  end

  test "enforces the IP limit across email addresses" do
    {limiter, _clock} = start_limiter()
    ip = {192, 0, 2, 1}

    for attempt <- 1..10 do
      assert AuthRateLimiter.allow?(ip, "user#{attempt}@example.com", limiter)
    end

    refute AuthRateLimiter.allow?(ip, "another@example.com", limiter)
  end

  test "allows attempts after the rolling window expires" do
    {limiter, clock} = start_limiter()

    for _attempt <- 1..5 do
      assert AuthRateLimiter.allow?({192, 0, 2, 1}, "user@example.com", limiter)
    end

    refute AuthRateLimiter.allow?({192, 0, 2, 1}, "user@example.com", limiter)
    :atomics.put(clock, 1, to_timeout(minute: 15))
    assert AuthRateLimiter.allow?({192, 0, 2, 1}, "user@example.com", limiter)
  end

  test "prunes stale entries on every check" do
    {limiter, clock} = start_limiter()

    assert AuthRateLimiter.allow?({192, 0, 2, 1}, "stale@example.com", limiter)
    :atomics.put(clock, 1, to_timeout(minute: 15))
    assert AuthRateLimiter.allow?({192, 0, 2, 2}, "fresh@example.com", limiter)

    assert %{
             email_attempts: %{"fresh@example.com" => [_email_timestamp]},
             ip_attempts: %{{192, 0, 2, 2} => [_ip_timestamp]}
           } = :sys.get_state(limiter)
  end

  defp start_limiter do
    clock = :atomics.new(1, signed: false)
    limiter = start_supervised!({AuthRateLimiter, name: nil, clock: fn -> :atomics.get(clock, 1) end})
    {limiter, clock}
  end
end
