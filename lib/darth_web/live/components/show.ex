defmodule DarthWeb.Components.Show do
  use DarthWeb, :component
  alias Phoenix.LiveView.JS

  attr :type, :string, required: true
  attr :source, :string, default: ""
  attr :data_source, :string, default: ""
  attr :author, :string, default: ""
  attr :visibility, :string, default: ""
  attr :updated_at, :string, default: ""
  attr :width, :string, default: ""
  attr :height, :string, default: ""
  attr :file_size, :string, default: ""
  attr :duration, :string, default: ""
  attr :media_type, :string, default: ""
  attr :status, :string, default: ""
  attr :changeset, :map, default: ""

  def render(assigns) do
    ~H"""
    <div class="lg:mx-auto lg:grid lg:max-w-7xl lg:grid-cols-2 lg:items-start lg:gap-24 lg:px-8">
    <div class="relative sm:py-16 lg:py-0">
        <div aria-hidden="true" class="hidden sm:block lg:absolute lg:inset-y-0 lg:right-0 lg:w-screen">
            <div class="absolute inset-y-0 right-1/2 w-full rounded-r-3xl bg-gray-50 lg:right-72">
            </div>
            <svg class="absolute top-8 left-1/2 -ml-3 lg:-right-8 lg:left-auto lg:top-12"
                width="404" height="392" fill="none" viewBox="0 0 404 392">
                <defs>
                    <pattern id="02f20b47-fd69-4224-a62a-4c9de5c763f7" x="0" y="0" width="20"
                        height="20" patternUnits="userSpaceOnUse">
                        <rect x="0" y="0" width="4" height="4" class="text-gray-200"
                            fill="currentColor" />
                    </pattern>
                </defs>
                <rect width="404" height="392" fill="url(#02f20b47-fd69-4224-a62a-4c9de5c763f7)" />
            </svg>
        </div>
        <div class="relative mx-auto max-w-md px-4 sm:max-w-3xl sm:px-6 lg:max-w-none lg:px-0 lg:py-20">
            <div class="relative overflow-hidden rounded-2xl shadow-xl">
                <%= if @type == "project" do%>
                <img class="w-full object-cover" src={@source} alt="">
                <%end%>
                <%=if @type == "audio_asset" do %>
                <img class="w-full object-cover" src={@source} alt="">
                <audio id="media" class="w-full object-cover" width="100%" controls></audio>
                <% end %>
                <%=if @type == "video_asset" do %>
                <video id="media" class="w-full object-cover" controls></video>
                <%end %>
                <div phx-mounted={JS.dispatch("media_load", detail: @data_source)}>
                </div>
                <%=if @type == "image_asset" do %>
                <img class="w-full object-cover" src={@source} alt="">
                <% end %>
            </div>
        </div>
    </div>
    <div class="relative mx-auto max-w-md px-4 sm:max-w-3xl sm:px-6 lg:px-0">
      <div class="mt-10">
        <dl class="grid grid-cols-2 gap-x-8 gap-y-8">
          <%= if @type == "project" do%>
          <.render_stats_entry stat_name="Author" stat_value= {@author}/>
          <.render_stats_entry stat_name="Visibility" stat_value= {@visibility} changeset={@changeset}/>
          <.render_stats_entry stat_name="Updated on" stat_value= {@updated_at}/>
          <%else%>
          <%= unless @type == "audio_asset" do %>
          <.render_stats_entry stat_name="Width" stat_value= {@width} unit="px"/>
          <.render_stats_entry stat_name="Height" stat_value= {@height} unit="px"/>
          <% end %>
          <.render_stats_entry stat_name="Size" stat_value= {@file_size} unit="MB"/>
          <%= unless @type == "image_asset" do %>
          <.render_stats_entry stat_name="Duration" stat_value= {@duration} unit="Sec"/>
          <%end%>
          <.render_stats_entry stat_name="Status" stat_value= {@status}/>
          <.render_stats_entry stat_name="Media Type" stat_value= {@media_type}/>
          <%end%>
        </dl>
      </div>
    </div>
    </div>
    """
  end

  attr :stat_name, :string, required: true
  attr :stat_value, :string, required: true
  attr :unit, :string, default: ""
  attr :changeset, :map, default: ""

  defp render_stats_entry(assigns) do
    ~H"""
    <%= if @stat_name == "Visibility" do%>
      <.form :let={f} for={@changeset} phx-change="update_visibility">
        <div class="border-t-2 border-gray-100 pt-6">
          <label class="text-base font-medium text-gray-500">Visibility</label>
          <%= select f, :visibility, ["Private": "private","LinkShare": "link_share","Discoverable": "discoverable"],
            class: "text-3xl font-bold tracking-tight text-gray-900" %></div>
        <div> <%= error_tag f, :visibility %> </div>
      </.form>
    <%else%>
    <div class="border-t-2 border-gray-100 pt-6">
      <dt class="text-base font-medium text-gray-500"><%=@stat_name%></dt>
      <dd class="text-3xl font-bold tracking-tight text-gray-900">
        <%=@stat_value%> <%=@unit%></dd>
    </div>
    <%end%>
    """
  end
end
