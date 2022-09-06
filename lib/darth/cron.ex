defmodule Darth.Cron do
  @moduledoc false

  import Ecto.Query
  import Swoosh.Email

  alias Darth.{AccountPlan, Controller, Mailer, Repo}
  alias Darth.Model.User

  # Ensure we've generated the last updated field for all projects
  def ensure_project_last_updated do
    query = ~s(UPDATE projects SET last_updated_at = updated_at WHERE last_updated_at IS NULL)
    {:ok, _res} = Ecto.Adapters.SQL.query(Repo, query, [])
  end

  def update_user_agent_database do
    UAInspector.Downloader.download()
    UAInspector.reload()
  end

  def fix_invalid_metadata do
    # delay randomly between 1 and 30 minutes, so appservers do not execute it simultaneously
    delay_min = Enum.random(1..30)
    :timer.apply_after(delay_min * 60 * 1000, __MODULE__, :do_fix_invalid_metadata, [])
  end

  def fix_invalid_account_plans do
    # delay randomly between 1 and 30 minutes, so appservers do not execute it simultaneously
    delay_min = Enum.random(1..30)
    :timer.apply_after(delay_min * 60 * 1000, __MODULE__, :do_fix_invalid_account_plans, [])
  end

  def do_fix_invalid_account_plans do
    gens = AccountPlan.generations()

    invalid_users =
      User
      |> where([u], u.account_generation not in ^gens or is_nil(u.account_plan))
      |> Repo.all()

    params = %{
      account_generation: AccountPlan.active_generation(),
      account_plan: AccountPlan.default()
    }

    res_return = fn
      {:ok, upd_u}, u ->
        """
        #{u.username} (#{u.email}, #{u.id}):
        old: generation #{inspect(u.account_generation)}, plan #{inspect(u.account_plan)}
        new:  generation #{upd_u.account_generation}, plan #{upd_u.account_plan}

        """

      err, u ->
        """
        #{u.username} (#{u.email}, #{u.id}):
        : #{inspect(err)}

        """
    end

    invalid_users
    |> Enum.map(fn u ->
      u
      |> Controller.User.update(params)
      |> res_return.(u)
    end)
    |> notify_invalid_account_plans
  end

  def do_fix_invalid_metadata do
    invalid_users =
      User
      |> where([u], is_nil(u.metadata) or u.metadata == ^%{})
      |> Repo.all()

    res_return = fn
      {:ok, _}, u ->
        """
        #{u.username} (#{u.email}, #{u.id}): fixed empty metadata

        """

      err, u ->
        """
        #{u.username} (#{u.email}, #{u.id}):
        : #{inspect(err)}

        """
    end

    fix_metadata = fn %{account_generation: account_generation} = u ->
      u
      |> Controller.User.update(%{account_generation: account_generation})
      |> res_return.(u)
    end

    invalid_users
    |> Enum.map(fix_metadata)
    |> notify_invalid_metadata
  end

  #
  # INTERNAL FUNCTIONS
  #

  defp notify_invalid_metadata([]), do: :ok

  defp notify_invalid_metadata(fixes) do
    text_body = """
    I found #{Enum.count(fixes)} user(s) with empty metadata.
    These are my fixes:

    #{fixes}
    """

    new(
      to: "operations@vragments.com",
      from: "darth_cron@vragments.com",
      subject: "Fixed invalid metadata",
      text_body: text_body
    )
    |> Mailer.deliver()
  end

  defp notify_invalid_account_plans([]), do: :ok

  defp notify_invalid_account_plans(fixes) do
    text_body = """
    I found #{Enum.count(fixes)} user(s) with invalid account_plan or account_generations.
    These are my fixes:

    #{fixes}
    """

    new(
      to: "operations@vragments.com",
      from: "darth_cron@vragments.com",
      subject: "Fixed invalid account plans and generations",
      text_body: text_body
    )
    |> Mailer.deliver()
  end
end
