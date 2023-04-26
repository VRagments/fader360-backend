defmodule DarthWeb.Components.ShowCard do
  use DarthWeb, :component

  attr :title, :string, required: true
  attr :path, :string, required: true
  attr :source, :string, required: true
  attr :subtitle, :string, required: true
  attr :status, :string, default: nil
  slot(:inner_block, required: true)

  def render(assigns) do
    ~H"""
      <li class="col-span-1 divide-y divide-gray-200 rounded-lg bg-white shadow-xl">
      <.link navigate={@path}>
      <div class="flex w-full items-center justify-between space-x-6 p-6">
        <div class="flex-1 truncate">
          <div class="flex items-center space-x-3">
            <h3 class="truncate text-sm font-medium text-gray-900"><%=@title%></h3>
          </div>
          <p class="mt-1 truncate text-sm text-gray-500"><%=@subtitle%></p>
          <%= unless is_nil(@status) do%>
            <span class="inline-block flex-shrink-0 rounded-full bg-green-200
              px-2 py-0.5 text-xs font-medium text-green-800"><%=@status%></span>
          <%end%>
        </div>
        <img class="h-20 w-20 overflow-hidden rounded-2xl shadow-xl" src={@source} alt="">
      </div>
      </.link>
      <div>
        <%= render_slot(@inner_block) %>
      </div>
      </li>
    """
  end
end
