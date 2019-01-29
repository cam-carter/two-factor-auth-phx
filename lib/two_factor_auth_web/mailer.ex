defmodule TwoFactorAuthWeb.Mailer do
  use Bamboo.Mailer, otp_app: :two_factor_auth

  alias TwoFactorAuth.Email
  alias TwoFactorAuth.Accounts.User

  def deliver_2fa_email(user = %User{has_2fa: true}, one_time_pass) do
    Email.two_factor_auth(user, one_time_pass)
    |> deliver_later()
  end
end
