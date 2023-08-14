defmodule DarthWeb.Components.IndexCard do
  use DarthWeb, :component

  attr :show_path, :string, default: "#"
  attr :image_source, :string, default: nil
  attr :audio_source, :string, default: nil
  attr :model_source, :string, default: nil
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :info, :string, default: nil
  slot(:inner_block, required: true)

  def render(assigns) do
    ~H"""
    <li class="col-span-1 flex flex-col divide-y divide-gray-200 rounded-lg bg-white text-center border shadow-xl">
      <div class="flex flex-1 flex-col p-8">
        <.link navigate={@show_path}>
          <%= if @model_source do %>
            <model-viewer
              class="object-cover mx-auto h-64 w-64 overflow-hidden rounded-2xl border shadow-xl"
              src={@model_source}
              autoplay
              ar
              camera-controls
              touch-action="pan-y"
            >
            </model-viewer>
          <%else%>
            <img
              class="object-cover mx-auto h-64 w-64 overflow-hidden rounded-2xl shadow-xl border"
              src={@image_source}
              alt=""
            >
          <%end%>
          <%= if @audio_source do %>
            <audio
              class="w-full"
              src={@audio_source}
              width="100%"
              controls
            >
            </audio>
          <%end%>
          <h3 class="mt-6 text-sm font-medium text-gray-900 truncate">
            <%=@title%>
          </h3>
          <dl class="mt-1 flex flex-grow flex-col justify-between">
            <dt class="sr-only">Title</dt>
            <dd class="text-sm text-gray-500"><%=@subtitle%></dd>
            <dt class="sr-only">Subtitle</dt>
            <dd class="mt-3">
            <%= unless is_nil(@info) do%>
              <span class="rounded-full bg-green-100 px-2 py-1 text-xs font-medium text-green-800">
                <%=@info%>
              </span>
            <%end%>
            </dd>
          </dl>
        </.link>
      </div>
      <%= render_slot(@inner_block) %>
    </li>
    """
  end
end
