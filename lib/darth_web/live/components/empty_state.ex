defmodule DarthWeb.Components.EmptyState do
  use DarthWeb, :component

  attr :label, :string, required: true

  def render(assigns) do
    ~H"""
    <section class="py-2 lg:pt-12 md:mx-auto lg:container">
      <div
        class="relative block w-full rounded-lg border-2 border-dashed border-gray-300
          p-12 text-center hover:border-gray-400 focus:outline-none focus:ring-2
          focus:ring-indigo-500 focus:ring-offset-2"
        >
        <span class="mt-2 block text-sm font-semibold text-gray-900"><%=@label%></span>
      </div>
    </section>
    """
  end
end
