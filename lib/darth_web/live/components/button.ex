defmodule DarthWeb.Components.Button do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  # Used to render the Icon of the button
  # Possible actions: [:add, :back, :edit, :add_all_mv_assets, :uploads]
  attr :action, :atom, required: true
  # Used to determine the color of the button
  # Possible levels: [:primary :secondary]
  attr :level, :atom, required: true
  # Used to decide between link or click or submit button
  # possible types: [:link, :click, :submit]
  attr :type, :atom, required: true
  # Link to navigate for the link button type
  attr :path, :string, default: nil
  # Text to render on the button
  attr :label, :string, required: true
  # Value to be sent when clicked on the button
  attr :phx_value_ref, :string, default: nil
  # Map will upload file information for LiveFormUpload
  attr :uploads, :map, default: nil
  # A popup message before deleting a card
  attr :confirm_message, :string, default: nil

  def render(%{type: :click} = assigns) do
    ~H"""
      <button
        phx-click= {@action}
        data-confirm={@confirm_message}
        phx-value-ref={@phx_value_ref}
        class={button_class(@level)}
      >
        <.render_svg action={@action} />
        <span class="ml-3"><%=@label%></span>
      </button>
    """
  end

  def render(%{type: :submit} = assigns) do
    ~H"""
      <form id="upload-form"
        class={button_class(@type)},
        id="small_size",
        phx-submit="save"
        phx-change="validate"
      >
        <.live_file_input upload={@uploads} />
        <button type={@type}
          class={button_class(@level)}
        >
          <.render_svg action={@action} />
          <span class="ml-3"><%=@label%></span>
        </button>
      </form>
    """
  end

  def render(assigns) do
    ~H"""
      <.link navigate={@path}>
        <button
          class={button_class(@level)}
        >
          <.render_svg action={@action} />
          <span class="ml-3"><%=@label%></span>
        </button>
      </.link>
    """
  end

  def button_class(:primary) do
    [
      "inline-flex",
      "items-center",
      "rounded-md",
      "border",
      "border-transparent",
      "bg-blue-600",
      "px-4",
      "py-2",
      "text-base",
      "font-medium",
      "text-white",
      "shadow-sm",
      "hover:bg-blue-700",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-blue-500",
      "focus:ring-offset-2"
    ]
    |> Enum.join(" ")
  end

  def button_class(:secondary) do
    [
      "inline-flex",
      "items-center",
      "rounded-md",
      "border",
      "border-transparent",
      "bg-white",
      "px-4",
      "py-2",
      "text-base",
      "font-medium",
      "text-black",
      "shadow-sm",
      "ring-1",
      "ring-inset",
      "ring-gray-300",
      "hover:bg-gray-50"
    ]
    |> Enum.join(" ")
  end

  def button_class(:submit) do
    [
      "block",
      "text-lg",
      "text-gray-900",
      "rounded-lg",
      "cursor-pointer",
      "dark:text-gray-400",
      "focus:outline-none"
    ]
    |> Enum.join(" ")
  end

  defp render_svg(%{action: :launch} = assigns), do: Icons.launch_arrow_top_right(assigns)
  defp render_svg(%{action: :edit} = assigns), do: Icons.edit_pencil_square(assigns)
  defp render_svg(%{action: :add} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: :manage} = assigns), do: Icons.manage_asset_adjustments_vertical(assigns)
  defp render_svg(%{action: :back} = assigns), do: Icons.back_curved_arrow(assigns)
  defp render_svg(%{action: :add_all_mv_assets} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: :uploads} = assigns), do: Icons.arrow_up_tray(assigns)
  defp render_svg(%{action: :delete} = assigns), do: Icons.delete_trash(assigns)
  defp render_svg(%{action: :add_mv_project} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: :sync_with_mv_project} = assigns), do: Icons.re_transcode_arrow_path(assigns)
  defp render_svg(%{action: :sync_with_mv_asset} = assigns), do: Icons.re_transcode_arrow_path(assigns)
  defp render_svg(%{action: :preview} = assigns), do: Icons.view_finder_circle(assigns)
  defp render_svg(%{action: :upload_to_mediverse} = assigns), do: Icons.cloud_arrow_up(assigns)
  defp render_svg(%{action: :create_template} = assigns), do: Icons.square_stack_3d(assigns)
  defp render_svg(%{action: :download} = assigns), do: Icons.download_arrow_down_tray(assigns)
end
