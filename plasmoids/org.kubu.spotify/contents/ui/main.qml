// Spotify en la barra superior de kubu: canción actual y controles (vía playerctl).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string status: ""          // Playing · Paused · "" (cerrado)
    property string artist: ""
    property string title: ""
    readonly property bool running: status !== ""
    readonly property color spotifyGreen: "#1db954"

    readonly property string pollCmd:
        "playerctl -p spotify metadata --format '{{status}}\t{{artist}}\t{{title}}' 2>/dev/null"
    readonly property string openCmd:
        "sh -c 'if command -v spotify >/dev/null; then setsid -f spotify; else setsid -f flatpak run com.spotify.Client; fi' >/dev/null 2>&1"

    preferredRepresentation: fullRepresentation
    toolTipMainText: running ? title : "Spotify"
    toolTipSubText: running ? artist : "Clic para abrir Spotify"

    function run(cmd) { exec.connectSource(cmd) }
    function control(action) {
        run("playerctl -p spotify " + action)
        refresh.restart()
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            if (source === root.pollCmd) {
                const parts = (data["stdout"] || "").replace(/\n$/, "").split("\t")
                root.status = parts.length >= 3 ? parts[0] : ""
                root.artist = parts[1] || ""
                root.title = parts[2] || ""
            }
            disconnectSource(source)
        }
    }

    Timer {
        interval: 1500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: exec.connectSource(root.pollCmd)
    }
    // Refresco rápido tras pulsar un botón
    Timer { id: refresh; interval: 300; onTriggered: exec.connectSource(root.pollCmd) }

    fullRepresentation: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth

        PlasmaComponents.ToolButton {
            visible: root.running
            icon.name: "media-skip-backward"
            onClicked: root.control("previous")
        }
        PlasmaComponents.ToolButton {
            visible: root.running
            icon.name: root.status === "Playing" ? "media-playback-pause" : "media-playback-start"
            icon.color: root.spotifyGreen
            onClicked: root.control("play-pause")
        }
        PlasmaComponents.ToolButton {
            visible: root.running
            icon.name: "media-skip-forward"
            onClicked: root.control("next")
        }

        MouseArea {
            Layout.preferredWidth: info.implicitWidth
            Layout.preferredHeight: info.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: root.run(root.openCmd)

            RowLayout {
                id: info
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    // Punto verde: sonando · gris: en pausa o cerrado
                    width: Kirigami.Units.smallSpacing * 2; height: width; radius: width / 2
                    color: root.status === "Playing" ? root.spotifyGreen : Kirigami.Theme.disabledTextColor
                }
                PlasmaComponents.Label {
                    text: root.running ? root.title : "Spotify"
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                    opacity: root.running ? 1 : 0.6
                }
                PlasmaComponents.Label {
                    visible: root.running && root.artist !== ""
                    text: "· " + root.artist
                    color: Kirigami.Theme.highlightColor
                    elide: Text.ElideRight
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 10
                }
            }
        }
    }
}
