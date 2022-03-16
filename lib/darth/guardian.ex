defmodule Darth.Guardian do
  use Guardian, otp_app: :darth

  alias Darth.{Controller}
  alias Darth.Model.{User}

  def subject_for_token(%User{id: id}, _claims) do
    {:ok, "User:#{id}"}
  end

  def subject_for_token(_, _) do
    {:error, "Unknown resource type"}
  end

  def resource_from_claims(claims), do: resource_from_subject(claims["sub"])

  def after_sign_in(conn, _resource, _token, _claims, %{key: :admin}) do
    user = Guardian.Plug.current_resource(conn, key: :admin)
    Controller.User.record_login(user)
    {:ok, conn}
  end

  def after_sign_in(conn, _resource, _token, _claims, _options) do
    user = Guardian.Plug.current_resource(conn)
    Controller.User.record_login(user)
    {:ok, conn}
  end

  def after_encode_and_sign(resource, claims, token, _options) do
    with {:ok, _} <- Guardian.DB.after_encode_and_sign(resource, claims["typ"], claims, token) do
      Controller.User.record_login(resource)
      {:ok, token}
    end
  end

  def on_verify(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_verify(claims, token) do
      {:ok, claims}
    end
  end

  def on_revoke(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_revoke(claims, token) do
      {:ok, claims}
    end
  end

  def on_refresh({old_token, old_claims}, {new_token, new_claims}, _options) do
    with {:ok, _, _} <- Guardian.DB.on_refresh({old_token, old_claims}, {new_token, new_claims}) do
      {:ok, {old_token, old_claims}, {new_token, new_claims}}
    end
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp resource_from_subject("User:" <> id), do: Controller.User.read(id, false)
  defp resource_from_subject(_), do: {:error, "Unknown resource type"}
end
