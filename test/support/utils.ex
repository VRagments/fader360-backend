defmodule Darth.TestUtils do
  alias Darth.Controller.User
  alias Darth.Repo

  def test_user() do
    test_params = %{
      "username" => "girish",
      "email" => "girish@vragments.com",
      "surname" => "Vadlamudi",
      "firstname" => "Girish",
      "display_name" => "Girish",
      "password" => "GirishVragments"
    }

    User.new(test_params)
    |> Repo.insert()
  end
end
