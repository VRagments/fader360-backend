defmodule Darth.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table("users") do
      add(:is_email_verified, :boolean, null: false)
      add(:username, :string, null: false)
      add(:email, :string, null: false)
      add(:is_admin, :boolean, null: false)
      add(:account_generation, :integer, null: false)
      add(:account_plan, :string, null: false)

      add(:hashed_password, :string)
      add(:last_logged_in_at, :utc_datetime)
      add(:surname, :string)
      add(:firstname, :string)
      add(:display_name, :string)
      add(:stripe_id, :string)
      add(:metadata, :map)

      timestamps()
    end

    create(index("users", [:username], unique: true))
    create(index("users", [:email], unique: true))
  end
end
