defmodule DarthWeb.Components.LoginPageLinkButton do
  use DarthWeb, :component

  attr :link, :string, required: true
  attr :label, :string, required: true

  def render(assigns) do
    ~H"""
      <.link navigate={@link}>
        <button type="button"
          class="inline-block px-7 py-3 bg-blue-600 text-white
            font-medium text-sm leading-snug uppercase rounded
            shadow-md hover:bg-blue-700 hover:shadow-lg
            focus:bg-blue-700 focus:shadow-lg focus:outline-none
            focus:ring-0 active:bg-blue-800 active:shadow-lg
            transition duration-150 ease-in-out w-full"
          >
          <span class="ml-3"><%=@label%></span>
        </button>
      </.link>
    """
  end
end
