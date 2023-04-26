defmodule DarthWeb.Components.Activity do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :action, :string, required: true
  attr :type, :string, required: true
  attr :name, :string, required: true
  attr :inserted_at, :string, required: true
  attr :show_path, :string, required: true

  def render(assigns) do
    ~H"""
      <li>
        <div class="relative pb-8">
          <div class="relative flex space-x-3">
            <div> <.render_svg action={@action} /></div>
          <div class="flex min-w-0 flex-1 justify-between space-x-4 pt-1.5">
          <.link href={@show_path}>
          <div> <p class="text-sm text-gray-500">Created <b><%= @type %></b> with title <b><%= @name %></b></p></div>
          </.link>
          <div class="whitespace-nowrap text-right text-sm text-gray-500">
            <time datetime="2020-09-28"><%=@inserted_at%></time>
          </div>
          </div>
          </div>
        </div>
      </li>
    """
  end

  defp render_svg(%{action: "activity_done"} = assigns), do: Icons.green_tick_mark_activity(assigns)
end
