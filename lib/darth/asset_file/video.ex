defmodule Darth.AssetFile.Video do
  @moduledoc false

  @enforce_keys [:metadata, :stat]
  defstruct [:metadata, :stat]
end

defimpl Darth.AssetFile, for: Darth.AssetFile.Video do
  def dimensions(%{metadata: %{"format" => _format, "streams" => streams}}) do
    v_str = Enum.find(streams, %{"width" => 0, "height" => 0}, &(&1["codec_type"] == "video"))
    %{"width" => width, "height" => height} = v_str
    # search nested list/map struct for rotation key
    if is_rotated(v_str) do
      {:ok, {height, width}}
    else
      {:ok, {width, height}}
    end
  end

  def dimensions(_), do: {:error, :invalid_metadata}

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

  #
  # INTERNAL FUNCTIONS
  #

  defp is_rotated(%{"rotation" => rot}), do: rot == -90 or rot == 90 or rot == 270 or rot == -270
  defp is_rotated(m) when is_map(m), do: Enum.reduce_while(m, false, fn {_, v}, acc -> rec_from_acc(v, acc) end)
  defp is_rotated(l) when is_list(l), do: Enum.reduce_while(l, false, &rec_from_acc(&1, &2))
  defp is_rotated(_), do: false

  defp rec_from_acc(v, acc) do
    if is_rotated(v) do
      {:halt, true}
    else
      {:cont, acc}
    end
  end
end
