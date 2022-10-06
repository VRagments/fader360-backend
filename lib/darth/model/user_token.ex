defmodule Darth.Model.UserToken do
  use Darth.Model
  alias Darth.Model.UserToken
  alias Darth.Model.User

  @hash_algorithm :sha256
  @rand_size 32

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    belongs_to :user, User

    timestamps(updated_at: false)
  end

  @spec build_token(atom | %{:id => any, optional(any) => any}, String.t()) ::
          {any,
           %Darth.Model.UserToken{
             __meta__: Ecto.Schema.Metadata.t(),
             context: <<_::56>>,
             id: nil,
             inserted_at: nil,
             sent_to: nil,
             token: any,
             user: Ecto.Association.NotLoaded.t(),
             user_id: any
           }}
  def build_token(user, context) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %UserToken{token: token, context: context, user_id: user.id}}
  end

  def build_token(user, token, context) do
    {token, %UserToken{token: token, context: context, user_id: user.id}}
  end

  def verify_token_query(token, context) do
    session_validity_in_days = Application.fetch_env!(:darth, :session_validity_in_days)

    query =
      from token in token_and_context_query(token, context),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(^session_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %UserToken{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  def verify_email_token_query(token, context) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)
        days = days_for_context(context)

        query =
          from token in token_and_context_query(hashed_token, context),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^days, "day") and token.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  defp days_for_context("confirm"), do: Application.fetch_env!(:darth, :confirm_validity_in_days)
  defp days_for_context("reset_password"), do: Application.fetch_env!(:darth, :reset_password_validity_in_days)

  def verify_change_email_token_query(token, "change:" <> _ = context) do
    change_email_validity_in_days = Application.fetch_env!(:darth, :change_email_validity_in_days)

    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in token_and_context_query(hashed_token, context),
            where: token.inserted_at > ago(^change_email_validity_in_days, "day")

        {:ok, query}

      :error ->
        :error
    end
  end

  def token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end

  def user_and_contexts_query(user, :all) do
    from t in UserToken, where: t.user_id == ^user.id
  end

  def user_and_contexts_query(user, [_ | _] = contexts) do
    from t in UserToken, where: t.user_id == ^user.id and t.context in ^contexts
  end
end
