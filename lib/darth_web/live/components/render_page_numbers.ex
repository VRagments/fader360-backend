defmodule DarthWeb.Components.RenderPageNumbers do
  use DarthWeb, :component
  alias DarthWeb.Components.PageNumbers

  attr :page, :string, required: true
  attr :current_page, :string, required: true
  attr :route, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="hidden md:-mt-px md:flex justify-center">
    <%= if @page == @current_page do %>
      <PageNumbers.render
        route={@route}
        label= {@page}
        class="inline-flex items-center border-t-2 border-blue-500 px-4 pt-4 text-sm
          font-medium text-blue-600"
      />
    <% else %>
      <PageNumbers.render
        route={@route}
        label= {@page}
        class="inline-flex items-center border-t-2 border-transparent px-4 pt-4 text-sm
          font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"
      />
    <% end %>
    </div>
    """
  end
end
