defmodule DarthWeb.Projects.ProjectLive.FormAssets do
  use DarthWeb, :live_navbar_view
  require Logger
  alias Darth.Controller.User
  alias Darth.Controller.AssetLease
  alias Darth.Controller.Asset
  alias Darth.Controller.Project
  alias Darth.Model.User, as: UserStruct
  alias Darth.MvApiClient
  alias DarthWeb.UploadProcessor

  alias DarthWeb.Components.{
    Header,
    ShowCard,
    EmptyState,
    UploadProgress,
    Pagination,
    CardButtons,
    HeaderButtons
  }

  @impl Phoenix.LiveView
  def mount(_params, %{"user_token" => user_token, "mv_token" => mv_token}, socket) do
    upload_file_size = Application.fetch_env!(:darth, :upload_file_size)

    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "projects") do
      {:ok,
       socket
       |> assign(current_user: user, mv_token: mv_token)
       |> assign(:uploaded_files, [])
       |> allow_upload(:media, accept: ~w(audio/* video/* image/*), max_entries: 1, max_file_size: upload_file_size)}
    else
      {:error, reason} ->
        Logger.error("Error while reading user information: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.page_page_path(socket, :index))

        {:ok, socket}

      nil ->
        Logger.error("Error message: User not found in database")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.page_page_path(socket, :index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"project_id" => project_id} = params, _url, socket) do
    with {:ok, project} <- Project.read(project_id, true),
         %{query_page: current_page, total_pages: total_pages, entries: asset_leases} <-
           AssetLease.query_by_user(socket.assigns.current_user.id, params, true),
         true <- project.user_id == socket.assigns.current_user.id do
      asset_leases_map = Map.new(asset_leases, fn al -> {al.id, al} end)
      asset_leases_list = Asset.get_sorted_asset_lease_list(asset_leases_map)
      map_with_all_links = map_with_all_links(socket, total_pages, project)

      {:noreply,
       socket
       |> assign(
         project: project,
         asset_leases_map: asset_leases_map,
         asset_leases_list: asset_leases_list,
         current_page: current_page,
         total_pages: total_pages,
         map_with_all_links: map_with_all_links
       )}
    else
      {:error, reason} ->
        Logger.error("Error message: Database error while fetching user project: #{inspect(reason)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch project")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}

      false ->
        Logger.error(
          "Error message: Database error while fetching user project: Current user don't have access to this project"
        )

        socket =
          socket
          |> put_flash(:error, "Current user don't have access to this project")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}

      err ->
        Logger.error("Error message: #{inspect(err)}")

        socket =
          socket
          |> put_flash(:error, "Unable to fetch assets")
          |> push_navigate(to: Routes.project_index_path(socket, :index))

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("assign", %{"ref" => asset_lease_id}, socket) do
    socket =
      with asset_lease = Map.get(socket.assigns.asset_leases_map, asset_lease_id),
           {:ok, _asset_lease} <-
             AssetLease.assign_project(asset_lease, socket.assigns.current_user, socket.assigns.project) do
        socket
        |> put_flash(:info, "Project assigned to asset")
        |> push_patch(
          to:
            Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
              page: socket.assigns.current_page
            )
        )
      else
        {:error, reason} ->
          Logger.error("Error message when assigning the asset_lease with project:#{inspect(reason)}")

          socket
          |> put_flash(:error, "Unable to assign project to the asset")
          |> push_patch(
            to:
              Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("unassign", %{"ref" => asset_lease_id}, socket) do
    asset_lease = Map.get(socket.assigns.asset_leases_map, asset_lease_id)

    socket =
      with {:ok, asset_lease} <-
             AssetLease.unassign_project(asset_lease, socket.assigns.current_user, socket.assigns.project),
           {:ok, project} <- Project.unassign_primary_asset_lease(socket.assigns.project, asset_lease) do
        socket
        |> put_flash(:info, "Asset removed from project")
        |> push_patch(
          to: Routes.project_form_assets_path(socket, :index, project.id, page: socket.assigns.current_page)
        )
      else
        {:error, reason} ->
          Logger.error("Error message:#{inspect(reason)}")

          socket
          |> put_flash(:error, "Unable to remove asset from the project")
          |> push_patch(
            to:
              Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("make_primary", %{"ref" => asset_lease_id}, socket) do
    socket =
      with {:ok, project} <- Project.update(socket.assigns.project, %{primary_asset_lease_id: asset_lease_id}),
           {:ok, project} <- Project.read(project.id) do
        socket
        |> assign(project: project)
        |> put_flash(:info, "Project primary asset updated")
        |> push_patch(
          to: Routes.project_form_assets_path(socket, :index, project.id, page: socket.assigns.current_page)
        )
      else
        {:error, reason} ->
          Logger.error("Error message:#{inspect(reason)}")

          socket
          |> put_flash(:error, "Unable to update the primary asset")
          |> push_patch(
            to:
              Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    user = socket.assigns.current_user

    socket =
      with :ok <- UploadProcessor.create_uploads_base_path(),
           {:ok, uploaded_file_path} <- UploadProcessor.get_uploaded_entries(socket, :media),
           {:ok, asset_details} <- UploadProcessor.get_asset_details(socket, uploaded_file_path),
           :ok <- UploadProcessor.check_for_uploaded_asset_media_type(asset_details),
           {:ok, asset_struct} <- Asset.create(asset_details),
           {:ok, asset_struct} <- Asset.init(asset_struct, asset_details),
           {:ok, _lease} <- AssetLease.create_for_user(asset_struct, user),
           :ok <- File.rm(uploaded_file_path) do
        socket
        |> put_flash(:info, "Uploaded Successfully")
        |> push_patch(
          to:
            Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
              page: socket.assigns.current_page
            )
        )
      else
        {:error, reason} ->
          Logger.error("Error while uploading the asset: #{inspect(reason)}")

          socket
          |> put_flash(:error, inspect(reason))
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("sync_with_mv_project", %{"ref" => mv_project_id}, socket) do
    fader_project = socket.assigns.project
    current_user = socket.assigns.current_user
    mv_node = current_user.mv_node
    mv_token = socket.assigns.mv_token
    user_params = %{mv_node: mv_node, mv_token: mv_token, current_user: current_user}

    socket =
      with {:ok, %{"assetIds" => mv_project_asset_key_list}} <-
             MvApiClient.show_project(mv_node, mv_token, mv_project_id),
           {:ok, fader_project_asset_leases} <- Project.fetch_project_asset_leases(fader_project),
           fader_project_asset_mv_keys =
             Enum.map(fader_project_asset_leases, fn asset_lease -> asset_lease.asset.mv_asset_key end),
           asset_key_list_to_add = mv_project_asset_key_list -- fader_project_asset_mv_keys,
           {:ok, mv_asset_info} <-
             Project.fetch_and_filter_mv_project_assets(mv_node, mv_token, mv_project_id, "0"),
           mv_asset_list_to_add =
             Enum.filter(mv_asset_info.filtered_mv_assets, fn mv_asset ->
               Enum.member?(asset_key_list_to_add, Map.get(mv_asset, "key"))
             end),
           {:ok, asset_leases} <-
             Project.add_project_assets_to_fader(user_params, mv_asset_list_to_add, fader_project) do
        Project.download_project_assets(user_params, asset_leases)

        socket
        |> put_flash(:info, "Synced Assets from Mediaverse project to Fader project")
        |> push_patch(
          to:
            Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
              page: socket.assigns.current_page
            )
        )
      else
        {:ok, %{"message" => message}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(message)}")

          socket
          |> put_flash(:error, message)
          |> push_patch(
            to:
              Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )

        {:error, %HTTPoison.Error{reason: reason}} ->
          Logger.error("Custom error message from MediaVerse: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Server response error")
          |> push_patch(
            to:
              Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )

        {:error, reason} ->
          Logger.error("Error while handling event add_mv_project: #{inspect(reason)}")

          socket
          |> put_flash(:error, "Error while fetching MediaVerse project")
          |> push_patch(
            to:
              Routes.project_form_assets_path(socket, :index, socket.assigns.project.id,
                page: socket.assigns.current_page
              )
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:assigned_project, asset_lease}, socket) do
    asset_leases_map = Map.put(socket.assigns.asset_leases_map, asset_lease.id, asset_lease)
    asset_leases_list = Asset.get_sorted_asset_lease_list(asset_leases_map)

    {:noreply, socket |> assign(asset_leases_list: asset_leases_list, asset_leases_map: asset_leases_map)}
  end

  @impl Phoenix.LiveView
  def handle_info({:unassigned_project, asset_lease}, socket) do
    asset_leases_map = Map.put(socket.assigns.asset_leases_map, asset_lease.id, asset_lease)
    asset_leases_list = Asset.get_sorted_asset_lease_list(asset_leases_map)

    {:noreply, socket |> assign(asset_leases_list: asset_leases_list, asset_leases_map: asset_leases_map)}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_updated, asset}, socket) do
    asset_leases_map = socket.assigns.asset_leases_map

    asset_lease_tuple = asset_leases_map |> Enum.find(fn {_, value} -> asset.id == value.asset.id end)

    socket =
      if is_nil(asset_lease_tuple) do
        socket
      else
        {_, asset_lease} = asset_lease_tuple
        updated_asset_lease = Map.put(asset_lease, :asset, asset)
        updated_asset_leases_map = Map.put(asset_leases_map, updated_asset_lease.id, updated_asset_lease)
        asset_leases_list = Asset.get_sorted_asset_lease_list(updated_asset_leases_map)
        socket |> assign(asset_leases_list: asset_leases_list, asset_leases_map: updated_asset_leases_map)
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_lease_created, _asset_lease}, socket) do
    get_updated_asset_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, _asset}, socket) do
    get_updated_asset_list(socket)
  end

  @impl Phoenix.LiveView
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp get_updated_asset_list(socket) do
    socket =
      case AssetLease.query_by_user(socket.assigns.current_user.id, %{}, false) do
        %{entries: asset_leases} ->
          asset_leases_map = Map.new(asset_leases, fn al -> {al.id, al} end)
          asset_leases_list = Asset.get_sorted_asset_lease_list(asset_leases_map)

          socket
          |> assign(asset_leases_list: asset_leases_list, asset_leases_map: asset_leases_map)

        {:error, query_error = %Ecto.QueryError{}} ->
          Logger.error("Database error while fetching asset via asset leases: #{inspect(query_error)}")

          socket
          |> put_flash(:error, "Unable to fetch assets")
          |> push_navigate(to: Routes.asset_index_path(socket, :index))

        err ->
          Logger.error("Error message from MediaVerse: #{inspect(err)}")

          socket
          |> put_flash(:error, "User not found")
          |> push_navigate(to: Routes.asset_index_path(socket, :index))
      end

    {:noreply, socket}
  end

  defp map_with_all_links(socket, total_pages, project) do
    Map.new(1..total_pages, fn page ->
      {page, Routes.project_form_assets_path(socket, :index, project.id, page: page)}
    end)
  end

  defp render_added_audio_card_with_one_button(assigns) do
    ~H"""
      <ShowCard.render
        title={@asset_lease.asset.name}
        path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
        subtitle={@asset_lease.asset.media_type}
        status="Asset added to Project"
      >
        <CardButtons.render
          buttons={[
            {
              :unassign,
              phx_value_ref: @asset_lease.id,
              label: "Remove"
            }
          ]}
        />
      </ShowCard.render>
    """
  end

  defp render_added_audio_card_with_two_buttons(assigns) do
    ~H"""
      <ShowCard.render
        title={@asset_lease.asset.name}
        path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
        subtitle={@asset_lease.asset.media_type}
        status="Asset added to Project"
      >
        <CardButtons.render
          buttons={[
            {
              :unassign,
              phx_value_ref: @asset_lease.id,
              label: "Remove"
            },
            {
              :make_primary,
              phx_value_ref: @asset_lease.id,
              label: "Make Primary"
            }
          ]}
        />
      </ShowCard.render>
    """
  end

  defp render_added_asset_card_with_one_button(assigns) do
    ~H"""
      <ShowCard.render
        title={@asset_lease.asset.name}
        path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        source={@asset_lease.asset.thumbnail_image}
        subtitle={@asset_lease.asset.media_type}
        status="Asset added to Project"
      >
        <CardButtons.render
            buttons={[
              {
                :unassign,
                phx_value_ref: @asset_lease.id,
                label: "Remove"
              }
            ]}
          />
      </ShowCard.render>
    """
  end

  defp render_added_asset_card_with_two_buttons(assigns) do
    ~H"""
      <ShowCard.render
        title={@asset_lease.asset.name}
        path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        source={@asset_lease.asset.thumbnail_image}
        subtitle={@asset_lease.asset.media_type}
        status= "Asset added to Project"
      >
        <CardButtons.render
            buttons={[
              {
                :unassign,
                phx_value_ref: @asset_lease.id,
                label: "Remove"
              },
              {
                :make_primary,
                phx_value_ref: @asset_lease.id,
                label: "Make Primary"
              }
            ]}
          />
      </ShowCard.render>
    """
  end

  defp render_added_model_card_with_two_buttons(assigns) do
    ~H"""
      <ShowCard.render
        title={@asset_lease.asset.name}
        path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        model_source={@asset_lease.asset.static_url}
        subtitle={@asset_lease.asset.media_type}
        status= "Asset added to Project"
      >
        <CardButtons.render
            buttons={[
              {
                :unassign,
                phx_value_ref: @asset_lease.id,
                label: "Remove"
              },
              {
                :make_primary,
                phx_value_ref: @asset_lease.id,
                label: "Make Primary"
              }
            ]}
          />
      </ShowCard.render>
    """
  end

  defp render_added_model_card_with_one_button(assigns) do
    ~H"""
      <ShowCard.render
        title={@asset_lease.asset.name}
        path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
        model_source={@asset_lease.asset.static_url}
        subtitle={@asset_lease.asset.media_type}
        status= "Asset added to Project"
      >
        <CardButtons.render
            buttons={[
              {
                :unassign,
                phx_value_ref: @asset_lease.id,
                label: "Remove"
              }
            ]}
          />
      </ShowCard.render>
    """
  end

  defp render_available_audio_card_with_one_button(assigns) do
    if Asset.is_asset_status_ready?(assigns.asset_lease.asset.status) do
      ~H"""
        <ShowCard.render
          title={@asset_lease.asset.name}
          path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
          source={Routes.static_path(@socket, "/images/audio_thumbnail_image.svg" )}
          subtitle={@asset_lease.asset.media_type}
        >
          <CardButtons.render
            buttons={[
              {
                :assign,
                phx_value_ref: @asset_lease.id,
                label: "Add"
              }
            ]}
          />
        </ShowCard.render>
      """
    else
      ~H"""
      """
    end
  end

  defp render_available_asset_card_with_one_button(assigns) do
    if Asset.is_asset_status_ready?(assigns.asset_lease.asset.status) do
      ~H"""
        <ShowCard.render
          title={@asset_lease.asset.name}
          path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
          source={@asset_lease.asset.thumbnail_image}
          subtitle={@asset_lease.asset.media_type}
        >
          <CardButtons.render
            buttons={[
              {
                :assign,
                phx_value_ref: @asset_lease.id,
                label: "Add"
              }
            ]}
          />
        </ShowCard.render>
      """
    else
      ~H"""
      """
    end
  end

  defp render_available_model_card_with_one_button(assigns) do
    if Asset.is_asset_status_ready?(assigns.asset_lease.asset.status) do
      ~H"""
        <ShowCard.render
          title={@asset_lease.asset.name}
          path={Routes.asset_show_path(@socket, :show, @asset_lease.id)}
          model_source={@asset_lease.asset.static_url}
          subtitle={@asset_lease.asset.media_type}
        >
          <CardButtons.render
            buttons={[
              {
                :assign,
                phx_value_ref: @asset_lease.id,
                label: "Add"
              }
            ]}
          />
        </ShowCard.render>
      """
    else
      ~H"""
      """
    end
  end

  defp render_asset_show_card(assigns) do
    if AssetLease.is_part_of_project?(assigns.asset_lease, assigns.project) do
      render_asset_card_with_one_or_two_buttons(assigns)
    else
      render_asset_card_with_one_button(assigns)
    end
  end

  defp render_asset_card_with_one_or_two_buttons(assigns) do
    media_type = Asset.normalized_media_type(assigns.asset_lease.asset.media_type)

    case media_type do
      :audio -> render_audio_card_with_one_or_two_buttons(assigns)
      :image -> render_image_card_with_one_or_two_buttons(assigns)
      :video -> render_image_card_with_one_or_two_buttons(assigns)
      :model -> render_model_card_with_one_or_two_buttons(assigns)
    end
  end

  defp render_image_card_with_one_or_two_buttons(assigns) do
    if AssetLease.is_primary_asset_lease?(assigns.project, assigns.asset_lease) do
      render_added_asset_card_with_one_button(assigns)
    else
      render_added_asset_card_with_two_buttons(assigns)
    end
  end

  defp render_audio_card_with_one_or_two_buttons(assigns) do
    if AssetLease.is_primary_asset_lease?(assigns.project, assigns.asset_lease) do
      render_added_audio_card_with_one_button(assigns)
    else
      render_added_audio_card_with_two_buttons(assigns)
    end
  end

  defp render_model_card_with_one_or_two_buttons(assigns) do
    if AssetLease.is_primary_asset_lease?(assigns.project, assigns.asset_lease) do
      render_added_model_card_with_one_button(assigns)
    else
      render_added_model_card_with_two_buttons(assigns)
    end
  end

  defp render_asset_card_with_one_button(assigns) do
    media_type = Asset.normalized_media_type(assigns.asset_lease.asset.media_type)

    case media_type do
      :audio -> render_available_audio_card_with_one_button(assigns)
      :image -> render_available_asset_card_with_one_button(assigns)
      :video -> render_available_asset_card_with_one_button(assigns)
      :model -> render_available_model_card_with_one_button(assigns)
    end
  end

  defp render_buttons(nil, uploads, project_id, socket) do
    [
      {
        :uploads,
        uploads: uploads.media, level: :primary, type: :submit, label: "Upload"
      },
      nil,
      {
        :back,
        level: :secondary, type: :link, path: Routes.project_show_path(socket, :show, project_id), label: "Back"
      }
    ]
  end

  defp render_buttons(mv_project_id, uploads, project_id, socket) do
    [
      {
        :uploads,
        uploads: uploads.media, level: :secondary, type: :submit, label: "Upload"
      },
      nil,
      {
        :sync_with_mv_project,
        phx_value_ref: mv_project_id, label: "Sync with MediaVerse", level: :primary, type: :click
      },
      nil,
      {
        :back,
        level: :secondary, type: :link, path: Routes.project_show_path(socket, :show, project_id), label: "Back"
      }
    ]
  end
end
