defmodule Darth.QrCodeGenerator do
  def generate_project_result_qr_code(player_url) do
    player_url
    |> QRCodeEx.encode()
    |> QRCodeEx.png()
  end
end
