defmodule TwoFactorAuthWeb.NewSessionTest do
  use TwoFactorAuth.FeatureCase

  alias TwoFactorAuth.{IndexPage, NewSessionPage, TwoFactorAuthPage}

  hound_session()

  setup do
    # Our factory inserts this user into the database
    user = insert(:user, password: "password")
    user_with_2fa = insert(:user, has_2fa: true)

    {:ok, %{user: user, user_with_2fa: user_with_2fa}}
  end

  test "logging in with valid user credentials", %{user: user} do
    NewSessionPage.visit()
    NewSessionPage.enter_credentials(user.email, "password")
    NewSessionPage.submit()

    assert IndexPage.is_current_path?()
    assert IndexPage.has_text?("Login successful!")
  end

  test "attempting to log in with invalid user credentials", %{user: user} do
    NewSessionPage.visit()
    NewSessionPage.enter_credentials(user.email, "definitely not the right password")
    NewSessionPage.submit()

    refute IndexPage.is_current_path?()
    assert NewSessionPage.has_text?("Invalid email or password!")
  end

  test "user with two factor authentication is redirected", %{user_with_2fa: user} do
    NewSessionPage.visit()
    NewSessionPage.enter_credentials(user.email, "password")
    NewSessionPage.submit()

    assert TwoFactorAuthPage.is_current_path?()
    assert TwoFactorAuthPage.has_text?("An email was sent to you with a code to log in.")
  end

  test "user can resend two factor auth code", %{user_with_2fa: user} do
    NewSessionPage.visit()
    NewSessionPage.enter_credentials(user.email, "password")
    NewSessionPage.submit()

    assert TwoFactorAuthPage.is_current_path?()
    TwoFactorAuthPage.resend_email()
    assert TwoFactorAuthPage.has_text?("A new two-factor authentication was sent to your email!")
  end
end
