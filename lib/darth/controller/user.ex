defmodule Darth.Controller.User do
  @moduledoc false

  use Darth.Controller, include_crud: true

  alias Darth.Model.{Project, User, UserToken, UserNotifier}
  alias Darth.{AccountPlan, AssetFile, Feature, Repo}

  def model_mod(), do: Darth.Model.User
  def default_query_sort_by(), do: "username"

  def default_select_fields() do
    ~w(
      account_generation
      account_plan
      display_name
      email
      firstname
      hashed_password
      id
      inserted_at
      is_admin
      is_email_verified
      last_logged_in_at
      stripe_id
      surname
      updated_at
      username
      metadata
    )a
  end

  def default_preload_assocs() do
    ~w(
      asset_leases
      projects
    )a
  end

  def new(params \\ %{}) do
    defaults = %{
      "is_admin" => "false",
      "is_email_verified" => "false",
      "mv_node" => nil,
      "account_generation" => AccountPlan.active_generation(),
      "account_plan" => AccountPlan.default()
    }

    new_params = Map.merge(defaults, params)
    User.changeset(%User{}, new_params)
  end

  def create(params) do
    params
    |> new()
    |> Repo.insert()
  end

  def update({:error, _} = err, _), do: err
  def update({:ok, user}, params), do: update(user, params)

  def update(%User{} = user, params) do
    user
    |> User.changeset(params)
    |> Repo.update()
  end

  def update(id, params), do: id |> read() |> update(params)

  def delete(%User{} = a), do: a |> User.delete_changeset() |> Repo.delete() |> delete_repo()
  def delete(nil), do: {:error, :not_found}
  def delete(id), do: User |> Repo.get(id) |> delete

  def make_admin!({:error, _} = err), do: err
  def make_admin!({:ok, user}), do: make_admin!(user)

  def make_admin!(%User{} = user) do
    cset = User.changeset(user, %{is_admin: true})
    Repo.update(cset)
  end

  def make_admin!(id), do: id |> read(false) |> make_admin!()

  def record_login(nil) do
    _ = Logger.error(~s(Can't record login for nil user))
    :ok
  end

  def record_login(user) do
    case update(user.id, %{"last_logged_in_at" => DateTime.utc_now()}) do
      {:ok, user} ->
        {:ok, user}

      err ->
        Logger.debug(~s(Error while recording login for user #{user.id}: #{inspect(err)}))
        err
    end
  end

  def find_owner(%Asset{id: a_id}) do
    User
    |> preload([:asset_leases])
    |> join(:inner, [user], al in assoc(user, :asset_leases), on: al.asset_id == ^a_id)
    |> where([_user, al], al.license == "owner")
    |> Repo.one()
  end

  def colorscheme(user) do
    if Feature.enabled?(user, "custom_colorscheme") do
      Map.get(user.metadata || %{}, "custom_colorscheme", %{})
    else
      %{}
    end
  end

  def update_colorscheme(user, colors) do
    colorscheme = Map.get(user.metadata || %{}, "custom_colorscheme", %{})
    supported_colors = User.colorscheme_colors()

    new_colorscheme =
      Enum.reduce(colors, colorscheme, fn {c, v}, acc ->
        case c in supported_colors do
          true ->
            Map.put(acc, c, v)

          false ->
            acc
        end
      end)

    metadata = Map.put(user.metadata || %{}, "custom_colorscheme", new_colorscheme)

    params = %{
      metadata: metadata
    }

    update(user, params)
  end

  def player_settings(user) do
    if Feature.enabled?(user, "custom_player_settings") do
      Map.get(user.metadata || %{}, "custom_player_settings", %{})
    else
      %{}
    end
  end

  def update_player_settings(user, values) do
    player_settings = Map.get(user.metadata || %{}, "custom_player_settings", %{})
    supported_settings = User.player_settings()

    convert_to_bool = fn v ->
      case v do
        "true" -> true
        "false" -> false
        s -> s
      end
    end

    new_player_settings =
      Enum.reduce(values, player_settings, fn {n, v}, acc ->
        case n in supported_settings do
          true ->
            Map.put(acc, n, convert_to_bool.(v))

          false ->
            acc
        end
      end)

    metadata = Map.put(user.metadata || %{}, "custom_player_settings", new_player_settings)

    params = %{
      metadata: metadata
    }

    update(user, params)
  end

  @default_custom_file %{
    "name" => "",
    "url" => "",
    "path" => ""
  }

  @custom_logo_allowed_mime_types ~w(
    image/png
    image/jpeg
  )

  @custom_icon_allowed_mime_types ~w(
    image/png
    image/jpeg
  )

  @custom_font_allowed_mime_types ~w(
    application/x-font-ttf
    application/x-font-otf
    application/font-woff
    application/font-woff2
    application/vnd.ms-fontobject
    application/vnd.ms-opentype
    application/font-sfnt
  )

  def font(user) do
    if Feature.enabled?(user, "custom_font") do
      Map.get(user.metadata || %{}, "custom_font", @default_custom_file)
    else
      @default_custom_file
    end
  end

  def update_font(user, params) do
    update_custom_file("custom_font", font(user), user, params)
  end

  def delete_font(user) do
    delete_custom_file("custom_font", font(user), user)
  end

  def icon_audio(user) do
    if Feature.enabled?(user, "custom_icon_audio") do
      Map.get(user.metadata || %{}, "custom_icon_audio", @default_custom_file)
    else
      @default_custom_file
    end
  end

  def update_icon_audio(user, params) do
    update_custom_file("custom_icon_audio", icon_audio(user), user, params)
  end

  def delete_icon_audio(user) do
    delete_custom_file("custom_icon_audio", icon_audio(user), user)
  end

  def icon_image(user) do
    if Feature.enabled?(user, "custom_icon_image") do
      Map.get(user.metadata || %{}, "custom_icon_image", @default_custom_file)
    else
      @default_custom_file
    end
  end

  def update_icon_image(user, params) do
    update_custom_file("custom_icon_image", icon_image(user), user, params)
  end

  def delete_icon_image(user) do
    delete_custom_file("custom_icon_image", icon_image(user), user)
  end

  def icon_video(user) do
    if Feature.enabled?(user, "custom_icon_video") do
      Map.get(user.metadata || %{}, "custom_icon_video", @default_custom_file)
    else
      @default_custom_file
    end
  end

  def update_icon_video(user, params) do
    update_custom_file("custom_icon_video", icon_video(user), user, params)
  end

  def delete_icon_video(user) do
    delete_custom_file("custom_icon_video", icon_video(user), user)
  end

  def logo(user) do
    if Feature.enabled?(user, "custom_logo") do
      Map.get(user.metadata || %{}, "custom_logo", @default_custom_file)
    else
      @default_custom_file
    end
  end

  def update_logo(user, params) do
    update_custom_file("custom_logo", logo(user), user, params)
  end

  def delete_logo(user) do
    delete_custom_file("custom_logo", logo(user), user)
  end

  def project_count(user, visibilities \\ [])
  def project_count(nil, _), do: 0

  def project_count(%User{} = user, []) do
    Project
    |> where([p], p.user_id == ^user.id)
    |> select([p], count(p.id))
    |> Repo.one()
  end

  def project_count(%User{} = user, visibilities) do
    Project
    |> where([p], p.user_id == ^user.id and p.visibility in ^visibilities)
    |> select([p], count(p.id))
    |> Repo.one()
  end

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def get_user_by_username_and_password(username, password)
      when is_binary(username) and is_binary(password) do
    user = Repo.get_by(User, username: username)
    if User.valid_password?(user, password), do: user
  end

  def get_user!(id), do: Repo.get!(User, id)

  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  def change_user_email(user, attrs \\ %{}) do
    user
    |> User.email_changeset(attrs)
  end

  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  def deliver_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs)
  end

  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  def generate_user_token(user, context) do
    {token, user_token} = UserToken.build_token(user, context)
    Repo.insert!(user_token)
    token
  end

  def generate_user_token(user, token, context) do
    {token, user_token} = UserToken.build_token(user, token, context)
    Repo.insert!(user_token)
    token
  end

  def get_user_by_token(token, context) do
    {:ok, query} = UserToken.verify_token_query(token, context)
    Repo.one(query)
  end

  def delete_token(token, context) do
    Repo.delete_all(UserToken.token_and_context_query(token, context))
    :ok
  end

  ## Confirmation
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  ## Reset password
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  def get_user_token_struct(current_user) do
    case Repo.preload(current_user, [:user_token]).user_token do
      nil ->
        nil

      user_token ->
        user_token
    end
  end

  def is_mediaverse_account?(user), do: not is_nil(user.mv_node)

  #
  # INTERNAL FUNCTIONS
  #

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, [context]))
  end

  defp delete_repo({:ok, _}), do: :ok
  defp delete_repo(err), do: err

  defp custom_file_mime_type_supported?("custom_font", mime_type) do
    Enum.member?(@custom_font_allowed_mime_types, mime_type)
  end

  defp custom_file_mime_type_supported?("custom_icon_audio", mime_type) do
    Enum.member?(@custom_icon_allowed_mime_types, mime_type)
  end

  defp custom_file_mime_type_supported?("custom_icon_image", mime_type) do
    Enum.member?(@custom_icon_allowed_mime_types, mime_type)
  end

  defp custom_file_mime_type_supported?("custom_icon_video", mime_type) do
    Enum.member?(@custom_icon_allowed_mime_types, mime_type)
  end

  defp custom_file_mime_type_supported?("custom_logo", mime_type) do
    Enum.member?(@custom_logo_allowed_mime_types, mime_type)
  end

  defp update_custom_file(_attribute, _old_value, _user, "") do
    {:error, :no_file_given}
  end

  defp update_custom_file(attribute, old_value, user, params) do
    filename = params.filename
    new_filename = Ecto.UUID.generate() <> Path.extname(filename)
    uploads_path = Application.get_env(:darth, :uploads_base_path)
    app_uploads_path = Application.app_dir(:darth, uploads_path)
    path = Path.join(app_uploads_path, new_filename)
    base_url = DarthWeb.Endpoint.url()
    url = "#{base_url}/files/#{new_filename}"
    {:ok, mime_type} = AssetFile.Helpers.mime_type(params.path)

    with true <- custom_file_mime_type_supported?(attribute, mime_type),
         _ <- delete_file(old_value["path"]),
         :ok <- File.mkdir_p(app_uploads_path),
         {:ok, _} <- File.copy(params.path, path) do
      new_value = %{
        "name" => filename,
        "url" => url,
        "path" => path
      }

      metadata = Map.put(user.metadata || %{}, attribute, new_value)

      user_params = %{
        metadata: metadata
      }

      update(user, user_params)
    else
      false ->
        Logger.error("Unsupported #{attribute} mime type #{mime_type} for file #{filename}")
        {:error, :file_type_not_supported}

      err ->
        Logger.error("Couldn't update #{attribute}: #{inspect(err)}")
        err
    end
  end

  defp delete_custom_file(attribute, old_value, user) do
    delete_file(old_value["path"])

    metadata = Map.delete(user.metadata || %{}, attribute)

    params = %{
      metadata: metadata
    }

    update(user, params)
  end

  defp delete_file(path) do
    if String.length(path) > 0 and File.exists?(path) do
      case File.rm(path) do
        :ok ->
          :ok

        err ->
          Logger.error("Couldn't delete file #{path}: #{inspect(err)}")
      end
    end
  end
end
