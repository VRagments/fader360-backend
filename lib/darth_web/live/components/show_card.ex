defmodule DarthWeb.Components.ShowCard do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :show_path, :string, required: true
  attr :image_source, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :button_one_phx_value_ref, :string, default: ""
  attr :button_one_action, :string, default: ""
  attr :button_one_label, :string, default: ""
  attr :button_two_phx_value_ref, :string, default: ""
  attr :button_two_action, :string, default: nil
  attr :state, :string, default: nil
  attr :button_two_label, :string, default: ""

  def render(assigns) do
    ~H"""
    <li class="col-span-1 divide-y divide-gray-200 rounded-lg bg-white shadow-xl">
    <.link navigate={@show_path}>
    <div class="flex w-full items-center justify-between space-x-6 p-6">
      <div class="flex-1 truncate">
        <div class="flex items-center space-x-3">
          <h3 class="truncate text-sm font-medium text-gray-900"><%=@title%></h3>
        </div>
        <p class="mt-1 truncate text-sm text-gray-500"><%=@subtitle%></p>
        <%= if not is_nil(@state) do%>
        <span class="inline-block flex-shrink-0 rounded-full bg-green-200
          px-2 py-0.5 text-xs font-medium text-green-800"><%=@state%></span>
        <%end%>
      </div>
      <img class="h-20 w-20 overflow-hidden rounded-2xl shadow-xl" src={@image_source} alt="">
    </div>
    </.link>
    <div>
      <div class="-mt-px flex divide-x divide-gray-200">
        <button type="button" phx-click= {@button_one_action} phx-value-ref={@button_one_phx_value_ref}
          class="relative -mr-px inline-flex w-0 flex-1 items-center justify-center rounded-bl-lg
            border border-transparent py-4 text-sm font-medium text-gray-700 hover:text-gray-500">
            <.render_svg action={@button_one_action} />
            <span class="ml-3"><%=@button_one_label%></span>
          </button>
          <%= if not is_nil(@button_two_action) do%>
          <button type="button" phx-click= {@button_two_action} phx-value-ref={@button_two_phx_value_ref}
          class="relative -mr-px inline-flex w-0 flex-1 items-center justify-center rounded-bl-lg
            border border-transparent py-4 text-sm font-medium text-gray-700 hover:text-gray-500">
            <.render_svg action={@button_two_action} />
            <span class="ml-3"><%=@button_two_label%></span>
          </button>
          <%end%>
      </div>
    </div>
    </li>
    """
  end

  defp render_svg(%{action: "assign"} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: "unassign"} = assigns), do: Icons.remove_minus(assigns)
  defp render_svg(%{action: "make_primary"} = assigns), do: Icons.make_primary_star(assigns)
end
