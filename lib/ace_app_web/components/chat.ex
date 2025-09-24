defmodule AceAppWeb.Components.Chat do
  use AceAppWeb, :live_component
  alias AceApp.Drafts

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{action: :new_global_message, message: message}, socket) do
    # Add new global message to the end of the list
    global_messages = socket.assigns.global_messages ++ [message]

    # Increment unread count if not viewing global channel
    unread_global =
      if socket.assigns.active_channel != "global" do
        socket.assigns.unread_global + 1
      else
        socket.assigns.unread_global
      end

    {:ok,
     socket
     |> assign(:global_messages, global_messages)
     |> assign(:unread_global, unread_global)}
  end

  def update(%{action: :new_team_message, message: message}, socket) do
    # Add new team message to the end of the list if it's for the current team
    if socket.assigns.current_team != nil && message.team_id == socket.assigns.current_team.id do
      team_messages = socket.assigns.team_messages ++ [message]

      # Increment unread count if not viewing team channel
      unread_team =
        if socket.assigns.active_channel != "team" do
          socket.assigns.unread_team + 1
        else
          socket.assigns.unread_team
        end

      {:ok,
       socket
       |> assign(:team_messages, team_messages)
       |> assign(:unread_team, unread_team)}
    else
      {:ok, socket}
    end
  end

  def update(%{action: :message_deleted, message_id: message_id}, socket) do
    # Remove deleted message from both lists
    global_messages = Enum.reject(socket.assigns.global_messages, &(&1.id == message_id))
    team_messages = Enum.reject(socket.assigns.team_messages, &(&1.id == message_id))

    {:ok,
     socket
     |> assign(:global_messages, global_messages)
     |> assign(:team_messages, team_messages)}
  end

  def update(%{draft: draft, user_role: user_role, current_team: current_team} = assigns, socket) do
    # Get initial chat messages
    global_messages = Drafts.get_recent_chat_messages(draft.id, 50)

    team_messages =
      if current_team != nil do
        Drafts.get_recent_team_chat_messages(draft.id, current_team.id, 50)
      else
        []
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:global_messages, global_messages)
     |> assign(:team_messages, team_messages)
     |> assign(:active_channel, "global")
     |> assign(:form, to_form(%{"message" => ""}, as: :chat))
     |> assign(:sender_name, get_sender_name(user_role, current_team))
     |> assign(:unread_global, 0)
     |> assign(:unread_team, 0)}
  end

  @impl true
  def handle_event("send_message", %{"chat" => %{"message" => content}}, socket)
      when content != "" do
    draft = socket.assigns.draft
    user_role = socket.assigns.user_role
    sender_name = socket.assigns.sender_name
    active_channel = socket.assigns.active_channel

    case active_channel do
      "global" ->
        case Drafts.send_chat_message(draft.id, atom_to_string(user_role), sender_name, content) do
          {:ok, message} ->
            # Broadcast to all clients
            Phoenix.PubSub.broadcast(
              AceApp.PubSub,
              "draft:#{draft.id}:chat",
              {:new_global_message, message}
            )

            {:noreply, assign(socket, :form, to_form(%{"message" => ""}, as: :chat))}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to send message")}
        end

      "team" ->
        if socket.assigns.current_team != nil and can_send_team_messages?(user_role) do
          case Drafts.send_team_chat_message(
                 draft.id,
                 socket.assigns.current_team.id,
                 atom_to_string(user_role),
                 sender_name,
                 content
               ) do
            {:ok, message} ->
              # Broadcast to team members
              Phoenix.PubSub.broadcast(
                AceApp.PubSub,
                "draft:#{draft.id}:team:#{socket.assigns.current_team.id}:chat",
                {:new_team_message, message}
              )

              {:noreply, assign(socket, :form, to_form(%{"message" => ""}, as: :chat))}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to send team message")}
          end
        else
          cond do
            socket.assigns.current_team == nil ->
              {:noreply, put_flash(socket, :error, "You must be on a team to send team messages")}

            not can_send_team_messages?(user_role) ->
              {:noreply,
               put_flash(socket, :error, "You don't have permission to send team messages")}
          end
        end
    end
  end

  def handle_event("send_message", %{"chat" => %{"message" => ""}}, socket) do
    {:noreply, socket}
  end

  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_message", %{"chat" => params}, socket) do
    form = to_form(params, as: :chat)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("switch_channel", %{"channel" => channel}, socket) do
    # Reset unread count for the channel being switched to
    updated_socket =
      case channel do
        "global" -> assign(socket, :unread_global, 0)
        "team" -> assign(socket, :unread_team, 0)
        _ -> socket
      end

    {:noreply, assign(updated_socket, :active_channel, channel)}
  end

  @impl true
  def handle_event("delete_message", %{"message_id" => message_id}, socket) do
    if socket.assigns.user_role == :organizer do
      case Drafts.get_chat_message!(message_id) do
        message ->
          case Drafts.delete_chat_message(message) do
            {:ok, _} ->
              # Broadcast deletion
              Phoenix.PubSub.broadcast(
                AceApp.PubSub,
                "draft:#{socket.assigns.draft.id}:chat",
                {:message_deleted, message_id}
              )

              {:noreply, socket}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to delete message")}
          end
      end
    else
      {:noreply, put_flash(socket, :error, "Only organizers can delete messages")}
    end
  end

  # Helper functions

  defp get_sender_name(:organizer, _), do: "Organizer"
  defp get_sender_name(:captain, %{name: team_name}), do: "#{team_name} Captain"
  defp get_sender_name(:spectator, _), do: generate_random_spectator_name()

  defp get_sender_name(:team_member, %{name: team_name}),
    do: "#{team_name} #{generate_random_spectator_name()}"

  defp get_sender_name(_, _), do: "Unknown"

  defp atom_to_string(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp atom_to_string(string), do: string

  defp format_timestamp(datetime) do
    datetime
    |> Calendar.strftime("%H:%M UTC")
  end

  defp can_send_team_messages?(user_role) do
    user_role in [:captain, :organizer, :team_member]
  end

  defp generate_random_spectator_name do
    adjectives = [
      "Swift",
      "Bold",
      "Wise",
      "Fierce",
      "Silent",
      "Brave",
      "Quick",
      "Sharp",
      "Bright",
      "Clever"
    ]

    nouns = [
      "Eagle",
      "Wolf",
      "Tiger",
      "Fox",
      "Hawk",
      "Lion",
      "Bear",
      "Raven",
      "Dragon",
      "Phoenix"
    ]

    adjective = Enum.random(adjectives)
    noun = Enum.random(nouns)
    number = :rand.uniform(99)

    "#{adjective}#{noun}#{number}"
  end

  # Message rendering function component
  def render_message(assigns) do
    ~H"""
    <div class={[
      "flex flex-col space-y-1",
      case @message.message_type do
        "system" -> "opacity-75"
        "announcement" -> "bg-yellow-900/20 border border-yellow-700/50 rounded-lg p-3"
        _ -> ""
      end
    ]}>
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-2">
          <!-- Sender Icon -->
          <div class={[
            "w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium",
            case @message.sender_type do
              "organizer" -> "bg-red-600 text-white"
              "captain" -> "bg-blue-600 text-white"
              "spectator" -> "bg-gray-600 text-white"
              "system" -> "bg-green-600 text-white"
              _ -> "bg-slate-600 text-white"
            end
          ]}>
            <%= case @message.sender_type do %>
              <% "organizer" -> %>
                🛡️
              <% "captain" -> %>
                👑
              <% "spectator" -> %>
                👁️
              <% "system" -> %>
                🤖
              <% _ -> %>
                ?
            <% end %>
          </div>
          
    <!-- Sender Name -->
          <span class={[
            "font-medium text-sm",
            case @message.sender_type do
              "organizer" -> "text-red-400"
              "captain" -> "text-blue-400"
              "spectator" -> "text-gray-400"
              "system" -> "text-green-400"
              _ -> "text-slate-400"
            end
          ]}>
            {@message.sender_name}
          </span>
          
    <!-- Timestamp -->
          <span class="text-xs text-slate-500">
            {format_timestamp(@message.inserted_at)}
          </span>
        </div>
        
    <!-- Delete Button (Organizer Only) -->
        <%= if assigns[:user_role] == :organizer and @message.sender_type != "system" do %>
          <button
            phx-click="delete_message"
            phx-value-message_id={@message.id}
            phx-target={@myself}
            class="text-slate-500 hover:text-red-400 transition-colors"
            title="Delete message"
          >
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path
                fill-rule="evenodd"
                d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9zM4 5a2 2 0 012-2v1a1 1 0 001 1h6a1 1 0 001-1V3a2 2 0 012 2v6a2 2 0 01-2 2H6a2 2 0 01-2-2V5zM8 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z"
                clip-rule="evenodd"
              />
            </svg>
          </button>
        <% end %>
      </div>
      
    <!-- Message Content -->
      <div class={[
        "text-sm leading-relaxed break-words",
        case @message.message_type do
          "system" -> "text-slate-400 italic"
          "announcement" -> "text-yellow-200 font-medium"
          _ -> "text-slate-200"
        end
      ]}>
        {@message.content}
      </div>
    </div>
    """
  end
end
