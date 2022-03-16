defmodule Darth.AssetFile.Image do
  @moduledoc false

  @enforce_keys [:metadata, :stat]
  defstruct [:metadata, :stat]
end

defimpl Darth.AssetFile, for: Darth.AssetFile.Image do
  def dimensions(%{metadata: [%{"image" => %{"geometry" => %{"width" => width, "height" => height}}}]}),
    do: {:ok, {width, height}}

  def dimensions(%{metadata: %{"image" => %{"geometry" => %{"width" => width, "height" => height}}}}),
    do: {:ok, {width, height}}

  def dimensions(_), do: {:error, :invalid_metadata}

  def duration(_), do: {:ok, 0}

  def file_size(%{stat: %{size: size}}), do: {:ok, size}
  def file_size(_), do: {:error, :invalid_stat}
end
