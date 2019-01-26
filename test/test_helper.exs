Application.ensure_all_started(:hound)
Application.ensure_all_started(:ex_machina)
ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(TwoFactorAuth.Repo, :manual)
