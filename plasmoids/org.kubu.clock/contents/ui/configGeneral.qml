// Configuración: tipografía y un color para cada parte, con una muestra debajo.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQC
import "style.js" as Style

KCM.SimpleKCM {
    id: page

    property string cfg_fontFile
    property string cfg_fontFileDefault
    property string cfg_dayColor
    property string cfg_dayColorDefault
    property string cfg_dateColor
    property string cfg_dateColorDefault
    property string cfg_separatorColor
    property string cfg_separatorColorDefault
    property string cfg_timeColor
    property string cfg_timeColorDefault

    // Color efectivo de cada parte (el guardado o el de por defecto)
    readonly property color dayColor: cfg_dayColor || Kirigami.Theme.highlightColor
    readonly property color dateColor: cfg_dateColor || Style.blue
    readonly property color separatorColor: cfg_separatorColor || Style.separator
    readonly property color timeColor: cfg_timeColor || Style.blue
    readonly property string family: cfg_fontFile && preview.status === FontLoader.Ready
        ? preview.name : Kirigami.Theme.defaultFont.family

    FontLoader {
        id: preview
        source: cfg_fontFile ? Qt.resolvedUrl("../fonts/" + cfg_fontFile) : ""
    }

    // Selector de color con botón para volver al de por defecto
    component ColorRow: RowLayout {
        id: colorRow
        property string label
        property string value          // cfg_* ("" = por defecto)
        property color effective
        property string defaultHint
        signal changed(string value)

        Kirigami.FormData.label: label
        spacing: Kirigami.Units.smallSpacing

        KQC.ColorButton {
            color: colorRow.effective
            dialogTitle: "Color: " + colorRow.label.replace(":", "")
            onAccepted: (c) => colorRow.changed(c.toString())
        }
        QQC2.Button {
            icon.name: "edit-undo"
            text: "Por defecto"
            enabled: colorRow.value !== ""
            onClicked: colorRow.changed("")
        }
        QQC2.Label {
            visible: colorRow.value === ""
            text: colorRow.defaultHint
            opacity: 0.6
        }
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: "Tipografía:"
            model: Style.fonts
            textRole: "label"
            valueRole: "file"
            Component.onCompleted: currentIndex = Math.max(0, indexOfValue(cfg_fontFile))
            onActivated: cfg_fontFile = currentValue
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Colores" }

        ColorRow {
            label: "Día:"
            value: cfg_dayColor
            effective: page.dayColor
            defaultHint: "acento del tema"
            onChanged: (v) => cfg_dayColor = v
        }
        ColorRow {
            label: "Fecha:"
            value: cfg_dateColor
            effective: page.dateColor
            defaultHint: "azul kubu"
            onChanged: (v) => cfg_dateColor = v
        }
        ColorRow {
            label: "Separador:"
            value: cfg_separatorColor
            effective: page.separatorColor
            defaultHint: "azul kubu al 50 %"
            onChanged: (v) => cfg_separatorColor = v
        }
        ColorRow {
            label: "Hora:"
            value: cfg_timeColor
            effective: page.timeColor
            defaultHint: "azul kubu"
            onChanged: (v) => cfg_timeColor = v
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Muestra" }

        // Muestra a escala con la tipografía y los colores elegidos
        Rectangle {
            Layout.preferredWidth: sample.implicitWidth + Kirigami.Units.largeSpacing * 2
            Layout.preferredHeight: sample.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.cornerRadius
            color: "#1b1e2b"

            RowLayout {
                id: sample
                anchors.centerIn: parent
                spacing: Kirigami.Units.largeSpacing

                ColumnLayout {
                    spacing: 2
                    QQC2.Label {
                        text: Qt.locale().toString(new Date(), "dddd")
                        color: page.dayColor
                        font.family: page.family
                        font.pixelSize: Kirigami.Units.gridUnit * 1.8
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: Kirigami.Units.gridUnit * 0.5
                    }
                    QQC2.Label {
                        text: Qt.locale().toString(new Date(), "d 'de' MMMM 'de' yyyy")
                        color: page.dateColor
                        font.family: page.family
                        font.pixelSize: Kirigami.Units.gridUnit * 0.55
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: Kirigami.Units.gridUnit * 0.12
                    }
                }
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 2
                    color: page.separatorColor
                }
                QQC2.Label {
                    text: Qt.locale().toString(new Date(), "HH:mm")
                    color: page.timeColor
                    font.family: page.family
                    font.pixelSize: Kirigami.Units.gridUnit * 2.4
                }
            }
        }
    }
}
