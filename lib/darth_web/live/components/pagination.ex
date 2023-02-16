defmodule DarthWeb.Components.Pagination do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :back_button_route, :string, required: true
  attr :forward_button_route, :string, required: true

  def render(assigns) do
    ~H"""
    <section class="container px-5 py-2 mx-auto lg:pt-12 lg:px-32">
    <nav class="flex items-center justify-between border-t border-gray-200 px-4 sm:px-0">
    <%= if @current_page > 1 do%>
    <div class="-mt-px flex w-0 flex-1">
    <.link navigate={@back_button_route} class="inline-flex items-center border-t-2
      border-transparent pt-4 pr-1 text-sm font-medium text-gray-500 hover:border-gray-300
      hover:text-gray-700">
    <.render_svg action="left"/>
      Previous
    </.link>
    </div>
    <%end%>

    <%= if @current_page < @total_pages do %>
    <div class="-mt-px flex w-0 flex-1 justify-end">
    <.link navigate={@forward_button_route} class="inline-flex items-center border-t-2
      border-transparent pt-4 pr-1 text-sm font-medium text-gray-500 hover:border-gray-300
      hover:text-gray-700">
    <.render_svg action="right"/>
      Next
    </.link>
    </div>
    <%end%>
    </nav>
    </section>
    """
  end

  defp render_svg(%{action: "left"} = assigns), do: Icons.arrow_long_left(assigns)
  defp render_svg(%{action: "right"} = assigns), do: Icons.arrow_long_right(assigns)
end
