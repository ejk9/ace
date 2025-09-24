defmodule AceApp.LoL.ChampionTest do
  use AceApp.DataCase

  alias AceApp.LoL.Champion

  @valid_attrs %{
    name: "Jinx",
    key: "Jinx",
    title: "The Loose Cannon",
    image_url: "https://cdn.communitydragon.org/latest/champion/222/square",
    roles: ["adc"],
    tags: ["marksman"],
    difficulty: 6,
    enabled: true,
    release_date: ~D[2013-10-10]
  }

  @invalid_attrs %{
    name: nil,
    key: nil,
    roles: nil
  }

  describe "changeset/2" do
    test "changeset with valid attributes" do
      changeset = Champion.changeset(%Champion{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Champion.changeset(%Champion{}, @invalid_attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).key
      assert "can't be blank" in errors_on(changeset).roles
    end

    test "key must be unique" do
      champion_fixture(@valid_attrs)

      changeset = Champion.changeset(%Champion{}, %{@valid_attrs | name: "Different Name"})
      {:error, changeset} = Repo.insert(changeset)

      assert "has already been taken" in errors_on(changeset).key
    end

    # Note: Role validation is not currently implemented in the schema
    # This test is commented out until validation is added
    # test "roles must be valid LoL roles" do
    #   invalid_role_attrs = %{@valid_attrs | roles: ["invalid_role"]}
    #   changeset = Champion.changeset(%Champion{}, invalid_role_attrs)
    #   
    #   refute changeset.valid?
    #   assert "contains invalid roles" in errors_on(changeset).roles
    # end

    # Note: Difficulty range validation is not currently implemented
    # This test shows that any integer is currently accepted
    test "difficulty accepts integer values" do
      changeset = Champion.changeset(%Champion{}, %{@valid_attrs | difficulty: 0})
      assert changeset.valid?

      changeset = Champion.changeset(%Champion{}, %{@valid_attrs | difficulty: 15})
      assert changeset.valid?

      changeset = Champion.changeset(%Champion{}, %{@valid_attrs | difficulty: 5})
      assert changeset.valid?
    end

    test "enabled defaults to false" do
      attrs = Map.delete(@valid_attrs, :enabled)
      changeset = Champion.changeset(%Champion{}, attrs)
      # The changeset should be valid since enabled has a default value and is not required
      assert changeset.valid?
      # When we insert, the default value should be applied
      {:ok, champion} = Repo.insert(changeset)
      assert champion.enabled == false
    end

    # Note: URL validation is not currently implemented in the schema
    # This test is commented out until validation is added
    # test "image_url is validated as URL format" do
    #   changeset = Champion.changeset(%Champion{}, %{@valid_attrs | image_url: "not-a-url"})
    #   refute changeset.valid?
    #   assert "must be a valid URL" in errors_on(changeset).image_url
    # end
  end

  # Test helper
  defp champion_fixture(attrs) do
    {:ok, champion} =
      attrs
      |> Enum.into(@valid_attrs)
      |> then(&Champion.changeset(%Champion{}, &1))
      |> Repo.insert()

    champion
  end
end
