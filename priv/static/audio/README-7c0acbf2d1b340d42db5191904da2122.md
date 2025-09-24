# Audio Files for Draft Tool

This directory contains audio files used for draft notifications and sound effects.

## Audio Sources & Attribution

### Current Implementation
The draft tool currently uses **synthetic audio generation** via Web Audio API as the primary audio source. This ensures:
- Zero dependencies on external files
- Consistent cross-browser compatibility
- No licensing concerns
- Real-time audio generation

### Professional Audio File Support (Optional Enhancement)

The system is designed to automatically load professional audio files from this directory if available, with synthetic fallback. Here are recommended sources for high-quality, legally usable audio:

#### Recommended Free Sources:

1. **Freesound.org** (Creative Commons licensed)
   - "The Designer's Choice UCS Pack #7 - BEEPS" by Nicholas A. Judy
   - License: Creative Commons, royalty-free for commercial use
   - Attribution: Optional but appreciated
   - Best for: Timer beeps, professional UI sounds

2. **Mixkit** (Royalty-free)
   - "Melodic race countdown" and "Sport start bleeps"
   - License: Royalty-free, no attribution required
   - Best for: Countdown timers, sport/game sounds

3. **Pixabay** (Royalty-free)
   - Timer and countdown sound effects
   - License: Royalty-free, no attribution required
   - Best for: General timer and notification sounds

#### File Structure:
```
/priv/static/audio/
├── timer_warning.mp3      # 30-second warning (subtle beep)
├── timer_urgent.mp3       # 10-second warning (double beep)
├── timer_critical.mp3     # 5-second warning (urgent/drums)
├── turn_notification.mp3  # Your team's turn (chime/fanfare)
├── pick_made.mp3         # Pick confirmation (soft click)
├── draft_started.mp3     # Draft begins (celebration)
└── README.md             # This file
```

#### Audio Specifications:
- **Format:** MP3 (for broad browser support)
- **Duration:** 0.3-2.0 seconds (timer dependent)
- **Quality:** 44.1kHz, 16-bit minimum
- **Volume:** Normalized to prevent startling users
- **Style:** Professional, non-intrusive, contextually appropriate

## Implementation Details

The audio manager (`assets/js/audio_manager.js`) automatically:
1. Attempts to load audio files from this directory
2. Falls back to synthetic generation if files unavailable
3. Maintains consistent volume and mute controls
4. Provides browser-compatible audio initialization

## Adding New Audio Files

1. Download appropriate Creative Commons or royalty-free audio
2. Convert to MP3 format if needed
3. Normalize volume levels
4. Place in this directory with correct filename
5. Update attribution in this README if required
6. Test in draft tool to ensure proper loading

## Current Status

**Status:** Synthetic audio generation (no external files required)
**Fallback:** Always available via Web Audio API
**Enhancement:** Ready for professional audio file integration when desired

---
*Last updated: September 19, 2025*