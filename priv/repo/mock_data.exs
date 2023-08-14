require Logger
alias Darth.PlaceholderAssets

case PlaceholderAssets.add_placeholder_assets_to_database() do
  {:ok, assets} ->
    Logger.info("""
      Created #{Enum.count(assets)} assets
    """)
  {:error, reasons} when is_list(reasons) -> Enum.each(reasons, &Logger.error("Error: #{&1}"))
  {:error, reason} -> Logger.error("Error: #{reason}")
end
