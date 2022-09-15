defmodule DarthWeb.FallbackController do
  use Phoenix.Controller

  alias DarthWeb.ErrorView

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(ErrorView)
    |> render(:"401", %{})
  end

  def call(conn, {:error, :could_not_delete_token}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ErrorView)
    |> render(:"422", %{})
  end

  def call(conn, {:error, :already_logged_in}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ErrorView)
    |> render(:"422", %{})
  end

  def call(conn, {:error, :not_implemented}) do
    conn
    |> put_status(:not_implemented)
    |> put_view(ErrorView)
    |> render(:"501", %{})
  end

  def call(conn, {:error, reason}) when is_binary(reason) or is_atom(reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ErrorView)
    |> render(:"4xx", error: reason)
  end

  def call(conn, {:error, err_cset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ErrorView)
    |> render(:"4xx", changeset: err_cset)
  end
end
