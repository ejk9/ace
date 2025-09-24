defmodule AceApp.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use AceApp.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias AceApp.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import AceApp.DataCase
    end
  end

  setup tags do
    AceApp.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(AceApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  A helper to get a random champion ID for test purposes.
  Returns the ID of the first enabled champion, or creates a test champion if none exist.
  """
  def random_champion_id do
    case AceApp.LoL.list_enabled_champions() do
      [] ->
        # Fallback to any champion if no enabled champions
        case AceApp.LoL.list_champions() do
          [] -> 
            # If no champions exist at all, create one for tests
            {:ok, champion} = AceApp.LoL.create_champion(%{
              name: "Test Champion",
              key: "TestChampion", 
              title: "The Test Hero",
              tags: ["Fighter"],
              resource_type: "Mana",
              attack_type: "Melee",
              primary_role: :top,
              secondary_role: nil,
              enabled: true,
              image_url: "https://example.com/test.jpg",
              roles: ["top"],
              difficulty: 3,
              release_date: ~D[2020-01-01]
            })
            champion.id
          champions -> 
            List.first(champions).id
        end
      enabled_champions ->
        List.first(enabled_champions).id
    end
  end
end
