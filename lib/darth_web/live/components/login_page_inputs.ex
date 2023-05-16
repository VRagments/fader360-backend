defmodule DarthWeb.Components.LoginPageInputs do
  use DarthWeb, :component
  alias DarthWeb.Components.LoginPageInput

  attr(:input_fields, :list, required: true)

  def render(assigns) do
    ~H"""
      <%= for i <- @input_fields do %>
        <LoginPageInput.render {convert_to_map(i)} />
      <% end %>
    """
  end

  defp convert_to_map({input_type, opts}) do
    %{
      input_type: input_type,
      name: Keyword.get(opts, :name),
      placeholder: Keyword.get(opts, :placeholder),
      value: Keyword.get(opts, :value),
      autocomplete: Keyword.get(opts, :autocomplete),
      label: Keyword.get(opts, :label),
      f: Keyword.get(opts, :form)
    }
  end
end
