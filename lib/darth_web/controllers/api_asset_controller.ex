defmodule DarthWeb.ApiAssetController do
  use DarthWeb, :controller
  require Logger
  alias Darth.Repo
  alias DarthWeb.QueryParameters
  alias Darth.Controller.Asset
  alias Darth.Controller.AssetLease

  def swagger_definitions do
    %{
      Asset:
        swagger_schema do
          title("Asset")
          description("An asset")

          properties do
            attributes(Schema.ref(:AssetAttributes), "Custom attributes")
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
      PartialAsset:
        swagger_schema do
          title("PartialAsset")
          description("A partial asset")

          properties do
            id(:string, "Asset ID")
            name(:string, "User-provided asset name")
            preview_image(:string, "URL for the asset's preview image")
            squared_image(:string, "URL for the asset's squared image")
            static_url(:string, "URL for the asset")
            status(:string, "Processing status of the asset")
            thumbnail_image(:string, "URL for the asset's thumbnail image")
          end

          example(%{
            id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            name: "my asset one",
            preview_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
            squared_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/squared_picture.jpg",
            static_url: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/picture.jpg",
            status: "ready",
            thumbnail_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg"
          })
        end,
      Assets:
        swagger_schema do
          title("Assets")
          description("A list of assets")

          properties do
            objects(Schema.array(:PartialAsset), "A partial asset")
            total(:integer, "The total count of all assets")
          end

          example(%{
            total: 11,
            entries: [
              %{
                id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                name: "my asset one",
                preview_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
                squared_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/squared_picture.jpg",
                static_url: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/picture.jpg",
                status: "ready",
                thumbnail_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg"
              },
              %{
                id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
                name: "my asset one",
                preview_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/preview_picture.jpg",
                squared_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/squared_picture.jpg",
                static_url: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/picture.jpg",
                status: "ready",
                thumbnail_image: "http://localhost/assets/fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7/thumb_picture.jpg"
              }
            ]
          })
        end,
      AssetLicense:
        swagger_schema do
          title("AssetLicense")
          description("The new license for an Asset")

          properties do
            license(:string, "Asset License",
              required: true,
              enum: [:owner, :link_share, :public]
            )
          end

          example(%{
            license: "public"
          })
        end,
      AssetAttributes:
        swagger_schema do
          title("AssetAttributes")
          description("Custom Asset Attributes")

          properties do
            some_key_one(:string, "some custom key")
            another_key(:string, "another custom key")
          end

          example(%{
            some_key_one: "my data",
            another_key: "other data here"
          })
        end
    }
  end

  swagger_path(:index) do
    get("/api/assets")
    summary("List of Assets")

    description(~s(Returns list of assets based on input parameters.
                   Combines public asset leases and asset leases owned by the authenticated user.))

    produces("application/json")
    security([%{Bearer: []}])
    QueryParameters.list_query()

    response(200, "OK", Schema.ref(:Assets))
  end

  def index(conn, params) do
    user = conn.assigns.current_api_user
    assigns = AssetLease.query_by_user(user.id, params)
    render(conn, "index.json", assigns)
  end

  swagger_path(:show) do
    get("/api/assets/{id}")
    summary("Show Asset")

    description(~s(Returns details of a given asset.
                   Only allowed for public asset leases and asset leases owned by the authenticated user.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:Asset))
    response(404, "Not Found, if the asset visibility prohibits the call")
  end

  def show(conn, %{"id" => lease_id}) do
    fun = fn _user, lease ->
      conn
      |> put_status(:ok)
      |> render("show.json", object: lease)
    end

    ensure_lease_owner_or_public(conn, lease_id, fun)
  end

  swagger_path(:create) do
    post("/api/assets")
    summary("Create Asset")

    description(~s(Creates new asset and corresponding asset lease with type owner.
                   Returns details of the created asset.))

    produces("application/json")
    security([%{Bearer: []}])
    QueryParameters.asset_create_or_update()

    response(201, "Created", Schema.ref(:Asset))
    response(422, "Error")
  end

  def create(conn, params) do
    user = conn.assigns.current_api_user
    asset_params = read_media_file_data(params)

    with {:ok, asset} <- Asset.create(asset_params),
         {:ok, asset} <- Asset.init(asset, asset_params),
         {:ok, lease} <- AssetLease.create_for_user(asset, user) do
      conn
      |> put_status(:created)
      |> render("show.json", object: lease)
    end
  end

  swagger_path(:update) do
    put("/api/assets/{id}")
    summary("Update Asset")
    description("Updates asset. Only allowed for asset owners.")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    QueryParameters.asset_create_or_update(false)

    response(200, "OK", Schema.ref(:Asset))
    response(404, "Not Found")
    response(422, "Error")
  end

  def update(conn, %{"id" => lease_id} = params) do
    fun = fn _user, lease ->
      with {:ok, _updated_asset} <- Asset.update(lease.asset_id, read_media_file_data(params)) do
        lease = Repo.preload(lease, [:asset])

        conn
        |> put_status(:ok)
        |> render("show.json", object: lease)
      end
    end

    ensure_lease_owner(conn, lease_id, fun)
  end

  swagger_path(:delete) do
    PhoenixSwagger.Path.delete("/api/assets/{id}")
    summary("Delete Asset Lease")

    description(~s(If the authenticated user is the asset owner:
                   invalidates all public asset leases, invalidates the owner lease.
                   Keeps the project assignments intact.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(204, "Success - No Content")
    response(404, "Not Found")
    response(422, "Error")
  end

  def delete(conn, %{"id" => lease_id}) do
    fun = fn user, lease ->
      with {:ok, asset_lease} <- AssetLease.remove_user(lease, user),
           :ok <- AssetLease.maybe_delete(asset_lease),
           :ok <- Asset.delete(asset_lease.asset) do
        send_resp(conn, :no_content, "")
      else
        _ ->
          handle_asset_lease_deletion(conn.assigns.current_api_user, lease_id)
      end
    end

    ensure_lease_user(conn, lease_id, fun)
  end

  swagger_path(:change_license) do
    put("/api/assets/{id}/license")
    summary("Change Asset Lease License")

    description(~s(Allows the asset owner to switch licenses.
                   If switch to public, a new public asset lease will be created.
                   If switch to private, all existing public asset leases will be invalidated.
                   Only allowed for asset owners.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")

      asset(:body, Schema.ref(:AssetLicense), "Asset License", required: true)
    end

    response(204, "Success - No Content")
    response(404, "Not Found")
    response(422, "Error")
  end

  def change_license(conn, %{"api_asset_id" => lease_id, "license" => license}) do
    fun = fn _user, lease ->
      with {:ok, _active_lease} <- Asset.change_license(lease.asset, license) do
        send_resp(conn, :no_content, "")
      end
    end

    ensure_lease_owner(conn, lease_id, fun)
  end

  swagger_path(:assign_user) do
    put("/api/assets/{id}/users")
    summary("Add User to Asset Lease")
    description("Adds the authenticated user to a given asset lease. Only allowed for public asset leases.")
    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:Asset))
    response(404, "Not Found")
    response(422, "Error")
  end

  def assign_user(conn, %{"api_asset_id" => lease_id}) do
    user = conn.assigns.current_api_user

    with {:ok, lease} <- AssetLease.read(lease_id),
         {:ok, active_lease} <- AssetLease.assign(lease, user) do
      conn
      |> put_status(:ok)
      |> render("show.json", object: active_lease)
    end
  end

  swagger_path(:remove_user) do
    PhoenixSwagger.Path.delete("/api/assets/{id}/users")
    summary("Remove User from Asset Lease")

    description(~s(Removes the authenticated user and all the user's projects from the given asset lease.
                   Only allowed for public asset leases.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:Asset))
    response(404, "Not Found")
    response(422, "Error")
  end

  def remove_user(conn, %{"api_asset_id" => lease_id}) do
    user = conn.assigns.current_api_user

    with {:ok, lease1} <- AssetLease.read(lease_id),
         {:ok, lease2} <- AssetLease.remove_user_projects(lease1, user),
         {:ok, active_lease} <- AssetLease.remove_user(lease2, user) do
      conn
      |> put_status(:ok)
      |> render("show.json", object: active_lease)
    end
  end

  swagger_path(:assign_project) do
    put("/api/assets/{id}/projects")
    summary("Add Project to Asset Lease")

    description(~s(Adds the authenticated user and the given project, which must be owned by the user,
                   to a given asset lease.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")

      project_id(:query, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:Asset))
    response(404, "Not Found")
    response(422, "Error")
  end

  def assign_project(conn, %{"api_asset_id" => lease_id, "project_id" => project_id}) do
    user = conn.assigns.current_api_user

    with {:ok, lease} <- AssetLease.read(lease_id),
         {:ok, active_lease} <- AssetLease.assign_project(lease, user, project_id) do
      conn
      |> put_status(:ok)
      |> render("show.json", object: active_lease)
    end
  end

  swagger_path(:remove_project) do
    PhoenixSwagger.Path.delete("/api/assets/{id}/projects")
    summary("Remove Project from Asset Lease")

    description(~s(Removes the given project, which must be owned by the authenticated user,
                   from the given asset lease.))

    produces("application/json")
    security([%{Bearer: []}])

    parameters do
      id(:path, :string, "Asset Lease ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")

      project_id(:query, :string, "Project ID", required: true, example: "5d7e8d3d-2505-4ea6-af2c-d304a3159e55")
    end

    response(200, "OK", Schema.ref(:Asset))
    response(404, "Not Found")
    response(422, "Error")
  end

  def remove_project(conn, %{"api_asset_id" => lease_id, "project_id" => project_id}) do
    user = conn.assigns.current_api_user

    with {:ok, lease} <- AssetLease.read(lease_id),
         {:ok, active_lease} <- AssetLease.unassign_project(lease, user, project_id) do
      conn
      |> put_status(:ok)
      |> render("show.json", object: active_lease)
    end
  end

  defp ensure_lease_owner_or_public(conn, lease_id, fun) do
    user = conn.assigns.current_api_user

    with {:ok, lease} <- AssetLease.read(lease_id) do
      if AssetLease.is_owner?(lease, user) or lease.license == :public do
        fun.(user, lease)
      else
        # Even if the lease exists, we report it as not found
        {:error, :not_found}
      end
    end
  end

  defp ensure_lease_user(conn, lease_id, fun) do
    user = conn.assigns.current_api_user

    with {:ok, lease} <- AssetLease.read(lease_id) do
      if AssetLease.has_user?(lease, user) do
        fun.(user, lease)
      else
        # Even if the lease exists, we report it as not found
        {:error, :not_found}
      end
    end
  end

  defp ensure_lease_owner(conn, lease_id, fun) do
    user = conn.assigns.current_api_user

    with {:ok, lease} <- AssetLease.read(lease_id) do
      if AssetLease.is_owner?(lease, user) do
        fun.(user, lease)
      else
        # Even if the lease exists, we report it as not found
        {:error, :not_found}
      end
    end
  end

  defp handle_asset_lease_deletion(user, asset_lease_id) do
    with {:ok, asset_lease} <- AssetLease.read(asset_lease_id),
         {:ok, _asset_lease} <- AssetLease.add_user(asset_lease, user) do
      {:error, "Asset cannot be deleted"}
    else
      {:error, reason} ->
        {:error, reason}

      nil ->
        {:error, :not_found}
    end
  end
end
