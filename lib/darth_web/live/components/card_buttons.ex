defmodule DarthWeb.Components.CardButtons do
  use DarthWeb, :component
  alias DarthWeb.Components.CardButton

  attr(:buttons, :list, required: true)

  def render(assigns) do
    ~H"""
      <div class="-mt-px flex divide-x divide-gray-200">
        <%= for b <- @buttons do %>
          <CardButton.render {convert_to_map(b)} />
        <% end %>
      </div>
    """
  end

  defp convert_to_map({action, opts}) do
    %{
      action: action,
      type: Keyword.get(opts, :type),
      label: Keyword.get(opts, :label),
      path: Keyword.get(opts, :path),
      confirm_message: Keyword.get(opts, :confirm_message),
      phx_value_ref: Keyword.get(opts, :phx_value_ref)
    }
  end
end
