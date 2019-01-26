defmodule TwoFactorAuth.NewSessionPage do
  use Hound.Helpers

  @page_path "/sessions/new"

  def visit do
    navigate_to(@page_path)
  end

  def is_current_path? do
    current_path() == @page_path
  end

  def has_text?(text) do
    String.contains?(page_source(), text)
  end

  def enter_credentials(email, password) do
    fill_field({:css, ".qa-session-email"}, email)
    fill_field({:css, ".qa-session-password"}, password)
  end

  def submit do
    click({:css, ".qa-session-submit"})
  end
end
