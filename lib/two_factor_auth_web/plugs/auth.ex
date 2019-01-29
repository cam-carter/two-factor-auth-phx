defmodule TwoFactorAuthWeb.Plugs.Auth do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Accounts.User

  def generate_one_time_pass(user = %User{has_2fa: true}) do
    token =
      :crypto.strong_rand_bytes(8)
      |> Base.encode32()

    one_time_pass = :pot.hotp(token, _number_of_trials = 1)

    {token, one_time_pass}
  end

  def assign_secret_to_session(conn, token, user_id) do
    updated_plug_session =
      conn.private[:plug_session]
      |> Map.put("user_secret", %{"token" => token, "user_id" => user_id})

    conn
    |> put_private(:plug_session, updated_plug_session)
  end

  def fetch_secret_from_session(conn) do
    %{"token" => token, "user_id" => user_id} =
      Kernel.get_in(conn.private, [:plug_session, "user_secret"])

    IO.inspect(token, label: "Token after fetch --------------->")
    {token, user_id}
  end

  def valid_one_time_pass?(one_time_pass, token) do
    case :pot.valid_hotp(one_time_pass, token, [{:last, 0}]) do
      1 -> true
      _ -> false
    end
  end

  def invalidate_one_time_pass(conn, user_id) do
    updated_plug_session =
      conn.private[:plug_session]
      |> Map.put("user_secret", %{"token" => nil, "user_id" => user_id})

    conn
    |> put_private(:plug_session, updated_plug_session)
  end
end
