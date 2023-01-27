defmodule DarthWeb.ApiPublicOptimizedProjectAssetsView do
  def render("index.json", %{entries: entries, total_entries: total_entries}) do
    objects =
      entries
      |> Darth.Repo.preload(:asset)
      |> Enum.map(&single/1)

    %{
      objects: objects,
      total: total_entries
    }
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp single(%{asset: a, id: id}) do
    %{
      attributes: a.attributes,
      id: id,
      inserted_at: a.inserted_at,
      lowres_image: a.lowres_image,
      media_type: a.media_type,
      midres_image: a.midres_image,
      name: a.name,
      preview_image: a.preview_image,
      squared_image: a.squared_image,
      static_url: a.static_url,
      status: a.status,
      thumbnail_image: a.thumbnail_image,
      updated_at: a.updated_at
    }
  end
end
