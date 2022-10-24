defmodule DarthWeb.AssetController do
  use DarthWeb, :controller
  require Logger
  alias Darth.Controller.Asset
  alias DarthWeb.UserAuth

  def index(conn, _opts) do
    with assets <- Asset.get_all_database_entries() do
      conn
      |> render("assets.html", assets: assets)
    else
      {:error, query_error = %Ecto.QueryError{}} ->
        Logger.error("Custom error message from MediaVerse: Database error while fetching assets")
        error_fetch_assets(conn, query_error)
    end
  end

  defp error_fetch_assets(conn, reason) do
    conn
    |> put_flash(:error, "Assets cannot be fetced due to: #{reason}")
    |> UserAuth.logout_user()
    |> redirect(to: Routes.user_session_path(conn, :login))
  end
end
