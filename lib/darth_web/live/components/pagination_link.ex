defmodule DarthWeb.Components.PaginationLink do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :label, :string, required: true
  attr :route, :string, required: true
  attr :action, :string, required: true
  attr :class, :string, required: true

  def render(assigns) do
    ~H"""
    <div class={@class}>
      <.link
        navigate={@route}
        class="inline-flex items-center border-t-2
          border-transparent pt-4 pr-1 text-sm font-medium text-gray-500 hover:border-gray-300
          hover:text-gray-700"
      >
        <.render_svg_in_position action={@action} label={@label}/>
      </.link>
    </div>
    """
  end

  defp render_svg(%{action: "left"} = assigns), do: Icons.arrow_long_left(assigns)
  defp render_svg(%{action: "right"} = assigns), do: Icons.arrow_long_right(assigns)

  defp render_svg_in_position(assigns) do
    ~H"""
    <%= if @action == "left" do %>
      <.render_svg action={@action}/>
      <%=@label%>
    <% else %>
      <%=@label%>
      <.render_svg action={@action}/>
    <% end %>
    """
  end
end
