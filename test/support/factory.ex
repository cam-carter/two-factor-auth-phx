defmodule TwoFactorAuth.Factory do
  use ExMachina.Ecto, repo: TwoFactorAuth.Repo

  defp set_password(user) do
    hashed_password = Comeonin.Bcrypt.hashpwsalt(user.password)

    user
    |> Map.merge(%{password_hash: hashed_password, password: nil})
  end

  def user_factory() do
    %TwoFactorAuth.Accounts.User{
      email: sequence(:email, &"user-#{&1}@example.com"),
      password: "password"
    }
    |> set_password
  end
end
