defmodule Darth.Controller.Auth do
  @moduledoc false

  use Darth.Controller

  def authenticate_user(username, password, gen_token \\ true) do
    authenticate(username, password, gen_token)
  end

  def get_token(user) do
    {:ok, jwt, _full_claims} = Darth.Guardian.encode_and_sign(user)
    {:ok, {jwt, user}}
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp authenticate(username, password, gen_token) do
    # always hash to avoid timing attacks for valid identies
    hash = Bcrypt.hash_pwd_salt(password)

    with {:ok, user} <- Darth.Controller.User.read_by(%{username: username}, false, [], false),
         true <- Bcrypt.verify_pass(user.hashed_password, hash) do
      if is_boolean(user.is_email_verified) and not user.is_email_verified do
        {:error, :email_not_verified}
      else
        if gen_token do
          get_token(user)
        else
          {:ok, user}
        end
      end
    else
      _ ->
        # former Aeacus error message - used for compatibility reasons
        {:error, "Invalid id."}
    end
  end
end
