defmodule Darth.MvApiClient do
  def authenticate(mv_node, email, password) do
    url = mv_node <> "/authentication/login"

    headers = [
      {"Content-type", "application/json"}
    ]

    with {:ok, request_body} <- Jason.encode(%{email: email, password: password}),
         {:ok, %{body: body}} <-
           HTTPoison.post(url, request_body, headers) do
      Jason.decode(body)
    end
  end

  def fetch_user(mv_node, mv_token) do
    url = mv_node <> "/user"

    with {:ok, %{body: body}} <- HTTPoison.get(url, get_headers(mv_token)),
         {:ok, response} <- Jason.decode(body) do
      {:ok, response}
    else
      {:ok, %{"message" => message}} -> {:error, message}
      error -> error
    end
  end

  defp get_headers(mv_token) do
    [
      {"Content-type", "application/json"},
      {"Authorization", "Bearer #{mv_token}"}
    ]
  end
end
