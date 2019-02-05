defmodule TwoFactorAuthWeb.SessionController do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Guardian
  alias TwoFactorAuth.Accounts
  alias TwoFactorAuthWeb.Mailer

  def new(conn, _) do
    render(conn, "new.html")
  end

  def create(conn, session_params) do
    with {:ok, user} <- Accounts.verify_login(session_params) do
      case user.has_2fa do
        true ->
          {token, one_time_pass} = Accounts.generate_one_time_pass()
          Mailer.deliver_2fa_email(user, one_time_pass)

          conn
          |> put_session("user_secret", %{"token" => token, "user_id" => user.id})
          |> put_flash(:info, "A two-factor authentication code has been sent to your email!")
          |> put_status(302)
          |> redirect(to: two_factor_auth_path(conn, :new))

        false ->
          conn
          |> Guardian.Plug.sign_in(user)
          |> put_flash(:info, "Login successful!")
          |> put_status(302)
          |> redirect(to: page_path(conn, :index))
      end
    else
      {:error, msg} ->
        conn
        |> put_flash(:error, msg)
        |> put_status(401)
        |> render("new.html")
    end
  end
end
