defmodule AceAppWeb.ProfileLive do
  use AceAppWeb, :live_view

  alias AceApp.Auth

  @impl true
  def mount(_params, session, socket) do
    # Get current user from session token (similar to the plug logic)
    current_user = case session["user_session_token"] do
      nil -> nil
      token -> 
        case Auth.get_valid_user_session_by_token(token) do
          %{user: user} -> user
          nil -> nil
        end
    end
    
    # Redirect to home if not authenticated
    if current_user == nil do
      socket = 
        socket
        |> put_flash(:error, "You must be logged in to view your profile.")
        |> push_navigate(to: ~p"/")
      
      {:ok, socket}
    else
      # Get user's drafts and stats
      user_drafts = Auth.list_accessible_drafts(current_user)
      
      draft_stats = %{
        total_drafts: length(user_drafts),
        setup_drafts: Enum.count(user_drafts, &(&1.status == :setup)),
        active_drafts: Enum.count(user_drafts, &(&1.status == :active)),
        completed_drafts: Enum.count(user_drafts, &(&1.status == :completed))
      }
      
      socket = 
        socket
        |> assign(:current_user, current_user)
        |> assign(:user_drafts, user_drafts)
        |> assign(:draft_stats, draft_stats)
      
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "Profile")
  end

  defp get_draft_status_badge(draft) do
    case draft.status do
      :setup -> {"bg-yellow-500/20 text-yellow-400 ring-yellow-500/30", "Setup"}
      :active -> {"bg-green-500/20 text-green-400 ring-green-500/30", "Active"}
      :paused -> {"bg-orange-500/20 text-orange-400 ring-orange-500/30", "Paused"}
      :completed -> {"bg-blue-500/20 text-blue-400 ring-blue-500/30", "Completed"}
      _ -> {"bg-gray-500/20 text-gray-400 ring-gray-500/30", "Unknown"}
    end
  end
end