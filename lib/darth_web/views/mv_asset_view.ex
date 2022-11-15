defmodule DarthWeb.MvAssetView do
  use DarthWeb, :view
  alias Darth.Controller.Asset
  alias Darth.Model.Asset, as: Assetstruct

  def asset_already_added?(mv_asset_key) do
    case Asset.get_asset_with_mv_asset_key(mv_asset_key) do
      %Assetstruct{} = asset_struct -> asset_struct.status == "ready"
      _ -> false
    end
  end
end
