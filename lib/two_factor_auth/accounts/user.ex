defmodule TwoFactorAuth.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:email, :string)
    field(:has_2fa, :boolean, default: false)
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

  defp downcase_email(%Ecto.Changeset{valid?: true, changes: %{email: email}} = changeset) do
    changeset
    |> change(%{email: String.downcase(email)})
  end

  defp downcase_email(changeset), do: changeset

  defp put_pass_hash(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    changeset
    |> change(Comeonin.Bcrypt.add_hash(password))
  end

  defp put_pass_hash(changeset), do: changeset
end
