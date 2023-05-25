defmodule DarthWeb.Projects.MvProjectLive.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias DarthWeb.Components.{Header, IndexCard, Pagination, EmptyState, CardButtons}
  alias Darth.{Controller.User, MvApiClient, Controller.Project}

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session") do
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
    current_page = Map.get(params, "page", "1")

    case MvApiClient.fetch_projects(mv_node, mv_token, current_page) do
      {:ok,
       %{
         "projects" => projects,
         "currentPage" => current_page,
         "totalPages" => total_pages
       }} ->
        map_with_all_links = map_with_all_links(socket, total_pages)

        {:noreply,
         socket
         |> assign(
           mv_projects: projects,
           current_page: current_page + 1,
           total_pages: total_pages,
           map_with_all_links: map_with_all_links,
           mv_node: mv_node
         )}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Error while fetching Mediaverse Projects")
          |> redirect(to: Routes.page_page_path(socket, :index))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, inspect(reason))
          |> redirect(to: Routes.page_page_path(socket, :index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("add_mv_project", %{"ref" => mv_project_id}, socket) do
    current_user = socket.assigns.current_user
    mv_node = current_user.mv_node
    mv_token = socket.assigns.mv_token
    user_params = %{mv_node: mv_node, mv_token: mv_token, current_user: current_user}

    socket =
      with {:ok, mv_project} <- MvApiClient.show_project(mv_node, mv_token, mv_project_id),
           {:ok, project_struct} <- Project.build_params_create_new_project(current_user, mv_project),
           {:ok, mv_asset_info} <-
             Project.fetch_and_filter_mv_project_assets(mv_node, mv_token, mv_project_id, "0"),
           {:ok, asset_leases} <-
             Project.add_project_assets_to_fader(user_params, mv_asset_info.filtered_mv_assets, project_struct) do
        Project.download_project_assets(user_params, asset_leases)

        socket
        |> put_flash(:info, "Added Mediaverse project to Fader")
        |> push_patch(to: Routes.mv_project_index_path(socket, :index, page: socket.assigns.current_page))
      else
        {:ok, %{"message" => message}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(message)}")

          socket
          |> put_flash(:error, message)
          |> push_patch(to: Routes.mv_project_index_path(socket, :index, page: socket.assigns.current_page))

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Server response error")
          |> push_patch(to: Routes.mv_project_index_path(socket, :index, page: socket.assigns.current_page))

        {:error, reason} ->
          Logger.error("Error while handling event add_mv_project: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Error while fetching MediaVerse project")
          |> push_patch(to: Routes.mv_project_index_path(socket, :index, page: socket.assigns.current_page))
      end

    {:noreply, socket}
  end

  defp map_with_all_links(socket, total_pages) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.mv_project_index_path(socket, :index, page: page)}
    end)
  end

  defp render_mv_project_card(assigns) do
    ~H"""
      <IndexCard.render
        show_path={Routes.mv_project_show_path(@socket, :show, Map.get(@mv_project, "id"))}
        image_source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg")}
        title={Map.get(@mv_project, "name" )}
        subtitle={Map.get(@mv_project, "author")}
        info={Map.get(@mv_project, "ownUserRole")}
      >
        <CardButtons.render
          buttons={[
            {
              :add_mv_project,
              phx_value_ref: Map.get(@mv_project, "id" ),
              label: "Add to Fader"
            }
          ]}
        />
      </IndexCard.render>
    """
  end
end
