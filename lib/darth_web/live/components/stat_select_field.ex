defmodule DarthWeb.Components.StatSelectField do
  use DarthWeb, :component

  attr :changeset, :map, required: true
  attr :form_chnage_name, :string, required: true
  attr :title, :string, required: true
  attr :input_name, :atom, required: true
  attr :select_options, :list, required: true

  def render(assigns) do
    ~H"""
      <.form :let={f} for={@changeset} phx-change={@form_chnage_name}>
        <div class="border-t-2 border-gray-100 pt-6">
          <dt class="text-base font-medium text-gray-500 pl-3"><%=@title%></dt>
          <%= select f, @input_name, @select_options,
            class: "text-xl font-bold tracking-tight text-gray-900 py-2.5 pl-3 pr-10 rounded-md" %>
        </div>
        <div> <%= error_tag f, @input_name %> </div>
      </.form>
    """
  end
end
