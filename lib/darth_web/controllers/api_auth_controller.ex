defmodule DarthWeb.ApiAuthController do
  use DarthWeb, :controller
  require Logger
  alias Darth.Controller.User
  alias Darth.Model.User, as: UserStruct
  alias DarthWeb.QueryParameters

  def swagger_definitions do
    %{
      AuthResponse:
        swagger_schema do
          title("AuthResponse")
          description("Authentication information.")

          properties do
            access_token(
              :string,
              "Bearer API token which can be used for authenticated API calls."
            )

            display_name(:string, "The authenticated user's display name.")
            email(:string, "The authenticated user's email address.")
            firstname(:string, "The authenticated user's firstname.")
            id(:string, "The authenticated user's object ID.")
            last_logged_in_at(:string, "The authenticated user's last known login time.")
            surname(:string, "The authenticated user's surname.")
            token_type(:string, "API token type.")
            username(:string, "The authenticated user's username.")
          end

          example(%{
            access_token: "tkMqYd0SSktAA3Ag3lo16nkmYjbVNc4W",
            display_name: "John Doe",
            email: "john@doe.com",
            firstname: "John",
            id: "fd414dd5-1f91-4a22-9ca4-275dd6ddf7b7",
            last_logged_in_at: "2018-06-18 16:35:43",
            surname: "Doe",
            token_type: "bearer",
            username: "johndoe"
          })
        end
    }
  end

  #
  # Unauthenticated Requests
  #

  swagger_path(:login) do
    get("/api/auth/login")
    summary("Requests authentication token for the given authentication credentials.")

    description(~s(The received token can be used in other API calls which require authentication.))

    produces("application/json")

    parameters do
      username(:query, :string, "Username", required: true, example: "apiuser_tester")
      password(:query, :string, "Password", required: true, example: "secret_words")
    end

    response(200, "OK", Schema.ref(:AuthResponse))
    response(406, "Missing Parameters")
    response(401, "User not found")
  end

  def login(conn, %{"username" => username, "password" => password}) do
    case User.get_user_by_username_and_password(username, password) do
      %UserStruct{} = user_struct ->
        binary_token = User.generate_user_token(user_struct, "api")
        token = Base.encode64(binary_token)

        conn
        |> render("token.json", token: token, user: user_struct)

      nil ->
        {:error, :unauthorized}
    end
  end

  def login(_conn, _params), do: {:error, "missing parameters"}
  #
  # Authenticated Requests
  #

  swagger_path(:logout) do
    post("/api/auth/logout")
    summary("Invalidates the access token for the logged in user.")

    description(~s(The used token cannot be used anymore in other API calls which require authentication.))

    produces("application/json")

    QueryParameters.authorization()

    response(204, "Success - No Content")
    response(422, "Couldn't delete token")
  end

  def logout(conn, _params) do
    user_token = conn.assigns.api_user_token
    User.delete_token(user_token, "api")
    send_resp(conn, :no_content, "")
  end

  swagger_path(:refresh) do
    post("/api/auth/refresh")
    summary("Replaces the access token for the logged in user with a new access token.")

    description(~s(The former token cannot be used anymore in other API calls which require authentication.))

    produces("application/json")

    QueryParameters.authorization()

    response(200, "OK", Schema.ref(:AuthResponse))
    response(422, "Couldn't refresh token")
  end

  def refresh(conn, _params) do
    user_token = conn.assigns.api_user_token
    user_struct = conn.assigns.current_api_user
    User.delete_token(user_token, "api")
    binary_token = User.generate_user_token(user_struct, "api")
    token = Base.encode64(binary_token)

    conn
    |> render("token.json", token: token, user: user_struct)
  end
end
