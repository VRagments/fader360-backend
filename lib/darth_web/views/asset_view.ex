defmodule DarthWeb.AssetView do
  use DarthWeb, :view

  def is_mediaverse_account?(conn) do
    case conn.assigns.current_user.mv_node do
      nil ->
        false

      _ ->
        true
    end
  end
end
