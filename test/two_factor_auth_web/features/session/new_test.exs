defmodule TwoFactorAuthWeb.Session.NewTest do
  use TwoFactorAuth.FeatureCase

  alias TwoFactorAuth.IndexPage
  alias TwoFactorAuth.{NewSessionPage, TwoFactorAuthPage}

  hound_session()

  setup do
    # Our factory inserts this user into the database
    user = insert(:user, password: "password")

    {:ok, %{user: user}}
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
end
