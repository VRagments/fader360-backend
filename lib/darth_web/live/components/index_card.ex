defmodule DarthWeb.Components.IndexCard do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :show_path, :string, required: true
  attr :image_source, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :visibility, :string, required: true
  attr :button_one_route, :string, default: ""
  attr :button_one_phx_value_ref, :string, default: ""
  attr :button_one_action, :string, required: true
  attr :button_one_label, :string, required: true
  attr :button_two_route, :string, default: ""
  attr :button_two_phx_value_ref, :string, default: ""
  attr :button_two_action, :string, required: true
  attr :button_two_label, :string, required: true

  def render(assigns) do
    ~H"""
    <li
        class="col-span-1 flex flex-col divide-y divide-gray-200 rounded-lg bg-white text-center shadow">
      <div class="flex flex-1 flex-col p-8">
      <.link navigate={@show_path}>
        <img class="mx-auto h-64 w-64" src={@image_source} alt="">
        <h3 class="mt-6 text-sm font-medium text-gray-900 truncate"><%=@title%></h3>
        <dl class="mt-1 flex flex-grow flex-col justify-between">
          <dt class="sr-only">Title</dt>
          <dd class="text-sm text-gray-500"><%=@subtitle%></dd>
          <dt class="sr-only">Visibility</dt>
          <dd class="mt-3">
            <span class="rounded-full bg-green-100 px-2 py-1 text-xs font-medium text-green-800"><%=@visibility%></span>
          </dd>
        </dl>
        </.link>
      </div>
      <div class="-mt-px flex divide-x divide-gray-200">
        <div class="flex w-0 flex-1">
        <%= if @button_one_action == "edit" do %>
        <button type="button" class="relative -mr-px inline-flex w-0 flex-1 items-center justify-center rounded-bl-lg
            border border-transparent py-4 text-sm font-medium text-gray-700 hover:text-gray-500">
            <.render_svg action={@button_one_action} />
          <.link navigate={@button_one_route} class="ml-3"><%=@button_one_label%></.link>
          </button>
          <% else %>
          <button type="button" phx-click= {@button_one_action} phx-value-ref={@button_one_phx_value_ref}
          class="relative -mr-px inline-flex w-0 flex-1 items-center justify-center rounded-bl-lg
            border border-transparent py-4 text-sm font-medium text-gray-700 hover:text-gray-500">
          <.render_svg action={@button_one_action} />
            <span class="ml-3"><%=@button_one_label%></span>
          </button>
          <% end %>
        </div>
        <div class="-ml-px flex w-0 flex-1">
        <%= if @button_two_action == "delete" do %>
          <button type="button" phx-click= {@button_two_action} phx-value-ref={@button_two_phx_value_ref}
          class="relative inline-flex w-0 flex-1 items-center justify-center rounded-br-lg
            border border-transparent py-4 text-sm font-medium text-gray-700 hover:text-gray-500">
            <.render_svg action={@button_two_action} />
            <span class="ml-3"><%=@button_two_label%></span>
          </button>
          <% else %>
          <button type="button" class="relative -mr-px inline-flex w-0 flex-1 items-center justify-center rounded-bl-lg
            border border-transparent py-4 text-sm font-medium text-gray-700 hover:text-gray-500">
            <.render_svg action={@button_two_action} />
            <.link navigate={@button_two_route} class="ml-3"><%=@button_two_label%></.link>
          </button>
          <% end %>
        </div>
      </div>
    </li>
    """
  end

  defp render_svg(%{action: "delete"} = assigns), do: Icons.delete_trash(assigns)
  defp render_svg(%{action: "edit"} = assigns), do: Icons.edit_pencil_square(assigns)
  defp render_svg(%{action: "re_transcode"} = assigns), do: Icons.re_transcode_arrow_path(assigns)
end
