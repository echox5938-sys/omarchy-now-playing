import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// shortcut: English strings only, add i18n/ catalogs if other languages are wanted.
Panel {
  id: root
  moduleName: "sahils.now-playing"
  manageIpc: false

  readonly property int barCount: 6
  readonly property int lingerMs: 2 * 60 * 1000
  property var levels: [0, 0, 0, 0, 0, 0]

  // --- What is playing -------------------------------------------------
  readonly property var players: Mpris.players ? Mpris.players.values : []
  property string lastKey: ""
  readonly property var player: {
    var fallback = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (p.isPlaying) return p
      if (String(p.dbusName) === lastKey) fallback = p
    }
    return fallback
  }
  readonly property bool playing: player !== null && player.isPlaying
  onPlayerChanged: if (player) lastKey = String(player.dbusName)

  // Stays for two minutes after playback stops.
  property bool lingering: false
  onPlayingChanged: {
    if (playing) { lingering = false; lingerTimer.stop() }
    else { lingering = true; lingerTimer.restart() }
  }
  Timer { id: lingerTimer; interval: root.lingerMs; onTriggered: root.lingering = false }

  // --- Meeting guard ---------------------------------------------------
  // A capture stream other than cava or dictation means a call has the mic
  // (or camera). Only isStream/isSink/name are read: reading .properties on
  // capture streams can destabilize Quickshell (see omarchy audio panel).
  readonly property bool micInUse: {
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isStream && !n.isSink && Model.isCallCapture(n.name)) return true
    }
    return false
  }
  readonly property bool meetingOpen: {
    var tops = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < tops.length; i++) {
      var ipc = tops[i].lastIpcObject
      if (Model.isMeetingWindow(ipc ? ipc.class : "", tops[i].title)) return true
    }
    return false
  }
  // lastIpcObject (window class) is only filled after a refresh.
  Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: Hyprland.refreshToplevels() }

  readonly property bool shown: player !== null && (playing || lingering) && !micInUse && !meetingOpen
  onShownChanged: if (!shown && opened) close()

  visible: shown
  // Works on top/bottom bars and on left/right (vertical) bars.
  readonly property bool vertical: bar ? bar.vertical === true : false
  readonly property real thickness: bar ? bar.barSize : Style.space(24)
  implicitWidth: !shown ? 0 : vertical ? thickness : bars.implicitWidth + Style.space(12)
  implicitHeight: !shown ? 0 : vertical ? Style.space(28) : thickness

  // --- Visualizer ------------------------------------------------------
  Process {
    id: cava
    running: root.shown && root.playing
    // Decoded, so an install path with spaces still works.
    command: ["cava", "-p", decodeURIComponent(String(Qt.resolvedUrl("cava.conf")).replace(/^file:\/\//, ""))]
    stdout: SplitParser { onRead: function(line) { root.levels = Model.parseCava(line, root.barCount) } }
    onRunningChanged: if (!running) root.levels = [0, 0, 0, 0, 0, 0]
  }

  Row {
    id: bars
    anchors.centerIn: parent
    spacing: Style.space(2)
    Repeater {
      model: root.barCount
      Rectangle {
        required property int index
        readonly property real maxH: Math.min(root.width, root.height) * 0.55
        width: root.vertical ? Style.space(2) : Style.space(3)
        // At rest each bar is a dot.
        height: Math.max(width, root.levels[index] * maxH)
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        // Follows the theme's accent, so it changes with `omarchy theme set`.
        color: Commons.Color.accent
        opacity: root.playing ? 1 : 0.5
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggle()
  }

  // --- Album art -------------------------------------------------------
  readonly property string artUrl: player ? String(player.trackArtUrl || "") : ""
  readonly property string artDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/sahils-now-playing"
  property string artSource: ""
  property int artSerial: 0
  property string artPending: ""

  onArtUrlChanged: {
    var plan = Model.artPlan(artUrl)
    curl.running = false
    artSource = ""
    if (plan.kind === "local") artSource = plan.url
    else if (plan.kind === "download") {
      // Two rotating files: the cache never holds more than two covers.
      artSerial = (artSerial + 1) % 2
      artPending = artUrl
      curl.command = Model.curlCommand(plan.url, artDir + "/cover-" + artSerial)
      // Next tick, so the stopped run has let go before the new one starts.
      Qt.callLater(function() { if (root.artPending === root.artUrl) curl.running = true })
    }
  }

  Process {
    id: curl
    onExited: function(code) {
      // Ignore answers for a track that already changed.
      if (code === 0 && root.artPending === root.artUrl)
        root.artSource = "file://" + root.artDir + "/cover-" + root.artSerial
    }
  }

  // --- Drop-down card --------------------------------------------------
  component Plain: Text {
    textFormat: Text.PlainText
    color: root.bar ? root.bar.foreground : Commons.Color.foreground
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    elide: Text.ElideRight
  }

  KeyboardPanel {
    id: card
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.opened
    // Both sizes include the card's padding and border; the helpers add them.
    contentWidth: card.fittedContentWidth(Style.space(260))
    contentHeight: card.fittedContentHeight(cardColumn.implicitHeight)
    focusTarget: keys

    // Esc closes the card; Space (or Enter) plays/pauses.
    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
    }

    Column {
      id: cardColumn
      width: parent.width
      spacing: Style.space(10)

      Rectangle {
        width: parent.width
        height: width
        radius: Style.cornerRadius
        color: Style.normalFillFor(root.barForeground, Commons.Color.accent)
        clip: true
        Image {
          id: cover
          anchors.fill: parent
          source: root.artSource
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          sourceSize.width: 520
          sourceSize.height: 520
        }
        Plain {
          anchors.centerIn: parent
          visible: cover.status !== Image.Ready
          text: "󰝚"
          font.pixelSize: Style.space(48)
        }
      }

      // Long titles scroll: pause, slide to the end, pause, jump back.
      Item {
        id: titleBox
        width: parent.width
        height: titleText.implicitHeight
        clip: true
        readonly property real overflow: Math.max(0, titleText.implicitWidth - width)

        Plain {
          id: titleText
          elide: Text.ElideNone
          text: root.player ? (root.player.trackTitle || "Unknown title") : ""
          font.pixelSize: Style.font.subtitle
          font.bold: true
          onTextChanged: x = 0
        }

        SequentialAnimation {
          running: root.opened && titleBox.overflow > 0
          loops: Animation.Infinite
          onRunningChanged: if (!running) titleText.x = 0
          PauseAnimation { duration: 1500 }
          NumberAnimation {
            target: titleText; property: "x"
            to: -titleBox.overflow
            // Constant reading speed: about 40 px a second.
            duration: Style.duration(titleBox.overflow * 25)
          }
          PauseAnimation { duration: 1500 }
          PropertyAction { target: titleText; property: "x"; value: 0 }
        }
      }
      Plain {
        width: parent.width
        text: root.player ? (root.player.trackArtist || root.player.identity || "") : ""
        font.pixelSize: Style.font.body
        opacity: 0.7
      }

      // Thin progress line. MPRIS doesn't push position, so ask once a second.
      Rectangle {
        width: parent.width
        height: Style.space(3)
        radius: height / 2
        color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.15)
        visible: !!(root.player && root.player.lengthSupported && root.player.length > 0)
        Rectangle {
          width: parent.width * Model.progress(root.player ? root.player.position : 0,
                                               root.player ? root.player.length : 0)
          height: parent.height
          radius: parent.radius
          color: Commons.Color.accent
        }
        Timer {
          interval: 1000; repeat: true; triggeredOnStart: true
          running: root.opened && root.playing
          onTriggered: if (root.player) root.player.positionChanged()
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(16)
        PanelActionButton {
          iconText: "󰒮"; tooltipText: "Previous"
          fontSize: Style.space(22)
          enabled: !!(root.player && root.player.canGoPrevious)
          onClicked: root.player.previous()
        }
        PanelActionButton {
          iconText: root.playing ? "󰏤" : "󰐊"; tooltipText: root.playing ? "Pause" : "Play"
          fontSize: Style.space(26)
          enabled: !!(root.player && root.player.canTogglePlaying)
          onClicked: root.player.togglePlaying()
        }
        PanelActionButton {
          iconText: "󰒭"; tooltipText: "Next"
          fontSize: Style.space(22)
          enabled: !!(root.player && root.player.canGoNext)
          onClicked: root.player.next()
        }
      }
    }
  }
}
