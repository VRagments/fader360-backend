defmodule DarthWeb.Components.HeaderButtons do
  use DarthWeb, :component
  alias DarthWeb.Components.Button

  attr :buttons, :list, required: true

  def render(assigns) do
    ~H"""
      <%= for b <- @buttons do %>
        <.render_b {convert_to_map(b)} />
      <% end %>
    """
  end

  defp render_b(%{empty_space: true} = assigns) do
    ~H"""
      <div class={class_invisible()} >
        <div class={"w-6 h-6"}>
        </div>
      </div>
    """
  end

  defp render_b(assigns) do
    ~H"""
      <Button.render
        action={@action}
        level={@level}
        path={@path}
        label={@label}
        type={@type}
        phx_value_ref={@phx_value_ref}
        uploads={@uploads}
      />
    """
  end

  defp convert_to_map(nil), do: %{empty_space: true}

  defp convert_to_map({action, opts}) do
    %{
      action: action,
      level: Keyword.get(opts, :level),
      type: Keyword.get(opts, :type),
      path: Keyword.get(opts, :path),
      label: Keyword.get(opts, :label),
      phx_value_ref: Keyword.get(opts, :phx_value_ref),
      uploads: Keyword.get(opts, :uploads)
    }
  end

  defp class_invisible() do
    [
      "border",
      "focus:outline-none",
      "focus:ring-2",
      "focus:ring-offset-2",
      "focus:ring-stone-500",
      "mx-1",
      "p-1",
      "rounded-md",
      "opacity-0"
    ]
    |> Enum.join(" ")
  end
end
