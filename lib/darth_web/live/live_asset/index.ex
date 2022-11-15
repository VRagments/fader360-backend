defmodule DarthWeb.LiveAsset.Index do
  use DarthWeb, :live_navbar_view
  require Logger
  alias DarthWeb.AssetView
  alias Darth.Controller.User
  alias Darth.Controller.Asset
  alias Darth.Model.User, as: UserStruct
  alias Darth.Controller.AssetLease

  @impl Phoenix.LiveView
  def mount(params, %{"user_token" => user_token}, socket) do
    with %UserStruct{} = user <- User.get_user_by_token(user_token, "session"),
         %{entries: asset_leases} <- AssetLease.query_by_user(user.id, params, false),
         upload_file_size = Application.fetch_env!(:darth, :upload_file_size),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "assets"),
         :ok <- Phoenix.PubSub.subscribe(Darth.PubSub, "asset_leases") do
      {:ok,
       socket
       |> assign(current_user: user, asset_leases: asset_leases)
       |> assign(:uploaded_files, [])
       |> allow_upload(:media, accept: ~w(audio/* video/* image/*), max_entries: 1, max_file_size: upload_file_size)}
    else
      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error(
          "Error message from MediaVerse: Database error while fetching asset via asset leases: #{query_error}"
        )

        socket =
          socket
          |> put_flash(:error, "Unable to fetch assets")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:ok, socket}

      _ ->
        Logger.error("Error message from MediaVerse: User not found while fetching assests")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_updated, asset}, socket) do
    asset_leases =
      Enum.map(socket.assigns.asset_leases, fn elem ->
        if Map.get(elem.asset, :id) == asset.id do
          Map.put(elem, :asset, asset)
        else
          elem
        end
      end)

    {:noreply,
     socket
     |> assign(asset_leases: asset_leases)}
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_lease_created, _asset_lease}, socket) do
    get_updated_socket(socket)
  end

  @impl Phoenix.LiveView
  def handle_info({:asset_deleted, _asset}, socket) do
    get_updated_socket(socket)
  end

  def handle_info(_, socket) do
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
    with uploads_base_path = Application.get_env(:darth, :uploads_base_path),
         :ok <- File.mkdir_p(uploads_base_path),
         uploaded_file_path =
           consume_uploaded_entries(socket, :media, fn %{path: path},
                                                       %Phoenix.LiveView.UploadEntry{
                                                         client_name: file_name
                                                       } ->
             dest = Path.join([:code.priv_dir(:darth), "static", "uploads", file_name])
             # The `static/uploads` directory must exist for `File.cp!/2` to work.
             File.cp!(path, dest)
             {:ok, Routes.static_path(socket, dest)}
           end),
         asset_details <- get_required_asset_details(socket, uploaded_file_path),
         true <- not is_nil(asset_details),
         true <- not is_nil(Asset.normalized_media_type(Map.get(asset_details, "media_type"))),
         user = socket.assigns.current_user,
         {:ok, asset_struct} <- Asset.create(asset_details),
         {:ok, _lease} <- AssetLease.create_for_user(asset_struct, user),
         :ok <- File.rm(uploaded_file_path) do
      socket =
        socket
        |> put_flash(:info, "Uploaded Successfully!!!")
        |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

      {:noreply, socket}
    else
      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Unable to add asset to the database: #{reason}")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}

      false ->
        socket =
          socket
          |> put_flash(:error, "Selected asset type cannot be used in Fader!")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}

      nil ->
        socket =
          socket
          |> put_flash(:error, "Choose a file to upload!")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}
    end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("re_transcode", %{"ref" => asset_id}, socket) do
    case Phoenix.PubSub.broadcast(Darth.PubSub, "assets", {:asset_transcode, asset_id}) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Re-transcoding asset")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}

      error ->
        socket =
          socket
          |> put_flash(:error, "Unable to start asset Re-transcoding: #{error}")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}
    end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete", %{"ref" => asset_id}, socket) do
    current_asset_folder = Application.get_env(:darth, :asset_static_base_path) <> asset_id

    with :ok <- Asset.delete(asset_id),
         {:ok, _} <- File.rm_rf(current_asset_folder) do
      socket =
        socket
        |> put_flash(:info, "Asset deleted successfully")
        |> push_navigate(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

      {:noreply, socket}
    else
      {:error, _, _} ->
        socket =
          socket
          |> put_flash(:error, "Asset cannot be deleted")
          |> push_patch(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}

      {:error, _} ->
        socket =
          socket
          |> put_flash(:error, "Asset not found")
          |> push_navigate(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}
    end
  end

  defp get_updated_socket(socket) do
    with %UserStruct{} = user <- socket.assigns.current_user,
         %{entries: asset_leases} <- AssetLease.query_by_user(user.id, %{}, false) do
      {:noreply,
       socket
       |> assign(asset_leases: asset_leases)}
    else
      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error(
          "Error message from MediaVerse: Database error while fetching asset via asset leases: #{query_error}"
        )

        socket =
          socket
          |> put_flash(:error, "Unable to fetch assets")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}

      _ ->
        Logger.error("Error message from MediaVerse: User not found while fetching assests")

        socket =
          socket
          |> put_flash(:error, "User not found")
          |> redirect(to: Routes.live_path(socket, DarthWeb.LiveAsset.Index))

        {:noreply, socket}
    end
  end

  defp get_required_asset_details(socket, filepath) do
    case socket.assigns.uploads.media.entries do
      [%Phoenix.LiveView.UploadEntry{} = uploaded_file] ->
        %{"name" => uploaded_file.client_name, "media_type" => uploaded_file.client_type, "data_path" => filepath}

      _ ->
        nil
    end
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
