defmodule Darth.MvApiClient do
  require Logger

  def authenticate(mv_node, email, password) do
    url = mv_node <> "/dam/authentication/login"

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
    url = mv_node <> "/dam/user"

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
    url = mv_node <> "/dam/assets/paginated"

    params = [
      page: int_current_page - 1,
      media_type: "image",
      media_type: "video",
      media_type: "audio",
      media_type: "model",
      per_page: 12
    ]

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
    url = mv_node <> "/dam/assets/" <> key

    case HTTPoison.get(url, get_headers(mv_token)) do
      {:ok, %{body: body}} -> Jason.decode(body)
      err -> {:error, "Error while fetching asset: #{inspect(err)}"}
    end
  end

  def fetch_projects(mv_node, mv_token, current_page) do
    int_current_page = String.to_integer(current_page)
    url = mv_node <> "/dam/project/userList/all/paginated"
    params = [page: int_current_page - 1, per_page: 12]

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
    url = mv_node <> "/dam/project/" <> mv_project_id

    case HTTPoison.get(url, get_headers(mv_token)) do
      {:ok, %{body: body}} -> Jason.decode(body)
      {:error, reason} -> {:error, reason}
    end
  end

  def download_asset(mv_node, mv_token, deeplinkkey) do
    url = mv_node <> "/dam/deeplink/" <> deeplinkkey <> "/download"
    HTTPoison.get(url, get_headers(mv_token), stream_to: self(), async: :once)
  end

  def download_preview_asset(mv_node, mv_token, previewlinkkey) do
    url = mv_node <> "/dam/previewlink/" <> previewlinkkey <> "/download"
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

  def fetch_asset_subtitles(mv_node, mv_token, mv_asset_key) do
    url = mv_node <> "/dam/assets/" <> mv_asset_key <> "/subtitles"

    with {:ok, %{body: body}} <- HTTPoison.get(url, get_headers(mv_token)),
         {:ok, asset_subtitles} when is_list(asset_subtitles) <- Jason.decode(body) do
      {:ok, asset_subtitles}
    else
      {:ok, %{"message" => message}} ->
        {:error, message}

      error ->
        error
    end
  end

  def download_asset_subtitle(mv_token, ext_file_url) do
    HTTPoison.get(ext_file_url, get_headers(mv_token), stream_to: self(), async: :once)
  end

  def fetch_project_assets(mv_node, mv_token, mv_project_id, current_page) do
    url = mv_node <> "/dam/project/" <> mv_project_id <> "/assets/paginated"
    int_current_page = String.to_integer(current_page)

    params = [
      page: int_current_page - 1,
      media_type: "image",
      media_type: "video",
      media_type: "audio",
      media_type: "model",
      per_page: 12
    ]

    with {:ok, %{body: body}} <- HTTPoison.get(url, get_headers(mv_token), params: params),
         {:ok, project_assets} when is_list(project_assets) <- Jason.decode(body) do
      {:ok, project_assets}
    else
      {:ok, %{"message" => message}} ->
        {:error, message}

      error ->
        error
    end
  end

  def upload_asset_to_mediaverse(asset_params) do
    url = asset_params.mv_node <> "/dam/assets"

    headers = [
      {"accept", "*/*"},
      {"Content-Type", "multipart/form-data"},
      {"Authorization", "Bearer #{asset_params.mv_token}"}
    ]

    params = [
      {:file, asset_params.data_file_path},
      {"description", asset_params.description},
      {"externalUrl", asset_params.external_url},
      {"externalTool", "Fader360"}
    ]

    {:ok, %{body: body}} = HTTPoison.post(url, {:multipart, params}, headers)
    Jason.decode(body)
  end

  def update_project(project_id, project_output, mv_node, mv_token) do
    url = mv_node <> "/dam/project/" <> project_id <> "/projectOutput"

    case HTTPoison.put(url, "", get_headers(mv_token), params: [projectOutput: project_output]) do
      {:ok, %{body: _body}} -> :ok
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
