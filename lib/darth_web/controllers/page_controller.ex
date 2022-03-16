defmodule DarthWeb.PageController do
  use DarthWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
