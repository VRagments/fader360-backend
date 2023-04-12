defmodule Darth.MvApiClient do
  require Logger

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

  def fetch_assets(mv_node, mv_token, current_page) do
    int_current_page = String.to_integer(current_page)
    url = mv_node <> Application.fetch_env!(:darth, :mv_asset_index_url)
    params = [page: int_current_page - 1]

    with {:ok, %{body: body}} <- HTTPoison.get(url, get_headers(mv_token), params: params),
         {:ok, assets} when is_list(assets) <- Jason.decode(body) do
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

    case HTTPoison.get(url, get_headers(mv_token)) do
      {:ok, %{body: body}} -> Jason.decode(body)
      err -> {:error, "Error while fetching asset: #{inspect(err)}"}
    end
  end

  def fetch_projects(mv_node, mv_token, current_page) do
    int_current_page = String.to_integer(current_page)
    url = mv_node <> Application.fetch_env!(:darth, :mv_project_index_url)
    params = [page: int_current_page - 1]

    with {:ok, %{body: body}} <- HTTPoison.get(url, get_headers(mv_token), params: params),
         {:ok, projects} when is_list(projects) <- Jason.decode(body) do
      {:ok, projects}
    else
      {:ok, %{"message" => message}} ->
        {:error, message}

      error ->
        error
    end
  end

  def show_project(mv_node, mv_token, mv_project_id) do
    url = mv_node <> "/project/" <> mv_project_id

    case HTTPoison.get(url, get_headers(mv_token)) do
      {:ok, %{body: body}} -> Jason.decode(body)
      {:error, reason} -> {:error, reason}
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

  def asset_created_by_current_user?(mv_node, mv_token, mv_asset_key) do
    with {:ok, %{"createdBy" => mv_asset_creator_id}} <- show_asset(mv_node, mv_token, mv_asset_key),
         {:ok, %{"id" => mv_user_id}} <- fetch_user(mv_node, mv_token) do
      mv_asset_creator_id == mv_user_id
    else
      {:ok, %{"message" => message}} ->
        Logger.error(
          "Custom error message from MediaVerse when checking for asset_created_by_current_user: #{inspect(message)}"
        )

        false

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error(
          "Custom error message from MediaVerse when checking for asset_created_by_current_user: #{inspect(reason)}"
        )

        false

      {:error, reason} ->
        Logger.error(
          "Custom error message from MediaVerse when checking for asset_created_by_current_user: #{inspect(reason)}"
        )

        false
    end
  end

  defp get_headers(mv_token) do
    [
      {"Content-type", "application/json"},
      {"Authorization", "Bearer #{mv_token}"}
    ]
  end
end
