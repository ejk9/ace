defmodule AceAppWeb.OverlayController do
  use AceAppWeb, :controller

  @doc """
  Serves the draft overlay HTML page with the draft ID pre-configured.
  This allows users to copy the URL directly into OBS without manual configuration.
  Supports query parameters like ?logo_only=true for display customization.
  """
  def draft_overlay(conn, %{"id" => id} = params) do
    # Validate that the draft exists
    case validate_draft_id(id) do
      {:ok, draft_id} ->
        # Read and serve the HTML file with the draft ID and query params injected
        html_content = get_draft_overlay_html(draft_id, params)
        
        conn
        |> put_resp_content_type("text/html")
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("pragma", "no-cache")
        |> put_resp_header("expires", "0")
        |> send_resp(200, html_content)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_resp_content_type("text/html")
        |> send_resp(404, """
        <!DOCTYPE html>
        <html>
        <head><title>Draft Not Found</title></head>
        <body>
          <h1>Draft Not Found</h1>
          <p>The draft with ID "#{id}" could not be found.</p>
          <p>Please check the draft ID and try again.</p>
        </body>
        </html>
        """)
    end
  end

  @doc """
  Serves the current pick overlay HTML page with the draft ID pre-configured.
  """
  def current_pick(conn, %{"id" => id}) do
    case validate_draft_id(id) do
      {:ok, draft_id} ->
        html_content = get_current_pick_html(draft_id)
        
        conn
        |> put_resp_content_type("text/html")
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("pragma", "no-cache")
        |> put_resp_header("expires", "0")
        |> send_resp(200, html_content)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_resp_content_type("text/html")
        |> send_resp(404, """
        <!DOCTYPE html>
        <html>
        <head><title>Draft Not Found</title></head>
        <body>
          <h1>Draft Not Found</h1>
          <p>The draft with ID "#{id}" could not be found.</p>
          <p>Please check the draft ID and try again.</p>
        </body>
        </html>
        """)
    end
  end

  @doc """
  Serves the team rosters overlay HTML page with the draft ID pre-configured.
  """
  def roster(conn, %{"id" => id}) do
    case validate_draft_id(id) do
      {:ok, draft_id} ->
        html_content = get_roster_overlay_html(draft_id)
        
        conn
        |> put_resp_content_type("text/html")
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("pragma", "no-cache")
        |> put_resp_header("expires", "0")
        |> send_resp(200, html_content)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_resp_content_type("text/html")
        |> send_resp(404, """
        <!DOCTYPE html>
        <html>
        <head><title>Draft Not Found</title></head>
        <body>
          <h1>Draft Not Found</h1>
          <p>The draft with ID "#{id}" could not be found.</p>
          <p>Please check the draft ID and try again.</p>
        </body>
        </html>
        """)
    end
  end

  @doc """
  Serves the available players overlay HTML page with the draft ID pre-configured.
  """
  def available_players(conn, %{"id" => id}) do
    case validate_draft_id(id) do
      {:ok, draft_id} ->
        html_content = get_available_players_html(draft_id)
        
        conn
        |> put_resp_content_type("text/html")
        |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
        |> put_resp_header("pragma", "no-cache")
        |> put_resp_header("expires", "0")
        |> send_resp(200, html_content)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_resp_content_type("text/html")
        |> send_resp(404, """
        <!DOCTYPE html>
        <html>
        <head><title>Draft Not Found</title></head>
        <body>
          <h1>Draft Not Found</h1>
          <p>The draft with ID "#{id}" could not be found.</p>
          <p>Please check the draft ID and try again.</p>
        </body>
        </html>
        """)
    end
  end

  # Private helper functions

  defp validate_draft_id(id) do
    case Integer.parse(id) do
      {draft_id, ""} ->
        try do
          _draft = AceApp.Drafts.get_draft_with_associations!(draft_id)
          {:ok, draft_id}
        rescue
          Ecto.NoResultsError ->
            {:error, :not_found}
        end
      _ ->
        {:error, :not_found}
    end
  end

  defp get_draft_overlay_html(draft_id, params) do
    # Read the template HTML file
    template_path = Path.join([:code.priv_dir(:ace_app), "static", "obs_examples", "draft_overlay.html"])
    template_content = File.read!(template_path)
    
    # Build query parameter injections
    query_params_js = build_query_params_js(params)
    
    # Inject the draft ID and query parameters directly into the JavaScript
    template_content
    |> String.replace(
      "const DRAFT_ID = urlParams.get('draft_id');",
      "const DRAFT_ID = '#{draft_id}';"
    )
    |> String.replace(
      "const LOGO_ONLY_MODE = urlParams.get('logo_only') === 'true';",
      query_params_js
    )
  end

  defp build_query_params_js(params) do
    logo_only = Map.get(params, "logo_only", "false")
    "const LOGO_ONLY_MODE = #{logo_only === "true"};"
  end

  defp get_current_pick_html(draft_id) do
    # Read the template HTML file
    template_path = Path.join([:code.priv_dir(:ace_app), "static", "obs_examples", "current_pick.html"])
    template_content = File.read!(template_path)
    
    # Inject the draft ID directly into the JavaScript
    String.replace(
      template_content,
      "const DRAFT_ID = urlParams.get('draft_id');",
      "const DRAFT_ID = '#{draft_id}';"
    )
  end

  defp get_roster_overlay_html(draft_id) do
    # Read the template HTML file
    template_path = Path.join([:code.priv_dir(:ace_app), "static", "obs_examples", "roster_overlay.html"])
    template_content = File.read!(template_path)
    
    # Inject the draft ID directly into the JavaScript
    String.replace(
      template_content,
      "const DRAFT_ID = urlParams.get('draft_id');",
      "const DRAFT_ID = '#{draft_id}';"
    )
  end

  defp get_available_players_html(draft_id) do
    # Read the template HTML file
    template_path = Path.join([:code.priv_dir(:ace_app), "static", "obs_examples", "available_players.html"])
    template_content = File.read!(template_path)
    
    # Inject the draft ID directly into the JavaScript
    String.replace(
      template_content,
      "const DRAFT_ID = urlParams.get('draft_id');",
      "const DRAFT_ID = '#{draft_id}';"
    )
  end
end