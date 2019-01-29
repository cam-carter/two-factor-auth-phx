defmodule TwoFactorAuthWeb.SessionController do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Guardian
  alias TwoFactorAuth.Accounts
  alias TwoFactorAuthWeb.Mailer
  alias TwoFactorAuthWeb.Plugs.Auth

  def new(conn, _) do
    render(conn, "new.html")
  end

  def create(conn, session_params) do
    with {:ok, user} <- Accounts.verify_login(session_params) do
      case user.has_2fa do
        true ->
          {token, one_time_pass} = Auth.generate_one_time_pass(user)
          Mailer.deliver_2fa_email(user, one_time_pass)

          conn
          |> Auth.assign_secret_to_session(token, user.id)
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

    # case Accounts.verify_login(session_params) do
    #   {:ok, user} ->
    #     conn
    #     |> Guardian.Plug.sign_in(user)
    #     |> put_flash(:info, "Login successful!")
    #     |> put_status(302)
    #     |> redirect(to: page_path(conn, :index))

    #   {:error, _} ->
    #     conn
    #     |> put_flash(:error, "Invalid email or password!")
    #     |> put_status(401)
    #     |> render("new.html")
    # end
  end
end
