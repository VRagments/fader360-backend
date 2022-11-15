defmodule DarthWeb.LiveMvAsset.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User
  alias DarthWeb.MvAssetView
  alias Darth.{MvApiClient, AssetProcessor.Downloader}

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         mv_node = user.mv_node,
         {:ok, assets} <- MvApiClient.fetch_assets(mv_node, mv_token) do
      {:ok,
       socket
       |> assign(current_user: user, mv_assets: assets, mv_token: mv_token)}
    else
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, inspect(reason))
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

        {:ok, socket}

      {:error, reason} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, inspect(reason))
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveMvAsset.Index))

        {:ok, socket}

      _ ->
        Logger.error("Error message from MediaVerse: User not found")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LivePage.Page))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("add_mv_asset", %{"ref" => mv_asset_key}, socket) do
    mv_node = socket.assigns.current_user.mv_node
    mv_token = socket.assigns.mv_token

    with {:ok, asset} <- MvApiClient.show_asset(mv_node, mv_token, mv_asset_key),
         download_params = %{
           media_type: Map.get(asset, "contentType"),
           mv_asset_key: Map.get(asset, "key"),
           mv_asset_deeplink_key: Map.get(asset, "deepLinkKey"),
           mv_node: mv_node,
           mv_token: mv_token,
           mv_asset_filename: Map.get(asset, "originalFilename"),
           current_user: socket.assigns.current_user
         },
         :ok <- Downloader.add_download_params(download_params) do
      socket =
        socket
        |> put_flash(:info, "Downloading MediVerse Asset")
        |> redirect(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

      {:noreply, socket}
    else
      {:ok, %{"message" => message}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(message)}")

        socket =
          socket
          |> put_flash(:error, message)
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Server response error")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}

      {:error, chnageset = %Ecto.Changeset{}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(chnageset)}")

        socket =
          socket
          |> put_flash(:error, "Databse error")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, inspect(reason))
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}

      nil ->
        Logger.error("Custom error message from MediaVerse: User Asset not found with the given asset_id")

        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}
    end
  end
end
