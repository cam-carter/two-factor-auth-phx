# TwoFactorAuth

`mix phx.new two_factor_auth`

deps:

```elixir
[
  {:bamboo, "~> 1.1"},
  {:comeonin, "~> 4.0"},
  {:ex_machina, "~>2.2"},
  {:guardian, "~> 1.1"},
  {:hound, "~> 1.0", only: :test}
  {:pot, "~> 0.9.6"}
]
```

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix

Two-factor authentication implies two layers of security, so we're going to walk hand-in-hand through both. The weird part starts at the second layer, so if you want to skip ahead feel free. But, if you're interested in seeing my way of basic user authentication, then you can come along for the ride.

We'll start with some tests that will help us map out the design of our login workflow. For feature (or integration testing, call it what you want) we'll need [Hound](), a pretty handy testing framework that uses chromedriver to uh... drive chrome through your app. We'll also be using [ExMachina]() for test factories.

Add this stuff to you `mix.exs` file under:
```elixir
defp deps do
  [
    {:ex_machina, "~> 2.2", only: test},
    {:hound, "~> 1.0", only: test}
  ]
end
```

Before we being writing feature tests using both Hound and ExMachina we have to create our own test case. We will call it `feature_case.ex`. The contents of this module will include the modules we need for testing and it will allout us to actually talk to our database in the event of tests running faster than those queries. If we don't include this, a particular test may fail but there may be a process that still exists trying to access the database.

```elixir
defmodule TwoFactorAuth.FeatureCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import TwoFactorAuth.Factory
      use Hound.Helpers
      use TwoFactorAuth.Page
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TwoFactorAuth.Repo)

    Ecto.Adapaters.SQL.Sandbox.mode(TwoFactorAuth.Repo, {:shared, self()})

    Hound.start_session(
      additional_capabilities: %{
        chromeOptions: %{
          "args" => ["--window-size=1920, 1080"] |> put_headless(tags) |> put_user_agent(tags)
        }
      }
    )

    {:ok, %{}}
  end

  defp put_headless(args, %{headless: false}), do: args
  defp put_headless(args, _), do: args ++ ["--headless", "--disable-gpu"]

  defp put_user_agent(args, %{async: false}), do: args

  defp put_user_agent(args, _) do
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(TwoFactorAuth.Repo, self())
    user_agent = Hound.Browser.user_agent(:chrome) |> Hound.Metadata.append(metadata)
    ["--user-agent=#{user_agent}" | args]
  end
end
```

Okay! We're ready to run our test.

```
mix test --trace  test/two_factor_auth_web/features/session/new_test.exs
Compiling 1 file (.ex)

== Compilation error in file test/support/factory.ex ==
** (CompileError) test/support/factory.ex:10: TwoFactorAuth.Accounts.User.__struct__/1 is undefined, cannot expand struct TwoFactorAuth.Accounts.User
    (elixir) expanding macro: Kernel.|>/2
        test/support/factory.ex:14: TwoFactorAuth.Factory.user_factory/0
```

Oh right. We actually need a User struct in order for our factory to insert it in the database. Which means we also need a `:users` table in our database. Our User schema module is going to live in our Accounts context. For the sake of simplicity we'll use the Phoenix generator for a new context.

```
mix phx.gen.context Accounts User users email:string password_hash:string
```

And like magic you have an Accounts context, a User module, and even a handy-dandy Ecto migration. However, we're going to want to make a few changes before we put a nail in this user's coffin. We'll first change up the user's changeset to downcase (or upcase) their email address, so we don't get into any trouble when we try and validate their session. Also we're gonna wanna hash their password for _security reasons_. For the latter we're gonna throw another depency onto the pil.

```elixir
defp deps do
	[
		{:comeonin, "~> 4.0"},
    {:bcrypt_elixir, "~> 1.1.1"}
	]
end
```

And here are the changes to the generated User schema module:

```elixir
defmodule TwoFactorAuth.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:password_hash, :string)
    field(:password, :string, virtual: true)

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> downcase_email()
    |> unique_constraint(:email)
    |> put_pass_hash()
  end

  defp downcase_email(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    changeset
    |> change(%{email: String.downcase(email)})
  end

  defp downcase_email(changeset), do: changeset

  defp put_pass_hash(%Ecto.Changeset{valid?: true, changes: %{password: passowrd}} = changeset) do
    changeset
    |> change(Comeonin.Bcrypt.add_hash(password))
  end

  defp put_pass_hash(changeset), do: changeset
end
```

Aaannd the changes to the migration:

```elixir
defmodule TwoFactorAuth.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:email, :string)
      add(:password_hash, :string)

      timestamps()
    end

    create(unique_index(:users, [:email]))
  end
end
```

Now that we've migrated that stuff let's run that test again. Alas, we need our page helper functions to run this test.
