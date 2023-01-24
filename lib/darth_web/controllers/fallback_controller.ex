defmodule DarthWeb.FallbackController do
  use Phoenix.Controller

  alias DarthWeb.ErrorView

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(ErrorView)
    |> render(:"401", %{})
  end

  def call(conn, {:error, :not_implemented}) do
    conn
    |> put_status(:not_implemented)
    |> put_view(ErrorView)
    |> render(:"501", %{})
  end

  def call(conn, {:error, :missing_parameters}) do
    conn
    |> put_status(:not_acceptable)
    |> put_view(ErrorView)
    |> render(:"406", %{})
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(ErrorView)
    |> render(:"404", %{})
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
