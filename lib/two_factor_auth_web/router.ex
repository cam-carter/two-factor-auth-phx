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

  scope "/", TwoFactorAuthWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/", SessionController, :new)
    get("/sessions/new", SessionController, :new)
    post("/sessions", SessionController, :create)

    get("/index", PageController, :index)
  end

  # Other scopes may use custom stacks.
  # scope "/api", TwoFactorAuthWeb do
  #   pipe_through :api
  # end
end
