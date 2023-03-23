defmodule DarthWeb.Components.IndexCardLinkClickButtonGroup do
  use DarthWeb, :component
  alias DarthWeb.Components.{IndexCardLinkButton, IndexCardClickButton}

  attr :link_button_action, :string, required: true
  attr :link_button_route, :string, required: true
  attr :link_button_label, :string, required: true
  attr :click_button_action, :string, required: true
  attr :click_button_label, :string, required: true
  attr :phx_value_ref, :string, required: true
  attr :confirm_message, :string, default: ""

  def render(assigns) do
    ~H"""
    <div class="-mt-px flex divide-x divide-gray-200">
      <IndexCardLinkButton.render
        action={@link_button_action}
        route={@link_button_route}
        label={@link_button_label}
      />
      <IndexCardClickButton.render
        action={@click_button_action}
        label={@click_button_label}
        phx_value_ref={@phx_value_ref}
        confirm_message={@confirm_message}
      />
    </div>
    """
  end
end
