defmodule TwoFactorAuthWeb.Router do
  use TwoFactorAuthWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :authenticated do
    plug(TwoFactorAuth.Guardian.AuthPipeline)
  end

  scope "/", TwoFactorAuthWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/sessions/new", SessionController, :new)
    get("/", SessionController, :new)
    post("/sessions", SessionController, :create)
    get("/sessions/new/two_factor_auth", TwoFactorAuthController, :new)
    post("/sessions/new/two_factor_auth", TwoFactorAuthController, :create)
    post("/sessions/new/two_factor_auth/resend_email", TwoFactorAuthController, :resend_email)

    pipe_through(:authenticated)

    get("/index", PageController, :index)
  end

  if Mix.env() == :dev do
    forward("/sent_emails", Bamboo.SentEmailViewerPlug)
  end

  # Other scopes may use custom stacks.
  # scope "/api", TwoFactorAuthWeb do
  #   pipe_through :api
  # end
end
