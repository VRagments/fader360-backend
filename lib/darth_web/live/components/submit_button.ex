defmodule DarthWeb.Components.SubmitButton do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :action, :string, required: true
  attr :label, :string, required: true

  def render(assigns) do
    ~H"""
    <button type="submit"
      class="inline-flex items-center rounded-md border border-transparent bg-blue-600 px-4
        py-2 text-base font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none
        focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
      >
      <.render_svg action={@action} />
      <span class="ml-3"><%=@label%></span>
    </button>
    """
  end

  defp render_svg(%{action: "Upload"} = assigns), do: Icons.arrow_up_tray(assigns)
end
