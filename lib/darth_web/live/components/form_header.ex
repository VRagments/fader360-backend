defmodule DarthWeb.Components.FormHeader do
  use DarthWeb, :component

  attr :title, :string, required: true
  attr :subtitle, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="md:col-span-1">
      <div class="px-4 sm:px-0">
        <h3 class="text-lg font-medium leading-6 text-gray-900"><%=@title%></h3>
        <p class="mt-1 text-sm text-gray-600"><%=@subtitle%></p>
      </div>
    </div>
    """
  end
end
