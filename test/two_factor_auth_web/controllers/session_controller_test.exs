defmodule TwoFactorAuthWeb.SessionControllerTest do
  use TwoFactorAuthWeb.ConnCase

  setup do
    user = insert(:user, %{password: "password"})
    user_with_2fa = insert(:user, %{password: "password", has_2fa: true})

    {:ok, %{user: user, user_with_2fa: user_with_2fa, conn: build_conn()}}
  end

  test "visiting login page", %{conn: conn} do
    response = get(conn, "/sessions/new")

    assert html_response(response, 200) =~ "Email"
  end

  test "logging in with valid credentials", %{conn: conn, user: user} do
    response = post(conn, "/sessions", %{email: user.email, password: "password"})

    assert html_response(response, 302) =~ "/index"
  end

  test "logging in with invalid credentials", %{conn: conn, user: user} do
    response = post(conn, "/sessions", %{email: user.email, password: "not the right password"})

    assert html_response(response, 401) =~ "Invalid email or password!"
  end

  test "logging in with 2fa enabled rediects to two factor auth form", %{
    conn: conn,
    user_with_2fa: user_with_2fa
  } do
    response = post(conn, "/sessions", %{email: user_with_2fa.email, password: "password"})

    assert html_response(response, 302) =~ "/sessions/new/two_factor_auth"
  end
end
