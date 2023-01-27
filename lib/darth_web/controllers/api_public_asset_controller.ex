defmodule DarthWeb.ApiPublicAssetController do
  use DarthWeb, :controller
  alias DarthWeb.QueryParameters
  alias Darth.Controller.AssetLease

  def swagger_definitions do
    %{
      PublicAsset:
        swagger_schema do
          title("PublicAsset")
          description("A public asset")

          properties do
            attributes(:object, "Custom asset attributes")
            id(:string, "Asset ID")
            inserted_at(:string, "created at this time (Date)")
            lowres_image(:string, "URL for the asset's low-resolution version (only applicable to image)")
            media_type(:string, "Media Type")
            midres_image(:string, "URL for the asset's mid-resolution version (only applicable to image)")
            name(:string, "User-provided asset name")
            preview_image(:string, "URL for the asset's preview image")
            squared_image(:string, "URL for the asset's squared image")
            static_url(:string, "URL for the asset")
            status(:string, "Processing status of the asset")
            thumbnail_image(:string, "URL for the asset's thumbnail image")
            updated_at(:string, "updated at this time (Date)")
          end

          example(%{
            attributes: %{
              "key_one" => "somedate",
              "key_two" => "someotherdate"
            },
            id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            lowres_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/lowres_picture.jpg",
            media_type: "image/jpeg",
            midres_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/midres_picture.jpg",
            name: "my asset one",
            preview_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
            squared_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/squared_picture.jpg",
            static_url: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/picture.jpg",
            status: "ready",
            thumbnail_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg"
          })
        end,
      PartialPublicAsset:
        swagger_schema do
          title("PartialPublicAsset")
          description("A partial public assets")

          properties do
            id(:string, "Asset ID")
            media_type(:string, "Media Type")
            name(:string, "User-provided asset name")
            preview_image(:string, "URL for the asset's preview image")
            squared_image(:string, "URL for the asset's squared image")
            static_url(:string, "URL for the asset")
            status(:string, "Processing status of the asset")
            thumbnail_image(:string, "URL for the asset's thumbnail image")
          end

          example(%{
            id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            media_type: "image/jpeg",
            name: "my asset one",
            preview_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
            squared_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/squared_picture.jpg",
            static_url: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/picture.jpg",
            status: "ready",
            thumbnail_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg"
          })
        end,
      PublicAssets:
        swagger_schema do
          title("PublicAssets")
          description("A list of public assets")

          properties do
            objects(Schema.array(:PublicAsset), "A public asset")
            total(:integer, "The total count of all assets")
          end

          example(%{
            total: 1,
            objects: [
              %{
                attributes: %{
                  "key_one" => "somedate",
                  "key_two" => "someotherdate"
                },
                id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                lowres_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/lowres_picture.jpg",
                media_type: "image/jpeg",
                midres_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/midres_picture.jpg",
                name: "my asset one",
                preview_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
                squared_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/squared_picture.jpg",
                static_url: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/picture.jpg",
                status: "ready",
                thumbnail_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg"
              }
            ]
          })
        end
    }
  end

  swagger_path(:index) do
    get("/api/public/assets")
    summary("List Public Assets")
    description("Returns list of assets based on input parameters. Only covers public asset leases.")
    produces("application/json")

    QueryParameters.list_query()

    response(200, "OK", Schema.ref(:PublicAssets))
  end

  def index(conn, params) do
    assigns = AssetLease.query_by_license("public", params)
    render(conn, "index.json", assigns)
  end

  swagger_path(:show) do
    get("/api/public/assets/{id}")
    summary("Show Public Asset")
    description("Returns details of an asset by asset lease ID. Only allowed for public asset leases.")
    produces("application/json")

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:PublicAsset))
    response(404, "Not Found, if the asset visibility prohibits the call")
  end

  def show(conn, %{"id" => id}) do
    fun = fn lease ->
      conn
      |> put_status(:ok)
      |> render("show.json", object: lease)
    end

    ensure_public_allowed(id, fun)
  end

  defp ensure_public_allowed(lease_id, fun) do
    with {:ok, lease} <- AssetLease.read(lease_id) do
      if lease.license == :public do
        fun.(lease)
      else
        # Even if the lease exists and is not public, we report it as not found
        {:error, :not_found}
      end
    end
  end
end
