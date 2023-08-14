defmodule DarthWeb.UploadProcessor do
  require Logger
  alias Darth.Controller.AssetSubtitle
  alias Darth.Controller.Asset
  alias DarthWeb.Router.Helpers, as: Routes

  def create_uploads_base_path do
    path = Application.get_env(:darth, :uploads_base_path)
    uploads_base_path = Application.app_dir(:darth, path)

    case File.mkdir_p(uploads_base_path) do
      :ok -> :ok
      {:error, reason} -> {:error, "Error while creating the upload file path: #{inspect(reason)}"}
    end
  end

  def get_uploaded_entries(socket, type) do
    uploaded_file_path =
      Phoenix.LiveView.consume_uploaded_entries(socket, type, fn %{path: path},
                                                                 %Phoenix.LiveView.UploadEntry{
                                                                   client_name: file_name
                                                                 } ->
        handle_uploaded_entries(socket, path, file_name)
      end)

    case Enum.all?(uploaded_file_path) do
      true -> {:ok, uploaded_file_path}
      false -> {:error, "Error while copying the uploaded asset"}
    end
  end

  def get_asset_details(socket, uploaded_file_path) do
    case get_required_asset_details(socket, uploaded_file_path) do
      nil -> {:error, "Asset details cannot be fetched from the uploaded entry"}
      asset_details -> {:ok, asset_details}
    end
  end

  def get_subtitle_file_details(socket, uploaded_file_path) do
    case get_required_subtitle_file_details(socket, uploaded_file_path) do
      nil -> {:error, "Subtitle file details cannot be fetched from the uploaded entry"}
      subtitle_file_details -> {:ok, subtitle_file_details}
    end
  end

  def check_for_uploaded_asset_media_type(asset_details) do
    case is_nil(Asset.normalized_media_type(Map.get(asset_details, "media_type"))) do
      true -> {:error, "Uploaded asset type is not supported in Fader"}
      false -> :ok
    end
  end

  def check_for_uploaded_subtitle_file_type(subtitle_file_details) do
    case is_nil(AssetSubtitle.normalized_media_type(Map.get(subtitle_file_details, "media_type"))) do
      true -> {:error, "Uploaded subtitle file type is not supported in Fader"}
      false -> :ok
    end
  end

  def get_required_asset_details(socket, filepath) do
    case socket.assigns.uploads.media.entries do
      [%Phoenix.LiveView.UploadEntry{} = uploaded_file] ->
        %{
          "name" => uploaded_file.client_name,
          "media_type" => uploaded_file.client_type,
          "data_path" => filepath
        }

      _ ->
        nil
    end
  end

  def get_required_subtitle_file_details(socket, filepath) do
    with {:ok, subtitle_file_mime_type} <- get_mime_type(filepath),
         [%Phoenix.LiveView.UploadEntry{} = uploaded_file] <- socket.assigns.uploads.subtitle.entries do
      %{
        "name" => uploaded_file.client_name,
        "media_type" => subtitle_file_mime_type,
        "file_path" => filepath
      }
    else
      _ -> nil
    end
  end

  def handle_uploaded_entries(socket, path, file_name) do
    dest = Application.app_dir(:darth, ["priv", "static", "uploads", file_name])
    Application.app_dir(:darth, ["priv", "static", "uploads", file_name])
    # The `static/uploads` directory must exist for `File.cp!/2` to work.
    case File.cp(path, dest) do
      :ok ->
        {:ok, Routes.static_path(socket, dest)}

      {:error, reason} ->
        Logger.error("Error while copying the uploaded asset: #{inspect(reason)}")
        {:ok, nil}
    end
  end

  def get_mime_type(file_path) do
    case System.cmd("file", ["--mime-type", to_string(file_path)]) do
      {result, 0} ->
        if String.contains?(result, "cannot open") do
          Logger.error("Error while extracting the mime type of given subtitle file: #{inspect(result)}")
          :error
        else
          [_, mime_type] = String.split(result, ":")
          {:ok, String.trim(mime_type)}
        end

      {_, status} ->
        Logger.error(
          "Exited with error code while extracting the mime type of the subtitle file: #{inspect(status)}"
        )

        :error
    end
  end
end
