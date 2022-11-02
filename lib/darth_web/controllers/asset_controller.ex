defmodule DarthWeb.AssetController do
  use DarthWeb, :controller
  require Logger
  alias Darth.Controller.Asset
  alias Darth.Controller.AssetLease
  alias DarthWeb.UserAuth

  def index(conn, params) do
    user = conn.assigns.current_user

    with %{entries: asset_leases} <- AssetLease.query_by_user(user.id, params, false) do
      conn
      |> render("assets.html", asset_leases: asset_leases)
    else
      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Custom error message from MediaVerse: Database error while fetching assets: #{query_error}")
        error_fetch_assets(conn, query_error)
    end
  end

  def show(conn, %{"asset_id" => asset_id}) do
    case Asset.read(asset_id) do
      {:ok, asset} ->
        asset_leases = AssetLease.current_leases(asset)

        conn
        |> render("asset_detail.html", asset: asset, asset_leases: asset_leases)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Unable to fetch asset details")
        |> redirect(to: Routes.asset_path(conn, :index))
    end
  end

  def upload(conn, params) do
    with %{} = upload <- Map.get(params, "upload"),
         %{} = media <- Map.get(upload, "media"),
         true <- not is_nil(Asset.normalized_media_type(media.content_type)),
         params = %{
           "name" => media.filename,
           "media_type" => media.content_type,
           "data_path" => media.path
         },
         user = conn.assigns.current_user,
         {:ok, asset_struct} <- Asset.create(params),
         {:ok, _lease} <- AssetLease.create_for_user(asset_struct, user) do
      conn
      |> put_flash(:info, "Asset uploaded successfully")
      |> redirect(to: Routes.asset_path(conn, :index))
    else
      {:error, reason} ->
        conn
        |> put_flash(:error, "Unable to add asset to the database: #{reason}")
        |> redirect(to: Routes.asset_path(conn, :index))

      false ->
        conn
        |> put_flash(:error, "Selected asset type cannot be used in Fader!")
        |> redirect(to: Routes.asset_path(conn, :index))

      nil ->
        conn
        |> put_flash(:error, "Choose a file to upload!")
        |> redirect(to: Routes.asset_path(conn, :index))
    end
  end

  def re_transcode_asset(conn, %{"asset_id" => asset_id}) do
    case Phoenix.PubSub.broadcast(Darth.PubSub, "assets", {:asset_transcode, asset_id}) do
      :ok ->
        conn
        |> put_flash(:info, "Re-transcoding asset")
        |> redirect(to: Routes.asset_path(conn, :index))

      error ->
        conn
        |> put_flash(:error, "Unable to start asset Re-transcoding: #{error}")
        |> redirect(to: Routes.asset_path(conn, :index))
    end
  end

  def delete_asset(conn, %{"asset_id" => asset_id}) do
    current_asset_folder = Application.get_env(:darth, :asset_static_base_path) <> asset_id

    with :ok <- Asset.delete(asset_id),
         {:ok, _} <- File.rm_rf(current_asset_folder) do
      conn
      |> put_flash(:info, "Asset deleted successfully")
      |> redirect(to: Routes.asset_path(conn, :index))
    else
      {:error, _, _} ->
        conn
        |> put_flash(:error, "Asset cannot be deleted")
        |> redirect(to: Routes.asset_path(conn, :index))

      {:error, _} ->
        conn
        |> put_flash(:error, "Asset not found")
        |> redirect(to: Routes.asset_path(conn, :index))
    end
  end

  defp error_fetch_assets(conn, reason) do
    conn
    |> put_flash(:error, "Assets cannot be fetced due to: #{reason}")
    |> UserAuth.logout_user()
    |> redirect(to: Routes.user_session_path(conn, :login))
  end
end
