defmodule DarthWeb.Assets.MvAssetLive.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.{MvApiClient, AssetProcessor.Downloader, AssetProcessor.PreviewDownloader}

  alias DarthWeb.Components.{
    Header,
    HeaderButtons,
    Pagination,
    EmptyState,
    IndexCard,
    CardButtons
  }

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_previews") do
      {:ok, socket |> assign(current_user: user, mv_token: mv_token)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.page_page_path(socket, :index))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.page_page_path(socket, :index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    mv_token = socket.assigns.mv_token
    mv_node = socket.assigns.current_user.mv_node
    base_url = DarthWeb.Endpoint.url()
    asset_preview_static_url = "#{base_url}/preview_download/"
    current_page = Map.get(params, "page", "1")

    case MvApiClient.fetch_assets(mv_node, mv_token, current_page) do
      {:ok,
       %{
         "assets" => assets,
         "currentPage" => current_page,
         "totalPages" => total_pages
       }} ->
        add_to_preview_downloader(assets, mv_node, mv_token)
        map_with_all_links = map_with_all_links(socket, total_pages)

        {:noreply,
         socket
         |> assign(
           mv_assets: assets,
           asset_preview_static_url: asset_preview_static_url,
           current_page: current_page + 1,
           total_pages: total_pages,
           map_with_all_links: map_with_all_links
         )}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, inspect(reason))
          |> redirect(to: Routes.page_page_path(socket, :index))

        {:noreply, socket}

      err ->
        Logger.error("Custom error message from MediaVerse: #{inspect(err)}")

        socket =
          socket
          |> put_flash(:error, inspect(err))
          |> redirect(to: Routes.page_page_path(socket, :index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_updated, _asset}, socket) do
    socket =
      socket
      |> push_navigate(to: Routes.mv_asset_index_path(socket, :index, page: socket.assigns.current_page))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, _asset}, socket) do
    socket =
      socket
      |> push_navigate(to: Routes.mv_asset_index_path(socket, :index, page: socket.assigns.current_page))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_preview_downloaded, _}, socket) do
    socket =
      socket
      |> push_navigate(to: Routes.mv_asset_index_path(socket, :index, page: socket.assigns.current_page))

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("add_mv_asset", %{"ref" => mv_asset_key}, socket) do
    add_to_fader(socket, mv_asset_key)
  end

  @impl Phoenix.LiveView
  def handle_event("add_all_mv_assets", _, socket) do
    mv_assets = socket.assigns.mv_assets

    for mv_asset <- mv_assets do
      mv_asset_key = Map.get(mv_asset, "key")

      case Asset.read_by(%{mv_asset_key: mv_asset_key}) do
        {:ok, _} -> :ok
        {:error, _} -> add_to_fader(socket, mv_asset_key)
      end
    end

    {:noreply, socket}
  end

  def handle_event("done", _, socket) do
    socket =
      socket
      |> put_flash(:info, "Asset already added to Fader")

    {:noreply, socket}
  end

  defp add_to_preview_downloader(assets, mv_node, mv_token) do
    for asset <- assets do
      filename = Map.get(asset, "originalFilename")
      asset_previewlink_key = Map.get(asset, "previewLinkKey")
      file_path = asset_file_path(asset_previewlink_key, filename)

      if File.exists?(file_path) do
        :ok
      else
        download_params = %{
          mv_asset_previewlink_key: asset_previewlink_key,
          mv_node: mv_node,
          mv_token: mv_token,
          mv_asset_filename: filename
        }

        PreviewDownloader.add_preview_download_params(download_params)
      end
    end
  end

  defp add_to_fader(socket, mv_asset_key) do
    mv_token = socket.assigns.mv_token
    current_user = socket.assigns.current_user
    mv_node = current_user.mv_node

    socket =
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
           database_params = Asset.build_asset_params(download_params),
           {:ok, asset_lease} <- Asset.add_asset_to_database(database_params, current_user),
           params = Map.put(download_params, :asset_struct, asset_lease.asset),
           :ok <-
             Downloader.add_download_params(params) do
        socket
        |> put_flash(:info, "Downloading MediaVerse Asset")
        |> push_patch(to: Routes.mv_asset_index_path(socket, :index, page: socket.assigns.current_page))
      else
        {:ok, %{"message" => message}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(message)}")

          socket
          |> put_flash(:error, message)
          |> push_patch(to: Routes.mv_asset_index_path(socket, :index))

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Server response error")
          |> push_patch(to: Routes.mv_asset_index_path(socket, :index))

        {:error, reason} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

          socket
          |> put_flash(:error, inspect(reason))
          |> push_patch(to: Routes.mv_asset_index_path(socket, :index))
      end

    {:noreply, socket}
  end

  defp map_with_all_links(socket, total_pages) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.mv_asset_index_path(socket, :index, page: page)}
    end)
  end

  defp render_audio_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={String.replace_suffix(@current_user.mv_node,"dam", "app/audio/" )<>
          Map.get(@mv_asset, "key")}
        image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
        audio_source={Path.join([@asset_preview_static_url,
          Map.get(@mv_asset, "previewLinkKey" ), Map.get(@mv_asset, "originalFilename" )])}
        title={Map.get(@mv_asset, "originalFilename" )}
        subtitle={Map.get(@mv_asset, "createdBy")}
        info={Map.get(@mv_asset, "contentType" )}
      >
        <.render_buttons
          mv_asset={@mv_asset}
          current_user={@current_user}
        />
      </IndexCard.render>
    """
  end

  defp render_video_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={String.replace_suffix(@current_user.mv_node,"dam", "app/video/")<>
          Map.get(@mv_asset, "key")}
        image_source={Path.join([@asset_preview_static_url,
          Map.get(@mv_asset, "previewLinkKey" ), Map.get(@mv_asset, "originalFilename" )])}
        title={Map.get(@mv_asset, "originalFilename" )}
        subtitle={Map.get(@mv_asset, "createdBy")}
        info={Map.get(@mv_asset, "contentType" )}
      >
        <.render_buttons
          mv_asset={@mv_asset}
          current_user={@current_user}
        />
      </IndexCard.render>
    """
  end

  defp render_image_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={String.replace_suffix(@current_user.mv_node,"dam", "app/image/" )<>
          Map.get(@mv_asset, "key")}
        image_source={Path.join([@asset_preview_static_url,
          Map.get(@mv_asset, "previewLinkKey" ), Map.get(@mv_asset, "originalFilename" )])}
        title={Map.get(@mv_asset, "originalFilename" )}
        subtitle={Map.get(@mv_asset, "createdBy")}
        info={Map.get(@mv_asset, "contentType" )}
      >
        <.render_buttons
          mv_asset={@mv_asset}
          current_user={@current_user}
        />
      </IndexCard.render>
    """
  end

  defp render_default_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={String.replace_suffix(@current_user.mv_node,"dam", "app/image/" )<>
          Map.get(@mv_asset, "key")}
        image_source={Routes.static_path(@socket, "/images/DefaultFileImage.svg" )}
        title={Map.get(@mv_asset, "originalFilename" )}
        subtitle={Map.get(@mv_asset, "createdBy")}
        info={Map.get(@mv_asset, "contentType" )}
      >
        <.render_buttons
          mv_asset={@mv_asset}
          current_user={@current_user}
        />
      </IndexCard.render>
    """
  end

  defp render_mv_asset_card(assigns) do
    if File.exists?(
         asset_file_path(
           Map.get(assigns.mv_asset, "previewLinkKey"),
           Map.get(assigns.mv_asset, "originalFilename")
         )
       ) do
      render_mv_asset_media_card(assigns)
    else
      render_default_card(assigns)
    end
  end

  defp render_mv_asset_media_card(assigns) do
    media_type = Asset.normalized_media_type(Map.get(assigns.mv_asset, "contentType"))

    case media_type do
      :audio ->
        render_audio_card(assigns)

      :video ->
        render_video_card(assigns)

      :image ->
        render_image_card(assigns)
    end
  end

  defp render_buttons(assigns) do
    ~H"""
      <%= if Asset.asset_already_added?(Map.get(@mv_asset, "key"), @current_user.id) do %>
        <CardButtons.render
          buttons={[
            {
              :done,
              label: "Added to Fader"
            }
          ]}
        />
      <%else%>
        <CardButtons.render
          buttons={[
            {
              :add_mv_asset,
              phx_value_ref: Map.get(@mv_asset, "key" ),
              label: "Add to Fader"
            }
          ]}
        />
      <% end %>
    """
  end

  defp asset_file_path(preview_link_key, original_filename) do
    download_path = Application.get_env(:darth, :mv_asset_preview_download_path)
    app_path = Application.app_dir(:darth, download_path)
    Path.join([app_path, preview_link_key, original_filename])
  end
end
