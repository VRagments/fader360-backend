defmodule DarthWeb.Components.ClickButton do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :action, :string, required: true
  attr :label, :string, required: true

  def render(assigns) do
    ~H"""
    <button type="button" phx-click= {@action}
      class="inline-flex items-center rounded-md border border-transparent bg-blue-600 px-4
        py-2 text-base font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none
        focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
      <.render_svg action={@action} />
      <span class="ml-3"><%=@label%></span>
    </button>
    """
  end

  defp render_svg(%{action: "add_all_mv_assets"} = assigns), do: Icons.add_mv_asset_plus(assigns)
end
