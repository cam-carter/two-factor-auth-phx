defmodule TwoFactorAuthWeb.TwoFactorAuthControllerTest do
  use TwoFactorAuthWeb.ConnCase

  alias TwoFactorAuthWeb.Plugs.Auth

  setup do
    user = insert(:user, %{password: "password", has_2fa: true})
    {token, one_time_pass} = Auth.generate_one_time_pass()

    plug_session = Map.put(%{}, "user_secret", %{"token" => token, "user_id" => user.id})

    conn =
      build_conn()
      |> put_private(:plug_session, plug_session)

    {:ok, %{conn: conn, one_time_pass: one_time_pass, user: user}}
  end

  test "visiting the two factor auth page", %{conn: conn} do
    response = get(conn, "/sessions/new/two_factor_auth")
    assert html_response(response, 200) =~ "/sessions/new/two_factor_auth"
  end

  test "visiting the two factor auth page with no token", %{conn: conn} do
    response =
      conn
      |> Auth.invalidate_secret()
      |> get("/sessions/new/two_factor_auth")

    assert html_response(response, 404) =~ "/sessions/new"
  end

  test "submitting a session with a valid one time password", %{
    conn: conn,
    one_time_pass: one_time_pass
  } do
    response = post(conn, "/sessions/new/two_factor_auth", %{one_time_pass: one_time_pass})
    assert html_response(response, 302) =~ "/index"
  end

  test "submitting a session with an invalid one time password", %{conn: conn} do
    response =
      post(conn, "/sessions/new/two_factor_auth", %{one_time_pass: "not the one_time_pass"})

    assert html_response(response, 401) =~ "/sessions/new/two_factor_auth"
  end
end
