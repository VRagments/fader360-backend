defmodule Darth.Model.PasswordReset do
  @moduledoc false

  use Darth.Model

  alias Darth.Model.{User}

  schema "password_resets" do
    field(:token, :string)
    field(:status, Ecto.Enum, values: [:used, :expired, :active, :invalid])
    field(:valid_until, :utc_datetime)

    belongs_to(:user, User)

    timestamps()
  end

  def search_attributes do
    ~w()
  end

  @allowed_fields ~w(token status user_id valid_until)a
  @required_fields ~w(token status user_id valid_until)a

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:token)
    |> assoc_constraint(:user)
  end

  #
  # INTERNAL FUNCTIONS
  #
end
