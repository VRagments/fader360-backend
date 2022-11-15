defmodule DarthWeb.AssetView do
  use DarthWeb, :view

  def is_asset_status_ready?(asset_status), do: asset_status == "ready"

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
