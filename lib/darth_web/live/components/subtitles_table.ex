defmodule DarthWeb.Components.SubtitlesTable do
  use DarthWeb, :component
  alias DarthWeb.Components.Button
  alias Darth.Model.AssetSubtitle, as: AssetSubtitleStruct

  attr(:entries, :list, required: true)
  attr(:select_options, :list, required: true)
  attr(:subtitle_edit_access, :boolean, default: false)

  def render(assigns) do
    ~H"""
      <div class="px-4 sm:px-6 lg:px-8">
        <div class="mt-8 flow-root">
          <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
            <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
              <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
                <table class="min-w-full divide-y divide-gray-300">
                  <thead class="bg-gray-50">
                    <tr>
                      <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm
                        font-semibold text-gray-900 sm:pl-6"
                      >
                        Name
                      </th>
                      <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Language</th>
                      <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                        <span class="sr-only">Delete</span>
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200 bg-white">
                      <%= for e <- @entries do %>
                        <tr>
                          <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm
                                font-medium text-gray-900 sm:pl-6"
                          >
                            <%= e.name %>
                          </td>
                          <%= unless @subtitle_edit_access do%>
                            <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                              <.form :let={f} for={AssetSubtitleStruct.changeset(e)} phx-change="update_language">
                                <%= text_input f, :id, type: :hidden, value: e.id%>
                                <%= select f, :language, @select_options,
                                  class: "text-sm tracking-tight text-gray-900 rounded-md" %>
                                <div> <%= error_tag f, :language %> </div>
                              </.form>
                            </td>
                            <td class="relative whitespace-nowrap py-4 pl-3
                                  pr-4 text-right text-sm font-medium sm:pr-6"
                            >
                              <Button.render
                                action={:delete}
                                level={:secondary}
                                label="Delete"
                                type={:click}
                                phx_value_ref={e.id}
                              />
                            </td>
                          <% else %>
                            <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                              <%= e.language %>
                            </td>
                          <% end %>
                        </tr>
                      <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    """
  end
end
