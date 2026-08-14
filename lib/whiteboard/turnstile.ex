defmodule Whiteboard.Turnstile do
  @moduledoc false

  require Logger

  @verify_url "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  def verify(token) do
    config = Application.get_env(:whiteboard, :turnstile)

    if config[:enabled] do
      do_verify(token, config[:secret_key])
    else
      :ok
    end
  end

  defp do_verify(token, _secret_key) when token in [nil, ""] do
    {:error, :verification_failed}
  end

  defp do_verify(token, secret_key) do
    body = URI.encode_query(%{secret: secret_key, response: token})
    headers = [{"content-type", "application/x-www-form-urlencoded"}]
    request = Finch.build(:post, @verify_url, headers, body)

    case Finch.request(request, Whiteboard.Finch) do
      {:ok, %Finch.Response{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"success" => true}} -> :ok
          {:ok, _response} -> {:error, :verification_failed}
          {:error, _reason} -> {:error, :verification_failed}
        end

      error ->
        Logger.warning("Turnstile verification request failed: #{inspect(error)}")
        {:error, :verification_failed}
    end
  end
end
