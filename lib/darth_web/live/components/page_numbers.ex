defmodule DarthWeb.Components.PageNumbers do
  use DarthWeb, :component

  attr :route, :string, required: true
  attr :label, :string, required: true
  attr :class, :string, required: true

  def render(assigns) do
    ~H"""
      <.link
        navigate={@route}
        class={@class}
      >
        <%=@label%>
      </.link>
    """
  end
end
