defmodule Darth.Controller.PasswordReset do
  @moduledoc false

  use Darth.Controller, include_crud: true

  alias Darth.{Repo, Controller}
  alias Darth.Model.{PasswordReset}

  def model_mod, do: Darth.Model.PasswordReset
  def default_query_sort_by, do: "updated_at"

  def default_select_fields do
    ~w(
      id
      inserted_at
      status
      token
      updated_at
      user_id
      valid_until
    )a
  end

  def default_preload_assocs do
    ~w(
      user
    )a
  end

  def new(user_id) do
    offset = Application.get_env(:darth, :password_reset_valid_offset, hours: 24)
    valid_until = Timex.now() |> Timex.shift(offset)

    params = %{
      status: :active,
      user_id: user_id,
      token: generate_token(),
      valid_until: valid_until
    }

    PasswordReset.changeset(%PasswordReset{}, params)
  end

  def create(user_id) do
    user_id |> new() |> Repo.insert()
  end

  def update({:error, _} = err, _), do: err
  def update({:ok, model}, params), do: update(model, params)

  def update(%PasswordReset{} = model, params) do
    cset = PasswordReset.changeset(model, params)

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

  def delete(%PasswordReset{} = model) do
    case Repo.delete(model) do
      {:ok, _} = ok ->
        ok

      err ->
        err
    end
  end

  def delete(id), do: id |> read(false) |> delete()

  def expire({:error, _} = err), do: err
  def expire({:ok, model}), do: expire(model)

  def expire(%PasswordReset{} = model) do
    cond do
      model.status != :active ->
        {:error, :status_not_active}

      Timex.after?(model.valid_until, Timex.now()) ->
        {:error, :still_valid}

      true ->
        update(model, %{status: :expired})
    end
  end

  def expire(id), do: id |> read() |> expire()

  def invalidate({:error, _} = err), do: err
  def invalidate({:ok, model}), do: invalidate(model)

  def invalidate(%PasswordReset{} = model) do
    if model.status != :active do
      {:error, :status_not_active}
    else
      update(model, %{status: :invalid})
    end
  end

  def invalidate(id), do: id |> read() |> invalidate()

  def use({:error, _} = err, _, _, _), do: err
  def use({:ok, model}, email, pw, pw_confirmation), do: use(model, email, pw, pw_confirmation)

  def use(%PasswordReset{} = model, email, pw, pw_confirmation) do
    cond do
      model.user.email != email ->
        {:error, :password_reset_email_mismatch}

      model.status != :active ->
        {:error, :status_not_active}

      {:error, :still_valid} == expire(model) ->
        params = %{
          password: pw,
          password_confirmation: pw_confirmation
        }

        case Controller.User.update(model.user, params) do
          {:ok, _} ->
            update(model, %{status: :used})

          err ->
            err
        end

      true ->
        {:error, :expired}
    end
  end

  def use(token, email, pw, pw_confirmation), do: %{token: token} |> read_by() |> use(email, pw, pw_confirmation)

  def generate(email) do
    with {:ok, user1} <- Controller.User.read_by(%{email: email}),
         user2 <- Repo.preload(user1, [:password_resets]) do
      # Invalidate all active tokens before proceeding
      _ =
        for r <- user2.password_resets do
          _ =
            case invalidate(r) do
              {:error, error} ->
                _ = Logger.error(~s(Error #{inspect(error)} while invalidating password reset token: #{inspect(r)}))

              _ ->
                :ok
            end
        end

      # Finally create new token
      create(user2.id)
    else
      err ->
        err
    end
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp generate_token do
    token = Darth.Token.build_hashed_token()

    case Repo.get_by(PasswordReset, %{token: token}) do
      nil ->
        token

      _ ->
        generate_token()
    end
  end
end
