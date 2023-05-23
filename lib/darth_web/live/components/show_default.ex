defmodule DarthWeb.Components.ShowDefault do
  use DarthWeb, :component

  # This component is used to render the default project display in the project detail pages.
  # With this component the aspect ratio is fixed so that user don't have to scroll down to
  #   see the second half of the page with relavent information.

  attr :source, :string, required: true

  def render(assigns) do
    ~H"""
      <div class="aspect-h-3 aspect-w-2 overflow-hidden rounded-lg sm:col-span-4 lg:col-span-5">
        <img src={@source} class="relative object-cover object-center">
      </div>
    """
  end
end
