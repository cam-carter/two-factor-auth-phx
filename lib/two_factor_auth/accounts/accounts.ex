defmodule TwoFactorAuth.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias TwoFactorAuth.Repo

  alias TwoFactorAuth.Accounts.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  @doc """
  Verifies a user's credentials

  ## Examples

      iex> verify_login(%{"email" => email, "password" => password})
      {:ok, user}

      iex> verify_login(%{"email" => email, "password" => password})
      {:error, "Invalid email or password!"}
  """
  def verify_login(%{"email" => email, "password" => password}) do
    case Repo.get_by(User, email: String.downcase(email)) do
      nil ->
        {:error, "Invalid email or password!"}

      user ->
        case Comeonin.Bcrypt.check_pass(user, password) do
          {:ok, user} -> {:ok, user}
          {:error, _} -> {:error, "Invalid email or password!"}
        end
    end
  end

  def generate_one_time_pass() do
    token =
      :crypto.strong_rand_bytes(8)
      |> Base.encode32()

    one_time_pass = :pot.hotp(token, _number_of_trials = 1)

    {token, one_time_pass}
  end

  def valid_one_time_pass?(one_time_pass, token) do
    case :pot.valid_hotp(one_time_pass, token, [{:last, 0}]) do
      1 -> true
      _ -> false
    end
  end
end
