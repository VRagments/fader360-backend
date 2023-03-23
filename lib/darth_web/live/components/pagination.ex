defmodule DarthWeb.Components.Pagination do
  use DarthWeb, :component
  alias DarthWeb.Components.PaginationLink
  alias DarthWeb.Components.RenderPageNumbers

  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :map_with_all_links, :map, required: true

  def render(assigns) do
    ~H"""
    <section class="py-2 lg:pt-12 md:mx-auto lg:container">
        <nav class="flex items-center justify-between border-t border-gray-200 px-4 sm:px-0">
            <%= if @current_page > 1 do %>
                <PaginationLink.render
                    route={Map.get(@map_with_all_links, @current_page-1)}
                    action="left"
                    label="Previous"
                    class="-mt-px flex w-0 flex-1"
                />
            <% else %>
                <div class="-mt-px flex w-0 flex-1"></div>
            <% end %>
            <%= for page <- 1..@total_pages do%>
                <RenderPageNumbers.render
                    page={page}
                    route={Map.get(@map_with_all_links, page)}
                    current_page={@current_page}
                />
        <% end %>
            <%= if @current_page < @total_pages do %>
                <PaginationLink.render
                    route={Map.get(@map_with_all_links, @current_page+1)}
                    action="right"
                    label="Next"
                    class="-mt-px flex w-0 flex-1 justify-end"
                />
            <% else %>
                <div class="-mt-px flex w-0 flex-1 justify-end"></div>
            <% end %>
        </nav>
    </section>
    """
  end
end
