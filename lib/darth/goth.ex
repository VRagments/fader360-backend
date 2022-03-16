defmodule Darth.Goth do
  @moduledoc """
  Keep [Goth](https://github.com/peburrows/goth) related stuff here.
  """

  @doc """
  Fetch json credentials and form source tuple for goth.
  """
  def source do
    credentials = Application.fetch_env!(:darth, :goth_credentials) |> Jason.decode!()
    scopes = ["https://www.googleapis.com/auth/analytics.readonly"]
    {:service_account, credentials, scopes: scopes}
  end
end
