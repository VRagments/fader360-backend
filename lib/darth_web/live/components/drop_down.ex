defmodule DarthWeb.Components.DropDown do
  use DarthWeb, :component
  alias Phoenix.LiveView.JS

  attr :buttons, :list, required: true

  def render(assigns) do
    ~H"""
      <%= for {button_id, button_label, options} <- @buttons do %>
        <div phx-click={show_element(button_id)}>
          <div class="inline-flex items-center border-b-2 border-transparent
            px-1 text-sm font-medium text-gray-500">
            <div class="relative inline-block">
              <div class="flex">
                <button type="button" class="inline-flex items-center border-b-2 border-transparent
                  px-1 text-sm font-medium text-gray-500"
                  aria-expanded="false" id="#{{button_id}}-button">
                  <%= button_label %>
                  <svg class="-mr-1 ml-1 h-5 w-5 flex-shrink-0 text-gray-400 group-hover:text-gray-500"
                    viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0
                      111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
                  </svg>
                </button>
              </div>
              <div id={button_id} phx-click-away={hide_element(button_id)}
                class="absolute left-0 z-10 mt-2 w-40 origin-top-right rounded-md bg-white
                  shadow-2xl ring-1 ring-black ring-opacity-5 focus:outline-none hidden"
                  role="menu" aria-orientation="vertical" aria-labelledby="#{{button_id}}-button"
                  tabindex="-1"
                >
                <div class="py-1" role="none">
                  <%= for {option_label, option_link} <- options do %>
                    <.link navigate={option_link}
                      class="font-medium text-gray-900 block px-4 py-2 text-sm"
                        role="menuitem" tabindex="-2" id="menu-item-2">
                      <%= option_label %>
                    </.link>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    """
  end

  defp hide_element(element) do
    %JS{}
    |> JS.hide(
      transition:
        {"transition ease-in duration-75", "transform opacity-100 scale-100", "transform opacity-0 scale-95"},
      to: "##{element}"
    )
  end

  defp show_element(element) do
    %JS{}
    |> JS.show(
      transition:
        {"transition ease-out duration-100", "transform opacity-0 scale-95", "transform opacity-100 scale-100"},
      to: "##{element}"
    )
  end
end
