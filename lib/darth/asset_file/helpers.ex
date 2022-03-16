defmodule Darth.AssetFile.Helpers do
  require Logger

  alias Darth.Controller.Asset, as: AssetController
  alias Darth.AssetFile.{Audio, Image, Video}

  @doc """
  Returns `Darth.AssetFile` from `media_type` and `metadata`.
  """
  def asset_file(media_type, metadata, stat) do
    case AssetController.normalized_media_type(media_type) do
      :audio ->
        %Audio{metadata: metadata, stat: stat}

      :image ->
        %Image{metadata: metadata, stat: stat}

      :video ->
        %Video{metadata: metadata, stat: stat}

      _ ->
        nil
    end
  end

  @doc """
  Determine mimetype from `path`.
  """
  def mime_type(path) do
    params = ["--brief", "--mime-type", "--no-buffer", "--no-pad", path]

    case System.cmd("file", params) do
      {mime, 0} ->
        mime
        |> String.trim()
        |> convert_exotic(path)

      {out, code} ->
        {:error, "Error during mime_type determination on #{path}: #{out} (#{code})"}
    end
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp file_string(path) do
    params = ["--brief", "--no-buffer", "--no-pad", path]

    case System.cmd("file", params) do
      {output, 0} ->
        {:ok, output}

      {out, code} ->
        {:error, "Error during mime_type determination of binary data on #{path}: #{out} (#{code})"}
    end
  end

  # Some videos mask themselves as audio mp4 in mimetype.
  defp convert_exotic("audio/mp4" = mime, path) do
    with {:ok, output} <- file_string(path),
         do:
           output
           |> String.downcase()
           |> (fn o ->
                 if String.starts_with?(o, "iso media, mpeg-4 (.mp4) for sonypsp") do
                   {:ok, "video/mp4"}
                 else
                   {:ok, mime}
                 end
               end).()
  end

  # Mimetype octet stream needs to be converted into video, audio or image.
  defp convert_exotic("application/octet-stream", path) do
    with {:ok, output} <- file_string(path),
         do:
           output
           |> String.downcase()
           |> (fn o ->
                 cond do
                   String.starts_with?(o, "data") and String.ends_with?(path, ".mp3") ->
                     {:ok, "audio/mp3"}

                   # This case assumes the mime-type is correct. If we encounter other example where this is not the
                   # case we saw it coming.
                   String.starts_with?(o, "iso media, mpeg v4 system, 3gpp") ->
                     {:ok, "video/mp4"}

                   String.contains?(o, "audio") ->
                     {:ok, "audio/mp3"}

                   String.contains?(o, "video") ->
                     {:ok, "video/mp4"}

                   String.contains?(o, "image") ->
                     {:ok, "image/jpg"}

                   true ->
                     {:error, "Unknown mime-type #{o}"}
                 end
               end).()
  end

  defp convert_exotic(x, _), do: {:ok, x}
end
