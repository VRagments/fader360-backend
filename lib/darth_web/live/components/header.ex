defmodule DarthWeb.Components.Header do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  attr :heading, :string, required: true
  attr :button_action, :string, default: ""
  attr :button_link, :string, default: ""
  attr :button_label, :string, default: ""
  attr :uploads, :map, default: %{}

  def render(assigns) do
    ~H"""
    <section class="container px-5 py-2 mx-auto lg:pt-12 lg:px-32">
      <div class="md:flex md:items-center md:justify-between">
      <div class="min-w-0 flex-1">
        <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-4xl sm:tracking-tight">
        <%=@heading%></h2>
      </div>
      <div class="mt-4 flex md:mt-0 md:ml-4">
        <%= if @button_action == "edit_project"do %>
        <.button_with_link button_action={@button_action} button_link={@button_link} button_label ={@button_label} />
        <%end%>

        <%=if @button_action == "create_project" do %>
        <.button_with_link button_action={@button_action} button_link={@button_link} button_label ={@button_label} />
        <% end %>

        <%=if @button_action == "add_all_mv_assets" do %>
        <.button_with_click button_action={@button_action} button_label ={@button_label} />
        <% end %>

        <%= if @button_action == "upload" do%>
        <form id="upload-form"
          class="block text-lg text-gray-900 rounded-lg cursor-pointer dark:text-gray-400 focus:outline-none"
          , id="small_size" , phx-submit="save" phx-change="validate">
          <.live_file_input upload={@uploads.media} />
          <.button_to_upload button_action={@button_action} button_label ="Upload" />
        </form>
        <%end%>
      </div>
      </div>
    </section>
    """
  end

  defp button_with_link(assigns) do
    ~H"""
    <button type="button"
      class="inline-flex items-center rounded-md border border-transparent bg-blue-600 px-4
            py-2 text-base font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none
            focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
      <.render_svg action={@button_action} />
      <.link class="ml-3" navigate={@button_link}><%=@button_label%></.link>
    </button>
    """
  end

  defp button_with_click(assigns) do
    ~H"""
    <button type="button" phx-click= {@button_action}
      class="inline-flex items-center rounded-md border border-transparent bg-blue-600 px-4
            py-2 text-base font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none
            focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
      <.render_svg action={@button_action} />
      <span class="ml-3"><%=@button_label%></span>
    </button>
    """
  end

  defp button_to_upload(assigns) do
    ~H"""
    <button type="submit"
      class="inline-flex items-center rounded-md border border-transparent bg-blue-600 px-4
            py-2 text-base font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none
            focus:ring-2 focus:ring-blue-500 focus:ring-offset-2">
      <.render_svg action={@button_action} />
      <span class="ml-3"><%=@button_label%></span>
    </button>
    """
  end

  defp render_svg(%{action: "edit_project"} = assigns), do: Icons.edit_pencil_square(assigns)
  defp render_svg(%{action: "create_project"} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: "add_all_mv_assets"} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: "upload"} = assigns), do: Icons.arrow_up_tray(assigns)
end
