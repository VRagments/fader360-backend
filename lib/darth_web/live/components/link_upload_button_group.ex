defmodule DarthWeb.Components.LinkUploadButtonGroup do
  use DarthWeb, :component
  alias DarthWeb.Components.{LinkButton, FormUpload}

  def render(assigns) do
    ~H"""
    <span class="isolate inline-flex rounded-md shadow-sm">
      <LinkButton.render link={@button_one_link} action={@button_one_action} label={@button_one_label}/>
      <div class="relative -ml-px inline-flex bg-white px-4 py-2 text-sm font-medium text-gray-700 focus:z-10"></div>
      <FormUpload.render action={@button_two_action} uploads={@uploads}/>
    </span>
    """
  end
end
