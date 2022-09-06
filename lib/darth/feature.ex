defmodule Darth.Feature do
  @moduledoc """
  This module provides the functions to implement feature switching in the rest of the system.
  In order to add a new feature, (1) add a default case and (2) for limits a verify_limits case.
  """

  alias Darth.{Controller}
  alias Darth.Model.{User}

  @type feature :: String.t()
  @type subject :: %User{} | Plug.Conn.t() | String.t() | nil
  @type bool_result :: boolean | {:error, atom}
  @type value :: boolean | integer | nil
  @type value_result :: value | {:error, atom}

  @doc "Check whether the given feature is enabled"
  @spec enabled?(subject, feature) :: bool_result
  def enabled?(%User{} = user, feature) do
    user
    |> Map.get(:metadata, %{})
    |> get_in(["features", feature])
    |> value(feature)
    |> verify_limits(feature, user)
  end

  def enabled?(nil, feature) do
    feature
    |> default()
    |> verify_limits(feature, nil)
  end

  def enabled?(user_id, feature) do
    with {:ok, user} <- Controller.User.read(user_id) do
      enabled?(user, feature)
    end
  end

  @doc "Get the limit value of a given feature"
  @spec limit(subject, feature) :: value_result
  def limit(%User{} = user, feature) do
    user
    |> Map.get(:metadata, %{})
    |> get_in(["features", feature])
    |> value(feature)
  end

  def limit(nil, feature) do
    value(nil, feature)
  end

  def limit(user_id, feature) do
    with {:ok, user} <- Controller.User.read(user_id) do
      limit(user, feature)
    end
  end

  @default_feature_settings %{
    # custom settings for font and player colors for animations and effect.
    "custom_colorscheme" => false,
    # custom font for player and assets.
    "custom_font" => false,
    # custom icon for 2D interactive audio slideshow hotspots.
    "custom_icon_audio" => false,
    # custom icon for 2D interactive image hotspots.
    "custom_icon_image" => false,
    # custom icon for 2D interactive video hotspots.
    "custom_icon_video" => false,
    # custome top left logo to replace Fader logo.
    "custom_logo" => false,
    # settings that change the default behaviour of the player, e.g. audio options.
    "custom_player_settings" => false,
    # if set, restricts the maximum number of available private projects.
    "nr_private_projects" => 1,
    # if set, restricts the maximum number of available public projects.
    "nr_public_projects" => 1,
    # if set, the intercom chat button shoews in the bottom right corner.
    "show_intercom" => true
  }

  #
  # INTERNAL FUNCTIONS
  #

  # Provide setting or limit for features.
  @spec value(value, feature) :: value
  defp value(nil, feature), do: default(feature)
  defp value(current, _feature), do: current

  # Provide default setting or limit for known features.
  @spec default(feature) :: value
  defp default(feature), do: Map.get(@default_feature_settings, feature, nil)

  # Verifies the feature based on a quantitive limit. Boolean feature switches are simply passed through.
  @spec verify_limits(value, feature, %User{} | nil) :: boolean | integer
  defp verify_limits(nil, _feature, nil), do: false
  defp verify_limits(value, _feature, nil) when is_integer(value), do: value
  defp verify_limits(value, _feature, nil) when is_boolean(value), do: value

  defp verify_limits(value, "nr_private_projects", user) do
    nr_projects = Controller.User.project_count(user, ["private"])

    if value == -1 do
      true
    else
      value > nr_projects
    end
  end

  defp verify_limits(value, "nr_public_projects", user) do
    nr_projects = Controller.User.project_count(user, ["discoverable", "link_share"])

    if value == -1 do
      true
    else
      value > nr_projects
    end
  end

  defp verify_limits(value, _feature, _user), do: value
end
