defmodule TwoFactorAuth.IndexPage do
  use Hound.Helpers

  @page_path "/index"

  def is_current_path? do
    current_path() == @page_path
  end

  def has_text?(text) do
    String.contains?(page_source(), text)
  end
end
