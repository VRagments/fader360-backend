defmodule Darth.Stripe do
  @moduledoc """
  A subscription is a recurring invoicing mechanism.
  Each subscription contains a plan that a user is subscribed to.
  When changing a plan the current subscription is updated.
  Stripe adheres to changed payments within a subscription month by default.

  ## Workflow:

  - Onboarding non subscribed user

  * Query available plans with `list_plans`.
  * User chooses a plan. Use stripe checkout/elements on client side to get a stripe token.
  * Onboard user with `subscribe`

  - Change subscription plan (also applies when switching to free plan)

  * Query available plans with `list_plans`.
  * Query existing plan with: `subscribed_plan`.
  * Display choices and let user select new plan.
  * Update plan inside user subscription with `change_plan`.

  - Changing payment method

  * Query current payment source with `payment_source`
  * Display something and allow for adding a new source.
  * Use stripe checkout/elements on client side to get new token for new card.
  * Call `change_payment_source` with token to replace old payment method.

  - Cancel subscription

  * User wants to delete payment data and/or account, use `cancel_subscription`.
  * This will take effect immediately

  - List invoices

  * Retrieve all invoices for a user with `list_invoices`.
  * This is limited to the last 100 invoices (should suffice for the next 8 years)

  ## Arbitrary limitations:

  Our users will have at most one subscription.
  We only allow one plan per subscription.
  Our users will have one payment source at any given time.
  No more than 100 plans/invoices can be requested since pagination is not implemented.
  """

  alias Darth.Model.User

  @doc """
  List all defined plans.

  @spec list_plans() :: {:ok, [Stripe.Plan.t()]} | {:error, Stripe.Error.t()}
  """
  def list_plans() do
    with {:ok, l} <- Stripe.Plan.list(%{limit: 100}),
         do: {:ok, l.data}
  end

  @doc """
    Onboard a new user who is not currently subscribed (has left no payment data).
    If a user still has a stripe connection the users payment data will be updated
    and a new subscription will be added.
    Fails if already subscribed.

    @spec subscribe(Darth.Model.User, Stripe.Plan.t(), Stripe.Token.t())
    :: {:ok, Stripe.Subscription.t()} | {:error, Stripe.Error.t()}
    | {:error, :already_subscribed} | {:error, Darth.Controller.User.UpdateError}
  """
  def subscribe(user, plan, token)

  def subscribe(%User{stripe_id: stripe_id} = user, %Stripe.Plan{id: plan_id}, %Stripe.Token{} = token)
      when is_nil(stripe_id) do
    params = %{
      email: user.email,
      metadata: %{username: user.username},
      source: token
    }

    with {:ok, customer} <- Stripe.Customer.create(params),
         {:ok, u} <- Darth.Controller.User.update(user, %{stripe_id: customer.id}),
         sub_params = %{customer: u.stripe_id, items: [%{plan: plan_id}]},
         do: Stripe.Subscription.create(sub_params)
  end

  def subscribe(%User{stripe_id: stripe_id}, %Stripe.Plan{id: plan_id}, %Stripe.Token{} = token) do
    check_subs = fn subs ->
      if Enum.empty?(subs) do
        :ok
      else
        {:error, :already_subscribed}
      end
    end

    with {:ok, l_subs} <- Stripe.Subscription.list(%{customer: stripe_id}),
         :ok <- check_subs.(l_subs.data),
         {:ok, customer} <- Stripe.Customer.update(stripe_id, %{source: token.id}),
         sub_params = %{customer: customer.id, items: [%{plan: plan_id}]},
         do: Stripe.Subscription.create(sub_params)
  end

  @doc """
  Get the stripe customer object associated with this user.
  This object can be used in multiple functions here to determine user payment profile.

  @spec customer(Darth.Model.User)
  :: {:ok, Stripe.Customer.t()} | {:error, :no_stripe_id} | {:error, Stripe.Error.t()}
  """
  def customer(%User{stripe_id: stripe_id}) when is_nil(stripe_id), do: {:error, :no_stripe_id}
  def customer(%User{stripe_id: stripe_id}), do: Stripe.Customer.retrieve(stripe_id)

  @doc """
  Change the plan of an already subscribed stripe customer.

  @spec change_plan(%Stripe.Customer.t(), %Stripe.Plan.t{})
  :: {:ok, %Stripe.Plan.t{}} | {:error, Stripe.Error.t()}
  """
  def change_plan(%Stripe.Customer{subscriptions: subscriptions}, %Stripe.Plan{id: plan_id}) do
    sub = List.first(subscriptions.data)

    with {:ok, sub} <- Stripe.Subscription.update(sub.id, %{plan: plan_id}),
         do: {:ok, sub.plan}
  end

  @doc """
  Change the payment method of a stripe customer.
  Stripe will replace the old method with the new one.

  @spec change_payment_source(%Stripe.Customer.t(), %Stripe.Token.t())
  :: {:ok, %Stripe.Source.t()} | {:error, Stripe.Error.t()}
  """
  def change_payment_source(%Stripe.Customer{id: stripe_id}, %Stripe.Token{} = t) do
    with {:ok, cust} <- Stripe.Customer.update(stripe_id, %{source: t.id}),
         do: {:ok, payment_source(cust)}
  end

  @doc """
  Cancel subscription for stripe customer.
  This will delete payment info and cancel his plan.

  @spec cancel_subscription(%Stripe.Customer.t())
  :: {:ok, %Stripe.Subscription.t()} | {:error, Stripe.Error.t()}
  """
  def cancel_subscription(%Stripe.Customer{subscriptions: subs}) do
    sub = List.first(subs.data)
    Stripe.Subscription.delete(sub.id)
  end

  @doc """
  Determine the payment sources of a stripe customer.
  Use `customer(Darth.Model.User)` to retrieve the customer.

  @spec payment_source(Stripe.Customer.t()) :: [Stripe.Source.t()]
  """
  def payment_source(%Stripe.Customer{sources: sources}), do: List.first(sources.data)

  @doc """
  Determine the currently subscribed plan of a stripe customer.
  Use `customer(Darth.Model.User)` to retrieve the customer.

  @spec subscribed_plan(Stripe.Customer.t()) :: {Stripe.Plan.t()}
  """
  def subscribed_plan(%Stripe.Customer{subscriptions: subscriptions}) do
    sub = List.first(subscriptions.data)
    sub.plan
  end

  @doc """
  Returns up to 100 invoices of a stripe customer.

  @spec list_invoices(Stripe.Customer.t()) :: {:ok, [Stripe.Invoice.t()]} | {:error, Stripe.Error.t()}
  """
  def list_invoices(%Stripe.Customer{id: stripe_id}) do
    params = %{
      customer: stripe_id,
      limit: 100
    }

    with {:ok, invoices} <- Stripe.Invoice.list(params),
         do: {:ok, invoices.data}
  end

  #
  # INTERNAL FUNCTIONS
  #
end
