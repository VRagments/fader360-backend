defmodule DarthWeb.Projects.MvProjectLive.FormPreviewAssets do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Controller.Project
  alias Darth.Model.User, as: UserStruct
  alias Darth.MvApiClient
  alias Darth.AssetProcessor.PreviewDownloader

  alias DarthWeb.Components.{
    Header,
    IndexCard,
    HeaderButtons,
    Pagination,
    EmptyState
  }

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    socket =
      case User.get_user_by_token(user_token, "session") do
        %UserStruct{} = user ->
          socket
          |> assign(current_user: user, mv_token: mv_token)

        {:error, reason} ->
          Logger.error("Error while reading user information: #{inspect(reason)}")

          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.page_page_path(socket, :index))

        nil ->
          Logger.error("Error message: User not found in database")

          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.page_page_path(socket, :index))
      end

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"mv_project_id" => mv_project_id} = params, _url, socket) do
    mv_token = socket.assigns.mv_token
    mv_node = socket.assigns.current_user.mv_node
    base_url = Path.join([DarthWeb.Endpoint.url(), DarthWeb.Endpoint.path("/")])
    asset_preview_static_url = "#{base_url}/preview_download/"
    current_page = Map.get(params, "page", "1")

    socket =
      with {:ok, mv_project} <- MvApiClient.show_project(mv_node, mv_token, mv_project_id),
           {:ok, %{"assets" => assets, "currentPage" => current_page, "totalPages" => total_pages}} <-
             Project.fetch_mv_project_assets(mv_node, mv_token, mv_project_id, current_page) do
        PreviewDownloader.add_to_preview_downloader(assets, mv_node, mv_token)
        map_with_all_links = map_with_all_links(socket, mv_project_id, total_pages)

        socket
        |> assign(
          mv_project: mv_project,
          mv_assets: assets,
          asset_preview_static_url: asset_preview_static_url,
          map_with_all_links: map_with_all_links,
          total_pages: total_pages,
          current_page: current_page + 1
        )
      else
        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Error message: Database error while fetching user projects: #{inspect(query_error)}")

          socket =
            socket
            |> put_flash(:error, "Unable to fetch projects")
            |> push_navigate(to: Routes.mv_project_show_path(socket, :show, mv_project_id))

          {:noreply, socket}

        {:ok, %{"message" => message}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(message)}")

          socket
          |> put_flash(:error, "Error fetching the MediaVerse project:#{inspect(message)}")
          |> push_navigate(to: Routes.mv_project_show_path(socket, :show, mv_project_id))

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Server response error")
          |> push_navigate(to: Routes.mv_project_show_path(socket, :show, mv_project_id))

        {:error, reason} ->
          Logger.error("Error while handling event add_mv_project: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Error while fetching MediaVerse project")
          |> push_navigate(to: Routes.mv_project_show_path(socket, :show, mv_project_id))
      end

    {:noreply, socket}
  end

  defp render_audio_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={@current_user.mv_node <> "/app/audio/" <> Map.get(@mv_asset, "key")}
        image_source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
        audio_source={Path.join([@asset_preview_static_url,
          Map.get(@mv_asset, "previewLinkKey" ), Map.get(@mv_asset, "originalFilename" )])}
        title={Map.get(@mv_asset, "originalFilename" )}
        subtitle={Map.get(@mv_asset, "author")}
        info={Map.get(@mv_asset, "contentType" )}
      >
        <%= %>
      </IndexCard.render>
    """
  end

  defp render_video_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={@current_user.mv_node <> "/app/video/" <> Map.get(@mv_asset, "key")}
        image_source={Path.join([@asset_preview_static_url,
          Map.get(@mv_asset, "previewLinkKey" ), Map.get(@mv_asset, "originalFilename" )])}
        title={Map.get(@mv_asset, "originalFilename" )}
        subtitle={Map.get(@mv_asset, "author")}
        info={Map.get(@mv_asset, "contentType" )}
      >
        <%= %>
      </IndexCard.render>
    """
  end

  defp render_image_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={@current_user.mv_node <> "/app/image/" <> Map.get(@mv_asset, "key")}
        image_source={Path.join([@asset_preview_static_url,
          Map.get(@mv_asset, "previewLinkKey" ), Map.get(@mv_asset, "originalFilename" )])}
        title={Map.get(@mv_asset, "originalFilename" )}
        subtitle={Map.get(@mv_asset, "author")}
        info={Map.get(@mv_asset, "contentType" )}
      >
        <%= %>
      </IndexCard.render>
    """
  end

  defp render_default_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={@current_user.mv_node <> "/app/image/" <> Map.get(@mv_asset, "key")}
        image_source={Routes.static_path(@socket, "/images/DefaultFileImage.svg" )}
        title={Map.get(@mv_asset, "originalFilename" )}
        subtitle={Map.get(@mv_asset, "author")}
        info={Map.get(@mv_asset, "contentType" )}
      >
        <%= %>
      </IndexCard.render>
    """
  end

  defp render_model_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={@current_user.mv_node <> "/app/model/" <> Map.get(@mv_asset, "key")}
        image_source={Path.join([@asset_preview_static_url,
          Map.get(@mv_asset, "previewLinkKey" ), Map.get(@mv_asset, "originalFilename" )])}
        title={Map.get(@mv_asset, "originalFilename" )}
        subtitle={Map.get(@mv_asset, "author")}
        info={Map.get(@mv_asset, "contentType" )}
      >
        <%=%>
      </IndexCard.render>
    """
  end

  defp render_mv_asset_card(assigns) do
    if File.exists?(
         PreviewDownloader.asset_file_path(
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

      :model ->
        render_model_card(assigns)
    end
  end

  defp map_with_all_links(socket, mv_project_id, total_pages) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.mv_project_form_preview_assets_path(socket, :index, mv_project_id, page: page)}
    end)
  end
end
