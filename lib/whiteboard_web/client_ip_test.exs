defmodule WhiteboardWeb.ClientIpTest do
  use ExUnit.Case, async: true

  alias WhiteboardWeb.ClientIp

  test "uses the forwarded address nearest the trusted loopback tunnel" do
    headers = [{"x-forwarded-for", "198.51.100.4, 203.0.113.8"}]

    assert {203, 0, 113, 8} == ClientIp.select({127, 0, 0, 1}, headers)
    assert {203, 0, 113, 8} == ClientIp.select({0, 0, 0, 0, 0, 0, 0, 1}, headers)
  end

  test "ignores forwarding headers from a non-loopback peer" do
    peer_ip = {203, 0, 113, 8}
    headers = [{"x-forwarded-for", "198.51.100.4"}]

    assert ^peer_ip = ClientIp.select(peer_ip, headers)
  end

  test "falls back to the loopback peer for invalid or ambiguous headers" do
    peer_ip = {127, 0, 0, 1}

    assert ^peer_ip = ClientIp.select(peer_ip, [{"x-forwarded-for", "not-an-ip"}])

    assert ^peer_ip =
             ClientIp.select(peer_ip, [
               {"x-forwarded-for", "198.51.100.4"},
               {"x-forwarded-for", "203.0.113.8"}
             ])
  end
end
