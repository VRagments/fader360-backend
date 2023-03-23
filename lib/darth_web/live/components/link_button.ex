defmodule DarthWeb.Components.LinkButton do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :link, :string, required: true
  attr :action, :string, required: true
  attr :label, :string, required: true

  def render(assigns) do
    ~H"""
    <.link navigate={@link}>
      <button type="button"
        class="inline-flex items-center rounded-md border border-transparent bg-blue-600 px-4
          py-2 text-base font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none
          focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
        >
        <.render_svg action={@action} />
        <span class="ml-3"><%=@label%></span>
      </button>
    </.link>
    """
  end

  defp render_svg(%{action: "edit"} = assigns), do: Icons.edit_pencil_square(assigns)
  defp render_svg(%{action: "add"} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: "manage"} = assigns), do: Icons.manage_asset_adjustments_vertical(assigns)
  defp render_svg(%{action: "back"} = assigns), do: Icons.back_curved_arrow(assigns)
end
