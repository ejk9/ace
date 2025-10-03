/**
 * AudioManager - Web Audio API integration for draft notifications
 * 
 * Provides audio notifications for:
 * - Timer warnings (30s, 10s, 5s)
 * - Turn notifications (when it's your team's turn)
 * - Draft events (picks made, draft started/paused)
 * 
 * Features:
 * - Volume control
 * - Mute toggle
 * - Progressive enhancement (graceful fallback)
 * - Browser localStorage for settings persistence
 */

class AudioManager {
  constructor() {
    this.audioContext = null
    this.sounds = {}
    this.settings = this.loadSettings()
    this.initialized = false
    this.buffers = {}
  }

  // Initialize audio context and load sounds
  async initialize() {
    if (this.initialized) return true

    try {
      // Create audio context (requires user interaction)
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
      
      // Load sound files
      await this.loadSounds()
      
      this.initialized = true
      console.log('AudioManager initialized successfully')
      return true
    } catch (error) {
      console.warn('AudioManager failed to initialize:', error)
      return false
    }
  }

  // Load and decode audio files with fallback to synthetic
  async loadSounds() {
    const soundFiles = {
      timer_warning: '/audio/timer_warning.mp3',
      timer_urgent: '/audio/timer_urgent.mp3', 
      timer_critical: '/audio/timer_critical.mp3',
      turn_notification: '/audio/sfx-cs-draft-notif-yourpick.ogg',
      pick_made: '/audio/pick_made.mp3',
      draft_started: '/audio/draft_started.mp3'
    }

    const loadPromises = Object.entries(soundFiles).map(async ([key, url]) => {
      try {
        // Try to load actual audio files first
        const response = await fetch(url)
        if (response.ok) {
          const arrayBuffer = await response.arrayBuffer()
          this.buffers[key] = await this.audioContext.decodeAudioData(arrayBuffer)
          console.log(`Loaded audio file: ${key}`)
        } else {
          throw new Error(`HTTP ${response.status}`)
        }
      } catch (error) {
        // Fallback to synthetic audio if file loading fails
        console.warn(`Failed to load audio file ${key}, using synthetic fallback:`, error)
        this.buffers[key] = this.createSyntheticSound(key)
        console.log(`Generated synthetic sound: ${key}`)
      }
    })

    await Promise.all(loadPromises)
  }

  // Create professional notification sounds using Web Audio API
  createSyntheticSound(type) {
    const sampleRate = this.audioContext.sampleRate
    let duration, config

    switch (type) {
      case 'timer_warning':
        duration = 0.4
        config = {
          type: 'beep',
          frequency: 1000,
          harmonics: [1, 0.3, 0.1] // Fundamental + 2nd/3rd harmonics for richer tone
        }
        break
      case 'timer_urgent':
        duration = 0.5
        config = {
          type: 'double_beep',
          frequency: 1400,
          gap: 0.1,
          harmonics: [1, 0.4, 0.2]
        }
        break
      case 'timer_critical':
        duration = 0.8
        config = {
          type: 'triple_beep',
          frequency: 1600,
          gap: 0.08,
          harmonics: [1, 0.5, 0.3, 0.1] // More complex harmonic structure
        }
        break
      case 'turn_notification':
        duration = 1.2
        config = {
          type: 'ascending_chime',
          frequencies: [523, 659, 784, 1047], // C5, E5, G5, C6 chord progression
          noteLength: 0.25
        }
        break
      case 'pick_made':
        duration = 0.25
        config = {
          type: 'soft_click',
          frequency: 800,
          harmonics: [1, 0.2]
        }
        break
      case 'draft_started':
        duration = 1.5
        config = {
          type: 'fanfare',
          frequencies: [523, 659, 784, 1047, 1319], // C major pentatonic
          noteLength: 0.3
        }
        break
      default:
        duration = 0.3
        config = { type: 'beep', frequency: 800, harmonics: [1] }
    }

    return this.generateSound(duration, config, sampleRate)
  }

  // Generate professional audio based on configuration
  generateSound(duration, config, sampleRate) {
    const frameCount = Math.floor(sampleRate * duration)
    const buffer = this.audioContext.createBuffer(1, frameCount, sampleRate)
    const channelData = buffer.getChannelData(0)

    switch (config.type) {
      case 'beep':
        this.generateBeep(channelData, config, sampleRate, duration)
        break
      case 'double_beep':
        this.generateMultiBeep(channelData, config, sampleRate, duration, 2)
        break
      case 'triple_beep':
        this.generateMultiBeep(channelData, config, sampleRate, duration, 3)
        break
      case 'ascending_chime':
        this.generateChime(channelData, config, sampleRate, duration)
        break
      case 'soft_click':
        this.generateSoftClick(channelData, config, sampleRate, duration)
        break
      case 'fanfare':
        this.generateFanfare(channelData, config, sampleRate, duration)
        break
    }

    return buffer
  }

  // Generate a professional beep with harmonics
  generateBeep(channelData, config, sampleRate, duration) {
    const { frequency, harmonics = [1] } = config
    
    for (let i = 0; i < channelData.length; i++) {
      const time = i / sampleRate
      let sample = 0

      // Add harmonics for richer tone
      harmonics.forEach((amplitude, index) => {
        const harmonic = frequency * (index + 1)
        sample += Math.sin(2 * Math.PI * harmonic * time) * amplitude * 0.15
      })

      // Professional envelope (attack, sustain, release)
      const envelope = this.getEnvelope(time, duration, 0.02, 0.8, 0.15)
      channelData[i] = sample * envelope
    }
  }

  // Generate multiple beeps with gaps
  generateMultiBeep(channelData, config, sampleRate, duration, count) {
    const { frequency, gap, harmonics = [1] } = config
    const beepDuration = (duration - (gap * (count - 1))) / count
    
    for (let i = 0; i < channelData.length; i++) {
      const time = i / sampleRate
      let sample = 0

      // Determine which beep we're in
      for (let beepIndex = 0; beepIndex < count; beepIndex++) {
        const beepStart = beepIndex * (beepDuration + gap)
        const beepEnd = beepStart + beepDuration

        if (time >= beepStart && time < beepEnd) {
          const beepTime = time - beepStart
          
          harmonics.forEach((amplitude, harmIndex) => {
            const harmonic = frequency * (harmIndex + 1)
            sample += Math.sin(2 * Math.PI * harmonic * beepTime) * amplitude * 0.15
          })

          const envelope = this.getEnvelope(beepTime, beepDuration, 0.01, 0.8, 0.1)
          sample *= envelope
          break
        }
      }

      channelData[i] = sample
    }
  }

  // Generate ascending musical chime
  generateChime(channelData, config, sampleRate, duration) {
    const { frequencies, noteLength } = config
    
    for (let i = 0; i < channelData.length; i++) {
      const time = i / sampleRate
      let sample = 0

      frequencies.forEach((freq, index) => {
        const noteStart = index * noteLength * 0.8 // Slight overlap
        const noteEnd = noteStart + noteLength
        
        if (time >= noteStart && time < noteEnd) {
          const noteTime = time - noteStart
          // Add slight detuning for natural sound
          const detunedFreq = freq * (1 + (Math.random() - 0.5) * 0.002)
          sample += Math.sin(2 * Math.PI * detunedFreq * noteTime) * 0.2
          
          // Bell-like envelope
          const envelope = Math.exp(-noteTime * 3) * this.getEnvelope(noteTime, noteLength, 0.01, 0.9, 0.1)
          sample *= envelope
        }
      })

      channelData[i] = sample
    }
  }

  // Generate soft click sound
  generateSoftClick(channelData, config, sampleRate, duration) {
    const { frequency, harmonics = [1, 0.2] } = config
    
    for (let i = 0; i < channelData.length; i++) {
      const time = i / sampleRate
      let sample = 0

      harmonics.forEach((amplitude, index) => {
        const harmonic = frequency * (index + 1)
        sample += Math.sin(2 * Math.PI * harmonic * time) * amplitude * 0.1
      })

      // Very fast attack and decay for click sound
      const envelope = Math.exp(-time * 20)
      channelData[i] = sample * envelope
    }
  }

  // Generate celebratory fanfare
  generateFanfare(channelData, config, sampleRate, duration) {
    const { frequencies, noteLength } = config
    
    for (let i = 0; i < channelData.length; i++) {
      const time = i / sampleRate
      let sample = 0

      // Play notes in sequence with overlap
      frequencies.forEach((freq, index) => {
        const noteStart = index * noteLength * 0.6
        const noteEnd = noteStart + noteLength * 1.2
        
        if (time >= noteStart && time < noteEnd) {
          const noteTime = time - noteStart
          sample += Math.sin(2 * Math.PI * freq * noteTime) * 0.15
          
          // Triumphant envelope
          const envelope = this.getEnvelope(noteTime, noteLength * 1.2, 0.05, 0.7, 0.3)
          sample *= envelope
        }
      })

      channelData[i] = sample
    }
  }

  // Professional ADSR envelope
  getEnvelope(time, duration, attack, sustain, release) {
    const sustainLevel = 0.8
    const attackTime = duration * attack
    const releaseTime = duration * release
    const sustainTime = duration - attackTime - releaseTime

    if (time < attackTime) {
      // Attack phase
      return (time / attackTime) * sustainLevel
    } else if (time < attackTime + sustainTime) {
      // Sustain phase
      return sustainLevel
    } else {
      // Release phase
      const releaseStart = attackTime + sustainTime
      const releaseProgress = (time - releaseStart) / releaseTime
      return sustainLevel * (1 - releaseProgress)
    }
  }

  // Play a sound by type
  async playSound(type, options = {}) {
    if (!this.initialized || this.settings.muted) {
      return false
    }

    try {
      const buffer = this.buffers[type]
      if (!buffer) {
        console.warn(`Sound not found: ${type}`)
        return false
      }

      // Create audio source
      const source = this.audioContext.createBufferSource()
      const gainNode = this.audioContext.createGain()

      source.buffer = buffer
      source.connect(gainNode)
      gainNode.connect(this.audioContext.destination)

      // Apply volume
      const volume = (options.volume ?? this.settings.volume) / 100
      gainNode.gain.setValueAtTime(volume, this.audioContext.currentTime)

      // Play sound
      source.start()
      
      console.log(`Played sound: ${type} at volume ${Math.round(volume * 100)}%`)
      return true
    } catch (error) {
      console.warn(`Failed to play sound ${type}:`, error)
      return false
    }
  }

  // Timer warning notification
  playTimerWarning(secondsRemaining) {
    if (!this.settings.enableTimerWarnings) {
      return false
    }
    
    let soundType
    if (secondsRemaining <= 5) {
      soundType = 'timer_critical'
    } else if (secondsRemaining <= 10) {
      soundType = 'timer_urgent'  
    } else {
      soundType = 'timer_warning'
    }
    
    return this.playSound(soundType)
  }

  // Turn notification (when it becomes your team's turn)
  playTurnNotification() {
    if (!this.settings.enableTurnNotifications) {
      return false
    }
    
    return this.playSound('turn_notification')
  }

  // Pick made notification
  playPickMade() {
    if (!this.settings.enablePickNotifications) {
      return false
    }
    
    return this.playSound('pick_made', { volume: this.settings.volume * 0.6 }) // Quieter
  }

  // Draft started notification
  playDraftStarted() {
    return this.playSound('draft_started')
  }

  // Settings management
  loadSettings() {
    try {
      const stored = localStorage.getItem('ace_audio_settings')
      return stored ? JSON.parse(stored) : this.getDefaultSettings()
    } catch {
      return this.getDefaultSettings()
    }
  }

  saveSettings() {
    try {
      localStorage.setItem('ace_audio_settings', JSON.stringify(this.settings))
    } catch (error) {
      console.warn('Failed to save audio settings:', error)
    }
  }

  getDefaultSettings() {
    return {
      volume: 50, // 0-100
      muted: false,
      enableTimerWarnings: false,
      enableTurnNotifications: true,
      enablePickNotifications: false
    }
  }

  // Update settings
  setVolume(volume) {
    this.settings.volume = Math.max(0, Math.min(100, volume))
    this.saveSettings()
  }

  setMuted(muted) {
    this.settings.muted = Boolean(muted)
    this.saveSettings()
  }

  toggleMute() {
    this.setMuted(!this.settings.muted)
    return this.settings.muted
  }

  // Settings getters
  getVolume() {
    return this.settings.volume
  }

  isMuted() {
    return this.settings.muted
  }

  // Test audio (requires user interaction)
  async testAudio() {
    await this.initialize()
    return this.playSound('timer_warning')
  }

  // Cleanup
  destroy() {
    if (this.audioContext && this.audioContext.state !== 'closed') {
      this.audioContext.close()
    }
    this.initialized = false
  }
}

// Export singleton instance
export const audioManager = new AudioManager()
export default audioManager