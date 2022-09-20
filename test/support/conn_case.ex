defmodule DarthWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use DarthWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  alias Darth.Controller.User
  alias Darth.TestUtils

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import DarthWeb.ConnCase
      import Darth.TestUtils

      alias DarthWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint DarthWeb.Endpoint
    end
  end

  def preauth_api(conn, user \\ nil) do
    preauth_conn(conn, user)
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp preauth_conn(conn, user) do
    {:ok, user} = if is_nil(user), do: TestUtils.test_user(), else: user

    login(conn, user)
  end

  defp login(conn, user) do
    binary_token = User.generate_user_token(user, "api")
    token = Base.encode64(binary_token)

    conn
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Darth.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
