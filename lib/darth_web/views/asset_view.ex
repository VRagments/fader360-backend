defmodule DarthWeb.AssetView do
  use DarthWeb, :view
  alias Darth.Controller.Asset

  def is_mediaverse_account?(conn) do
    case conn.assigns.current_user.mv_node do
      nil ->
        false

      _ ->
        true
    end
  end

  def is_asset_status_ready(asset_status) do
    case asset_status == "ready" do
      true -> true
      false -> false
    end
  end

  def is_audio_file(media_type) do
    case Asset.normalized_media_type(media_type) do
      :audio -> true
      _ -> false
    end
  end

  def is_video_file(media_type) do
    case Asset.normalized_media_type(media_type) do
      :audio -> true
      _ -> false
    end
  end

  def is_image_file(media_type) do
    case Asset.normalized_media_type(media_type) do
      :image -> true
      _ -> false
    end
  end

  def get_width(attributes) do
    Map.get(attributes, "width")
  end

  def get_height(attributes) do
    Map.get(attributes, "height")
  end

  def get_file_size(attributes) do
    size = Map.get(attributes, "file_size")

    (size * 0.000001)
    |> Float.round(2)
    |> inspect
  end

  def get_duration(attributes) do
    duration = Map.get(attributes, "duration")

    case duration > 0 do
      true ->
        duration
        |> Float.round(2)
        |> inspect

      false ->
        duration
    end
  end
end
