defmodule TwoFactorAuth.Email do
  import Bamboo.Email
  use Bamboo.Phoenix, view: TwoFactorAuthWeb.EmailView

  def two_factor_auth(user, one_time_pass) do
    new_email
    |> from("two_factor_auth@email.com")
    |> to(user.email)
    |> put_html_layout({TwoFactorAuthWeb.LayoutView, "email.html"})
    |> subject("Two-factor authentication")
    |> render(
      "two_factor_auth.html",
      user: user,
      one_time_pass: one_time_pass
    )
  end
end
