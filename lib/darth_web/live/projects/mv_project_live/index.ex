defmodule DarthWeb.Projects.MvProjectLive.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Model.User, as: UserStruct
  alias Darth.Model.Project, as: ProjectStruct
  alias Darth.Model.Asset, as: AssetStruct
  alias DarthWeb.Components.{Header, IndexCard, IndexCardClickButton, Pagination, EmptyState}

  alias Darth.{
    Controller.User,
    MvApiClient,
    AssetProcessor.Downloader,
    Controller.Asset,
    Controller.Project,
    Controller.AssetLease
  }

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
           map_with_all_links: map_with_all_links
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

    socket =
      with {:ok, %{"assetIds" => mv_project_asset_key_list} = mv_project} <-
             MvApiClient.show_project(mv_node, mv_token, mv_project_id),
           {:ok, project_struct} <- create_new_project(socket, mv_project),
           {:ok, asset_leases} <-
             get_project_assigned_asset_leases(socket, mv_project_asset_key_list, project_struct) do
        download_project_assets(socket, asset_leases)

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

  defp create_new_project(socket, mv_project) do
    current_user = socket.assigns.current_user

    project_params = %{
      "author" => current_user.display_name,
      "name" => Map.get(mv_project, "name"),
      "user_id" => current_user.id,
      "visibility" => "private",
      "mv_project_id" => Map.get(mv_project, "id")
    }

    case Project.create(project_params) do
      {:ok, %ProjectStruct{} = project_struct} ->
        {:ok, project_struct}

      {:error, reason} ->
        Logger.error("Project creation failed while adding mv_project: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp assign_asset_to_project(socket, mv_asset_key, project_struct) do
    current_user = socket.assigns.current_user
    mv_node = current_user.mv_node
    mv_token = socket.assigns.mv_token

    with {:ok, mv_asset} <- MvApiClient.show_asset(mv_node, mv_token, mv_asset_key),
         params = create_params(socket, mv_asset),
         database_params = Asset.build_asset_params(params),
         {:ok, asset_struct} <- Asset.add_asset_to_database(database_params, current_user),
         {:ok, asset_lease} <- AssetLease.read_by(%{asset_id: asset_struct.id}),
         {:ok, asset_lease} <- AssetLease.assign_project(asset_lease, current_user, project_struct) do
      {:ok, asset_lease}
    else
      {:ok, %{"message" => message}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(message)}")

        {:error, message}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

        {:error, reason}

      {:error, reason} ->
        Logger.error("Error while adding asset lease to project while adding mv_project: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_project_assigned_asset_leases(socket, mv_project_asset_key_list, project_struct) do
    result =
      Enum.map(mv_project_asset_key_list, fn mv_asset_key ->
        assign_asset_to_project(socket, mv_asset_key, project_struct)
      end)
      |> Enum.split_with(fn
        {:ok, _} -> true
        {:error, _} -> false
      end)

    case result do
      {ok_tuples, []} ->
        asset_leases = Enum.map(ok_tuples, fn {:ok, asset_lease} -> asset_lease end)
        {:ok, asset_leases}

      {_, errors} ->
        Enum.each(errors, fn {:error, reason} ->
          Logger.error("Custom error message in mv_projects: #{inspect(reason)}")
        end)

        {:error, "Error adding project to Fader"}
    end
  end

  defp create_params(socket, asset_struct = %AssetStruct{}) do
    current_user = socket.assigns.current_user
    mv_node = current_user.mv_node
    mv_token = socket.assigns.mv_token

    %{
      media_type: asset_struct.media_type,
      mv_asset_key: asset_struct.mv_asset_key,
      mv_asset_deeplink_key: asset_struct.mv_asset_deeplink_key,
      mv_node: mv_node,
      mv_token: mv_token,
      mv_asset_filename: asset_struct.name,
      current_user: socket.assigns.current_user,
      asset_struct: asset_struct
    }
  end

  defp create_params(socket, mv_asset) do
    current_user = socket.assigns.current_user
    mv_node = current_user.mv_node
    mv_token = socket.assigns.mv_token

    %{
      media_type: Map.get(mv_asset, "contentType"),
      mv_asset_key: Map.get(mv_asset, "key"),
      mv_asset_deeplink_key: Map.get(mv_asset, "deepLinkKey"),
      mv_node: mv_node,
      mv_token: mv_token,
      mv_asset_filename: Map.get(mv_asset, "originalFilename"),
      current_user: socket.assigns.current_user
    }
  end

  defp download_project_assets(socket, asset_leases) do
    Enum.each(asset_leases, fn asset_lease ->
      if asset_lease.asset.status == "ready" do
        :ok
      else
        Downloader.add_download_params(create_params(socket, asset_lease.asset))
      end
    end)
  end

  defp map_with_all_links(socket, total_pages) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.mv_project_index_path(socket, :index, page: page)}
    end)
  end

  defp render_mv_project_card(assigns) do
    ~H"""
    <IndexCard.render
      show_path="#"
      image_source={Routes.static_path(@socket, "/images/project_file_copy_outline.svg")}
      title={Map.get(@mv_project, "name" )}
      subtitle={Map.get(@mv_project, "createdBy")}
    >
      <IndexCardClickButton.render
        action="add_mv_project"
        phx_value_ref={Map.get(@mv_project, "id" )}
        label="Add to Fader"
        class="-mt-px flex divide-x divide-gray-200"
      />
    </IndexCard.render>
    """
  end
end
