defmodule AceAppWeb.Components.Timer do
  @moduledoc """
  Timer component for displaying draft pick countdown timers.
  
  Provides visual countdown display with different states and warning indicators.
  """
  
  use Phoenix.Component
  
  @doc """
  Renders a countdown timer with visual states.
  
  ## Examples
  
      <.timer timer_state={@timer_state} current_team={@current_team} />
      
      <.timer 
        timer_state={@timer_state} 
        current_team={@current_team}
        size="large"
        show_team_name={true} 
      />
  """
  attr :timer_state, :map, required: true, doc: "Timer state from DraftTimer"
  attr :current_team, :map, default: nil, doc: "Currently picking team"
  attr :size, :string, default: "medium", values: ~w(small medium large)
  attr :show_team_name, :boolean, default: true, doc: "Whether to show team name"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  
  def timer(assigns) do
    ~H"""
    <div 
      id={"timer-#{@timer_state.current_team_id || "main"}"}
      phx-hook="ClientTimer"
      class={[
        "timer-container",
        "flex flex-col items-center justify-center",
        timer_container_classes(@timer_state, @size),
        @class
      ]}
    >
      <!-- Timer Circle with Progress -->
      <div class="relative">
        <svg class={["timer-circle", circle_size_classes(@size)]} viewBox="0 0 120 120">
          <!-- Background circle -->
          <circle
            cx="60"
            cy="60"
            r="54"
            fill="none"
            stroke="currentColor"
            stroke-width="12"
            class="text-gray-200 dark:text-gray-700"
          />
          <!-- Progress circle -->
          <circle
            cx="60"
            cy="60"
            r="54"
            fill="none"
            stroke="currentColor"
            stroke-width="12"
            stroke-linecap="round"
            class={["timer-progress", progress_circle_classes(@timer_state)]}
            style={progress_circle_style(@timer_state)}
            transform="rotate(-90 60 60)"
            data-timer-progress
          />
        </svg>
        
        <!-- Timer Text Display -->
        <div class="absolute inset-0 flex flex-col items-center justify-center">
          <div 
            class={["timer-text", text_size_classes(@size), timer_text_classes(@timer_state)]}
            data-timer-display
            data-timer-status={@timer_state.status}
            data-remaining-seconds={@timer_state.remaining_seconds || 0}
          >
            <%= format_time(@timer_state) %>
          </div>
          
          <!-- Timer Status -->
          <div class={["timer-status", status_size_classes(@size)]}>
            <%= timer_status_text(@timer_state) %>
          </div>
        </div>
      </div>
      
      <!-- Team Information -->
      <div :if={@show_team_name and not is_nil(@current_team)} class={["timer-team-info", "mt-2 text-center", team_info_size_classes(@size)]}>
        <div class="font-semibold text-gray-700 dark:text-gray-300">
          <%= @current_team.name %>
        </div>
        <div class="text-sm text-gray-500 dark:text-gray-400">
          picking...
        </div>
      </div>
      
      <!-- Timer Controls removed - now handled in main template with proper permissions -->
    </div>
    """
  end
  
  @doc """
  Renders a compact timer display for headers or sidebars.
  """
  attr :timer_state, :map, required: true
  attr :current_team, :map, default: nil
  attr :class, :string, default: ""
  
  def compact_timer(assigns) do
    ~H"""
    <div 
      id={"compact-timer-#{@timer_state.current_team_id || "main"}"}
      phx-hook="ClientTimer"
      class={[
        "compact-timer flex items-center gap-2 px-3 py-2 rounded-lg",
        compact_timer_classes(@timer_state),
        @class
      ]}
    >
      <!-- Timer Icon/Indicator -->
      <div class={["timer-indicator w-3 h-3 rounded-full", timer_indicator_classes(@timer_state)]}>
      </div>
      
      <!-- Time Display -->
      <div 
        class={["timer-compact-text font-mono text-sm font-semibold", compact_text_classes(@timer_state)]}
        data-timer-display
        data-timer-status={@timer_state.status}
        data-remaining-seconds={@timer_state.remaining_seconds || 0}
      >
        <%= format_time(@timer_state) %>
      </div>
      
      <!-- Team Name (if space allows) -->
      <div :if={not is_nil(@current_team) and @timer_state.status == :running} class="text-xs text-gray-600 dark:text-gray-300 truncate max-w-20">
        <%= @current_team.name %>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders timer warnings and alerts.
  """
  attr :timer_state, :map, required: true
  attr :class, :string, default: ""
  
  def timer_alert(assigns) do
    ~H"""
    <div :if={show_timer_alert?(@timer_state)} class={[
      "timer-alert p-3 rounded-lg border-2 animate-pulse",
      alert_classes(@timer_state),
      @class
    ]}>
      <div class="flex items-center gap-2">
        <div class="timer-alert-icon text-xl">
          <%= alert_icon(@timer_state) %>
        </div>
        <div class="timer-alert-text">
          <div class="font-semibold">
            <%= alert_title(@timer_state) %>
          </div>
          <div class="text-sm">
            <%= alert_message(@timer_state) %>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  # Private helper functions
  
  defp format_time(%{remaining_seconds: seconds}) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    
    if minutes > 0 do
      "#{minutes}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
    else
      "#{remaining_seconds}s"
    end
  end
  
  defp format_time(_), do: "--"
  
  defp timer_status_text(%{status: :running}), do: "PICKING"
  defp timer_status_text(%{status: :paused}), do: "PAUSED"
  defp timer_status_text(%{status: :expired}), do: "TIME UP!"
  defp timer_status_text(_), do: "WAITING"
  
  defp timer_container_classes(%{status: :running}, size) do
    base = case size do
      "small" -> "w-20 h-20"
      "medium" -> "w-32 h-32"
      "large" -> "w-48 h-48"
    end
    [base, "text-blue-600 dark:text-blue-400"]
  end
  
  defp timer_container_classes(%{status: :expired}, size) do
    base = case size do
      "small" -> "w-20 h-20"
      "medium" -> "w-32 h-32"
      "large" -> "w-48 h-48"
    end
    [base, "text-red-600 dark:text-red-400 animate-pulse"]
  end
  
  defp timer_container_classes(%{status: :paused}, size) do
    base = case size do
      "small" -> "w-20 h-20"
      "medium" -> "w-32 h-32"
      "large" -> "w-48 h-48"
    end
    [base, "text-yellow-600 dark:text-yellow-400"]
  end
  
  defp timer_container_classes(_, size) do
    base = case size do
      "small" -> "w-20 h-20"
      "medium" -> "w-32 h-32"
      "large" -> "w-48 h-48"
    end
    [base, "text-gray-400 dark:text-gray-500"]
  end
  
  defp circle_size_classes("small"), do: "w-20 h-20"
  defp circle_size_classes("medium"), do: "w-32 h-32"
  defp circle_size_classes("large"), do: "w-48 h-48"
  
  defp text_size_classes("small"), do: "text-sm"
  defp text_size_classes("medium"), do: "text-lg"
  defp text_size_classes("large"), do: "text-2xl"
  
  defp status_size_classes("small"), do: "text-xs"
  defp status_size_classes("medium"), do: "text-sm"
  defp status_size_classes("large"), do: "text-base"
  
  defp team_info_size_classes("small"), do: "text-xs"
  defp team_info_size_classes("medium"), do: "text-sm"
  defp team_info_size_classes("large"), do: "text-base"
  
  defp timer_text_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 10 do
    "font-bold text-red-600 dark:text-red-400 animate-pulse"
  end
  
  defp timer_text_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 30 do
    "font-bold text-orange-600 dark:text-orange-400"
  end
  
  defp timer_text_classes(%{status: :running}) do
    "font-mono font-semibold text-blue-600 dark:text-blue-400"
  end
  
  defp timer_text_classes(%{status: :expired}) do
    "font-bold text-red-600 dark:text-red-400"
  end
  
  defp timer_text_classes(%{status: :paused}) do
    "font-mono font-semibold text-yellow-600 dark:text-yellow-400"
  end
  
  defp timer_text_classes(_) do
    "font-mono text-gray-500 dark:text-gray-400"
  end
  
  defp progress_circle_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 10 do
    "text-red-500 transition-all duration-1000"
  end
  
  defp progress_circle_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 30 do
    "text-orange-500 transition-all duration-1000"
  end
  
  defp progress_circle_classes(%{status: :running}) do
    "text-blue-500 transition-all duration-1000"
  end
  
  defp progress_circle_classes(%{status: :expired}) do
    "text-red-500"
  end
  
  defp progress_circle_classes(%{status: :paused}) do
    "text-yellow-500"
  end
  
  defp progress_circle_classes(_) do
    "text-gray-300"
  end
  
  defp progress_circle_style(%{status: :running, remaining_seconds: remaining, total_seconds: total}) 
       when is_integer(remaining) and is_integer(total) and total > 0 do
    # Calculate progress percentage (remaining / total)
    progress_percent = remaining / total
    # SVG circle circumference: 2 * π * radius = 2 * π * 54 ≈ 339.29
    circumference = 339.29
    # Stroke dash offset for progress
    dash_offset = circumference * (1 - progress_percent)
    
    "stroke-dasharray: #{circumference}; stroke-dashoffset: #{dash_offset};"
  end
  
  defp progress_circle_style(%{status: :expired}) do
    "stroke-dasharray: 339.29; stroke-dashoffset: 339.29;"
  end
  
  defp progress_circle_style(_) do
    "stroke-dasharray: 339.29; stroke-dashoffset: 0;"
  end
  
  # Compact timer styles
  
  defp compact_timer_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 10 do
    "bg-red-100 border border-red-300 dark:bg-red-900 dark:border-red-700"
  end
  
  defp compact_timer_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 30 do
    "bg-orange-100 border border-orange-300 dark:bg-orange-900 dark:border-orange-700"
  end
  
  defp compact_timer_classes(%{status: :running}) do
    "bg-blue-100 border border-blue-300 dark:bg-blue-900 dark:border-blue-700"
  end
  
  defp compact_timer_classes(%{status: :paused}) do
    "bg-yellow-100 border border-yellow-300 dark:bg-yellow-900 dark:border-yellow-700"
  end
  
  defp compact_timer_classes(%{status: :expired}) do
    "bg-red-100 border border-red-300 dark:bg-red-900 dark:border-red-700"
  end
  
  defp compact_timer_classes(_) do
    "bg-gray-100 border border-gray-300 dark:bg-gray-800 dark:border-gray-600"
  end
  
  defp timer_indicator_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 10 do
    "bg-red-500 animate-pulse"
  end
  
  defp timer_indicator_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 30 do
    "bg-orange-500"
  end
  
  defp timer_indicator_classes(%{status: :running}) do
    "bg-blue-500"
  end
  
  defp timer_indicator_classes(%{status: :paused}) do
    "bg-yellow-500"
  end
  
  defp timer_indicator_classes(%{status: :expired}) do
    "bg-red-500"
  end
  
  defp timer_indicator_classes(_) do
    "bg-gray-400"
  end
  
  defp compact_text_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 10 do
    "text-red-700 dark:text-red-300"
  end
  
  defp compact_text_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 30 do
    "text-orange-700 dark:text-orange-300"
  end
  
  defp compact_text_classes(%{status: :running}) do
    "text-blue-700 dark:text-blue-300"
  end
  
  defp compact_text_classes(_) do
    "text-gray-700 dark:text-gray-300"
  end
  
  # Timer alerts
  
  defp show_timer_alert?(%{status: :running, remaining_seconds: seconds}) when seconds <= 10, do: true
  defp show_timer_alert?(%{status: :expired}), do: true
  defp show_timer_alert?(_), do: false
  
  defp alert_classes(%{status: :running, remaining_seconds: seconds}) when seconds <= 10 do
    "border-orange-500 bg-orange-50 dark:bg-orange-900/20"
  end
  
  defp alert_classes(%{status: :expired}) do
    "border-red-500 bg-red-50 dark:bg-red-900/20"
  end
  
  defp alert_classes(_) do
    "border-gray-300 bg-gray-50 dark:bg-gray-800"
  end
  
  defp alert_icon(%{status: :running, remaining_seconds: _}), do: "⏰"
  defp alert_icon(%{status: :expired}), do: "⚠️"
  defp alert_icon(_), do: "ℹ️"
  
  defp alert_title(%{status: :running, remaining_seconds: seconds}) when seconds <= 10 do
    "Time Running Out!"
  end
  
  defp alert_title(%{status: :expired}), do: "Time Expired!"
  defp alert_title(_), do: "Timer Alert"
  
  defp alert_message(%{status: :running, remaining_seconds: seconds}) when seconds <= 10 do
    "Only #{seconds} seconds remaining to make your pick!"
  end
  
  defp alert_message(%{status: :expired}) do
    "Time has run out for this pick. Organizer intervention may be required."
  end
  
  defp alert_message(_), do: ""
end