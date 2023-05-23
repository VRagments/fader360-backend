defmodule DarthWeb.Components.ShowImage do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :source, :string, required: true

  def render(assigns) do
    ~H"""
      <Icons.dots_pattern />
      <div class="relative mx-auto max-w-md px-4 sm:max-w-3xl sm:px-6 lg:max-w-none lg:px-0 lg:py-20">
        <div class="relative overflow-hidden rounded-2xl shadow-xl">
          <img class="w-full object-cover" src={@source} alt="">
        </div>
      </div>
    """
  end
end
