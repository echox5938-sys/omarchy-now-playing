// Pure rules, kept free of QML so tests/model.test.js can check them with node.

// Window classes and titles that mean a call is on screen.
var MEETING_CLASS = /^(zoom|teams-for-linux|microsoft teams|slack)$/i
var MEETING_TITLE = /(zoom meeting|^meet - |google meet|huddle|microsoft teams.*(call|meeting))/i

function isMeetingWindow(cls, title) {
  var c = String(cls || ""), t = String(title || "")
  // Slack is open all day; only its huddle window counts.
  if (/^slack$/i.test(c)) return /huddle/i.test(t)
  return MEETING_CLASS.test(c) || MEETING_TITLE.test(t)
}

// Mic users that are not calls: our own visualizer and dictation.
var NOT_A_CALL = ["cava", "superwhisper-capture"]

function isCallCapture(nodeName) {
  return NOT_A_CALL.indexOf(String(nodeName || "")) === -1
}

// Song progress as 0..1; 0 when the player gives no usable length.
function progress(position, length) {
  var p = Number(position), l = Number(length)
  if (!isFinite(p) || !isFinite(l) || l <= 0) return 0
  return Math.max(0, Math.min(1, p / l))
}

// Some players (SimpMusic) leave Metadata out of GetAll, so Quickshell starts
// with no title. `busctl --json=short get-property ... Metadata` still works;
// this reads its output. Bad or oversized input -> null.
function parseBusctlMetadata(text) {
  var raw = String(text || "")
  if (raw.length > 65536) return null
  var json
  try { json = JSON.parse(raw) } catch (e) { return null }
  var d = json && json.data
  if (!d || typeof d !== "object") return null
  function str(key) {
    var v = d[key] && d[key].data
    if (Array.isArray(v)) v = v.join(", ")
    return typeof v === "string" ? v.slice(0, 500) : ""
  }
  return { title: str("xesam:title"), artist: str("xesam:artist"), artUrl: str("mpris:artUrl") }
}

// Only real MPRIS bus names go to busctl.
function isMprisBusName(name) {
  return /^org\.mpris\.MediaPlayer2\.[A-Za-z0-9_.\-]{1,200}$/.test(String(name || ""))
}

// cava raw ascii frame: "12;40;7;0;3;9;" -> [0..1] per bar, bad input -> [].
function parseCava(line, bars) {
  var parts = String(line || "").split(";")
  var out = []
  for (var i = 0; i < bars; i++) {
    var v = parseInt(parts[i], 10)
    out.push(isFinite(v) ? Math.max(0, Math.min(100, v)) / 100 : 0)
  }
  return out
}

// What to do with a player's art URL: show it as is, download it, or skip.
function artPlan(url) {
  var u = String(url || "")
  // mpv (mpv-mpris) embeds the cover as base64. No network; cap ~3 MB.
  if (/^data:image\/(png|jpeg|jpg|webp|gif);base64,[A-Za-z0-9+\/=]+$/i.test(u) && u.length <= 4 * 1024 * 1024)
    return { kind: "local", url: u }
  if (u.length > 4096) return { kind: "none" }
  // Browsers send "file:/tmp/x" (one slash); both forms are local files.
  if (/^file:\//i.test(u)) return { kind: "local", url: u }
  // No whitespace/control chars: curl gets it as one argv entry, never a shell.
  if (/^https:\/\/[^\s\x00-\x1f\x7f]+$/i.test(u)) return { kind: "download", url: u }
  return { kind: "none" }
}

// curl with hard limits: HTTPS only (redirects too), 2 MB, 10 s.
function curlCommand(url, outPath) {
  // -L follows redirects (CDNs use them); each hop must still be https.
  return ["curl", "-fsSL", "--proto", "=https", "--proto-redir", "=https",
    "--max-redirs", "3", "--max-filesize", "2097152", "--max-time", "10",
    "--create-dirs", "-o", outPath, "--", url]
}

if (typeof module !== "undefined") module.exports = {
  isMeetingWindow: isMeetingWindow, parseCava: parseCava,
  isCallCapture: isCallCapture, progress: progress,
  parseBusctlMetadata: parseBusctlMetadata, isMprisBusName: isMprisBusName,
  artPlan: artPlan, curlCommand: curlCommand
}
