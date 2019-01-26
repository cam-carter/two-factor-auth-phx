defmodule TwoFactorAuthWeb.SessionController do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Guardian
  alias TwoFactorAuth.Accounts

  def new(conn, _) do
    render(conn, "new.html")
  end

  def create(conn, session_params) do
    case Accounts.verify_login(session_params) do
      {:ok, user} ->
        conn
        |> Guardian.Plug.sign_in(user)
        |> put_flash(:info, "Login successful!")
        |> put_status(302)
        |> redirect(to: page_path(conn, :index))

      {:error, _} ->
        conn
        |> put_flash(:error, "Invalid email or password!")
        |> put_status(401)
        |> render("new.html")
    end
  end
end
