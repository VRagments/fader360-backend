defmodule DarthWeb.Components.ShowModel do
  use DarthWeb, :component
  attr :source, :string, required: true

  def render(assigns) do
    ~H"""
      <div class="aspect-h-3 aspect-w-2 overflow-hidden rounded-lg sm:col-span-4 lg:col-span-5">
        <model-viewer
          class="container"
          style="inline-block width: 100%; height:600px;"
          src={@source}
          autoplay
          ar
          camera-controls
          touch-action="pan-y"
        >
        </model-viewer>
      </div>
    """
  end
end
