defmodule TwoFactorAuthWeb.SessionControllerTest do
  use TwoFactorAuthWeb.ConnCase

  setup do
    user = insert(:user, %{password: "password"})

    {:ok, %{user: user, conn: build_conn()}}
  end

  test "visiting login page", %{conn: conn} do
    response = get(conn, "/sessions/new")

    assert html_response(response, 200) =~ "Email"
  end

  test "logging in with valid credentials", %{conn: conn, user: user} do
    response = post(conn, "/sessions", %{email: user.email, password: "password"})

    assert html_response(response, 302) =~ "Login successful!"
  end

  test "logging in with invalid credentials", %{conn: conn, user: user} do
    response = post(conn, "/sessions", %{email: user.email, password: "not the right password"})

    assert html_response(response, 401) =~ "Invalid email or password!"
  end
end
