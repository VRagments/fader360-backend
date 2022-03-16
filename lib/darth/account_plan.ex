defmodule Darth.AccountPlan do
  @moduledoc """
  This modules provides all currently supported plans and their settings.
  """

  # Generation IDs must be integer values.
  @active_generation 2

  def active_generation(), do: @active_generation

  def generations() do
    [
      0,
      1,
      2,
      3
    ]
  end

  def details(type, generation \\ @active_generation)

  def details(type, generation) when is_atom(type) do
    details(to_string(type), generation)
  end

  def details(type, generation) do
    types = types(generation)

    case types do
      {:error, _} = err ->
        err

      _ ->
        if Map.has_key?(types, type) do
          {:ok, Map.get(types, type)}
        else
          {:error, :plan_type_not_in_generation}
        end
    end
  end

  def default(generation \\ @active_generation)
  def default(1), do: "free"
  def default(2), do: "free"
  def default(3), do: "free"

  def default_features(generation \\ @active_generation), do: generation |> default() |> details(generation)

  def list(generation \\ @active_generation) do
    types = types(generation)

    case types do
      {:error, _} ->
        []

      _ ->
        Map.keys(types)
    end
  end

  @doc "Returns all plans and plan details for the given generation."
  def all(generation \\ @active_generation) do
    types(generation)
  end

  @doc "Returns all plans and plan details for all known generations."
  def all_generations() do
    gens = generations()
    for g <- gens, into: %{}, do: {g, types(g)}
  end

  #
  # GENERATIONS
  #

  defp types(0) do
    #  This is only used as a base and should not be assigned to anyone.
    %{
      "base" => %{}
    }
  end

  defp types(1) do
    %{
      "free" => %{
        "custom_colorscheme" => false,
        "custom_font" => false,
        "custom_icon_audio" => false,
        "custom_icon_image" => false,
        "custom_icon_video" => false,
        "custom_logo" => false,
        "custom_player_settings" => false,
        "nr_private_projects" => 1,
        "nr_public_projects" => 1,
        "show_intercom" => true
      },
      "fan" => %{
        "custom_colorscheme" => false,
        "custom_font" => false,
        "custom_icon_audio" => false,
        "custom_icon_image" => false,
        "custom_icon_video" => false,
        "custom_logo" => false,
        "custom_player_settings" => false,
        "nr_private_projects" => 10,
        "nr_public_projects" => 10,
        "show_intercom" => true
      },
      "backstage" => %{
        "custom_colorscheme" => true,
        "custom_font" => true,
        "custom_icon_audio" => true,
        "custom_icon_image" => true,
        "custom_icon_video" => true,
        "custom_logo" => true,
        "custom_player_settings" => true,
        "nr_private_projects" => -1,
        "nr_public_projects" => 20,
        "show_intercom" => true
      },
      "vip" => %{
        "custom_colorscheme" => true,
        "custom_font" => true,
        "custom_icon_audio" => true,
        "custom_icon_image" => true,
        "custom_icon_video" => true,
        "custom_logo" => true,
        "custom_player_settings" => true,
        "nr_private_projects" => -1,
        "nr_public_projects" => -1,
        "show_intercom" => true
      },
      "allaccess" => %{
        "custom_colorscheme" => true,
        "custom_font" => true,
        "custom_icon_audio" => true,
        "custom_icon_image" => true,
        "custom_icon_video" => true,
        "custom_logo" => true,
        "custom_player_settings" => true,
        "nr_private_projects" => -1,
        "nr_public_projects" => -1,
        "show_intercom" => true
      }
    }
  end

  defp types(2) do
    %{
      "free" => %{
        "custom_colorscheme" => false,
        "custom_font" => false,
        "custom_icon_audio" => false,
        "custom_icon_image" => false,
        "custom_icon_video" => false,
        "custom_logo" => false,
        "custom_player_settings" => false,
        "nr_private_projects" => 1,
        "nr_public_projects" => 0,
        "show_intercom" => true
      },
      "basic" => %{
        "custom_colorscheme" => false,
        "custom_font" => false,
        "custom_icon_audio" => false,
        "custom_icon_image" => false,
        "custom_icon_video" => false,
        "custom_logo" => false,
        "custom_player_settings" => false,
        "nr_private_projects" => -1,
        "nr_public_projects" => 1,
        "show_intercom" => true
      },
      "professional" => %{
        "custom_colorscheme" => false,
        "custom_font" => false,
        "custom_icon_audio" => false,
        "custom_icon_image" => false,
        "custom_icon_video" => false,
        "custom_logo" => false,
        "custom_player_settings" => false,
        "nr_private_projects" => -1,
        "nr_public_projects" => 11,
        "show_intercom" => true
      },
      "enterprise" => %{
        "custom_colorscheme" => true,
        "custom_font" => true,
        "custom_icon_audio" => true,
        "custom_icon_image" => true,
        "custom_icon_video" => true,
        "custom_logo" => true,
        "custom_player_settings" => true,
        "nr_private_projects" => -1,
        "nr_public_projects" => -1,
        "show_intercom" => true
      }
    }
  end

  defp types(3) do
    %{
      "free" => %{
        "custom_colorscheme" => false,
        "custom_font" => false,
        "custom_icon_audio" => false,
        "custom_icon_image" => false,
        "custom_icon_video" => false,
        "custom_logo" => false,
        "custom_player_settings" => false,
        "nr_private_projects" => 1,
        "nr_public_projects" => 0,
        "show_intercom" => true
      },
      "professional" => %{
        "custom_colorscheme" => false,
        "custom_font" => false,
        "custom_icon_audio" => false,
        "custom_icon_image" => false,
        "custom_icon_video" => false,
        "custom_logo" => false,
        "custom_player_settings" => false,
        "nr_private_projects" => -1,
        "nr_public_projects" => 1,
        "show_intercom" => true
      },
      "enterprise" => %{
        "custom_colorscheme" => true,
        "custom_font" => true,
        "custom_icon_audio" => true,
        "custom_icon_image" => true,
        "custom_icon_video" => true,
        "custom_logo" => true,
        "custom_player_settings" => true,
        "nr_private_projects" => -1,
        "nr_public_projects" => -1,
        "show_intercom" => true
      }
    }
  end

  defp types(_), do: {:error, :unknown_generation}
end
