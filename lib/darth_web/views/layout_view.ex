defmodule DarthWeb.LayoutView do
  use DarthWeb, :view
  alias Phoenix.LiveView.JS

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def id_user_menu(), do: "user-menu"

  def hide_user_menu(js \\ %JS{}) do
    js
    |> JS.hide(
      transition:
        {"transition ease-in duration-75", "transform opacity-100 scale-100", "transform opacity-0 scale-95"},
      to: "##{id_user_menu()}"
    )
  end

  def show_user_menu(js \\ %JS{}) do
    js
    |> JS.show(
      transition:
        {"transition ease-out duration-100", "transform opacity-0 scale-95", "transform opacity-100 scale-100"},
      to: "##{id_user_menu()}"
    )
  end
end
