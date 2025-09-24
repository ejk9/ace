# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **AceApp** - a production-ready League of Legends draft tool built with Phoenix LiveView. The application provides real-time team drafting for competitive tournaments with professional stream integration, spectator engagement features, and comprehensive tournament management capabilities.

**Current Status:** Version 1.0 Production Release  
**Technology Stack:** Phoenix LiveView, PostgreSQL, Elixir/OTP  
**Architecture:** Real-time collaborative platform with zero in-memory state (full database persistence)

## Development Commands

### Project Setup
```bash
# Initial setup - installs deps, sets up database, populates game data
make setup

# Start development with all services (PostgreSQL, screenshot service)
make start

# Start with IEx shell for debugging
make start-iex

# Database management
make db-setup          # Create and migrate database
make db-reset          # Drop, create, migrate, and seed
make seed-dev          # Reset and seed with comprehensive test data
```

### Development Workflow
```bash
# Quality assurance (runs before commits)
make precommit         # Format, lint, compile with warnings as errors, test

# Individual commands
make test              # Run full test suite
make format            # Format Elixir code
make lint              # Run Credo linter
make compile           # Compile with warnings as errors

# Asset management
make assets            # Build assets for development
```

### Testing
```bash
# Core testing commands
mix test                    # Full test suite
mix test --failed          # Re-run only failed tests
mix test test/path/file.exs # Run specific test file

# End-to-end testing (Playwright)
npm run test:e2e           # Run E2E tests headless
npm run test:e2e:ui        # Run E2E tests with UI

# Test environment runs on port 4002
```

### Data Management
```bash
# Champion and game data
mix setup_game_data        # Populate champions and skins (automated)
mix populate_champions     # Champions only
mix populate_skins        # Skins only
mix backfill_champions    # Update existing player champion assignments

# Development data
make seed-dev             # Comprehensive development seed data with test URLs
```

### Production Deployment
```bash
# Production build
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release

# Database operations
MIX_ENV=prod mix ecto.migrate
MIX_ENV=prod mix setup_game_data --skip-migration
```

## Application Architecture

### Domain Contexts (lib/ace_app/)
- **`AceApp.Drafts`** - Core draft management, teams, players, picks, queue system
- **`AceApp.LoL`** - League of Legends game data (champions, skins, roles, regions)
- **`AceApp.MockDrafts`** - Dual-track prediction system for spectator engagement
- **`AceApp.Discord`** - Discord webhook integration for tournament notifications
- **`AceApp.Files`** - File upload management for team logos and CSV imports

### Web Layer (lib/ace_app_web/)
- **`live/`** - Phoenix LiveView modules for real-time interfaces
- **`controllers/`** - API endpoints and static page controllers  
- **`components/`** - Reusable UI components (timer, chat, navigation)

### Key LiveViews
- **`DraftSetupLive`** - Draft creation wizard with CSV import, team/player management
- **`DraftRoomLive`** - Main drafting interface for organizers, captains, and spectators
- **`MockDraftLive/PreDraftLive`** - Complete draft prediction submissions
- **`MockDraftLive/LivePredictionLive`** - Real-time pick-by-pick predictions
- **`DraftLinksLive`** - Share links and access stream overlays

### Real-time Architecture
- **Phoenix PubSub** - Event broadcasting for draft state changes
- **LiveView Streams** - Memory-efficient collection handling
- **Timer System** - GenServer-based countdown timers with visual components
- **Queue System** - Multi-pick team queues with automatic execution

### Database Schema Highlights
```sql
-- Core entities with full relationships
drafts          # Main draft configuration and state
teams           # Team information with logo support and pick order
players         # Player pool with LoL account data and champion assignments
picks           # Individual draft picks with timing data
pick_queues     # Team-specific pick queues with position ordering
chat_messages   # Real-time messaging system

-- Mock draft prediction system
mock_drafts           # Dual-track prediction configuration
mock_draft_submissions # Pre-draft complete predictions
mock_draft_participants # Live prediction participants
mock_draft_predictions # Individual pick predictions with scoring

-- League of Legends data
champions        # Game champion data from Riot API
champion_skins   # Skin variations with splash art URLs
```

## Stream Integration & Broadcasting

### OBS Overlays (priv/static/obs_examples/)
Production-ready HTML overlays for tournament streaming:

- **`draft_overlay.html`** - Main draft board with team rosters and live timer
- **`roster_overlay.html`** - Team overview with full screen optimization
- **`available_players.html`** - Role-grouped available players
- **Champion splash art popup system** - Full-screen player celebration with consistency

### Stream API Endpoints (/stream/:id/)
JSON endpoints for external integrations:
- **`overlay.json`** - Complete draft state with image pre-caching
- **`teams.json`** - Team rosters and composition analysis
- **`current.json`** - Current pick status and timer state
- **`available.json`** - Available players grouped by role

Access via Draft Links page after draft creation.

## Key Features & Systems

### Draft Management
- **Snake draft format** - Proper pick order calculation with visual timeline
- **Real-time collaboration** - Sub-second updates across unlimited participants
- **Advanced organizer controls** - Timeline scrubbing, rollback, undo, preview system
- **Queue system** - Multi-pick team queues with conflict resolution
- **Professional timer system** - Visual countdown with audio notifications

### Team & Player Management
- **Team logos** - Upload system (10MB, WebP/PNG/JPG/SVG) with smart fallbacks
- **CSV import/export** - Bulk data management with Google Sheets integration
- **Player accounts** - Multiple LoL accounts per player with rank tracking
- **Champion assignments** - Automated splash art system with skin consistency

### Mock Draft & Predictions
- **Track 1** - Pre-draft complete submissions with personalized URLs
- **Track 2** - Real-time pick-by-pick predictions during live drafts
- **Dual leaderboards** - Combined competition with separate scoring systems
- **Professional UI** - Click-to-select interface with progress tracking

### Discord Integration
- **Rich embed notifications** - Team colors, logos, tournament formatting
- **Champion splash art screenshots** - Automated capture and attachment
- **Webhook validation** - Real-time testing with error recovery
- **Event broadcasting** - Draft status, picks, milestones

## Authentication & Access Control

**Important:** This application uses a **custom token-based authentication system** rather than `phx.gen.auth`. Each draft generates unique tokens for different user roles.

### Token-Based Access Pattern
```elixir
# Router patterns for different user roles
live "/drafts/:token", DraftRoomLive, :organizer              # Organizer access
live "/drafts/spectator/:token", DraftRoomLive, :spectator    # Spectator access  
live "/drafts/team/:token", DraftRoomLive, :team             # Team captain access
```

### Role Assignment in LiveViews
The application determines user roles based on token validation in `mount/3`:
```elixir
# Role determination pattern
def mount(%{"token" => token}, _session, %{assigns: %{live_action: :organizer}} = socket) do
  case Drafts.get_draft_by_organizer_token(token) do
    nil -> redirect_with_error(socket)
    draft -> assign(socket, :user_role, :organizer)
  end
end
```

### User Role Types
- **`:organizer`** - Full draft control (setup, start, pause, timeline management)
- **`:captain`** - Team captain (can make picks for their team)
- **`:team_member`** - Team member (view team interface)
- **`:spectator`** - View-only access to draft progress

### Permission Patterns
Always validate user roles for restricted actions:
```elixir
# Server-side permission validation
def handle_event("start_draft", _params, %{assigns: %{user_role: :organizer}} = socket) do
  # Only organizers can start drafts
end

def handle_event("start_draft", _params, socket) do
  {:noreply, put_flash(socket, :error, "Only organizers can start drafts")}
end
```

### Template Role-Based Rendering
Use role-based conditionals in templates:
```html
<!-- Organizer-only controls -->
<%= if @user_role == :organizer do %>
  <button phx-click="start_draft">Start Draft</button>
<% end %>

<!-- Team-specific interface -->
<%= if @user_role in [:captain, :team_member] do %>
  <div class="team-interface">...</div>  
<% end %>
```

## Development Patterns

### Phoenix LiveView Best Practices
- Use `~H` sigil and .html.heex files exclusively
- Leverage `Phoenix.Component.form/1` and `to_form/2` for forms
- Use LiveView streams for all collections to prevent memory issues
- Prefer `<.link navigate={href}>` over deprecated navigation functions
- Real-time updates via Phoenix PubSub with selective broadcasting

### Elixir Code Standards
- Pattern matching over conditional logic where appropriate
- `{:ok, result}` and `{:error, reason}` patterns for error handling
- OTP integration with GenServers and DynamicSupervisor for system processes
- Complete database persistence (no in-memory state for recovery capability)

### Error Handling
- Comprehensive server-side validation for all user inputs
- Graceful degradation when non-critical components fail
- User-friendly error messages with actionable guidance
- Automatic recovery systems for temporary failures

### Security
- Token-based access with unique links per draft and role
- Role-based permissions with server-side validation
- File upload security (content-type validation, size limits)
- CSRF protection on all forms

## Testing Strategy

### Test Structure
- **Unit tests** - All context functions and business logic
- **LiveView tests** - User interactions and real-time updates
- **Integration tests** - End-to-end workflows and system interactions
- **Playwright E2E tests** - Browser automation testing

### Common Test Patterns
```elixir
# Context testing
test "creates draft with valid attributes" do
  assert {:ok, draft} = Drafts.create_draft(valid_attrs)
end

# LiveView testing
test "organizer can start draft", %{conn: conn} do
  {:ok, view, html} = live(conn, "/drafts/#{draft.id}/room/#{draft.organizer_token}")
  assert render_click(view, "start_draft")
end
```

## Production Considerations

### Performance
- Database query optimization with proper indexing and preloading
- Real-time PubSub optimization with selective subscriptions
- Memory management via LiveView streams and proper garbage collection
- Concurrent draft handling tested with 10+ simultaneous drafts

### Monitoring
- Phoenix LiveDashboard at `/dev/dashboard` with custom telemetry
- System metrics (VM, memory, database performance, connection health)
- Business metrics (draft completion rates, user engagement, system health)
- Error tracking and performance analytics

### Deployment
- Docker compose setup for development (PostgreSQL, screenshot service)
- Environment-based configuration with proper secrets management
- Health checks and graceful shutdown procedures
- Database migration strategies for zero-downtime deployments

## Common Tasks & Troubleshooting

### Development Setup Issues
- Ensure PostgreSQL is running: `make db-start`
- Reset environment: `make clean-all && make setup`
- Check service health: `docker compose ps`

### Testing Issues
- E2E tests run on port 4002 with separate test database
- Ensure test database is migrated: `MIX_ENV=test mix ecto.migrate`
- Use `make seed-dev` for realistic development data

### Performance Issues
- Check LiveDashboard at `/dev/dashboard` for system metrics
- Database query analysis via Ecto logging
- PubSub monitoring for event broadcast efficiency

### Champion Data Issues
- Update game data: `mix setup_game_data --force-update`
- Backfill player assignments: `mix backfill_champions`
- Check champion/skin consistency in database

## Integration Points

### External Services
- **Community Dragon CDN** - Champion splash art with automatic patch detection
- **Discord API** - Webhook notifications with screenshot attachments
- **Google Sheets** - CSV export integration via IMPORTDATA formula
- **OBS Studio** - Browser source overlays for tournament streaming

### File Management
- Team logo uploads stored in `priv/static/uploads/`
- Screenshots generated in `priv/static/screenshots/`
- Static assets served via Phoenix endpoint configuration
- CSV templates available for download in draft setup

This application represents a production-ready League of Legends tournament management platform with comprehensive real-time features, professional stream integration, and sophisticated spectator engagement systems.