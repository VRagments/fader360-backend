defmodule DarthWeb.Components.Header do
  use DarthWeb, :component

  attr :heading, :string, required: true
  attr :size, :atom, default: :big
  slot(:inner_block, required: false)

  def render(assigns) do
    ~H"""
      <section class="py-2 lg:pt-12 md:mx-auto lg:container">
        <div class="md:flex md:items-center md:justify-between">
          <div class="min-w-0 flex-1">
            <h2 class={heading_class(@size)}>
              <%=@heading%></h2>
          </div>
          <div class="mt-4 flex md:mt-0 md:ml-4">
            <%= render_slot(@inner_block) %>
          </div>
        </div>
      </section>
    """
  end

  defp heading_class(:small) do
    ["font-bold", "leading-7", "text-gray-900", "sm:truncate", "sm:text-3xl", "sm:tracking-tight"]
    |> Enum.join(" ")
  end

  defp heading_class(:big) do
    ["font-bold", "leading-7", "text-gray-900", "sm:truncate", "sm:text-4xl", "sm:tracking-tight"]
    |> Enum.join(" ")
  end
end
