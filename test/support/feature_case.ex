defmodule TwoFactorAuth.FeatureCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import TwoFactorAuth.Factory
      use Hound.Helpers
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TwoFactorAuth.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(TwoFactorAuth.Repo, {:shared, self()})
    end

    {:ok, %{}}
  end
end
