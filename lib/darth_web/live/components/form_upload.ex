defmodule DarthWeb.Components.FormUpload do
  use DarthWeb, :component
  alias DarthWeb.Components.SubmitButton

  attr :uploads, :map, required: true
  attr :action, :string, required: true

  def render(assigns) do
    ~H"""
    <form id="upload-form"
      class="block text-lg text-gray-900 rounded-lg cursor-pointer dark:text-gray-400 focus:outline-none",
        id="small_size" , phx-submit="save" phx-change="validate">
      <.live_file_input upload={@uploads.media} />
      <SubmitButton.render action={@action} label={@action}/>
    </form>
    """
  end
end
