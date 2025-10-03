# Feature Development TODO

## New Features to Implement

### 1. Role Validation System
**Goal:** Enforce role constraints during draft picks - teams can only pick players for roles they haven't filled yet.

#### Phase 1: Basic Info Configuration
- [ ] Add role validation toggle to draft setup basic info tab
  - Location: `lib/ace_app_web/live/draft_setup_live.html.heex` (basic_info section)
  - Add checkbox: "Enable role validation (teams can only pick available roles)"
  - Update schema: Add `role_validation_enabled` boolean to `drafts` table
  - Migration: `mix ecto.gen.migration add_role_validation_to_drafts`
  - Default: `false` (opt-in feature)

#### Phase 2: Role Tracking Per Team
- [ ] Track filled roles for each team during draft
  - Add function: `Drafts.get_team_filled_roles(team_id, draft_id)` 
  - Query existing picks to determine which roles are filled
  - Return list of roles: `["top", "jungle", "mid", "adc", "support"]`
  - Cache in LiveView assigns for performance

#### Phase 3: Player Filtering Logic
- [ ] Filter available players based on unfilled roles
  - Update: `DraftRoomLive.available_players/1` helper
  - When role validation enabled:
    - Get team's filled roles
    - Filter players to only show those with `preferred_roles` matching unfilled roles
    - Handle edge case: Player with multiple roles (show if ANY role is unfilled)
  - When role validation disabled: Show all available players (current behavior)

#### Phase 4: Pick Validation
- [ ] Server-side validation on pick submission
  - Update: `Drafts.make_pick/3` or add `Drafts.validate_pick_role/3`
  - Check if picked player's role is already filled for the team
  - Return `{:error, "Role already filled"}` if invalid
  - Add error handling in `DraftRoomLive.handle_event("make_pick")`
  - Display user-friendly error message via `put_flash`

#### Phase 5: UI Updates
- [ ] Visual indicators for role constraints
  - Show filled/unfilled roles for each team in draft room
  - Gray out unavailable players (wrong role) in player selection UI
  - Add tooltip: "This role is already filled for your team"
  - Update roster display to show role icons next to players

---

### 2. Automatic Picks System
**Goal:** When only 1 player remains for an unfilled role, automatically pick them after a brief delay. Notify captains of pending auto-picks.

#### Phase 1: Auto-Pick Detection Logic
- [ ] Detect when auto-pick conditions are met
  - Function: `Drafts.detect_auto_pick(draft_id, team_id)`
  - Logic:
    - Get team's unfilled roles (from role validation system)
    - For each unfilled role, count available players
    - If exactly 1 player available for a role → auto-pick candidate
  - Return: `%{role: "top", player_id: 123}` or `nil`

#### Phase 2: Captain Notification System
- [ ] Notify captain when draft picks are complete
  - Trigger notification when all remaining picks are auto-pickable
  - Display flash message: "Your draft is complete! Auto-picking: PlayerX (Top), PlayerY (Support)"
  - Show countdown: "Auto-picks will execute in 5 seconds..."
  - Allow captain to manually confirm or adjust if needed
  - UI location: Banner at top of draft room interface

#### Phase 3: Auto-Pick Execution with Delay
- [ ] Implement delayed auto-pick system
  - Use GenServer or Task for delayed execution (similar to timer system)
  - Delay: 3-5 seconds between auto-picks (configurable)
  - Flow:
    1. Detect auto-pick condition
    2. Broadcast PubSub event: `{:auto_pick_pending, player_id, delay_ms}`
    3. Wait delay period
    4. Execute: `Drafts.make_pick(draft_id, team_id, player_id)`
    5. Continue to next auto-pick if more exist
  - Handle interruptions: Cancel auto-pick if captain makes manual pick

#### Phase 4: Queue System Integration
- [ ] Integrate with existing pick queue system
  - Check: Can auto-picks coexist with queued picks?
  - Priority: Execute queued picks first, then auto-picks
  - Add auto-picked players to queue with special flag: `auto_picked: true`
  - Display in queue UI: "🤖 Auto-pick: PlayerX (Top)"

#### Phase 5: OBS Overlay Integration
- [ ] Ensure overlay handles auto-picks gracefully
  - Test: Do auto-picks trigger splash art celebrations?
  - Timing: Space out auto-picks to match preview draft cadence
  - Add visual indicator: Small "AUTO" badge on auto-picked players in overlay
  - Ensure `/stream/:id/overlay.json` API includes auto-pick data
  - Update: `priv/static/obs_examples/draft_overlay.html` to show auto-pick badge

#### Phase 6: Edge Cases & Error Handling
- [ ] Handle edge cases
  - What if player is picked by another team before auto-pick executes?
    - Re-detect auto-pick candidates
    - If no more candidates, stop auto-pick sequence
  - What if draft is paused/rolled back during auto-pick?
    - Cancel pending auto-picks
    - Re-calculate when draft resumes
  - What if role validation is disabled mid-draft?
    - Disable auto-picks
    - Show warning to organizer

---

## Implementation Order

### Recommended Sequence
1. **Start with Role Validation System** (Foundation)
   - Phases 1-5 of Role Validation
   - Fully test before moving to auto-picks
   - Role validation is prerequisite for auto-picks

2. **Build Auto-Pick System** (Enhancement)
   - Phases 1-6 of Automatic Picks
   - Depends on role tracking from validation system
   - Test extensively with live drafts

### Testing Strategy
- **Unit tests:** Role detection, auto-pick logic, edge cases
- **Integration tests:** Draft flow with role validation enabled
- **E2E tests (Playwright):** Complete draft with auto-picks
- **Manual testing:** OBS overlay behavior, captain notifications

---

## Database Schema Changes

### Migration 1: Add Role Validation Flag
```elixir
defmodule AceApp.Repo.Migrations.AddRoleValidationToDrafts do
  use Ecto.Migration

  def change do
    alter table(:drafts) do
      add :role_validation_enabled, :boolean, default: false, null: false
    end
  end
end
```

### Potential Migration 2: Track Auto-Picks (Optional)
```elixir
# If we want to track which picks were automatic
alter table(:picks) do
  add :auto_picked, :boolean, default: false
end
```

---

## Files to Modify

### Role Validation System
- `priv/repo/migrations/XXXXXX_add_role_validation_to_drafts.exs` (new)
- `lib/ace_app/drafts/draft.ex` - Add `:role_validation_enabled` field
- `lib/ace_app_web/live/draft_setup_live.html.heex` - Add UI toggle
- `lib/ace_app_web/live/draft_room_live.ex` - Filter available players
- `lib/ace_app/drafts.ex` - Add validation functions

### Automatic Picks System  
- `lib/ace_app/drafts.ex` - Auto-pick detection and execution
- `lib/ace_app_web/live/draft_room_live.ex` - Captain notifications, auto-pick triggers
- `lib/ace_app/drafts/auto_pick_server.ex` (new) - GenServer for delayed execution
- `priv/static/obs_examples/draft_overlay.html` - Auto-pick visual indicators

---

## Questions to Answer

- **Should auto-picks respect pick queues?** Yes - execute queued picks first
- **Should auto-pick delay be configurable per draft?** Start with fixed 3-5 seconds, make configurable later if needed
- **What happens if captain leaves during auto-picks?** Auto-picks continue (they're inevitable anyway)
- **Should organizer be able to disable auto-picks mid-draft?** Yes - add organizer override button
- **Show auto-pick countdown to spectators?** Yes - adds engagement and transparency

---

## Success Criteria

### Role Validation
- ✅ Captains cannot pick players for already-filled roles
- ✅ Player list updates dynamically as roles are filled
- ✅ Clear error messages when invalid pick attempted
- ✅ Works seamlessly with existing draft flow

### Automatic Picks
- ✅ Auto-picks execute when only 1 player available for role
- ✅ Captains receive clear notification before auto-picks start
- ✅ Auto-picks spaced out appropriately for overlay visibility
- ✅ Splash art celebrations work for auto-picked players
- ✅ No race conditions or duplicate picks
- ✅ Graceful handling of all edge cases
