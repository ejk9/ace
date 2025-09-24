# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     AceApp.Repo.insert!(%AceApp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias AceApp.Repo
alias AceApp.Drafts.{Draft, Team, Player, PlayerAccount, Pick, SpectatorControls}
alias AceApp.LoL

require Logger

# Clear existing data in development
if Mix.env() in [:dev, :test] do
  Logger.info("🧹 Clearing existing data...")
  
  Repo.delete_all(Pick)
  Repo.delete_all(PlayerAccount)
  Repo.delete_all(Player)
  Repo.delete_all(Team)
  Repo.delete_all(SpectatorControls)
  Repo.delete_all(Draft)
  
  Logger.info("✅ Database cleared!")
end

Logger.info("🌱 Seeding development data...")

# Helper function to generate unique tokens
generate_token = fn ->
  :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
end

# Create sample drafts
Logger.info("📋 Creating sample drafts...")

# Draft 1: Setup phase draft for testing setup flow
draft1 = Repo.insert!(%Draft{
  name: "Spring Tournament - Group A",
  status: :setup,
  format: :snake,
  pick_timer_seconds: 60,
  organizer_token: generate_token.(),
  spectator_token: generate_token.()
})

# Draft 2: Active draft for testing live drafting
draft2 = Repo.insert!(%Draft{
  name: "Summer Championship Finals",
  status: :active,
  format: :snake,
  pick_timer_seconds: 90,
  organizer_token: generate_token.(),
  spectator_token: generate_token.()
})

# Draft 3: Completed draft for testing results view
draft3 = Repo.insert!(%Draft{
  name: "Winter League - Week 1",
  status: :completed,
  format: :snake,
  pick_timer_seconds: 45,
  organizer_token: generate_token.(),
  spectator_token: generate_token.()
})

# Create teams for each draft
Logger.info("👥 Creating teams...")

# Teams for Draft 1 (Setup)
teams1 = [
  %{name: "Blue Dragons", logo_url: "https://via.placeholder.com/64/0066cc/ffffff?text=BD", pick_order_position: 1},
  %{name: "Red Phoenix", logo_url: "https://via.placeholder.com/64/cc0000/ffffff?text=RP", pick_order_position: 2},
  %{name: "Green Wolves", logo_url: "https://via.placeholder.com/64/00cc66/ffffff?text=GW", pick_order_position: 3},
  %{name: "Purple Storm", logo_url: "https://via.placeholder.com/64/9900cc/ffffff?text=PS", pick_order_position: 4}
]

draft1_teams = Enum.map(teams1, fn team_attrs ->
  Repo.insert!(%Team{
    draft_id: draft1.id,
    name: team_attrs.name,
    logo_url: team_attrs.logo_url,
    pick_order_position: team_attrs.pick_order_position,
    captain_token: generate_token.(),
    team_member_token: generate_token.(),
    is_ready: false
  })
end)

# Teams for Draft 2 (Active) - some ready, some not
teams2 = [
  %{name: "TSM Academy", logo_url: "https://via.placeholder.com/64/000000/ffffff?text=TSM", pick_order_position: 1, is_ready: true},
  %{name: "Cloud9 Blue", logo_url: "https://via.placeholder.com/64/0099ff/ffffff?text=C9", pick_order_position: 2, is_ready: true},
  %{name: "Team Liquid", logo_url: "https://via.placeholder.com/64/003366/ffffff?text=TL", pick_order_position: 3, is_ready: false}
]

draft2_teams = Enum.map(teams2, fn team_attrs ->
  Repo.insert!(%Team{
    draft_id: draft2.id,
    name: team_attrs.name,
    logo_url: team_attrs.logo_url,
    pick_order_position: team_attrs.pick_order_position,
    captain_token: generate_token.(),
    team_member_token: generate_token.(),
    is_ready: team_attrs.is_ready
  })
end)

# Teams for Draft 3 (Completed)
teams3 = [
  %{name: "FlyQuest", logo_url: "https://via.placeholder.com/64/00ffcc/ffffff?text=FQ", pick_order_position: 1},
  %{name: "100 Thieves", logo_url: "https://via.placeholder.com/64/ff0066/ffffff?text=100T", pick_order_position: 2}
]

draft3_teams = Enum.map(teams3, fn team_attrs ->
  Repo.insert!(%Team{
    draft_id: draft3.id,
    name: team_attrs.name,
    logo_url: team_attrs.logo_url,
    pick_order_position: team_attrs.pick_order_position,
    captain_token: generate_token.(),
    team_member_token: generate_token.(),
    is_ready: true
  })
end)

# Create realistic player pools
Logger.info("🎮 Creating player pools...")

# Pro player names and data for more realistic testing
pro_players = [
  %{name: "Faker", roles: [:mid], tier: :challenger, division: :i, region: :kr},
  %{name: "Canyon", roles: [:jungle], tier: :challenger, division: :i, region: :kr},
  %{name: "Keria", roles: [:support], tier: :challenger, division: :i, region: :kr},
  %{name: "Gumayusi", roles: [:adc], tier: :challenger, division: :i, region: :kr},
  %{name: "Zeus", roles: [:top], tier: :challenger, division: :i, region: :kr},
  %{name: "Caps", roles: [:mid], tier: :challenger, division: :i, region: :euw1},
  %{name: "Jankos", roles: [:jungle], tier: :grandmaster, division: :i, region: :euw1},
  %{name: "Mikyx", roles: [:support], tier: :grandmaster, division: :i, region: :euw1},
  %{name: "Flakked", roles: [:adc], tier: :master, division: :i, region: :euw1},
  %{name: "Broken Blade", roles: [:top], tier: :grandmaster, division: :i, region: :euw1},
  %{name: "Bjergsen", roles: [:mid], tier: :challenger, division: :i, region: :na1},
  %{name: "Blaber", roles: [:jungle], tier: :challenger, division: :i, region: :na1},
  %{name: "CoreJJ", roles: [:support], tier: :challenger, division: :i, region: :na1},
  %{name: "Doublelift", roles: [:adc], tier: :master, division: :i, region: :na1},
  %{name: "Impact", roles: [:top], tier: :grandmaster, division: :i, region: :na1},
  %{name: "Sneaky", roles: [:adc], tier: :diamond, division: :i, region: :na1},
  %{name: "Meteos", roles: [:jungle], tier: :diamond, division: :ii, region: :na1},
  %{name: "Aphromoo", roles: [:support], tier: :diamond, division: :i, region: :na1},
  %{name: "Dyrus", roles: [:top], tier: :platinum, division: :i, region: :na1},
  %{name: "Scarra", roles: [:mid], tier: :platinum, division: :ii, region: :na1},
  %{name: "IWillDominate", roles: [:jungle], tier: :diamond, division: :iii, region: :na1},
  %{name: "Voyboy", roles: [:top, :mid], tier: :platinum, division: :i, region: :na1},
  %{name: "Imaqtpie", roles: [:adc], tier: :diamond, division: :ii, region: :na1},
  %{name: "Pokimane", roles: [:adc, :support], tier: :gold, division: :i, region: :na1},
  %{name: "Tyler1", roles: [:adc], tier: :master, division: :i, region: :na1},
  %{name: "Yassuo", roles: [:mid], tier: :diamond, division: :i, region: :na1},
  %{name: "TF Blade", roles: [:top], tier: :challenger, division: :i, region: :na1},
  %{name: "Shiphtur", roles: [:mid], tier: :grandmaster, division: :i, region: :na1},
  %{name: "Nightblue3", roles: [:jungle], tier: :diamond, division: :i, region: :na1},
  %{name: "BoxBox", roles: [:top], tier: :diamond, division: :ii, region: :na1}
]

# Create players for each draft
create_players_for_draft = fn draft, players_data ->
  Enum.map(players_data, fn player_data ->
    # Create player
    player = Repo.insert!(%Player{
      draft_id: draft.id,
      display_name: player_data.name,
      preferred_roles: player_data.roles,
      custom_stats: %{
        "kda" => :rand.uniform(5) + 1.0,
        "winrate" => :rand.uniform(30) + 60,
        "main_champions" => Enum.take_random(["Azir", "LeBlanc", "Syndra", "Zed", "Yasuo", "Ahri", "Orianna"], 3)
      },
      organizer_notes: "Strong #{Enum.join(player_data.roles, "/")} player with good game sense."
    })
    
    # Create player account
    Repo.insert!(%PlayerAccount{
      player_id: player.id,
      summoner_name: "#{player_data.name}#{:rand.uniform(999)}",
      rank_tier: player_data.tier,
      rank_division: player_data.division,
      server_region: player_data.region,
      is_primary: true
    })
    
    player
  end)
end

# Create player pools for each draft
draft1_players = create_players_for_draft.(draft1, Enum.take(pro_players, 20))
draft2_players = create_players_for_draft.(draft2, Enum.take(pro_players, 15))
draft3_players = create_players_for_draft.(draft3, Enum.take(pro_players, 10))

# Create some picks for the completed draft
Logger.info("⚡ Creating sample picks for completed draft...")

[team_a, team_b] = draft3_teams
[p1, p2, p3, p4, p5, p6, p7, p8, p9, p10] = Enum.take(draft3_players, 10)

# Snake draft order: Team A, Team B, Team B, Team A, Team A, Team B, Team B, Team A, Team A, Team B
completed_picks = [
  %{team: team_a, player: p1, pick_number: 1, round_number: 1},
  %{team: team_b, player: p2, pick_number: 2, round_number: 1},
  %{team: team_b, player: p3, pick_number: 3, round_number: 2},
  %{team: team_a, player: p4, pick_number: 4, round_number: 2},
  %{team: team_a, player: p5, pick_number: 5, round_number: 3},
  %{team: team_b, player: p6, pick_number: 6, round_number: 3},
  %{team: team_b, player: p7, pick_number: 7, round_number: 4},
  %{team: team_a, player: p8, pick_number: 8, round_number: 4},
  %{team: team_a, player: p9, pick_number: 9, round_number: 5},
  %{team: team_b, player: p10, pick_number: 10, round_number: 5}
]

Enum.each(completed_picks, fn pick_data ->
  Repo.insert!(%Pick{
    draft_id: draft3.id,
    team_id: pick_data.team.id,
    player_id: pick_data.player.id,
    pick_number: pick_data.pick_number,
    round_number: pick_data.round_number,
    picked_at: DateTime.utc_now() |> DateTime.add(-:rand.uniform(3600), :second),
    pick_duration_ms: :rand.uniform(45000) + 15000  # 15-60 seconds
  })
end)

# Create spectator controls for each draft
Logger.info("👁️ Creating spectator controls...")

Enum.each([draft1, draft2, draft3], fn draft ->
  Repo.insert!(%SpectatorControls{
    draft_id: draft.id,
    show_player_notes: true,
    show_detailed_stats: true,
    show_match_history: false,
    stream_overlay_config: %{
      "show_timers" => true,
      "show_pick_order" => true,
      "theme" => "dark"
    }
  })
end)

# Set current turn for active draft
if length(draft2_teams) > 0 do
  first_team = Enum.at(draft2_teams, 0)
  Repo.update!(Draft.changeset(draft2, %{current_turn_team_id: first_team.id}))
end

Logger.info("✅ Seeding completed successfully!")

Logger.info("""

🎉 Sample data created! Here are your test drafts:

📋 Draft 1: "#{draft1.name}" (Setup Phase)
   - Status: #{draft1.status}
   - Teams: #{length(draft1_teams)} teams
   - Players: #{length(draft1_players)} players
   - Organizer URL: http://localhost:4000/draft/organizer/#{draft1.organizer_token}
   - Spectator URL: http://localhost:4000/draft/spectator/#{draft1.spectator_token}

📋 Draft 2: "#{draft2.name}" (Active)
   - Status: #{draft2.status}
   - Teams: #{length(draft2_teams)} teams (some ready, some not)
   - Players: #{length(draft2_players)} players
   - Organizer URL: http://localhost:4000/draft/organizer/#{draft2.organizer_token}
   - Spectator URL: http://localhost:4000/draft/spectator/#{draft2.spectator_token}

📋 Draft 3: "#{draft3.name}" (Completed)
   - Status: #{draft3.status}
   - Teams: #{length(draft3_teams)} teams
   - Players: #{length(draft3_players)} players (10 picks completed)
   - Organizer URL: http://localhost:4000/draft/organizer/#{draft3.organizer_token}
   - Spectator URL: http://localhost:4000/draft/spectator/#{draft3.spectator_token}

🔗 Team Captain URLs for Draft 1:
#{Enum.map_join(draft1_teams, "\n", fn team -> "   - #{team.name}: http://localhost:4000/draft/team/#{team.captain_token}" end)}

🔗 Team Captain URLs for Draft 2:
#{Enum.map_join(draft2_teams, "\n", fn team -> "   - #{team.name}: http://localhost:4000/draft/team/#{team.captain_token}" end)}

💡 Quick commands:
   - Reset and re-seed: make db-reset
   - Just run seeds: make db-seed
   - Start server: make start

""")