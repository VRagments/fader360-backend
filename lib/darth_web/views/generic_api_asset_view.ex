defmodule DarthWeb.GenericApiAssetView do
  defmacro __using__(_) do
    quote do
      use DarthWeb, :view

      def render("index.json", %{attributes: attrs, entries: entries, total_entries: total}) do
        %{
          objects: render_many(entries, __MODULE__, "partial-asset.json", %{attributes: attrs}),
          total: total
        }
      end

      def render("show.json", %{object: object} = assigns) do
        attrs = if is_nil(assigns[:attributes]), do: [], else: assigns[:attributes]
        render_one(object, __MODULE__, "asset.json", %{attributes: attrs})
      end

      def render("asset.json", %{attributes: []} = params) do
        model = get_model(params)
        %{asset: a} = Darth.Repo.preload(model, [:asset])

        %{
          attributes: a.attributes,
          id: model.id,
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

      def render("asset.json", %{attributes: attrs} = params) do
        model = get_model(params)
        build_body(nil, Darth.Model.Asset, model, attrs)
      end

      def render("partial-asset.json", %{attributes: []} = params) do
        model = get_model(params)
        %{asset: a} = Darth.Repo.preload(model, [:asset])

        %{
          attributes: a.attributes,
          id: model.id,
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

      def render("partial-asset.json", %{attributes: attrs} = params) do
        model = get_model(params)
        build_body(nil, Darth.Model.Asset, model, attrs)
      end

      #
      # INTERNAL FUNCTIONS
      #

      defp get_model(%{api_public_project_asset: model}), do: model
      defp get_model(%{api_project_asset: model}), do: model
      defp get_model(%{api_public_asset: model}), do: model
      defp get_model(%{api_asset: model}), do: model
      defp get_model(_), do: nil
    end
  end
end
