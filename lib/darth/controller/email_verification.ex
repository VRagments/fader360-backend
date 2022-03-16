defmodule Darth.Controller.EmailVerification do
  @moduledoc false

  use Darth.Controller, include_crud: true

  alias Darth.{Repo, Controller}
  alias Darth.Model.{EmailVerification}

  def model_mod, do: Darth.Model.EmailVerification
  def default_query_sort_by, do: "updated_at"

  def default_select_fields do
    ~w(
      id
      inserted_at
      is_activated
      is_expired
      is_invalid
      token
      updated_at
      user_id
    )a
  end

  def default_preload_assocs do
    ~w(
      user
    )a
  end

  def new(user_id) do
    params = %{
      is_expired: false,
      is_invalid: false,
      is_activated: false,
      user_id: user_id,
      token: generate_token()
    }

    EmailVerification.changeset(%EmailVerification{}, params)
  end

  def create(user_id) do
    user_id |> new() |> Repo.insert()
  end

  def update({:error, _} = err, _), do: err
  def update({:ok, model}, params), do: update(model, params)

  def update(%EmailVerification{} = model, params) do
    cset = EmailVerification.changeset(model, params)

    case Repo.update(cset) do
      {:ok, _} = ok ->
        ok

      err ->
        err
    end
  end

  def update(id, params), do: id |> read() |> update(params)

  def delete({:error, _} = err), do: err
  def delete({:ok, model}), do: delete(model)

  def delete(%EmailVerification{} = model) do
    case Repo.delete(model) do
      {:ok, _} = ok ->
        ok

      err ->
        err
    end
  end

  def delete(id), do: id |> read(false) |> delete()

  def expire(id) do
    case read(id) do
      {:ok, model} ->
        cond do
          model.is_expired ->
            {:error, :already_expired}

          model.is_activated ->
            {:error, :already_activated}

          model.is_invalid ->
            {:error, :already_invalid}

          true ->
            update(model, %{is_expired: true})
        end

      err ->
        err
    end
  end

  def activate(token, email) do
    case read_by(%{token: token}) do
      {:ok, model} ->
        if model.user.email == email do
          case update(model, %{is_activated: true}) do
            {:ok, _} ->
              Controller.User.update(model.user, %{is_email_verified: true})

            err2 ->
              err2
          end
        else
          {:error, :email_verification_email_mismatch}
        end

      err ->
        err
    end
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp generate_token do
    token = Darth.Token.build_hashed_token()

    case Repo.get_by(EmailVerification, %{token: token}) do
      nil ->
        token

      _ ->
        generate_token()
    end
  end
end
