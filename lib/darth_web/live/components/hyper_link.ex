defmodule DarthWeb.Components.HyperLink do
  use DarthWeb, :component

  attr :link_route, :string, required: true
  attr :link_text, :string, required: true

  def render(assigns) do
    ~H"""
      <div class="mt-4 flex">
      <.link navigate={@link_route} class="text-sm font-medium text-blue-600 hover:text-blue-500">
        <%=@link_text%>
        <span aria-hidden="true"> &rarr;</span>
      </.link>
    </div>
    """
  end
end
