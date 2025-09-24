defmodule AceAppWeb.DraftsLive do
  use AceAppWeb, :live_view

  alias AceApp.Auth
  alias AceApp.Drafts

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
    
    drafts = Auth.list_accessible_drafts(current_user)
    
    socket = 
      socket
      |> assign(:drafts, drafts)
      |> assign(:current_user, current_user)
    
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Drafts")
  end

  @impl true
  def handle_event("toggle_visibility", %{"draft_id" => draft_id}, socket) do
    case Drafts.get_draft!(draft_id) do
      draft when draft.user_id == socket.assigns.current_user.id or socket.assigns.current_user.is_admin ->
        new_visibility = if draft.visibility == :public, do: :private, else: :public
        
        case Drafts.update_draft(draft, %{visibility: new_visibility}) do
          {:ok, _updated_draft} ->
            # Refresh the drafts list
            current_user = socket.assigns.current_user
            updated_drafts = Auth.list_accessible_drafts(current_user)
            
            socket = 
              socket
              |> assign(:drafts, updated_drafts)
              |> put_flash(:info, "Draft visibility updated to #{new_visibility}")
            
            {:noreply, socket}
            
          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update draft visibility")}
        end
        
      _draft ->
        {:noreply, put_flash(socket, :error, "You don't have permission to modify this draft")}
    end
  rescue
    Ecto.NoResultsError ->
      {:noreply, put_flash(socket, :error, "Draft not found")}
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

  defp format_created_at(created_at) do
    case created_at do
      %DateTime{} = dt ->
        dt
        |> DateTime.shift_zone!("Etc/UTC")
        |> Calendar.strftime("%b %d, %Y at %I:%M %p UTC")
      
      %NaiveDateTime{} = ndt ->
        ndt
        |> Calendar.strftime("%b %d, %Y at %I:%M %p")
      
      _ -> "Unknown"
    end
  end

  defp get_teams_count(draft) do
    case draft.teams do
      teams when is_list(teams) -> length(teams)
      _ -> 0
    end
  end

  defp get_draft_progress(draft) do
    case draft.status do
      :setup -> "Not started"
      :active -> "In progress"
      :paused -> "Paused"
      :completed -> "Finished"
      _ -> "Unknown"
    end
  end

  @impl true
  def handle_event("archive_draft", %{"draft-id" => draft_id}, socket) do
    case Drafts.get_draft(draft_id) do
      %{status: status} = draft when status in [:active, :paused] ->
        case Drafts.update_draft(draft, %{status: :completed}) do
          {:ok, _draft} ->
            updated_drafts = Drafts.list_drafts()
            {:noreply, 
             socket
             |> assign(:drafts, updated_drafts)
             |> put_flash(:info, "Draft has been archived successfully")}
          
          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to archive draft")}
        end
      
      %{status: :setup} ->
        {:noreply, put_flash(socket, :error, "Cannot archive draft in setup phase. Use delete instead.")}
      
      %{status: :completed} ->
        {:noreply, put_flash(socket, :error, "Draft is already archived")}
      
      nil ->
        {:noreply, put_flash(socket, :error, "Draft not found")}
    end
  end

  def handle_event("delete_draft", %{"draft-id" => draft_id}, socket) do
    case Drafts.get_draft(draft_id) do
      %{status: :setup} = draft ->
        case Drafts.delete_draft(draft) do
          {:ok, _draft} ->
            updated_drafts = Drafts.list_drafts()
            {:noreply, 
             socket
             |> assign(:drafts, updated_drafts)
             |> put_flash(:info, "Draft has been deleted successfully")}
          
          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to delete draft")}
        end
      
      %{status: status} when status in [:active, :paused, :completed] ->
        {:noreply, put_flash(socket, :error, "Cannot delete active, paused, or completed drafts. Use archive instead.")}
      
      nil ->
        {:noreply, put_flash(socket, :error, "Draft not found")}
    end
  end
end