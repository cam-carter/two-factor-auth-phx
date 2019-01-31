defmodule TwoFactorAuthWeb.Plugs.AuthTest do
  use TwoFactorAuthWeb.ConnCase
  use Bamboo.Test

  alias TwoFactorAuthWeb.Plugs.Auth

  setup do
    user = insert(:user, has_2fa: true)

    conn =
      build_conn()
      |> put_private(:plug_session, %{})

    {:ok, %{conn: conn, user: user}}
  end

  test "generating a valid one time password" do
    {token, one_time_pass} = Auth.generate_one_time_pass()
    assert Auth.valid_one_time_pass?(one_time_pass, token)
  end

  test "assigning and fetching the secret from the session", %{conn: conn, user: %{id: user_id}} do
    {token, one_time_pass} = Auth.generate_one_time_pass()
    assert Auth.valid_one_time_pass?(one_time_pass, token)

    updated_conn =
      conn
      |> Auth.assign_secret_to_session(token, user_id)

    assert {token, user_id} = Auth.fetch_secret_from_session(updated_conn)
  end

  test "invalidating the token", %{conn: conn, user: %{id: user_id}} do
    {token, one_time_pass} = Auth.generate_one_time_pass()
    assert Auth.valid_one_time_pass?(one_time_pass, token)

    updated_conn =
      conn
      |> Auth.assign_secret_to_session(token, user_id)

    assert {token, user_id} = Auth.fetch_secret_from_session(updated_conn)

    invalid_conn =
      updated_conn
      |> Auth.invalidate_secret()

    assert Auth.fetch_secret_from_session(invalid_conn) == nil
  end
end
