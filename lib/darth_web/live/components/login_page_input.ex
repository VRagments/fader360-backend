defmodule DarthWeb.Components.LoginPageInput do
  use DarthWeb, :component

  attr :name, :atom, required: true
  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :f, :any, required: true
  attr :autocomplete, :string, required: true
  attr :placeholder, :string, required: true

  def render(%{input_type: :email} = assigns) do
    ~H"""
      <div class="mb-6">
        <%=
          label @f, @name, @label,
            class: "form-check-label inline-block text-gray-800"
        %>
        <%=
          email_input @f, @name, required: true, type: "email",
            autocomplete: @autocomplete, placeholder: @placeholder,
            class: input_field_class()
        %>
      </div>
      <div> <%= error_tag @f, @name %> </div>
    """
  end

  def render(%{input_type: :password} = assigns) do
    ~H"""
      <div class="mb-6">
        <%=
          label @f, @name, @label,
            class: "form-check-label inline-block text-gray-800"
        %>
        <%=
          password_input @f, @name, required: true, type: "password",
            autocomplete: @autocomplete, placeholder: @placeholder,
            class: input_field_class()
        %>
      </div>
      <div> <%= error_tag @f, @name %> </div>
    """
  end

  def render(assigns) do
    ~H"""
      <div class="mb-6">
        <%=
          label @f, @name, @label,
            class: "form-check-label inline-block text-gray-800"
        %>
        <%=
          text_input @f, @name, required: true, type: "text",
            autocomplete: @autocomplete, placeholder: @placeholder,value: @value,
            class: input_field_class()
        %>
      </div>
      <div> <%= error_tag @f, @name %> </div>
    """
  end

  defp input_field_class() do
    [
      "form-control",
      "block",
      "w-full",
      "px-4",
      "py-2",
      "text-xl",
      "font-normal",
      "text-gray-700",
      "bg-white",
      "bg-clip-padding",
      "border",
      "border-solid",
      "border-gray-300",
      "rounded",
      "transition",
      "ease-in-out",
      "m-0",
      "focus:text-gray-700",
      "focus:bg-white",
      "focus:border-blue-600",
      "focus:outline-none"
    ]
    |> Enum.join(" ")
  end
end
