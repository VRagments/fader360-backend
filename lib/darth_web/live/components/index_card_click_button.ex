defmodule DarthWeb.Components.IndexCardClickButton do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :action, :string, required: true
  attr :phx_value_ref, :string, required: true
  attr :label, :string, required: true
  attr :confirm_message, :string, default: ""
  attr :class, :string, default: "flex w-0 flex-1"

  def render(assigns) do
    ~H"""
    <div class={@class}>
      <button
        type="button"
        data-confirm={@confirm_message}
        phx-click= {@action}
        phx-value-ref={@phx_value_ref}
        class="relative inline-flex w-0 flex-1 items-center
          justify-center rounded-br-lg border border-transparent
          py-4 text-sm font-medium text-gray-700 hover:text-gray-500"
      >
        <.render_svg action={@action}/>
        <span class="ml-3"><%=@label%></span>
      </button>
    </div>
    """
  end

  defp render_svg(%{action: "delete"} = assigns), do: Icons.delete_trash(assigns)
  defp render_svg(%{action: "re_transcode"} = assigns), do: Icons.re_transcode_arrow_path(assigns)
  defp render_svg(%{action: "add_mv_asset"} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: "add_mv_project"} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: "download"} = assigns), do: Icons.download_arrow_down_tray(assigns)
end
