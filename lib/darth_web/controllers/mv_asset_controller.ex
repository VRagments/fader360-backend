defmodule DarthWeb.MvAssetController do
  use DarthWeb, :controller
  require Logger

  alias Darth.{MvApiClient, AssetProcessor.Downloader}
  alias DarthWeb.UserAuth

  def index(conn, _params) do
    mv_node = conn.assigns.current_user.mv_node
    mv_token = conn.assigns.user_token

    with {:ok, assets} <- MvApiClient.fetch_assets(mv_node, mv_token) do
      conn
      |> render("mv_assets.html", mv_assets: assets)
    else
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")
        error_get_assets(conn, "Server response error")

      {:error, reason} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")
        error_get_assets(conn, inspect(reason))
    end
  end

  def download_asset(conn, params) do
    mv_node = conn.assigns.current_user.mv_node
    mv_token = conn.assigns.user_token
    mv_asset_key = Map.get(params, "asset_key")

    with {:ok, asset} <- MvApiClient.show_asset(mv_node, mv_token, mv_asset_key),
         download_params = %{
           media_type: Map.get(asset, "contentType"),
           mv_asset_key: Map.get(asset, "key"),
           mv_asset_deeplink_key: Map.get(asset, "deepLinkKey"),
           mv_node: mv_node,
           mv_token: mv_token,
           mv_asset_filename: Map.get(asset, "originalFilename")
         },
         :ok <- Downloader.add_download_params(download_params) do
      conn
      |> redirect(to: Routes.mv_asset_path(conn, :index))
    else
      {:ok, %{"message" => message}} ->
        error_get_assets(conn, message)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")
        error_get_assets(conn, "Server response error")

      {:error, chnageset = %Ecto.Changeset{}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(chnageset)}")

      {:error, reason} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        error_get_assets(conn, inspect(reason))

      nil ->
        Logger.error("Custom error message from MediaVerse: User Asset not found with the given asset_id")

        error_get_assets(conn, "Asset not found")
    end
  end

  defp error_get_assets(conn, reason) do
    conn
    |> put_flash(:error, "MediaVerse assets cannot be fetced due to: #{reason}")
    |> UserAuth.logout_user()
    |> redirect(to: Routes.user_session_path(conn, :mv_login))
  end
end
