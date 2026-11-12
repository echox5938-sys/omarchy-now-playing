// Run: node tests/model.test.js
const assert = require("assert")
const M = require("../Model.js")

// Meetings
assert(M.isMeetingWindow("zoom", "Zoom Meeting"))
assert(M.isMeetingWindow("teams-for-linux", "Chat"))
assert(M.isMeetingWindow("chromium", "Meet - abc-defg-hij"))
assert(M.isMeetingWindow("Slack", "Huddle with Sam"))
assert(!M.isMeetingWindow("Slack", "general | Workspace"))
assert(!M.isMeetingWindow("spotify", "Spotify Premium"))
assert(!M.isMeetingWindow("", ""))

// Dictation and our visualizer are not calls; anything else is
assert(!M.isCallCapture("cava"))
assert(!M.isCallCapture("superwhisper-capture"))
assert(M.isCallCapture("Chromium input"))

// Progress
assert.strictEqual(M.progress(30, 120), 0.25)
assert.strictEqual(M.progress(500, 120), 1)
assert.strictEqual(M.progress(10, 0), 0)
assert.strictEqual(M.progress(NaN, 100), 0)

// busctl metadata fallback
const meta = M.parseBusctlMetadata('{"type":"a{sv}","data":{"xesam:title":{"type":"s","data":"Long Nights"},"xesam:artist":{"type":"as","data":["Asthenic","B"]},"mpris:artUrl":{"type":"s","data":"file:/tmp/a.tmp"}}}')
assert.deepStrictEqual(meta, { title: "Long Nights", artist: "Asthenic, B", artUrl: "file:/tmp/a.tmp" })
assert.strictEqual(M.parseBusctlMetadata("not json"), null)
assert.strictEqual(M.parseBusctlMetadata('{"data":5}'), null)
assert.strictEqual(M.parseBusctlMetadata('{"data":{"xesam:title":{"data":{"x":1}}}}').title, "")
assert(M.isMprisBusName("org.mpris.MediaPlayer2.SimpMusic"))
assert(M.isMprisBusName("org.mpris.MediaPlayer2.chromium.instance123"))
assert(!M.isMprisBusName("--user"))
assert(!M.isMprisBusName("org.mpris.MediaPlayer2.x y"))

// cava frames
assert.deepStrictEqual(M.parseCava("100;50;0;0;0;0;", 6), [1, 0.5, 0, 0, 0, 0])
assert.deepStrictEqual(M.parseCava("junk", 3), [0, 0, 0])
assert.deepStrictEqual(M.parseCava("999;-5;", 2), [1, 0])

// Art: https downloads, file passes, everything else refused
assert.strictEqual(M.artPlan("https://i.scdn.co/image/ab").kind, "download")
assert.strictEqual(M.artPlan("file:///tmp/a.png").kind, "local")
assert.strictEqual(M.artPlan("file:/tmp/nowplaying_artwork_1.tmp").kind, "local")
for (const bad of ["http://x/a.png", "data:image/png;base64,AA", "https://x/a b",
                   "https://x/\n", "-o/etc/passwd", "https://x/" + "a".repeat(5000)])
  assert.strictEqual(M.artPlan(bad).kind, "none", bad)

// URL always sits after "--", so it can never be read as a curl option
const cmd = M.curlCommand("https://x/a", "/tmp/o")
assert.strictEqual(cmd[cmd.length - 2], "--")
assert(cmd.includes("=https"))

console.log("ok")
