defmodule DarthWeb.Components.ShowAudio do
  use DarthWeb, :component
  alias Phoenix.LiveView.JS

  attr :source, :string, required: true
  attr :data_source, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="relative mx-auto max-w-md px-4 sm:max-w-3xl sm:px-6 lg:max-w-none lg:px-0 lg:py-20">
      <div class="relative overflow-hidden rounded-2xl shadow-xl">
        <img class="w-full object-cover" src={@source} alt="">
        <audio id="media" class="w-full object-cover" width="100%" controls></audio>
        <div phx-mounted={JS.dispatch("media_load", detail: @data_source)}></div>
      </div>
    </div>
    """
  end
end