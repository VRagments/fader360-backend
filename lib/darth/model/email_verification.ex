defmodule Darth.Model.EmailVerification do
  @moduledoc false

  use Darth.Model

  alias Darth.Model.{User}

  schema "email_verifications" do
    field(:token, :string)
    field(:is_expired, :boolean)
    field(:is_invalid, :boolean)
    field(:is_activated, :boolean)

    belongs_to(:user, User)

    timestamps()
  end

  def search_attributes do
    ~w()
  end

  @allowed_fields ~w(token is_expired is_invalid is_activated user_id)a
  @required_fields ~w(token is_expired is_invalid is_activated user_id)a

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
