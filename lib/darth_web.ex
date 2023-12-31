defmodule DarthWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use DarthWeb, :controller
      use DarthWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: DarthWeb

      use PhoenixSwagger
      import Plug.Conn
      import DarthWeb.Gettext
      alias DarthWeb.FallbackController
      alias DarthWeb.Router.Helpers, as: Routes

      action_fallback(FallbackController)

      defp read_media_file_data(%{"file" => file} = params) do
        params
        |> Map.put("data_path", file.path)
        |> Map.put("media_type", file.content_type)
      end

      defp read_media_file_data(params), do: params
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/darth_web/templates",
        namespace: DarthWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
      import Phoenix.Component
      def build_body(base, _schema, _model, []), do: base

      def build_body(_base, schema, model, attrs) do
        Enum.reduce(attrs, %{}, fn a, acc ->
          if a != :id and a not in schema.virtual_attributes() and Map.has_key?(model, :asset) do
            Map.put(acc, a, Map.get(model.asset, a))
          else
            Map.put(acc, a, Map.get(model, a))
          end
        end)
      end

      def render_date(nil), do: nil

      def render_date(date) do
        Calendar.strftime(date, "%Y %m %d")
      end
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {DarthWeb.LayoutView, "live.html"}

      unquote(view_helpers())
    end
  end

  def live_navbar_view do
    quote do
      use Phoenix.LiveView, layout: {DarthWeb.LayoutView, "_user_menu.html"}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
      import Phoenix.Component
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import DarthWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView and .heex helpers (live_render, live_patch, <.form>, etc)
      import Phoenix.LiveView.Helpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import DarthWeb.ErrorHelpers
      import DarthWeb.Gettext
      alias DarthWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
