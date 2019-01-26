defmodule TwoFactorAuth.TwoFactorAuthPage do
  use Hound.Helpers

  @page_path "/sessions/new/two_factor_auth"

  def is_current_path? do
    current_path() == @page_path
  end

  def has_text?(text) do
    String.contains?(page_source(), text)
  end

  def enter_credentials(one_time_pass) do
    fill_field({:css, "qa-2fa-one_time_pass"}, one_time_pass)
  end

  def submit do
    click({:css, ".qa-2fa-submit"})
  end
end
