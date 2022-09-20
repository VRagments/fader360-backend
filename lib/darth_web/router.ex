defmodule DarthWeb.Router do
  use DarthWeb, :router
  import DarthWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {DarthWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_query_params
  end

  pipeline :api_auth do
    plug :api
    plug :ensure_user_login
  end

  scope "/", DarthWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # API routes

  scope "/api/auth", DarthWeb do
    pipe_through [:api]
    get "/login", ApiAuthController, :login
  end

  scope "/api/auth", DarthWeb do
    pipe_through [:api_auth]
    post "/logout", ApiAuthController, :logout
    post "/refresh", ApiAuthController, :refresh
  end

  if Application.compile_env(:darth, :env, :dev) in ~w(dev)a do
    forward "/swagger", PhoenixSwagger.Plug.SwaggerUI, otp_app: :darth, swagger_file: "swagger.json"
  end

  ## Authentication routes

  scope "/", DarthWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/login", UserSessionController, :new
    post "/users/logn", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", DarthWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", DarthWeb do
    pipe_through [:browser]

    delete "/users/logout", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end

  def swagger_info do
    %{
      openapi: "2.0",
      info: %{
        version: "1.0",
        title: "Darth Fader"
      },
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header"
        }
      }
    }
  end
end
