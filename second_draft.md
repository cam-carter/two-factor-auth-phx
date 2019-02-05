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

This code is going to come in handy later, so we'll want to hold on to it. We're creating a token with the `:crypto` application which provides an API to cryptographic functions in Erlang. Then we're using that token to generate a one time password that can only be used... You, guessed it: once.

## Add a flag to the User? Add a flag to the User.

To get things poppin' off we're going to want to add a boolean flag to our `User` schema module and `:users` tabel. We can do that by generating a new Ecto migration.

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

Then we'll run our new, fancy migration.

```
mix ecto.migrate
```

And to great success we now have `:has_2fa` attached to our users! This flag is going to tell us which users to send a one time password to and which ones to just let slide through with only one piece of authentic evidence. (Note: two factor authentication won't protect anything if your password for both the system and your email are just `password`)

## We're gonna need some new routes

We need a place to go to render our form for 2fa and when we're there we need a way for our user to send their one time password to the controller for examination and verification.

```elixir
### lib/two_factor_auth_web/router.ex ###

get("/sessions/new/two_factor_auth", TwoFactorAuthController, :new)
post("/sessions/new/two_factor_auth", TwoFactorAuthController, :create)
```

And the corresponding form:

```elixir
### lib/two_factor_auth_web/templates/two_factor_auth/two_factor_auth.html.eex ###

<%= form_for @conn, two_factor_auth_path(@conn, :create), fn f -> %>
  <label>
    Code: <%= text_input f, :one_time_pass, class: "qa-one_time_pass" %>
  </label>

  <%= submit "Submit", class: "qa-submit" %>
<% end %>
```

## And now the all-powerfull controllers

Before we can get to the meat and potatoes of two-factor authentication, we need to take a gander at our session controller and, using that shiny, new boolean on our users, make sure we're sending people to their appropriate destinations.

```elixir
defmodule TwoFactorAuthWeb.SessionController do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Guardian
  alias TwoFactorAuth.Accounts
  alias TwoFactorAuthWeb.Mailer

  def new(conn, _), do: render(conn, "new.html")

  def create(conn, session_params) do
    # You could use a nested case here, but withs are cool, too
    with {:ok, user} <- Accounts.verify_login(session_params) do
      case user.has_2fa do
        true ->
          # remember that code at the beginning... this is where it went
          {token, one_time_pass} = Accounts.generate_one_time_pass(user)
          Mailer.deliver_2fa_email(user, one_time_pass)

          conn
          |> put_session("user_secret", %{"token" => token, "user_id" => user_id})
          |> put_flash(:info, "A heckin' 2fa code has been sent to you! Isn't that cool?")
          |> put_status(302)
          |> redirect(to: two_factor_auth_path(conn, :new))

        false ->
          conn
          |> Guardian.Plug.sign_in(user)
          |> put_flash(:info, "Login successful! But you should enable two-factor auth ngl")
          |> put_status(302)
          |> redirect(to: page_path(conn, :index))
      end
    else
      {:error, _} ->
        conn
        |> put_flash(:error, "You entered an invalid password or email!")
        |> put_status(401)
        |> render("new.html")
  end
end
```

Here we verify the the email and password passed in through `session_params` and return `{:ok, user}`. If the user has enabled two-factor auth on their account, we will generate them a one time password and email it to them. We then use `put_session/3` to store the `user_secret` on `%Plug.Conn{private: :plug_session}`.

`:plug_session` is the session storage for the `conn` that gets encrypted and sent to thend password passed in through `session_params` and return `{:ok, user}`. If the user has enabled two-factor auth on their account, we will generate them a one time password and email it to them. We then use `put_session/3` to store the `user_secret` on `%Plug.Conn{private: :plug_session}`. We need both t
user as a cookie. We really don't want this token getting into the wrong hands, because we'll use it later on down the road to validate the one time password.

```elixir
defmodule TwoFactorAuthWeb.TwoFactorAuthController do
  use TwoFactorAuthWeb, :controller
  import Plug.Conn

  alias TwoFactorAuth.Guardian
  alias TwoFactorAuth.Accounts

  def new(conn, _) do
    # we want to see if our token is empty, and if it is we redirect them back to the new session page
    # the goal here is to have one continuous session through the flow of 2fa
    with %{} <- Auth.fetch_secret_from_session(conn) do
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
    %{"token" => token, "user_id" => user_id} = get_session(conn)
    user = Accounts.get_user!(user_id)

    case Auth.valid_one_time_pass?(one_time_pass, token) do
      true ->
        conn
        # our one time password can only be used once, duh
        # but we wanna go that extra mile and also invalidate our token
        # just in case?
        |> Auth.invalidate_secret()
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

There's a couple challenges when it comes to dealing with the second factor of our authentication workflow. We need to be able to assure that there is one continuous session throughout the entire process, meaning that we can't take any requests from a user that hasn't first logged in with their username and password. We also need to be sure no sensitive data, i.e. our secret token, is being leaked to the user.

That's where `:plug_session` comes in. This is the session store on our `conn` that get's encrypted when it's sent to the client and is stored by your browser as a cookie. We'll need to use `put_session/3` and `get_session/2` from `Plug.Conn` to assign and fetch our `"user_secret"` to and from the session.

```elixir
### from Plug.Conn (conn.ex) ###

def put_session(conn, key, value) when is_atom(key) or is_binary(key) do
	put_session(conn, &Map.put(&1, session_key(key), value))
end

defp put_session(conn, fun) do
	private =
		conn.private
		|> Map.put(:plug_session, fun.(get_session(conn)))
		|> Map.put_new(:plug_session_info, :write)

	%{conn | private: private}
end
```

`put_session` takes your connection, the new key, and the value you want to assign to that key and puts them in `:plug_session` which lives in the private store of you connection.

`conn[:private]` is meant to be used by libraries and frameworks, such as `Plug.Conn`, to avoid writing to the user storage (the `:assigns` field).

So inside of our `conn` lives a special `:private` map that keeps our deep, dark secrets about the session from the user instead of leaking this information through `conn[:assigns]`. It's meant to be used by libraries, such as `Plug.Conn`, to avoid writing to `:assigns`.

Here we're putting on the secret sauce during the first step of authentication and then sending the user along to the next stop:

```elixir
### lib/two_factor_auth_web/controllers/session_controller.ex ###

conn
|> put_session("user_secret", %{"token" => token, "user_id" => user_id})
|> put_flash(:info, "A heckin' 2fa code has been sent to you! Isn't that cool?")
|> put_status(302)
|> redirect(to: two_factor_auth_path(conn, @new))
```

When get's redirected to our new path, that's when we'll implement `get_session/2` to fetch our secret and check to see if we can even let them in and if we can, authenticate their one time password.

```elixir
### from Plug.Conn (conn.ex) ###

def get_session(conn, key) when is_atom(key) or is_binary(key) do
  conn |> get_session |> Map.get(session_key(key))
end

defp get_session(%Conn{private: private}) do
  if session = Map.get(private, :plug_session) do
    session
  else
    raise ArgumentError, "session not fetched, call fetch_session/2"
  end
end

defp session_key(binary) when is_binary(binary), do: binary
defp session_key(atom) when is_atom(atom), do: Atom.to_string(atom)
```
So now we have all the ingredients, assuming that the user has access to their email, for two successful pieces of evidence to finally sign them in to the system.

```elixir

```


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

## A plug for our Plug

Notice the keys returned from looking at the `conn[:private]`, besides our router, are all dependencies for our Phoenix application. So let's try this again but nest our `:user_secret` map inside of an applicable place in `:private`.

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
    # putting our secret inside of :plug_session makes sense?
    updated_plug_session =
      conn.private[:plug_session]
      |> Map.put("user_secret", %{"token" => token, "user_id" => user_id})

    conn
    |> put_private(:plug_session, updated_plug_session)
  end

  def fetch_secret_from_session(conn) do
    # fetch the secret from the plug session
    # if the key doesn't exist just return nil
    with {:ok, %{"token" => token, "user_id" => user_id}} <-
           conn.private[:plug_session] |> Match.fetch("user_secret") do
      {token, user_id}
    else
      _ ->
        nil
    end
  end

  # When you check the validity of an HMAC one time password, since it's trial-based,
  # it returns the current number of trials on the password when it is valid. Otherwise
  # it returns false. When we generated our password we only allowed for 1 trial, so
  # anything over that will now count as invalid or false.
  def valid_one_time_pass?(one_time_pass, token) do
    case :pot.valid_hotp(one_time_pass, token, [{:last, 0}]) do
      1 -> true
      _ -> false
    end
  end

  def invalidate_secret(conn) do
    # when we're invalidating the secret we'll just drop the key
    updated_plug_session =
      conn.private[:plug_session]
      |> Map.drop("user_secret")

    conn
    |> put_private(:plug_session, updated_plug_session)
  end
end
```

There's a lot going on in this file, so let me try to explain my reasoning behind a couple of these functions. Notice `assign_secret_to_session/3`; we end up putting our `:user_secret` (now the stringified key `"user_secret"`) inside of `:plug_session`. Why? Well it seemed like the aforementioned _applicable_ place. Considering that we wanted to continue the private data on our connection's current session, I thought it best to stash the goods inside of there. So if we latch our `"user_secret"` onto `:plug_session`, `conn[:private]` keeps it there after the redirect.

Another weird thing you might notice is that `try ... rescue ...` block in `fetch_secret_from_session/1`. Well this comes in to play in our `two_factor_auth_controller` on the new path. For reference here's that function again:

```elixir
### lib/two_factor_auth_web/controllers/two_factor_auth_controller.ex ###

def new(conn, _) do
  with {token, _user_id} <- Auth.fetch_secret_from_session(conn) do
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
```

So without catching the `MatchError`, our application would have failed when we tried to call `fetch_secret_from_session/1` on a conn that didn't have a token. Now if the the `"user_secret"` key doesn't exist our `with` fails and takes us to the `else` clause where we can give our user a 404.

Another strange caveat 

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

## The cherry on top

So what if our user doesn't recieve the email? Maybe some shark was nibbling on some transatlantic communications cable and something went wrong? Well, we could give our user the option to resend their email. We'd just need a new route and some extra goodies in the controller to generate another one time password and token.

```elixir
### liv/two_factor_auth_web/router.ex ###

post("/sessions/new/two_factor_auth/resend_email", TwoFactorAuthController, :resend_email)
```

```elixir
### lib/two_factor_auth_web/controllers/two_factor_auth_controller.ex ###

def resend_email(conn, _) do
  {_old_token, user_id} = Auth.fetch_secret_from_session(conn)
  user = Accounts.get_user!(user_id)

  {new_token, one_time_pass} = Auth.generate_one_time_pass()
  Mailer.deliver_2fa_email(user, one_time_pass)

  conn
  |> Auth.assign_secret_to_session(token, user_id)
  |> put_flash(:info, "A new two-factor authentication code was sent to your email!")
  |> put_status(200)
  |> render("two_factor_auth.html", action: two_factor_auth_path(conn, :create))
end
```