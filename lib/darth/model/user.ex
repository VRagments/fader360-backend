defmodule Darth.Model.User do
  @moduledoc false

  use Darth.Model

  alias Darth.{AccountPlan}
  alias Darth.Model.{AssetLease, Project, EmailVerification, PasswordReset}

  schema "users" do
    field(:email, :string)
    field(:hashed_password, :string)
    field(:last_logged_in_at, :utc_datetime)
    field(:surname, :string)
    field(:firstname, :string)
    field(:password, :string, virtual: true)
    field(:password_confirmation, :string, virtual: true)
    field(:username, :string)
    field(:display_name, :string)
    field(:is_admin, :boolean)
    field(:is_email_verified, :boolean)
    field(:stripe_id, :string)
    field(:metadata, :map)
    field(:account_generation, :integer)
    field(:account_plan, :string)

    has_many(:projects, Project)
    has_many(:email_verifications, EmailVerification)
    has_many(:password_resets, PasswordReset)

    many_to_many(:asset_leases, AssetLease,
      join_through: "users_asset_leases",
      on_delete: :delete_all
    )

    has_many(:assets, through: [:asset_leases, :asset])

    timestamps()
  end

  def search_attributes do
    ~w(
       id
       display_name
       username
     )
  end

  @allowed_fields ~w(is_email_verified hashed_password password password_confirmation username last_logged_in_at
                     firstname surname display_name email is_admin stripe_id metadata
                     account_generation account_plan)a
  @required_fields ~w(is_email_verified username email is_admin account_generation account_plan)a

  def changeset(model, params \\ %{}) do
    pw_min_len = Application.get_env(:darth, :user_password_min_len, 10)
    pw_max_len = Application.get_env(:darth, :user_password_max_len, 100)

    params_clean =
      params
      |> trim_string_params()
      |> filter_empty_password()
      |> filter_custom_colorscheme()
      |> filter_custom_player_settings()

    model
    |> common_changeset(params_clean)
    |> validate_length(:password, min: pw_min_len, max: pw_max_len)
    |> validate_confirmation(:password, message: "Passwords do not match")
    |> hash_password()
  end

  def delete_changeset(model), do: model |> common_changeset(%{}) |> Map.put(:action, :delete)

  def example_data do
    {:ok, features} = AccountPlan.default_features()

    %{
      "features" => features,
      "custom_colorscheme" => Enum.reduce(colorscheme_colors(), %{}, &Map.put(&2, &1, "#ffffff")),
      "custom_player_settings" => Enum.reduce(player_settings(), %{}, &Map.put(&2, &1, true))
    }
  end

  @doc "Returns a list of supported colors."
  @spec colorscheme_colors() :: [String.t()]
  def colorscheme_colors do
    ~w(
      primary
      secondary
      font
    )
  end

  # CHANGE_ANCHOR: playersettings

  @doc """
  Returns a list of supported custom settings.

  showAuthor: add author field to credits sections
  unmute: allow stories to start playing with sound by default
  """
  @spec player_settings() :: [Boolean.t()]
  def player_settings do
    ~w(
      showAuthor
      unmute
    )
  end

  #
  # INTERNAL FUNCTIONS
  #

  # This regex is taken from OWASPs input validation regex repository
  @email_regex ~r/^[a-zA-Z0-9_+&*-]+(?:\.[a-zA-Z0-9_+&*-]+)*@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,7}$/

  defp common_changeset(model, params) do
    model
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> validate_length(:username, min: 1)
    |> validate_length(:email, min: 1)
    |> validate_format(:email, @email_regex)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> validate_account_plan()
  end

  defp filter_custom_colorscheme(params) do
    metadata = Map.get(params, :metadata) || Map.get(params, "metadata") || %{}
    colorscheme = Map.get(metadata, "custom_colorscheme", %{})

    case Enum.empty?(colorscheme) do
      true ->
        params

      false ->
        new_colorscheme = for {c, v} <- colorscheme, c in colorscheme_colors(), into: %{}, do: {c, v}

        new_metadata = Map.put(metadata, "custom_colorscheme", new_colorscheme)

        params
        |> Map.drop(["metadata", :metadata])
        |> Map.put(:metadata, new_metadata)
    end
  end

  defp filter_custom_player_settings(params) do
    metadata = Map.get(params, :metadata) || Map.get(params, "metadata") || %{}
    player_settings = Map.get(metadata, "custom_player_settings", %{})

    case Enum.empty?(player_settings) do
      true ->
        params

      false ->
        new_player_settings = for {c, v} <- player_settings, c in player_settings(), into: %{}, do: {c, v}

        new_metadata = Map.put(metadata, "custom_player_settings", new_player_settings)

        params
        |> Map.drop(["metadata", :metadata])
        |> Map.put(:metadata, new_metadata)
    end
  end

  defp filter_empty_password(%{<<"password">> => pw, <<"password_confirmation">> => pwc} = params) do
    if pw == pwc and (pw == nil or pw == "") do
      Map.drop(params, [<<"password">>, <<"password_confirmation">>])
    else
      params
    end
  end

  defp filter_empty_password(params), do: params

  defp hash_password(cset) do
    password = get_change(cset, :password)

    if password do
      cset
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
    else
      cset
    end
  end

  @string_params ["email", :email, "username", :username]
  defp trim_string_params(params) do
    Enum.reduce(@string_params, params, fn p, acc ->
      if Map.has_key?(acc, p) do
        Map.update(acc, p, nil, &String.trim/1)
      else
        acc
      end
    end)
  end

  defp validate_account_plan(cset) do
    fun = fn field, _ ->
      plan = get_field(cset, :account_plan)
      generation = get_field(cset, :account_generation)

      cond do
        generation not in AccountPlan.generations() ->
          [{field, "Account generation unknown"}]

        plan not in AccountPlan.list(generation) ->
          [{field, "Account plan unknown"}]

        true ->
          []
      end
    end

    cset
    |> validate_change(:account_plan, fun)
    |> validate_change(:account_generation, fun)
    |> update_features()
  end

  defp update_features(cset) do
    plan0 = get_change(cset, :account_plan)
    generation0 = get_change(cset, :account_generation)
    metadata0 = get_field(cset, :metadata, %{}) || %{}

    if Enum.empty?(metadata0) or not is_nil(plan0) or not is_nil(generation0) do
      plan1 = get_field(cset, :account_plan)
      generation1 = get_field(cset, :account_generation)

      metadata1 =
        case AccountPlan.details(plan1, generation1) do
          {:ok, features} ->
            Map.put(metadata0, "features", features)

          _ ->
            metadata0
        end

      cset
      |> put_change(:metadata, metadata1)
    else
      cset
    end
  end
end
