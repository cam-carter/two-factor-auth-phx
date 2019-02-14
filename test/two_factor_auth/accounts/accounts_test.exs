defmodule TwoFactorAuth.AccountsTest do
  use TwoFactorAuth.DataCase

  alias TwoFactorAuth.Accounts

  describe "users" do
    alias TwoFactorAuth.Accounts.User

    @valid_attrs %{email: "some email", password: "password"}
    @update_attrs %{email: "some updated email", password: "some updated password"}
    @invalid_attrs %{email: nil, password_hash: nil}

    setup do
      user = insert(:user)

      {:ok, %{user: user}}
    end

    test "list_users/0 returns all users", %{user: user} do
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id", %{user: user} do
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Accounts.create_user(@valid_attrs)
      assert user.email == "some email"
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user", %{user: user} do
      assert {:ok, user} = Accounts.update_user(user, @update_attrs)
      assert %User{} = user
      assert user.email == "some updated email"
    end

    test "update_user/2 with invalid data returns error changeset", %{user: user} do
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user", %{user: user} do
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset", %{user: user} do
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end

    test "verify_login/1 with valid data verifies a user's credentials", %{user: user} do
      assert {:ok, user} =
               Accounts.verify_login(%{"email" => user.email, "password" => "password"})

      assert %User{} = user
    end

    test "generating a valid one time password" do
      {token, one_time_pass} = Accounts.generate_one_time_pass()
      assert Accounts.valid_one_time_pass?(one_time_pass, token)
    end
  end
end
