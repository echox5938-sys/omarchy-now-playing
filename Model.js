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
  if (u.length > 4096) return { kind: "none" }
  if (/^file:\/\//i.test(u)) return { kind: "local", url: u }
  // No whitespace/control chars: curl gets it as one argv entry, never a shell.
  if (/^https:\/\/[^\s\x00-\x1f\x7f]+$/i.test(u)) return { kind: "download", url: u }
  return { kind: "none" }
}

// curl with hard limits: HTTPS only (redirects too), 2 MB, 10 s.
function curlCommand(url, outPath) {
  return ["curl", "-fsS", "--proto", "=https", "--proto-redir", "=https",
    "--max-redirs", "3", "--max-filesize", "2097152", "--max-time", "10",
    "--create-dirs", "-o", outPath, "--", url]
}

if (typeof module !== "undefined") module.exports = {
  isMeetingWindow: isMeetingWindow, parseCava: parseCava,
  artPlan: artPlan, curlCommand: curlCommand
}
