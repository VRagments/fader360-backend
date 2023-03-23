defmodule Darth.MvApiClient do
  def authenticate(mv_node, email, password) do
    url = mv_node <> "/authentication/login"

    headers = [
      {"Content-type", "application/json"}
    ]

    with {:ok, request_body} <- Poison.encode(%{email: email, password: password}),
         {:ok, %{body: body}} <-
           HTTPoison.post(url, request_body, headers) do
      Poison.decode(body)
    end
  end

  def fetch_user(mv_node, mv_token) do
    url = mv_node <> "/user"

    with {:ok, %{body: body}} <- HTTPoison.get(url, get_headers(mv_token)),
         {:ok, response} <- Poison.decode(body) do
      {:ok, response}
    else
      {:ok, %{"message" => message}} -> {:error, message}
      error -> error
    end
  end

  def fetch_assets(mv_node, mv_token, current_page) do
    int_current_page = String.to_integer(current_page)
    url = mv_node <> "/assets/paginated?page=#{int_current_page - 1}"

    with {:ok, %{body: body}} <- HTTPoison.get(url, get_headers(mv_token)),
         {:ok, assets} when is_list(assets) <- Poison.decode(body) do
      {:ok, assets}
    else
      {:ok, %{"message" => message}} ->
        {:error, message}

      error ->
        error
    end
  end

  def show_asset(mv_node, mv_token, key) do
    url = mv_node <> "/assets/" <> key

    with {:ok, %{body: body}} <- HTTPoison.get(url, get_headers(mv_token)) do
      Poison.decode(body)
    end
  end

  def download_asset(mv_node, mv_token, deeplinkkey) do
    url = mv_node <> "/deeplink/" <> deeplinkkey <> "/download"
    HTTPoison.get(url, get_headers(mv_token), stream_to: self(), async: :once)
  end

  def download_preview_asset(mv_node, mv_token, previewlinkkey) do
    url = mv_node <> "/previewlink/" <> previewlinkkey <> "/download"
    HTTPoison.get(url, get_headers(mv_token), stream_to: self(), async: :once)
  end

  defp get_headers(mv_token) do
    [
      {"Content-type", "application/json"},
      {"Authorization", "Bearer #{mv_token}"}
    ]
  end
end
