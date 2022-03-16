defmodule Darth.Repo.Migrations.CreateEmailVerifications do
  use Ecto.Migration

  def change do
    create table("email_verifications") do
      add(:token, :string, null: false)
      add(:is_expired, :boolean, null: false)
      add(:is_invalid, :boolean, null: false)
      add(:is_activated, :boolean, null: false)

      add(:user_id, references(:users, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index("email_verifications", [:token], unique: true))
  end
end
