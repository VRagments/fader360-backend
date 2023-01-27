defmodule DarthWeb.ApiOembedView do
  use DarthWeb, :view

  def render("show.json", %{project: project, width: width, height: height}) do
    project
    |> base(width, height)
    |> thumbnail(project, width, height)
    |> author(project)
    |> iframe(project, width, height)
  end

  defp iframe(base, %{id: id}, width, height) do
    Map.put(
      base,
      :html,
      """
      <iframe
      allowfullscreen="allowfullscreen"
      allowvr="allowvr"
      width=#{round(width)}
      height=#{round(height)}
      src="#{DarthWeb.Endpoint.url()}/projects/#{id}/publish"></iframe>
      """
      |> String.slice(0..-2)
      |> String.replace("\n", " ")
    )
  end

  defp base(project, width, height) do
    %{
      provider_name: "Fader",
      provider_url: "#{DarthWeb.Endpoint.url()}/discover",
      title: project.name,
      type: "rich",
      version: "1.0",
      width: width,
      height: height
    }
  end

  @default_thumbnail_width 1080
  @default_thumbnail_height 540
  defp thumbnail(base, project, width, height) do
    cond do
      is_nil(project.primary_asset_lease_id) ->
        base

      width < @default_thumbnail_width ->
        base

      height < @default_thumbnail_height ->
        base

      true ->
        Map.merge(base, %{
          thumbnail_height: @default_thumbnail_height,
          thumbnail_url: project.primary_asset.thumbnail_image,
          thumbnail_width: @default_thumbnail_width
        })
    end
  end

  defp author(base, %{user: %{display_name: display_name}}) do
    if is_nil(display_name) or display_name == "" do
      base
    else
      Map.merge(base, %{
        author_name: display_name,
        author_url: "#{DarthWeb.Endpoint.url()}/discover?filter[display_name]=#{display_name}"
      })
    end
  end
end
