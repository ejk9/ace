defmodule AceAppWeb.Components.SidebarNav do
  @moduledoc """
  Sidebar navigation component for draft-related pages.
  """
  use AceAppWeb, :live_component

  alias AceApp.Drafts

  @impl true
  def update(%{refresh: true} = assigns, socket) do
    # Force refresh of drafts list
    drafts = Drafts.list_drafts()

    {:ok,
     socket
     |> assign(Map.delete(assigns, :refresh))
     |> assign(:drafts, drafts)}
  end

  @impl true
  def update(assigns, socket) do
    drafts = Drafts.list_drafts()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:drafts, drafts)}
  end

  @impl true
  def handle_event("delete_draft", %{"draft-id" => draft_id}, socket) do
    case Drafts.delete_draft(Drafts.get_draft!(draft_id)) do
      {:ok, _deleted_draft} ->
        # Refresh the drafts list
        drafts = Drafts.list_drafts()
        {:noreply, assign(socket, :drafts, drafts)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed left-0 top-0 h-full w-64 bg-gradient-to-b from-slate-900 to-slate-800 shadow-xl z-40">
      <!-- Header -->
      <div class="p-6 border-b border-slate-700">
        <div class="flex items-center">
          <div class="flex items-center justify-center w-10 h-10 rounded-lg bg-gradient-to-br from-yellow-500 to-yellow-600 text-slate-900 mr-3 shadow-lg">
            <svg class="w-6 h-6 font-bold" fill="currentColor" viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M3 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm0 4a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div>
            <h2 class="text-lg font-bold text-white">Draft Tool</h2>
            <p class="text-sm text-slate-400">Navigation</p>
          </div>
        </div>
      </div>
      
    <!-- Navigation Menu -->
      <nav class="flex-1 px-4 py-6 space-y-2">
        <!-- Home Link -->
        <a
          href="/"
          class="flex items-center px-4 py-3 text-sm font-medium text-slate-300 rounded-lg hover:bg-slate-700 hover:text-white transition-colors duration-200 group"
        >
          <svg
            class="w-5 h-5 mr-3 text-slate-400 group-hover:text-yellow-500"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z" />
          </svg>
          Home
        </a>
        
    <!-- Create New Draft -->
        <a
          href="/drafts/new"
          data-phx-link="redirect"
          class="flex items-center px-4 py-3 text-sm font-medium text-slate-300 rounded-lg hover:bg-slate-700 hover:text-white transition-colors duration-200 group"
        >
          <svg
            class="w-5 h-5 mr-3 text-slate-400 group-hover:text-yellow-500"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fill-rule="evenodd"
              d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z"
              clip-rule="evenodd"
            />
          </svg>
          Create New Draft
        </a>
        
    <!-- Divider -->
        <div class="border-t border-slate-700 my-4"></div>
        
    <!-- Active Drafts Section -->
        <div class="px-4 py-2">
          <h3 class="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-3">
            Active Drafts
          </h3>
          <%= if Enum.empty?(@drafts) do %>
            <p class="text-sm text-slate-500 italic">No active drafts</p>
          <% else %>
            <div class="space-y-1">
              <%= for draft <- @drafts do %>
                <a
                  href={
                    if draft.status == :setup,
                      do: "/drafts/new?draft_id=#{draft.id}",
                      else: "/drafts/links/#{draft.organizer_token}"
                  }
                  class="flex items-center justify-between px-3 py-2 text-sm text-slate-300 rounded-md hover:bg-slate-700 hover:text-white transition-colors duration-200 group"
                >
                  <div class="flex items-center">
                    <div class="flex items-center justify-center w-6 h-6 rounded bg-gradient-to-br from-blue-500 to-blue-600 text-white mr-3 text-xs font-bold">
                      {String.first(draft.name)}
                    </div>
                    <div class="flex-1">
                      <div class="font-medium truncate">{draft.name}</div>
                      <div class="text-xs text-slate-500">
                        <%= case draft.status do %>
                          <% :setup -> %>
                            Setup
                          <% :draft -> %>
                            Drafting
                          <% :complete -> %>
                            Complete
                          <% _ -> %>
                            Unknown
                        <% end %>
                        · {if Ecto.assoc_loaded?(draft.teams), do: length(draft.teams), else: "?"} teams
                      </div>
                    </div>
                  </div>
                  <div class="flex items-center space-x-1">
                    <%= if draft.status == :setup do %>
                      <button
                        phx-click="delete_draft"
                        phx-value-draft-id={draft.id}
                        phx-target={@myself}
                        class="p-1 text-red-500 hover:text-red-400 hover:bg-red-500/10 rounded transition-colors duration-200"
                        data-confirm="Are you sure you want to delete this draft?"
                      >
                        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                          <path
                            fill-rule="evenodd"
                            d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z"
                            clip-rule="evenodd"
                          />
                          <path
                            fill-rule="evenodd"
                            d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                            clip-rule="evenodd"
                          />
                        </svg>
                      </button>
                    <% end %>
                    <svg
                      class="w-4 h-4 text-slate-500 group-hover:text-slate-300"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </div>
                </a>
              <% end %>
            </div>
          <% end %>
        </div>
      </nav>
      
    <!-- Footer -->
      <div class="p-4 border-t border-slate-700">
        <div class="text-xs text-slate-500 text-center">
          League of Legends Draft Tool
        </div>
      </div>
    </div>
    """
  end
end
