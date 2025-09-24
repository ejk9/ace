// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.






// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/ace_app"
import topbar from "../vendor/topbar"



// Import audio manager
import audioManager from "./audio_manager.js"

// Custom hooks
const Hooks = {
  AutoScroll: {
    mounted() {
      this.scrollToBottom()
    },
    updated() {
      this.scrollToBottom()
    },
    scrollToBottom() {
      this.el.scrollTop = this.el.scrollHeight
    }
  },
  ChatInput: {
    mounted() {
      this.el.addEventListener("keydown", (e) => {
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault()
          const form = this.el.closest("form")
          if (form && this.el.value.trim()) {
            form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }))
          }
        }
      })
    }
  },
  AudioManager: {
    mounted() {
      // Initialize audio on first user interaction
      this.initializeAudio()

      // Listen for audio events from LiveView
      this.handleEvent("play_timer_warning", ({seconds_remaining}) => {
        audioManager.playTimerWarning(seconds_remaining)
      })

      this.handleEvent("play_turn_notification", ({team_name}) => {
        audioManager.playTurnNotification()
      })

      this.handleEvent("play_pick_made", ({player_name}) => {
        audioManager.playPickMade()
      })

      this.handleEvent("show_champion_splash", (data) => {
        this.showChampionSplash(data)
      })

      this.handleEvent("play_draft_started", () => {
        audioManager.playDraftStarted()
      })

      this.handleEvent("test_audio", () => {
        audioManager.testAudio()
      })

      // Settings events
      this.handleEvent("set_audio_volume", ({volume}) => {
        audioManager.setVolume(volume)
        this.pushEvent("audio_settings_updated", {
          volume: audioManager.getVolume(),
          muted: audioManager.isMuted()
        })
      })

      this.handleEvent("toggle_audio_mute", () => {
        const muted = audioManager.toggleMute()
        this.pushEvent("audio_settings_updated", {
          volume: audioManager.getVolume(),
          muted: muted
        })
      })

      // Send current settings to LiveView
      this.pushEvent("audio_settings_loaded", {
        volume: audioManager.getVolume(),
        muted: audioManager.isMuted()
      })
    },

    async initializeAudio() {
      // Try to initialize audio context on user interaction
      const initOnInteraction = async () => {
        await audioManager.initialize()
        document.removeEventListener('click', initOnInteraction)
        document.removeEventListener('keydown', initOnInteraction)
      }

      document.addEventListener('click', initOnInteraction, { once: true })
      document.addEventListener('keydown', initOnInteraction, { once: true })
    },

    showChampionSplash(data) {
      // Create splash art overlay
      const overlay = document.createElement('div')
      overlay.className = 'fixed inset-0 bg-black bg-opacity-80 flex items-center justify-center z-50'
      overlay.style.animation = 'fadeIn 0.3s ease-in-out'
      
      const splashContainer = document.createElement('div')
      splashContainer.className = 'relative max-w-4xl max-h-screen p-4'
      
      const splashImg = document.createElement('img')
      splashImg.src = data.splash_url
      splashImg.alt = `${data.champion_name} splash art`
      splashImg.className = 'w-full h-auto rounded-lg shadow-2xl'
      splashImg.style.maxHeight = '80vh'
      splashImg.style.objectFit = 'contain'
      
      const infoPanel = document.createElement('div')
      infoPanel.className = 'absolute bottom-4 left-4 bg-black bg-opacity-70 text-white p-4 rounded-lg'
      infoPanel.innerHTML = `
        <div class="text-2xl font-bold">${data.champion_name}</div>
        <div class="text-lg opacity-90">${data.champion_title}</div>
        ${data.skin_name ? `<div class="text-sm opacity-75">${data.skin_name}</div>` : ''}
        <div class="text-sm opacity-75">Picked by ${data.player_name}</div>
        ${data.team_name ? `<div class="text-sm opacity-75">${data.team_name}</div>` : ''}
      `
      
      splashContainer.appendChild(splashImg)
      splashContainer.appendChild(infoPanel)
      overlay.appendChild(splashContainer)
      document.body.appendChild(overlay)
      
      // Auto-remove after 4 seconds or on click
      const removeOverlay = () => {
        overlay.style.animation = 'fadeOut 0.3s ease-in-out'
        setTimeout(() => {
          if (document.body.contains(overlay)) {
            document.body.removeChild(overlay)
          }
        }, 300)
      }
      
      overlay.addEventListener('click', removeOverlay)
      setTimeout(removeOverlay, 4000)
    },

    destroyed() {
      audioManager.destroy()
    }
  },
  CsvDownload: {
    mounted() {
      this.handleEvent("download_csv", ({content, filename}) => {
        const blob = new Blob([content], { type: 'text/csv' })
        const url = window.URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = filename
        a.click()
        window.URL.revokeObjectURL(url)
      })
    }
  },
  DraftProgressScroll: {
    mounted() {
      this.scrollToCurrentPick()
    },
    updated() {
      // Small delay to ensure DOM has updated
      setTimeout(() => this.scrollToCurrentPick(), 100)
    },
    scrollToCurrentPick() {
      // Find the current pick element
      const currentPickElement = this.el.querySelector('[id^="current-pick-"]')
      if (currentPickElement) {
        // Scroll the current pick into view with smooth animation
        currentPickElement.scrollIntoView({
          behavior: 'smooth',
          block: 'nearest', 
          inline: 'center'
        })
      }
    }
  },
  ClientTimer: {
    mounted() {
      this.deadline = null
      this.clientInterval = null
      this.lastSync = null
      this.driftThreshold = 3000 // 3 seconds drift tolerance
      
      // Handle timer state updates from server
      this.handleEvent("timer_state", (data) => {
        this.updateTimerState(data)
      })
      
      // Handle sync updates from server  
      this.handleEvent("timer_sync", (data) => {
        this.syncTimer(data)
      })
      
      // Handle timer events
      this.handleEvent("timer_started", (data) => {
        this.startClientTimer(data)
      })
      
      this.handleEvent("timer_paused", (data) => {
        this.pauseClientTimer()
      })
      
      this.handleEvent("timer_resumed", (data) => {
        this.resumeClientTimer(data)
      })
      
      this.handleEvent("timer_stopped", (data) => {
        this.stopClientTimer()
      })
      
      this.handleEvent("timer_expired", (data) => {
        this.expireClientTimer()
      })
    },
    
    updateTimerState(data) {
      if (data.status === 'running' && data.deadline) {
        this.startClientTimer(data)
      } else if (data.status === 'paused') {
        this.pauseClientTimer()
      } else if (data.status === 'stopped') {
        this.stopClientTimer()
      }
    },
    
    startClientTimer(data) {
      // Clear any existing timer
      this.clearClientTimer()
      
      // Calculate deadline accounting for server/client time difference
      const serverTime = new Date(data.server_time)
      const clientTime = new Date()
      const timeDiff = clientTime - serverTime
      const deadline = new Date(data.deadline)
      
      // Adjust deadline for client time
      this.deadline = new Date(deadline.getTime() + timeDiff)
      this.lastSync = clientTime
      this.totalSeconds = data.total_seconds || data.remaining_seconds
      
      // Start client countdown
      this.clientInterval = setInterval(() => {
        this.updateDisplay()
      }, 1000)
      
      // Update display immediately
      this.updateDisplay()
    },
    
    pauseClientTimer() {
      this.clearClientTimer()
      this.deadline = null
    },
    
    resumeClientTimer(data) {
      this.startClientTimer(data)
    },
    
    stopClientTimer() {
      this.clearClientTimer()
      this.deadline = null
      this.updateDisplayElement(0, 'stopped')
    },
    
    expireClientTimer() {
      this.clearClientTimer()
      this.deadline = null
      this.updateDisplayElement(0, 'expired')
    },
    
    syncTimer(data) {
      if (!this.deadline) return
      
      // Calculate how far off our client timer is from server
      const serverTime = new Date(data.server_time)
      const clientTime = new Date()
      const timeDiff = clientTime - serverTime
      const serverDeadline = new Date(data.deadline)
      const adjustedDeadline = new Date(serverDeadline.getTime() + timeDiff)
      
      const drift = Math.abs(this.deadline - adjustedDeadline)
      
      // If drift is significant, correct it
      if (drift > this.driftThreshold) {
        console.log(`Timer drift detected: ${drift}ms, correcting...`)
        this.deadline = adjustedDeadline
        this.lastSync = clientTime
      }
    },
    
    updateDisplay() {
      if (!this.deadline) return
      
      const now = new Date()
      const remainingMs = this.deadline - now
      const remainingSeconds = Math.max(0, Math.ceil(remainingMs / 1000))
      
      // Check if we should request a sync (every 30 seconds of client time)
      if (this.lastSync && (now - this.lastSync) > 30000) {
        this.pushEvent("request_timer_sync", {})
        this.lastSync = now
      }
      
      // Update the display
      this.updateDisplayElement(remainingSeconds, 'running')
      
      // Handle client-side expiration
      if (remainingSeconds <= 0) {
        this.clearClientTimer()
        this.pushEvent("timer_client_expired", {})
      }
    },
    
    updateDisplayElement(seconds, status) {
      // Update the timer display element (text)
      const timerElement = this.el.querySelector('[data-timer-display]')
      
      if (timerElement) {
        const minutes = Math.floor(seconds / 60)
        const secs = seconds % 60
        const timeString = `${minutes}:${secs.toString().padStart(2, '0')}`
        
        timerElement.textContent = timeString
        timerElement.setAttribute('data-timer-status', status)
        timerElement.setAttribute('data-remaining-seconds', seconds)
        
        // Add visual indicators for warnings
        if (status === 'running') {
          // Remove existing timer status classes
          timerElement.classList.remove('timer-critical', 'timer-warning', 'timer-caution', 'timer-normal')
          
          if (seconds <= 5) {
            timerElement.classList.add('timer-critical')
          } else if (seconds <= 10) {
            timerElement.classList.add('timer-warning')
          } else if (seconds <= 30) {
            timerElement.classList.add('timer-caution')
          } else {
            timerElement.classList.add('timer-normal')
          }
        }
      }
      
      // Update the timer progress circle (visual wheel)
      const progressElement = this.el.querySelector('[data-timer-progress]')
      
      if (progressElement && this.totalSeconds && status === 'running') {
        // Calculate progress percentage (remaining / total)
        const progressPercent = seconds / this.totalSeconds
        // SVG circle circumference: 2 * π * radius = 2 * π * 54 ≈ 339.29
        const circumference = 339.29
        // Stroke dash offset for progress
        const dashOffset = circumference * (1 - progressPercent)
        
        const progressStyle = `stroke-dasharray: ${circumference}; stroke-dashoffset: ${dashOffset};`
        progressElement.setAttribute('style', progressStyle)
      } else if (progressElement && status === 'stopped') {
        // Reset progress circle for stopped timer
        progressElement.setAttribute('style', 'stroke-dasharray: 339.29; stroke-dashoffset: 0;')
      }
    },
    
    clearClientTimer() {
      if (this.clientInterval) {
        clearInterval(this.clientInterval)
        this.clientInterval = null
      }
    },
    
    destroyed() {
      this.clearClientTimer()
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()



// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

