defmodule DarthWeb.Components.FormInputField do
  use DarthWeb, :component

  attr :title, :string, required: true
  attr :input_name, :atom, required: true
  attr :form, :any, required: true
  attr :autocomplete, :string, required: true
  attr :placeholder, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="col-span-6 sm:col-span-3">
      <%=label @input_name, @title, class: "block text-sm font-medium text-gray-700"%>
      <%= text_input @form, @input_name, required: true, type: "text",
        autocomplete: @autocomplete, placeholder: @placeholder,
        class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm
          focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
    </div>
    <div> <%= error_tag @form, @input_name %> </div>
    """
  end
end
