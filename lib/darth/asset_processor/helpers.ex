defmodule Darth.AssetProcessor.Helpers do
  @doc """
  Trigger close operation on `port`. Does nothing if `port` is nil.
  """
  def close_port(port) when is_nil(port), do: :ok

  def close_port(port) do
    if not is_nil(Port.info(port)) do
      Port.close(port)
    end
  end
end
