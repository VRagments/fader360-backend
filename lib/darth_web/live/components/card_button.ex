defmodule DarthWeb.Components.CardButton do
  use DarthWeb, :component
  alias DarthWeb.Components.Icons

  # Used to render the Icon on the button
  # Possible actions: [:edit, :delete, :assign, :unassign, :re_transcode]
  attr :action, :atom, required: true
  # Used to decide between link or click or submit button
  # possible types: [:link, :click]
  attr :type, :atom, default: :click
  # Text to render on the button
  attr :label, :string, required: true
  # Link to navigate for the link button type
  attr :path, :string, default: nil
  # A popup message before deleting a card
  attr :confirm_message, :string, default: nil
  # Value to be sent when clicked on button
  attr :phx_value_ref, :string, default: nil

  def render(%{type: :link} = assigns) do
    ~H"""
      <.link
        navigate={@path}
        class={button_class()}
      >
        <button
          class={button_class(@type)}
        >
          <.render_svg action={@action}/>
          <div class="ml-3"><%=@label%></div>
        </button>
      </.link>
    """
  end

  def render(assigns) do
    ~H"""
      <button
        data-confirm={@confirm_message}
        phx-click= {@action}
        phx-value-ref={@phx_value_ref}
        class={button_class()}
      >
        <.render_svg action={@action}/>
        <span class="ml-3"><%=@label%></span>
      </button>
    """
  end

  defp button_class(:link) do
    [
      "relative",
      "-mr-px",
      "inline-flex",
      "w-0",
      "flex-1",
      "items-center",
      "justify-center"
    ]
    |> Enum.join(" ")
  end

  defp button_class() do
    [
      button_class(:link),
      "py-4",
      "text-sm",
      "font-medium",
      "text-gray-700",
      "hover:text-gray-500"
    ]
    |> Enum.join(" ")
  end

  defp render_svg(%{action: :delete} = assigns), do: Icons.delete_trash(assigns)
  defp render_svg(%{action: :re_transcode} = assigns), do: Icons.re_transcode_arrow_path(assigns)
  defp render_svg(%{action: :add_mv_asset} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: :add_mv_project} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: :download} = assigns), do: Icons.download_arrow_down_tray(assigns)
  defp render_svg(%{action: :edit} = assigns), do: Icons.edit_pencil_square(assigns)
  defp render_svg(%{action: :assign} = assigns), do: Icons.add_mv_asset_plus(assigns)
  defp render_svg(%{action: :unassign} = assigns), do: Icons.remove_minus(assigns)
  defp render_svg(%{action: :make_primary} = assigns), do: Icons.make_primary_star(assigns)
end
