defmodule DarthWeb.ApiOembedController do
  use DarthWeb, :controller
  alias Darth.Controller.Project

  def swagger_definitions do
    %{
      OEmbed:
        swagger_schema do
          title("OEmbed")
          description("OEmbed response")

          properties do
            type(:string, "The resource type - will always be `rich`")
            version(:string, "The oEmbed version number - this must be 1.0")
            title(:string, "Story title")

            author_name(:string, "[Optional] Displayname of the story author if it holds a value", required: false)

            author_url(
              :string,
              "[Optional] URL to discover search by the stories author if the story author has a displayname",
              required: false
            )

            provider_name(:string, "Fader")
            provider_url(:string, "app.getfader.com/discover")

            cache_age(:integer, "[Optional] The suggested cache lifetime for this resource, in seconds",
              required: false
            )

            thumbnail_url(:string, "Story thumbnail")
            thumbnail_width(:integer, "The width of the thumbnail")
            thumbnail_height(:integer, "The height of the thumbnail")

            html(
              :string,
              """
              The HTML required to display the resource. The HTML should have no padding or margins.
              Consumers may wish to load the HTML in an off-domain iframe to avoid XSS vulnerabilities.
              The markup should be valid XHTML 1.0 Basic.
              """
            )

            width(:integer, "The width of the experience")
            height(:integer, "The height of the experience")
          end

          example(%{
            type: "rich",
            version: "1.0",
            title: "NYC 2017-21-01 #WomensMarch",
            author_name: "Stephan@Vragments",
            author_url: "https://app.getfader.com/discover?filter[username]=stephan",
            provider_name: "Fader",
            provider_url: "app.getfader.com/discover",
            thumbnail_url:
              "https://app.getfader.com/assets/834ac843-8042-483f-b9d4-53ad1b8a75c7/thumb_dscn0206.mp4.jpg",
            thumbnail_width: 1080,
            thumbnail_height: 540,
            html:
              """
              <iframe
              allowfullscreen="allowfullscreen"
              allowvr="allowvr"
              width=1200
              height=600
              src="https://app.getfader.com/projects/8f05d205-47e9-4209-af88-978782b11b5d/publish"></iframe>
              """
              |> String.slice(0..-2)
              |> String.replace("\n", " "),
            width: 1200,
            height: 600
          })
        end
    }
  end

  swagger_path(:show) do
    get("/api/oembed")
    summary("oEmbed endpoint")
    description("Answers oEmbed queries.")
    produces("application/json")

    parameters do
      url(:query, :string, "The URL to retrieve embedding information for.",
        required: true,
        example: "https://app.getfader.com/projects/d746922b-4c89-40c1-973d-c0873e6d56f9/publish"
      )

      maxwidth(:query, :integer, "The maximum width of the embedded resource.", required: false, example: 1080)
      maxheight(:query, :integer, "The maximum height of the embedded resource.", required: false, example: 540)

      format(:query, :string, "The required response format. Only json allowed.",
        required: false,
        default: "json",
        example: "json"
      )
    end

    response(200, "OK", Schema.ref(:OEmbed))
    response(401, "Unauthorized - the project is not discoverable or link_share")
    response(404, "Not Found - if the url does not point to a project")
    response(501, "Not Implemented - this should be sent when (for example) the request includes format=xml")
  end

  def show(conn, params) do
    format = Map.get(params, "format", "json")
    show_format(conn, params, format)
  end

  defp show_format(conn, %{"url" => url} = params, "json") do
    {:ok, r_url} =
      Regex.compile(
        "#{DarthWeb.Endpoint.url()}/projects/(?<id>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})"
      )

    captures = Regex.named_captures(r_url, url)
    show_json_captures(conn, params, captures)
  end

  defp show_format(_, _, _), do: {:error, :not_implemented}

  defp show_json_captures(conn, params, %{"id" => id}) do
    case Project.read(id) do
      {:ok, %{visibility: :private}} ->
        {:error, :unauthorized}

      {:ok, p} ->
        maxwidth = params |> Map.get("maxwidth") |> parseint
        maxheight = params |> Map.get("maxheight") |> parseint
        {width, height} = determine_width_height(maxwidth, maxheight)

        conn
        |> put_status(:ok)
        |> render("show.json", project: p, width: width, height: height)

      e ->
        e
    end
  end

  defp show_json_captures(_, _, _), do: {:error, :not_found}

  @default_width 1200
  @default_height 600
  defp determine_width_height(nil, nil), do: {@default_width, @default_height}
  defp determine_width_height(w, nil), do: {w, w / 2}
  defp determine_width_height(nil, h), do: {h * 2, h}

  defp determine_width_height(maxw, maxh) do
    {w, h} = {maxw, maxw / 2}

    if maxh < h do
      {maxh * 2, maxh}
    else
      {w, h}
    end
  end

  defp parseint(nil), do: nil

  defp parseint(s) do
    case Integer.parse(s) do
      {i, _} ->
        i

      _ ->
        nil
    end
  end
end
