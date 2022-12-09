defmodule Darth.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Darth.Repo

  alias Darth.{AccountPlan}
  alias Darth.Model.{Asset, AssetLease, Project, ProjectCategory, User}

  def project_factory do
    %Project{
      data: map_factory(),
      name: Faker.Team.name(),
      primary_asset_lease_id: nil,
      user: build(:user),
      visibility: Enum.random(Ecto.Enum.values(Project, :visibility))
    }
  end

  def user_factory do
    email_prefix = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string()
    generation = Enum.random(AccountPlan.generations())
    plan = Enum.random(AccountPlan.list(generation))
    {:ok, features} = AccountPlan.details(plan, generation)

    metadata = %{
      features: features
    }

    %User{
      account_plan: Enum.random(AccountPlan.list(generation)),
      account_generation: generation,
      display_name: Enum.random([Faker.Person.name(), ""]),
      email: sequence(:email, &"email-#{email_prefix}-#{&1}@example.com"),
      firstname: Faker.Person.first_name(),
      hashed_password: Bcrypt.hash_pwd_salt(Faker.Code.iban()),
      is_admin: Enum.random([false, true]),
      is_email_verified: Enum.random([false, true]),
      last_logged_in_at: Faker.DateTime.backward(5),
      metadata: metadata,
      surname: Faker.Person.last_name(),
      username: Faker.Internet.user_name()
    }
  end

  def project_category_factory do
    %ProjectCategory{
      name: Faker.App.name()
    }
  end

  def asset_factory do
    %Asset{
      attributes: attributes(),
      data_filename: Faker.File.file_name(),
      media_type: Enum.random(~w(audio/ogg video/mp4 image/jpeg)),
      name: Faker.File.file_name(),
      raw_metadata: raw_metadata(),
      static_filename: Faker.File.file_name(),
      static_path: Faker.File.file_name(),
      status: Enum.random(~w(initialized transcoding_started transcoding_failed ready))
    }
  end

  def asset_lease_factory do
    valid_since = Faker.DateTime.backward(3)

    %AssetLease{
      asset: build(:asset),
      license: Enum.random(Ecto.Enum.values(AssetLease, :license)),
      valid_since: valid_since,
      valid_until: nil
    }
  end

  #
  # INTERNAL FUNCTIONS
  #

  @max_dim 8096
  @max_dur 3600
  @max_size 1_000_000_000
  defp attributes() do
    %{
      height: :rand.uniform(@max_dim),
      duration: @max_dur * :rand.uniform(),
      file_size: :rand.uniform(@max_size),
      width: :rand.uniform(@max_dim)
    }
  end

  defp raw_metadata() do
    with {:ok, json_a} <- Poison.encode(map_factory()),
         {:ok, json_p} <- Poison.encode(map_factory(1)),
         {:ok, json_s} <- Poison.encode(map_factory()),
         do: %{analysis: json_a, plug: json_p, stat: json_s}
  end

  defp map_factory(max_keys \\ 3) do
    Enum.reduce(1..:rand.uniform(max_keys), %{}, fn _, acc ->
      v =
        Enum.reduce(1..:rand.uniform(max_keys), %{}, fn _, acc2 ->
          Map.put(acc2, Faker.Superhero.power(), Faker.Pokemon.location())
        end)

      Map.put(acc, Faker.Superhero.name(), v)
    end)
  end
end
