# Two-Factor Authentication in Elixir and Phoenix

Multi-factor authentication relies on the user having two or more pieces of evidence (or factors) in order to gain access into a system. In this example we will implement a two-factor authentication system that requires the user to present two forms of evidence: what the user and only that user knows, their password, and a one time password sent to what only the user has access to, their email.

### A Disclaimer

Now I'm just going to assume that if you're reading this you've already got the first factor of two-factor authentication figured out on your own. If that's not the case you can take a dive into the source code of the [example application](https://github.com/cam-carter/two-factor-auth-phx) that already implements basic user authentication with [Guardian] and [comeonin].

Also I'm doing some pretty wacky stuff with this code, so if you figure out a better way of doing this (there's always a better way), then please feel free to email me your suggestions, insults, or compliments.

### Oh and app dependencies

Here's the list of dependencies I'm using. You can just throw this in your `mix.exs` file.

```elixir
defp deps do
  [
    {:bamboo, "~> 1.0"},
    {:ex_machina, "~> 2.2", only: test},
    {:hound, "~> 1.0", only: test},
    {:pot, "~> 0.9.6"}
  ]
end
```

## HMAC one time password generation

To generate this one time password, we will be using an Erlang library called [pot]. The function we'll use will generate an HOTP, a one time password based on HMAC (hash-based message authentication code).

```elixir
# the secret token we'll need to generate the hotp
# this will need to stay hidden from the user
token =
  :crypto.strong_rand_bytes
  |> Base.encode32()

# the one_time_pass we'll send to our user's email
one_time_pass = :pot.hotp(token, _number_of_trials = 1)
```

This code is going to come in handy later, so we'll want to hold on to it. We're creating a token with the `:crypto` application which provides an API to cryptographic functions in Erlang. The we're using that token to generate a one time password that can only be used -- well -- once.

## Add a flag to the User? Add a flag to the User.

To get things poppin' off we're gonna wanna add a boolean flag to our `User` schema module and `:users` tabel. We can do that by generating a new Ecto migration.

```
mix ecto.gen.migration add_has_2fa_to_users
```

Then we'll add the stuff to the other stuff...

```elixir
### whatevertimestamp_add_has_2fa_to_users.exs ###

def change do
  alter table(:users) do
    add(:has_2fa, :boolean, default: true)
  end
end


### user.ex ###

schema "users" do
  field(:email, :string)
  field(:has_2fa, :boolean, default: false) # <- the new stuff
  field(:password_hash, :string)
  field(:password, :string, virtual: true)
end
```

The we'll run our new, fancy migration.

```
mix ecto.migrate
```

And to great success we now have `:has_2fa` attached to our users! This flag is going to tell us which users to send a one time password to and which ones to just let slide through with only one piece of authentic evidence. (Note: two factor authentication won't protect anything if your password for both the system and your email are just `password`)

## We're gonna need a new some new routes

We need a place to go to render our form for 2fa and when we're there we need a way to send our code to the controller for examination and verification.

```
get("/sessions/new/two_factor_auth", TwoFactorAuthController, :new)
post("/sessions/new/two_factor_auth", TwoFactorAuthController, :create)
```

## And now the all-powerfull controllers

Before we can get to the meat and potatoes of two-factor authentication, we need to take a gander at our session controller and using that shiny, new boolean on our users, make sure we're sending people to their appropriate destinations.

```elixir
defmodule TwoFactorAuthWeb.SessionController do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Guardian
  alias TwoFactorAuth.Accounts
  alias TwoFactorAuthWeb.Mailer
  alias TwoFactorAuthWeb.Plugs.Auth

  def new(conn, _), do: render(conn, "new.html")

  def create(conn, session_params) do
    # You could use a nested case here, but withs are cool, too
    with {:ok, user} <- Accounts.verify_login(session_params) do
      case user.has_2fa do
        true ->
          # remember that code at the beginning... this is where it went
          {token, one_time_pass} = Auth.generate_one_time_pass(user)
          Mailer.deliver_2fa_email(user, one_time_pass)

          conn
          |> Auth.assign_secret_to_session(token, user.id) # the weirdest part about all this
          |> put_flash(:info, "A heckin' 2fa code has been send to you! Isn't that cool?")
          |> put_status(302)
          |> redirect(to: two_factor_auth_path(conn, :new))

        false ->
          conn
          |> Guardian.Plug.sign_in(user)
          |> put_flash(:info, "Login successful!")
          |> put_status(302)
          |> redirect(to: page_path(conn, :index))
      end
    else
      {:error, msg} ->
        conn
        |> put_flash(:error, msg)
        |> put_status(401)
        |> render("new.html")
  end
end
```

I know you probably dieing to see those abstracted functions that generate the one time password and assign the token to the session, but you'll have to wait. Firstly we need to checkout the two-factor auth controller, and then I'll show off the goods.

```elixir
defmodule TwoFactorAuthWeb.TwoFactorAuthController do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Guardian
  alias TwoFactorAuth.Accounts
  alias TwoFactorAuthWeb.Plugs.Auth

  def new(conn, _) do
    with {token, _user_id} when not is_nil(token) <- Auth.fetch_secret_from_session(conn) do
      conn
      |> render("two_factor_auth.html", action: two_factor_auth_path(conn, :create))
    else
    _ ->
      conn
      |> put_flash(:error, "Page not found")
      |> put_status(404)
      |> redirect(to: session_path(conn, :new))
    end
  end

  def create(conn, %{"one_time_pass" => one_time_pass}) do
    {token, user_id} = Auth.fetch_secret_from_session(conn)
    user = Accounts.get_user!(user_id)

    case Auth.valid_one_time_pass?(one_time_pass, token) do
      true ->
        conn
        |> Auth.invalidate_one_time_pass(user_id)
        |> Guardian.Plug.sign_in(user)
        |> put_flash(:info, "Login successful!")
        |> put_status(302)
        |> redirect(to: page_path(conn, :index))

      false ->
        conn
        |> put_flash(:error, "The authentication code you entered was invalid!")
        |> put_status(401)
        |> render("two_factor_auth.html", action: two_factor_auth_path(conn, :create))
    end
  end
end
```
