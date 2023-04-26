defmodule DarthWeb.Components.StatLinkButton do
  use DarthWeb, :component
  alias DarthWeb.Components.HeaderButtons

  attr(:action, :atom, required: true)
  attr(:level, :atom, required: true)
  attr(:type, :atom, required: true)
  attr(:path, :string, required: true)
  attr(:label, :string, required: true)

  def render(assigns) do
    ~H"""
      <div class="border-t-2 border-gray-100 pt-6">
        <div class="pt-3"></div>
        <dd class="text-xl font-bold tracking-tight text-gray-900 py-2.5 pl-3 pr-10">
          <HeaderButtons.render
            buttons={[
              {
                  @action,
                  label: @label,
                  level: @level,
                  path: @path,
                  type: @type
              }
            ]}
          />
        </dd>
      </div>
    """
  end
end
