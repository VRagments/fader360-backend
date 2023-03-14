defmodule DarthWeb.Components.Stat do
  use DarthWeb, :component

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :unit, :string, default: ""

  def render(assigns) do
    ~H"""
    <div class="border-t-2 border-gray-100 pt-6">
      <dt class="text-base font-medium text-gray-500 pl-3"><%=@title%></dt>
      <dd class="text-xl font-bold tracking-tight text-gray-900 py-2.5 pl-3 pr-10">
      <%=@value%> <%=@unit%></dd>
    </div>
    """
  end
end
