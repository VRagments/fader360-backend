defmodule DarthWeb.MvAssetView do
  use DarthWeb, :view
  alias Darth.Controller.Asset
  alias Darth.Model.Asset, as: Assetstruct

  def asset_already_added(mv_asset_key) do
    with %Assetstruct{} = asset_struct <- Asset.get_asset_with_mv_asset_key(mv_asset_key),
         true <- asset_struct.status == "ready" do
      true
    else
      _ -> false
    end
  end
end
