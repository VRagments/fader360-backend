defmodule DarthWeb.Components.IndexCardClickButtonGroup do
  use DarthWeb, :component
  alias DarthWeb.Components.IndexCardClickButton

  attr :button_one_action, :string, required: true
  attr :button_one_phx_value_ref, :string, required: true
  attr :button_one_label, :string, required: true
  attr :button_two_action, :string, required: true
  attr :button_two_label, :string, required: true
  attr :button_two_phx_value_ref, :string, required: true
  attr :confirm_message, :string, default: ""

  def render(assigns) do
    ~H"""
    <div class="-mt-px flex divide-x divide-gray-200">
      <IndexCardClickButton.render
        action={@button_one_action}
        phx_value_ref={@button_one_phx_value_ref}
        label={@button_one_label}
      />
      <IndexCardClickButton.render
        action={@button_two_action}
        phx_value_ref={@button_two_phx_value_ref}
        label={@button_two_label}
        confirm_message={@confirm_message}
      />
    </div>
    """
  end
end
