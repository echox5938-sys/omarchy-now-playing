# Now Playing

A tiny music visualizer for the Omarchy bar.

- Appears only while media plays (any MPRIS app: Spotify, browsers, YouTube apps, VLC…).
- Bars move with the sound and use your theme's accent colour.
- Click it for a card with album art, a scrolling title, a progress line, and ⏮ ⏯ ⏭. Space plays/pauses, Ctrl+, previous, Ctrl+. next, Esc closes (only while the card is open).
- Hides 2 minutes after playback stops.
- Hides during calls: when an app uses your mic (dictation tools like Superwhisper are ignored), or a Zoom, Teams, Google Meet or Slack huddle window is open.

## Works with

Any app that supports MPRIS, the Linux standard for "now playing":

- Browsers: Chromium, Brave, Firefox, and other Chromium-based browsers (any site with audio or video: YouTube, SoundCloud, Spotify Web…)
- Desktop players: Spotify, SimpMusic, VLC, Rhythmbox, and more
- mpv: needs the `mpv-mpris` package (`omarchy pkg add mpv-mpris`)

Covers work whether the player gives a file, embedded image data, or an `https://` link.

## Install

Needs Omarchy 4.5+ and `cava` for the visualizer:

```bash
omarchy pkg add cava
omarchy plugin add https://github.com/echox5938-sys/omarchy-now-playing.git --enable
```

Without `cava` it still works; the bars just stay as dots.

## Remove

```bash
omarchy plugin remove sahils.now-playing
rm -rf ~/.cache/sahils-now-playing   # cached album art
```

## Network

The plugin only goes online for album art, and only when the player gives an
`https://` cover link (e.g. Spotify). It downloads with `curl`: HTTPS only,
max 2 MB, 10 s timeout, saved to `~/.cache/sahils-now-playing/` (two files at
most). Covers the player already saved on disk are used directly.

## Tests

```bash
node tests/model.test.js
```
