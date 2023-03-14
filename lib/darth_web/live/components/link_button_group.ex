defmodule DarthWeb.Components.LinkButtonGroup do
  use DarthWeb, :component
  alias DarthWeb.Components.LinkButton

  attr :button_one_link, :string, required: true
  attr :button_one_action, :string, required: true
  attr :button_one_label, :string, required: true
  attr :button_two_link, :string, required: true
  attr :button_two_action, :string, required: true
  attr :button_two_label, :string, required: true

  def render(assigns) do
    ~H"""
    <span class="isolate inline-flex rounded-md shadow-sm">
      <LinkButton.render link={@button_one_link} action={@button_one_action} label={@button_one_label}/>
      <div class="relative -ml-px inline-flex bg-white px-4 py-2 text-sm font-medium text-gray-700 focus:z-10"></div>
      <LinkButton.render link={@button_two_link} action={@button_two_action} label={@button_two_label}/>
    </span>
    """
  end
end
