defmodule TwoFactorAuthWeb.PageController do
  use TwoFactorAuthWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
