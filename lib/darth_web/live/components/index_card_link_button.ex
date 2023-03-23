defmodule DarthWeb.Components.IndexCardLinkButton do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :route, :string, required: true
  attr :action, :string, required: true
  attr :label, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="flex w-0 flex-1">
      <.link
        navigate={@route}
        class="relative -mr-px inline-flex w-0 flex-1 items-center
            justify-center rounded-bl-lg border border-transparent
            py-4 text-sm font-medium text-gray-700 hover:text-gray-500"
      >
        <button
          type="button"
          class="relative -mr-px inline-flex w-0 flex-1 items-center
            justify-center rounded-bl-lg border border-transparent"
        >
          <.render_svg action={@action}/>
          <div class="pl-2"><%=@label%></div>
        </button>
      </.link>
    </div>
    """
  end

  defp render_svg(%{action: "edit"} = assigns), do: Icons.edit_pencil_square(assigns)
end
