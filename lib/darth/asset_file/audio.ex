defmodule Darth.AssetFile.Audio do
  @moduledoc false

  @enforce_keys [:metadata, :stat]
  defstruct [:metadata, :stat]
end

defimpl Darth.AssetFile, for: Darth.AssetFile.Audio do
  def dimensions(_), do: {:ok, {0, 0}}

  def duration(%{metadata: %{"format" => %{"duration" => duration}}}) do
    case Float.parse(duration) do
      {dur, ""} ->
        {:ok, dur}

      _ ->
        {:error, :invalid_duration}
    end
  end

  def duration(_), do: {:error, :invalid_metadata}

  def file_size(%{stat: %{size: size}}), do: {:ok, size}
  def file_size(_), do: {:error, :invalid_stat}
end
