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
    {:guardian, "~> 1.1"},
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

```elixir
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

I know you're probably dieing to see those abstracted functions that generate the one time password and assign the token to the session, but you'll have to wait. First we need to checkout the two-factor auth controller, and then I'll show off the goods.

```elixir
defmodule TwoFactorAuthWeb.TwoFactorAuthController do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Guardian
  alias TwoFactorAuth.Accounts
  alias TwoFactorAuthWeb.Plugs.Auth

  def new(conn, _) do
    # we want to see if our token is empty, and if it is we redirect them back to the new session page
    # the goal here is to have one continuous session through the flow of 2fa
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
    # to verify the one_time_pass that comes in through the form we need the secret token off the conn
    # we also need the user_id to know who we're building the session for
    {token, user_id} = Auth.fetch_secret_from_session(conn)
    user = Accounts.get_user!(user_id)

    case Auth.valid_one_time_pass?(one_time_pass, token) do
      true ->
        conn
        # our one time password can only be used once, duh
        # but we wanna go that extra mile and also invalidate our token
        # just in case?
        |> Auth.invalidate_secret(user_id)
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

## The legend of Plug.Conn

Now let's take a look at `auth.ex`. This is our plug module that holds all that fancy `hotp` functionality we saw earlier. There's a couple challenges when it comes to dealing with the second factor of our authentication workflow. We need to be able to assure that there is one continuous session throughout the entire process, meaning that we can't take any requests from a user that hasn't first logged in with their username and password. We also need to be sure no sensitive data, i.e. our secret token, is being leaked to the user. That's where the function `put_private` comes in, but even nice things come with stipulations.

`put_private` is a function that comes from `Plug.Conn`. To quote the doumentation:

```
Assigns a new private key and value in the connection.

This storage is meant to be used by libraries and frameworks to avoid writing to the user storage (the :assigns field). It is recommended for libraries/frameworks to prefix the keys with the library name.
```

So inside of our `conn` lives a special `:private` map that keeps our deep, dark secrets about the session from the user instead of leaking this information through `conn[:assigns]`. The key takeaway here is that the storage "is meant to be used by libraries and frameworks". Let's take a look at how this might work with the secret sauce of our one time password validation.

```elixir
def assign_secret_to_session(conn, token, user_id) do
  conn
  |> put_private(:user_secret, %{token: token, user_id: user_id})
end
```

The functionality of `put_private` looks just like `Map.put`. We take a map, then a key, and then a value to put under that key. Now lets get that secret out of our conn, so we can put those values to good use.

```elixir
def fetch_secret_from_session(conn) do
  %{token: token, user_id: user_id} = conn.private[:user_id]

  {token, user_id}
end
```

You'd expect this to work, right? Well think think again! We just got a nasty `MatchError`. When we try to fetch that secret after our `conn` is redirected from our session create to the two factor auth new path, that `:user_secret` key is gone. Now if I'm being honest with you, I really don't have a clue why this is happening. But, if we go back and look at the documentation, we can read into a little more:

```
This storage is meant to be used by libraries and frameworks to avoid writing to the user storage (the :assigns field). It is recommended for libraries/frameworks to prefix the keys with the library name.
```

So is our `:user_secret` being dropped because it's not a library? Let's take a look at conn[:private] and try something different.

```elixir
%Plud.Conn{
  private: %{
    TwoFactorAuthWeb.Router => {[],
    :phoenix_action => :new,
    :phoenix_controller => TwoFactorAuthWeb.TwoFactorAuthController,
    :phoenix_endpoint => TwoFactorAuthWeb.Endpoint,
    :phoenix_flash => %{
      "info" => "A two-factor authentication code has been sent to your email!"
    },
    :phoenix_format => "html",
    :phoenix_layout => {TwoFactorAuthWeb.LayoutView, :app},
    :phoenix_pipelines => [:browser],
    :phoenix_router => TwoFactorAuthWeb.Router,
    :phoenix_view => TwoFactorAuthWeb.TwoFactorAuthView,
    :plug_session => %{
      "_csrf_token" => "MXbH2CPKOEs5iMltrA38ZQ==",
      "guardian_default_token" => "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJ0d29fZmFjdG9yX2F1dGgiLCJleHAiOjE1NTExMzE1NDMsImlhdCI6MTU0ODcxMjM0MywiaXNzIjoidHdvX2ZhY3Rvcl9hdXRoIiwianRpIjoiYmMyMzUyZDktODk1Yi00N2ZiLTkzMWItNWNlY2I2OTcwMjMzIiwibmJmIjoxNTQ4NzEyMzQyLCJzdWIiOiIxIiwidHlwIjoiYWNjZXNzIn0.5rFnDhFhB28LxksKqt_sc0ZfgYv-QbuTX5PLFKJkgi7J4NzxKt5N-PphQT2Z39uMWbp3V2p22Fz1Yz3pqisfWw",
      "phoenix_flash" => %{
        "info" => "A two-factor authentication code has been sent to your email!"
      }
  }
}
```

Notice these keys, besides our router, are all dependencies for our Phoenix application. So let's try this again but nest our `:user_secret` map inside of an applicable place in `:private`.

```elixir
defmodule TwoFactorAuthWeb.Plugs.Auth do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Accounts.User

  def generate_one_time_pass() do
    token =
      :crypto.strong_rand_bytes(8)
      |> Base.encode32()

    one_time_pass = :pot.hotp(token, _number_of_trials = 1)

    {token, one_time_pass}
  end

  def assign_secret_to_session(conn, token, user_id) do
    updated_plug_session =
      conn.private[:plug_session]
      |> Map.put("user_secret", %{"token" => token, "user_id" => user_id})

    conn
    |> put_private(:plug_session, updated_plug_session)
  end

  def fetch_secret_from_session(conn) do
    %{"token" => token, "user_id" => user_id} =
      conn.private[:plug_session]
      |> Map.get("user_id")

    {token, user_id}
  end

  def valid_one_time_pass?(one_time_pass, token) do
    case :pot.valid_hotp(one_time_pass, token, [{:last, 0}]) do
      1 -> true
      _ -> false
    end
  end

  def invalidate_token(conn, user_id) do
    updated_plug_session =
      conn.private[:plug_session]
      |> Map.drop("user_secret")

    conn
    |> put_private(:plug_session, updated_plug_session)
  end
end
```

So if we latch our `:user_secret` onto `:plug_session`, the `conn` keeps state after the redirect.

```
private: %{
    TwoFactorAuthWeb.Router => {[],
    :phoenix_action => :new,
    :phoenix_controller => TwoFactorAuthWeb.TwoFactorAuthController,
    :phoenix_endpoint => TwoFactorAuthWeb.Endpoint,
    :phoenix_flash => %{
      "info" => "A two-factor authentication code has been sent to your email!"
    },
    :phoenix_format => "html",
    :phoenix_layout => {TwoFactorAuthWeb.LayoutView, :app},
    :phoenix_pipelines => [:browser],
    :phoenix_router => TwoFactorAuthWeb.Router,
    :phoenix_view => TwoFactorAuthWeb.TwoFactorAuthView,
    :plug_session => %{
      "_csrf_token" => "MXbH2CPKOEs5iMltrA38ZQ==",
      "guardian_default_token" => "eyJhbGciOiJIUzUxMiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJ0d29fZmFjdG9yX2F1dGgiLCJleHAiOjE1NTExMzE1NDMsImlhdCI6MTU0ODcxMjM0MywiaXNzIjoidHdvX2ZhY3Rvcl9hdXRoIiwianRpIjoiYmMyMzUyZDktODk1Yi00N2ZiLTkzMWItNWNlY2I2OTcwMjMzIiwibmJmIjoxNTQ4NzEyMzQyLCJzdWIiOiIxIiwidHlwIjoiYWNjZXNzIn0.5rFnDhFhB28LxksKqt_sc0ZfgYv-QbuTX5PLFKJkgi7J4NzxKt5N-PphQT2Z39uMWbp3V2p22Fz1Yz3pqisfWw",
      "phoenix_flash" => %{
        "info" => "A two-factor authentication code has been sent to your email!"
      },
      "user_secret" => %{"token" => "TBPUPSS55IC7C===", "user_id" => 1} # <- ding! ding! ding!
    },
    :plug_session_fetch => :done
  }
```

And finally, after some weirdness, we have our secret token that we need to validate the user's one time password!
