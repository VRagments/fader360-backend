defmodule DarthWeb.Components.Header do
  use DarthWeb, :component

  attr :heading, :string, required: true
  slot(:inner_block, required: true)

  def render(assigns) do
    ~H"""
    <section class="container px-5 py-2 mx-auto lg:pt-12 lg:px-32">
      <div class="md:flex md:items-center md:justify-between">
        <div class="min-w-0 flex-1">
          <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-4xl sm:tracking-tight">
            <%=@heading%></h2>
        </div>
      <div class="mt-4 flex md:mt-0 md:ml-4">
        <%= render_slot(@inner_block) %>
      </div>
      </div>
    </section>
    """
  end
end
