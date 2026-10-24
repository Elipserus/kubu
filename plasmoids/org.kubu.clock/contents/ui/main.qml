// Fecha para el escritorio de kubu: a la izquierda el día de la semana en grande
// con la fecha debajo, y a la derecha la hora. Sin fondo; todo escala para llenar
// el widget, así que se agranda desde el modo de edición de Plasma. Tipografía y
// colores se eligen en Configurar (por defecto: día con el acento del tema, resto
// en azul kubu; ver style.js).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "style.js" as Style

PlasmoidItem {
    id: root

    property date now: new Date()
    readonly property color dayColor: Plasmoid.configuration.dayColor || Kirigami.Theme.highlightColor
    readonly property color dateColor: Plasmoid.configuration.dateColor || Style.blue
    readonly property color separatorColor: Plasmoid.configuration.separatorColor || Style.separator
    readonly property color timeColor: Plasmoid.configuration.timeColor || Style.blue
    readonly property string fontFile: Plasmoid.configuration.fontFile
    readonly property string family: fontFile && loader.status === FontLoader.Ready
        ? loader.name : Kirigami.Theme.defaultFont.family
    // Tamaño base del diseño; luego se escala entero para encajar en el widget
    readonly property real unit: 24

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    FontLoader {
        id: loader
        source: root.fontFile ? Qt.resolvedUrl("../fonts/" + root.fontFile) : ""
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    component Label: Text {
        font.family: root.family
        renderType: Text.QtRendering   // escala sin pixelarse
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 3
        Layout.preferredWidth: row.implicitWidth
        Layout.preferredHeight: row.implicitHeight

        RowLayout {
            id: row
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            transformOrigin: Item.Left
            scale: Math.min(parent.width / implicitWidth, parent.height / implicitHeight)
            spacing: root.unit * 1.5

            ColumnLayout {
                spacing: root.unit * 0.4

                Label {
                    text: Qt.locale().toString(root.now, "dddd")
                    color: root.dayColor
                    font.pixelSize: root.unit * 3.6
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: root.unit
                }
                Label {
                    text: Qt.locale().toString(root.now, "d 'de' MMMM 'de' yyyy")
                    color: root.dateColor
                    font.pixelSize: root.unit * 1.1
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: root.unit * 0.25
                }
            }

            // Línea fina de separación, del alto del bloque de la izquierda
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 2
                color: root.separatorColor
            }

            Label {
                text: Qt.locale().toString(root.now, "HH:mm")
                color: root.timeColor
                font.pixelSize: root.unit * 4.8
                font.letterSpacing: root.unit * 0.15
            }
        }

        // Sombra suave para que se lea sobre cualquier fondo
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#99000000"
            shadowBlur: 0.6
            shadowVerticalOffset: 2
        }
    }
}
