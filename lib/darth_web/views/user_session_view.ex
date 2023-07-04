defmodule DarthWeb.UserSessionView do
  use DarthWeb, :view
  alias DarthWeb.Components.LoginPageButton
  alias DarthWeb.Components.LoginPageInputs

  def render_input_fields(false, mv_node, form) do
    [
      {
        :text,
        name: :mediaverse_node,
        placeholder: "MediaVerse node url to login",
        label: "MediaVerse Node",
        value: mv_node,
        autocomplete: "mediaverse_node",
        form: form
      },
      {
        :email,
        name: :email,
        placeholder: "Email address used to register in given MediaVerse node",
        label: "Email",
        autocomplete: "email",
        form: form
      },
      {
        :password,
        name: :password,
        placeholder: "Password used to register in given Mediaverse node",
        label: "Password",
        autocomplete: "password",
        form: form
      }
    ]
  end

  def render_input_fields(true, mv_node, form) do
    [
      {
        :text,
        name: :mediaverse_node,
        placeholder: "MediaVerse node url to login",
        label: "MediaVerse Node",
        value: mv_node,
        autocomplete: "mediaverse_node",
        form: form
      },
      {
        :text,
        name: :username,
        placeholder: "Provide username to use in Fader",
        label: "Fader Username",
        autocomplete: "username",
        form: form
      },
      {
        :email,
        name: :email,
        placeholder: "Email address used to register in given MediaVerse node",
        label: "Email",
        autocomplete: "email",
        form: form
      },
      {
        :password,
        name: :password,
        placeholder: "Password used to register in given Mediaverse node",
        label: "Password",
        autocomplete: "password",
        form: form
      }
    ]
  end
end
