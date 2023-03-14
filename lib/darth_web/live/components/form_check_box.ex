defmodule DarthWeb.Components.FormCheckBox do
  use DarthWeb, :component

  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :input_name, :atom, required: true
  attr :form, :any, required: true

  def render(assigns) do
    ~H"""
    <div class="col-span-6 sm:col-span-3">
      <div class="ml-3 text-sm leading-6">
        <%= checkbox @form, @input_name, checked_value: true, unchecked_value: false,
        class: "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600" %>
        <%= label @input_name, @title, class: "font-medium text-gray-900"%>
        <p class="text-gray-500"><%=@subtitle%></p>
      </div>
    </div>
    """
  end
end
