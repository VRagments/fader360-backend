defmodule Darth.Model do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema

      alias Darth.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query, only: [from: 1, from: 2]

      require Logger

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    end
  end
end
