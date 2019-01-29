defmodule TwoFactorAuthWeb.TwoFactorAuthController do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Guardian
  alias TwoFactorAuth.Accounts
  alias TwoFactorAuthWeb.Plugs.Auth

  def new(conn, _) do
    # we want to see if our token is nil, and if it is we redirect them back to the new session page
    # the goal here is to have one continuous session through the flow of 2fa
    with {token, _user_id} when not is_nil(token) <- Auth.fetch_secret_from_session(conn) do
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
    {token, user_id} = Auth.fetch_secret_from_session(conn)
    user = Accounts.get_user!(user_id)

    case Auth.valid_one_time_pass?(one_time_pass, token) do
      true ->
        conn
        |> Auth.invalidate_token(user_id)
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
end
