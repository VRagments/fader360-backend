defmodule Darth.PlaceholderAssets do
  require Logger
  alias DarthWeb.UploadProcessor
  alias Darth.Controller.Asset

  def placeholder_assets() do
    video_attr = %{duration: 14.2142, file_size: 19_862_487, height: 720, width: 1280}
    audio_attr = %{duration: 4.320998, file_size: 45486, height: 0, width: 0}
    image_attr = %{duration: 0, file_size: 2_029_652, height: 1440, width: 2560}

    [
      placeholder_asset("2d_video.mp4", "video", video_attr),
      placeholder_asset("image.jpg", "image", image_attr),
      placeholder_asset("audio.ogg", "audio", audio_attr)
    ]
  end

  defp placeholder_asset(file_name, status_prefix, attr) do
    %{
      "static_url" => static_url(file_name),
      "thumbnail_image" => static_url(file_name),
      "media_type" => mime_type(Application.app_dir(:darth, ["priv", "static", "placeholder_assets", file_name])),
      "name" => file_name,
      "status" => "#{status_prefix}_placeholder",
      "attributes" => attr
    }
  end

  defp mime_type(file_path) do
    case UploadProcessor.get_mime_type(file_path) do
      {:ok, asset_mime_type} ->
        asset_mime_type

      :error ->
        Logger.error("Cannot extract the mimetype of the placeholder asset: #{file_path}")
        nil
    end
  end

  defp static_url(asset_name) do
    base_url = Path.join([DarthWeb.Endpoint.url(), DarthWeb.Endpoint.path("/")])
    "#{base_url}/placeholder_assets/#{asset_name}"
  end

  def add_placeholder_assets_to_database() do
    Enum.map(placeholder_assets(), fn placeholder_asset_details ->
      with false <- skip_asset_creation?(placeholder_asset_details),
           :ok <- UploadProcessor.check_for_uploaded_asset_media_type(placeholder_asset_details),
           {:ok, asset_struct} <- Asset.create(placeholder_asset_details) do
        {:ok, asset_struct}
      else
        {:error, reason} ->
          Logger.error("Adding the placeholder asset to Fader failed:
              #{Map.get(placeholder_asset_details, "name")} with reason
                #{inspect(reason)}")

          {:error, reason}

        true ->
          Logger.error("Skipped placeholder asset creation as it already exists:
              #{Map.get(placeholder_asset_details, "name")}")
          {:error, "Skipped"}
      end
    end)
    |> errors_from_results()
  end

  defp errors_from_results(results) do
    errors =
      results
      |> Enum.filter(fn
        {:error, _} -> true
        {:ok, _} -> false
      end)
      |> Enum.map(fn {_, reason} -> reason end)

    case errors do
      [] -> {:ok, Enum.map(results, fn {:ok, r} -> r end)}
      x -> {:error, x}
    end
  end

  defp skip_asset_creation?(%{"status" => status}) do
    case Asset.read_by(%{status: status}) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
