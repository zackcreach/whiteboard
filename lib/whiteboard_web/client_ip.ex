defmodule WhiteboardWeb.ClientIp do
  @moduledoc false

  def from_conn(conn) do
    peer_ip = conn |> Plug.Conn.get_peer_data() |> Map.fetch!(:address)
    select(peer_ip, conn.req_headers)
  end

  def from_socket(socket) do
    peer_ip = socket |> Phoenix.LiveView.get_connect_info(:peer_data) |> Map.fetch!(:address)
    headers = Phoenix.LiveView.get_connect_info(socket, :x_headers)
    select(peer_ip, headers)
  end

  def select({127, _second, _third, _fourth} = peer_ip, headers), do: forwarded_ip_or_peer(headers, peer_ip)

  def select({0, 0, 0, 0, 0, 0, 0, 1} = peer_ip, headers), do: forwarded_ip_or_peer(headers, peer_ip)

  def select({0, 0, 0, 0, 0, 65_535, first, _last} = peer_ip, headers) when first >= 32_512 and first <= 32_767,
    do: forwarded_ip_or_peer(headers, peer_ip)

  def select(peer_ip, _headers), do: peer_ip

  defp forwarded_ip_or_peer(headers, peer_ip) do
    case forwarded_ip(headers) do
      nil -> peer_ip
      forwarded_ip -> forwarded_ip
    end
  end

  defp forwarded_ip(nil), do: nil

  defp forwarded_ip(headers) do
    with [header] <- for({"x-forwarded-for", value} <- headers, do: value),
         forwarding_chain when forwarding_chain != [] <- String.split(header, ","),
         address = List.last(forwarding_chain),
         {:ok, ip} <- address |> String.trim() |> String.to_charlist() |> :inet.parse_address() do
      ip
    else
      _invalid_forwarding_header -> nil
    end
  end
end
