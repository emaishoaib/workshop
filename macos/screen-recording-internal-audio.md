# Screen recording with internal audio on a Mac (free)

QuickTime can record your screen, but it can't capture internal computer
audio (system sound) — only a microphone. This uses BlackHole, a free
virtual audio driver, to route system audio into QuickTime as an input.

Source: [How To Screen Record With INTERNAL COMPUTER AUDIO On A Mac (FREE)](https://www.youtube.com/watch?v=KjL_sJS9Rko)

## 1. Record screen with QuickTime

1. Launch QuickTime via Spotlight (`Cmd+Space`, type "QuickTime").
2. `File` → `New Screen Recording`.
3. Choose a mode: record the entire screen, or a selected portion.
4. In the recording options, set save destination, countdown timer (usually
   none), and microphone input. By default there's no system-audio option
   here — that's what BlackHole fixes.

## 2. Install BlackHole (captures internal audio)

1. Go to [existential.audio/blackhole](https://existential.audio/blackhole).
2. Submit name/email to get the download link.
3. Download and install **BlackHole 2ch**.

## 3. Set up virtual audio devices

Open **Audio MIDI Setup** (Spotlight → "Audio MIDI Setup") and create two devices:

- **Aggregate Device** → rename to `Computer Audio Input`
  - Add BlackHole 2ch to it.
- **Multi-Output Device** → rename to `Headphones (For Recording)`
  - Select your headphones first, then BlackHole 2ch. Order matters —
    headphones first.

## 4. Record with sound

1. In QuickTime's screen recording options, set the output device to
   `Headphones (For Recording)` so you still hear audio while it's
   routed through BlackHole.
2. Under microphone options, select `Computer Audio Input`.
3. Start recording — screen and internal audio are both captured.
4. Adjust volume via the headphones device, not the Mac's main output.

## Bonus: cursor visibility (Presentation Assistant, ~$3)

Optional paid app for click highlights during recordings.

- Three pointer highlight styles: ring, spotlight (toggle: `Option+1`), disk.
- Customizable click circle size/opacity, pointer magnify-on-click.
- Can hide desktop icons for a clean recording surface.
- Menubar toggle for quick settings changes mid-recording.

## Bonus: video ideas cheat sheet

A free PDF of video ideas/formats, offered via the video's description —
not part of the recording setup itself, just a content-planning aid.
