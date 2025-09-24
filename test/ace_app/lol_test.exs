defmodule AceApp.LoLTest do
  use ExUnit.Case
  alias AceApp.LoL

  describe "roles/0" do
    test "returns all valid roles" do
      roles = LoL.roles()
      assert :top in roles
      assert :jungle in roles
      assert :mid in roles
      assert :adc in roles
      assert :support in roles
      assert length(roles) == 5
    end
  end

  describe "tiers/0" do
    test "returns all valid tiers" do
      tiers = LoL.tiers()

      expected_tiers = [
        :iron,
        :bronze,
        :silver,
        :gold,
        :platinum,
        :emerald,
        :diamond,
        :master,
        :grandmaster,
        :challenger
      ]

      assert tiers == expected_tiers
    end
  end

  describe "divisions/0" do
    test "returns all valid divisions" do
      divisions = LoL.divisions()
      expected_divisions = [:i, :ii, :iii, :iv]
      assert divisions == expected_divisions
    end
  end

  describe "regions/0" do
    test "returns all valid regions" do
      regions = LoL.regions()
      assert :na1 in regions
      assert :euw1 in regions
      assert :kr in regions
      assert length(regions) > 10
    end
  end

  describe "role_display_name/1" do
    test "converts roles to display names" do
      assert LoL.role_display_name(:top) == "Top"
      assert LoL.role_display_name(:jungle) == "Jungle"
      assert LoL.role_display_name(:mid) == "Mid"
      assert LoL.role_display_name(:adc) == "ADC"
      assert LoL.role_display_name(:support) == "Support"
    end
  end

  describe "tier_display_name/1" do
    test "converts tiers to display names" do
      assert LoL.tier_display_name(:iron) == "Iron"
      assert LoL.tier_display_name(:bronze) == "Bronze"
      assert LoL.tier_display_name(:silver) == "Silver"
      assert LoL.tier_display_name(:gold) == "Gold"
      assert LoL.tier_display_name(:platinum) == "Platinum"
      assert LoL.tier_display_name(:emerald) == "Emerald"
      assert LoL.tier_display_name(:diamond) == "Diamond"
      assert LoL.tier_display_name(:master) == "Master"
      assert LoL.tier_display_name(:grandmaster) == "Grandmaster"
      assert LoL.tier_display_name(:challenger) == "Challenger"
    end
  end

  describe "division_display_name/1" do
    test "converts divisions to display names" do
      assert LoL.division_display_name(:i) == "I"
      assert LoL.division_display_name(:ii) == "II"
      assert LoL.division_display_name(:iii) == "III"
      assert LoL.division_display_name(:iv) == "IV"
    end
  end

  describe "region_display_name/1" do
    test "converts regions to display names" do
      assert LoL.region_display_name(:na1) == "North America"
      assert LoL.region_display_name(:euw1) == "Europe West"
      assert LoL.region_display_name(:eun1) == "Europe Nordic & East"
      assert LoL.region_display_name(:kr) == "Korea"
      assert LoL.region_display_name(:br1) == "Brazil"
    end
  end

  describe "valid_roles?/1" do
    test "validates valid roles" do
      assert LoL.valid_roles?([:top]) == true
      assert LoL.valid_roles?([:jungle, :mid]) == true
      assert LoL.valid_roles?([:adc, :support]) == true
    end

    test "rejects invalid roles" do
      assert LoL.valid_roles?([:invalid_role]) == false
      assert LoL.valid_roles?([:top, :invalid_role]) == false
      # Empty list is valid
      assert LoL.valid_roles?([]) == true
    end
  end
end
