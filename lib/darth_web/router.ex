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

  scope "/api", DarthWeb do
    pipe_through [:api_auth]

    resources "/projects", ApiProjectController, only: [:index, :show, :create, :update, :delete] do
      resources "/assets", ApiProjectAssetController, only: [:index, :show, :create]
    end

    resources("/assets", ApiAssetController, only: [:index, :show, :create, :update, :delete]) do
      put("/license", ApiAssetController, :change_license)
      put("/users", ApiAssetController, :assign_user)
      delete("/users", ApiAssetController, :remove_user)
      put("/projects", ApiAssetController, :assign_project)
      delete("/projects", ApiAssetController, :remove_project)
    end
  end

  scope "/api/public", DarthWeb do
    pipe_through([:api])

    resources "/projects", ApiPublicProjectController, only: [:index, :show] do
      get("/recommendations", ApiPublicProjectController, :recommendations)
      resources("/assets", ApiPublicProjectAssetController, only: [:index, :show])
    end

    resources("/assets", ApiPublicAssetController, only: [:index, :show])
  end

  scope "/api/public/optimized", DarthWeb do
    pipe_through([:api])
    resources("/assets", ApiPublicOptimizedProjectAssetsController, only: [:index])
  end

  scope "/api/oembed", DarthWeb do
    pipe_through([:api])
    get("/", ApiOembedController, :show)
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
    post "/users/login", UserSessionController, :create
    get "/users/reset-password", UserResetPasswordController, :new
    post "/users/reset-password", UserResetPasswordController, :create
    get "/users/reset-password/:token", UserResetPasswordController, :edit
    put "/users/reset-password/:token", UserResetPasswordController, :update
  end

  scope "/", DarthWeb do
    pipe_through [:browser, :require_authenticated_user]
    live "/", LivePage.Page
    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
    live "/users/assets", LiveAsset.Index
    live "/users/assets/:asset_lease_id", LiveAsset.Detail
    live "/users/projects", LiveProject.Index
    live "/users/projects/:project_id", LiveProject.Detail
  end

  scope "/", DarthWeb do
    pipe_through [:browser, :redirect_if_user_is_mv_authenticated]
    get "/users/mv-login", UserSessionController, :mv_login
    post "/users/mv-login", UserSessionController, :mv_login_post
  end

  scope "/", DarthWeb do
    pipe_through [:browser, :required_mv_authenticated_user]
    live "/users/mv-assets", LiveMvAsset.Index
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
          name: "authorization",
          in: "header"
        }
      }
    }
  end
end
