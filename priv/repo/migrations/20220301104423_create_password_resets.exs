defmodule Darth.Repo.Migrations.CreatePasswordResets do
  use Ecto.Migration

  def change do
    create_query =
      "CREATE TYPE password_reset_status AS ENUM ('used', 'expired', 'active', 'invalid')"

    drop_query = "DROP TYPE password_reset_status"
    execute(create_query, drop_query)

    create table("password_resets") do
      add(:token, :string, null: false)
      add(:status, :password_reset_status, null: false)
      add(:valid_until, :utc_datetime, null: false)

      add(:user_id, references(:users, on_delete: :delete_all), null: false)

      timestamps()
    end

    create(index("password_resets", [:token], unique: true))
    create(index("password_resets", [:status]))
  end
end
