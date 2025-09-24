defmodule AceAppWeb.Router do
  use AceAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AceAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :optional_auth do
    plug AceAppWeb.Plugs.OptionalAuth
  end

  # Authentication Routes
  scope "/auth", AceAppWeb do
    pipe_through :browser

    get "/discord", AuthController, :discord_redirect
    get "/discord/callback", AuthController, :discord_callback
    delete "/logout", AuthController, :logout
  end

  scope "/", AceAppWeb do
    pipe_through [:browser, :optional_auth]

    get "/", PageController, :home

    # User Profile (requires authentication)
    live "/profile", ProfileLive, :show

    # Drafts Listing (now with optional authentication)
    live "/drafts", DraftsLive, :index

    # Draft Creation (regular controller to avoid LiveView history issues)
    get "/drafts/new", DraftController, :new
    post "/drafts", DraftController, :create
    
    # Draft Setup (LiveView for editing existing drafts)
    live "/drafts/:draft_id/setup", DraftSetupLive, :edit

    # Draft Room
    live "/drafts/:id/room", DraftRoomLive, :show

    # CSV Import
    live "/drafts/:draft_id/csv-import", CsvImportLive, :index

    # Draft Links
    live "/drafts/links/:token", DraftLinksLive, :show

    # Draft Access Routes
    live "/drafts/:token", DraftRoomLive, :organizer
    live "/drafts/spectator/:token", DraftRoomLive, :spectator
    live "/drafts/team/:token", DraftRoomLive, :team

    # Screenshot endpoints
    get "/screenshots/player-popup", ScreenshotController, :player_popup
  end

  # Mock Draft Routes
  scope "/mock-drafts", AceAppWeb.MockDraftLive do
    pipe_through :browser
    
    # Track 1: Complete Draft Submissions
    live "/:token/predraft", PreDraftLive, :index
    live "/:token/predraft/:submission_token", PreDraftLive, :existing_submission
    
    # Track 2: Real-Time Predictions  
    live "/:token/live", LivePredictionLive, :index
    live "/:token/participant/:participant_token", ParticipantViewLive, :index
    
    # Combined Leaderboards
    live "/:token/leaderboard", LeaderboardLive, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", AceAppWeb do
    pipe_through :api

    get "/drafts/:id/status.csv", ApiController, :draft_status_csv
    get "/drafts/:id/teams.csv", ApiController, :team_info_csv
  end

  # Stream overlay endpoints for OBS integration
  scope "/stream", AceAppWeb do
    pipe_through :api

    get "/:id/overlay.json", StreamController, :overlay
    get "/:id/teams.json", StreamController, :teams
    get "/:id/timeline.json", StreamController, :timeline
    get "/:id/current.json", StreamController, :current
    get "/:id/roster.json", StreamController, :roster
    get "/:id/available.json", StreamController, :available_players
  end

  # HTML overlay pages for direct OBS use
  scope "/overlay", AceAppWeb do
    pipe_through :browser

    get "/:id/draft", OverlayController, :draft_overlay
    get "/:id/current-pick", OverlayController, :current_pick
    get "/:id/roster", OverlayController, :roster
    get "/:id/available", OverlayController, :available_players
  end

  # Mock Draft API endpoints (TODO: Implement MockDraftController)
  # scope "/api/mock-drafts", AceAppWeb.API do
  #   pipe_through :api
  #   
  #   # Stream graphics (JSON for OBS)
  #   get "/:token/stream_overlay.json", MockDraftController, :stream_overlay
  #   
  #   # CSV exports
  #   get "/:token/results.csv", MockDraftController, :results_csv
  #   get "/:token/submissions.csv", MockDraftController, :submissions_csv
  #   
  #   # External webhook endpoints (future)
  #   post "/:token/webhook", MockDraftController, :webhook
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ace_app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AceAppWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
