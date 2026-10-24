// CPU y RAM en la barra superior de kubu (sensores de Plasma). Clic: monitor del sistema.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    readonly property real cpu: cpuSensor.value || 0
    readonly property real memUsed: memUsedSensor.value || 0
    readonly property real memTotal: memTotalSensor.value || 1
    readonly property real memPct: memUsed / memTotal * 100

    preferredRepresentation: fullRepresentation
    toolTipMainText: "Uso del sistema"
    toolTipSubText: "CPU " + Math.round(cpu) + "%\nRAM " + gib(memUsed) + " de " + gib(memTotal) + " GB\nClic para abrir el monitor del sistema"

    function gib(bytes) { return (bytes / 1073741824).toFixed(1) }
    // Verde · naranja · rojo según la carga
    function loadColor(pct) {
        if (pct >= 85) return Kirigami.Theme.negativeTextColor
        if (pct >= 60) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.positiveTextColor
    }

    Sensors.Sensor { id: cpuSensor; sensorId: "cpu/all/usage"; updateRateLimit: 2000 }
    Sensors.Sensor { id: memUsedSensor; sensorId: "memory/physical/used"; updateRateLimit: 2000 }
    Sensors.Sensor { id: memTotalSensor; sensorId: "memory/physical/total"; updateRateLimit: 60000 }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
    }

    component Meter: RowLayout {
        property string label
        property string value
        property real pct
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label { text: label; opacity: 0.7 }
        PlasmaComponents.Label { text: value; font.bold: true; color: root.loadColor(pct) }
        // Barrita de uso
        Rectangle {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
            Layout.preferredHeight: Math.round(Kirigami.Units.smallSpacing * 1.2)
            radius: height / 2
            color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
            Rectangle {
                width: parent.width * Math.min(pct, 100) / 100
                height: parent.height
                radius: parent.radius
                color: root.loadColor(pct)
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
    }

    fullRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        cursorShape: Qt.PointingHandCursor
        onClicked: exec.connectSource("setsid -f plasma-systemmonitor >/dev/null 2>&1")

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing

            Meter { label: "CPU"; value: Math.round(root.cpu) + "%"; pct: root.cpu }
            Meter { label: "RAM"; value: root.gib(root.memUsed) + " GB"; pct: root.memPct }
        }
    }
}
