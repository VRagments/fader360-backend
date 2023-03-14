defmodule DarthWeb.Components.FormSelectField do
  use DarthWeb, :component

  attr :title, :string, required: true
  attr :form, :any, required: true
  attr :input_name, :atom, required: true
  attr :options, :list, required: true

  def render(assigns) do
    ~H"""
    <div class="col-span-6 sm:col-span-3">
     <%= label @input_name, @title, class: "block text-sm font-medium text-gray-700"%>
     <%= select @form, @input_name, @options,
        class: "mt-1 block w-full rounded-md border border-gray-300 bg-white py-2 px-3
          shadow-sm focus:border-blue-500 focus:outline-none focus:ring-blue-500 sm:text-sm" %>
        <div> <%= error_tag @form, @input_name %> </div>
    </div>
    """
  end
end
