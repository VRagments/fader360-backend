defmodule DarthWeb.ApiAuthView do
  use DarthWeb, :view

  def render("token.json", %{token: token, user: user}) do
    %{
      access_token: token,
      display_name: user.display_name,
      email: user.email,
      firstname: user.firstname,
      id: user.id,
      last_logged_in_at: user.last_logged_in_at,
      surname: user.surname,
      token_type: "bearer",
      username: user.username
    }
  end
end
