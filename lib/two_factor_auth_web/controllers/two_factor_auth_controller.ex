defmodule TwoFactorAuthWeb.TwoFactorAuthController do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Guardian
  alias TwoFactorAuth.Accounts
  alias TwoFactorAuthWeb.Mailer

  def new(conn, _) do
    # we want to see if our token is nil, and if it is we redirect them back to the new session page
    # the goal here is to have one continuous session through the flow of 2fa
    # %{"token" => token, "user_id" => user_id}

    with %{"token" => token, "user_id" => user_id} <- get_session(conn, "user_secret") do
      conn
      |> render("two_factor_auth.html", action: two_factor_auth_path(conn, :create))
    else
      _ ->
        conn
        |> put_flash(:error, "Page not found")
        |> put_status(404)
        |> redirect(to: session_path(conn, :new))
    end
  end

  def create(conn, %{"one_time_pass" => one_time_pass}) do
    # to verify the one_time_pass we need the token off of the conn, which lives in the :private map
    # we also need the user_id to know who we're building the session for
    %{"token" => token, "user_id" => user_id} = get_session(conn, "user_secret")
    user = Accounts.get_user!(user_id)

    case Accounts.valid_one_time_pass?(one_time_pass, token) do
      true ->
        conn
        |> delete_session("user_secret")
        |> Guardian.Plug.sign_in(user)
        |> put_flash(:info, "Login successful!")
        |> put_status(302)
        |> redirect(to: page_path(conn, :index))

      false ->
        conn
        |> put_flash(:error, "The authentication code you entered was invalid!")
        |> put_status(401)
        |> render("two_factor_auth.html", action: two_factor_auth_path(conn, :create))
    end
  end

  def resend_email(conn, _) do
    %{"user_id" => user_id} = get_session(conn, "user_secret")
    user = Accounts.get_user!(user_id)

    {new_token, one_time_pass} = Accounts.generate_one_time_pass()
    Mailer.deliver_2fa_email(user, one_time_pass)

    conn
    |> put_session("user_secret", %{"token" => new_token, "user_id" => user_id})
    |> put_flash(:info, "A new two-factor authentication code was sent to your email!")
    |> put_status(200)
    |> render("two_factor_auth.html", action: two_factor_auth_path(conn, :create))
  end
end
