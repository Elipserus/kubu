// IP local en la barra superior de kubu. Clic: alterna con la IP pública.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property string localIp: "…"
    property string iface: ""
    property string publicIp: ""
    property bool showPublic: false

    readonly property string localCmd:
        "ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<NF;i++){if($i==\"src\")s=$(i+1);if($i==\"dev\")d=$(i+1)}} END{print s\" \"d}'"
    readonly property string publicCmd: "curl -fs --max-time 5 https://api.ipify.org"

    preferredRepresentation: fullRepresentation
    toolTipMainText: showPublic ? "IP pública" : "IP local"
    toolTipSubText: (iface ? "Interfaz " + iface + "\n" : "") + "Clic para ver la IP " + (showPublic ? "local" : "pública")

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            const out = (data["stdout"] || "").trim()
            if (source === root.localCmd) {
                const parts = out.split(" ")
                root.localIp = parts[0] || "sin red"
                root.iface = parts[1] || ""
            } else {
                root.publicIp = out || "sin conexión"
            }
            disconnectSource(source)
        }
    }

    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: exec.connectSource(root.localCmd)
    }

    fullRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.showPublic = !root.showPublic
            if (root.showPublic) {
                root.publicIp = "…"
                exec.connectSource(root.publicCmd)
            }
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: root.showPublic ? "globe" : (root.iface.startsWith("w") ? "network-wireless" : "network-wired")
                color: Kirigami.Theme.highlightColor
                isMask: true
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
            }
            PlasmaComponents.Label {
                text: root.showPublic ? root.publicIp : root.localIp
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.25
                color: root.showPublic ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
            }
        }
    }
}
