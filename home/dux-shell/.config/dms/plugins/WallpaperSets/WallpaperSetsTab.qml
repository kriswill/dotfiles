import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import qs.Modules.DDash
import qs.Modules.DDash.Overview
import "sets.js" as Sets

// Dash tab: shows what each display has now, saves that combination under a
// name, and lists saved sets — click one to put every display's image back.
// Pick the per-display images themselves in the built-in Wallpapers tab.
DashTabComponent {
    id: root

    property int rowBudget: DashMetrics.minimumTabRows

    readonly property var screens: Quickshell.screens
    readonly property var sets: Sets.normalize(pluginData.sets)
    readonly property var currentWallpapers: {
        SessionData.monitorWallpapers;
        SessionData.perMonitorWallpaper;
        SessionData.wallpaperPath;
        return Sets.snapshot(SessionData, screens);
    }
    readonly property var currentLayout: Sets.layoutOf(screens)
    readonly property int activeIndex: {
        currentWallpapers;
        return Sets.activeIndex(sets, SessionData, screens);
    }
    readonly property int columns: width >= DashMetrics.gridRowUnit * 7 ? 3 : 2
    readonly property real cardWidth: (content.width - Theme.spacingM * (columns - 1)) / columns

    focusTarget: nameField
    implicitHeight: Math.max(DashMetrics.tabMinHeight, Math.min(content.implicitHeight + Theme.spacingL * 2, DashMetrics.heightForRows(rowBudget)))

    function tr(text) {
        return I18n.trFor("wallpaperSets", text);
    }

    function restoreFocus() {
        nameField.forceActiveFocus();
    }

    function saveCurrent() {
        const name = nameField.text.trim();
        if (!name)
            return;
        const existed = Sets.indexOf(sets, name) >= 0;
        Sets.store(pluginService, pluginId, Sets.upsert(sets, name, currentWallpapers, currentLayout));
        nameField.text = "";
        ToastService.showInfo((existed ? tr("Updated wallpaper set") : tr("Saved wallpaper set")) + " “" + name + "”");
    }

    function applySet(index) {
        const set = sets[index];
        if (!set)
            return;
        const result = Sets.apply(set, SessionData, screens);
        if (result.missing.length > 0)
            ToastService.showWarning(tr("Some displays in this set are not connected"), result.missing.join(", "));
    }

    function removeSet(index) {
        const set = sets[index];
        if (!set)
            return;
        Sets.store(pluginService, pluginId, Sets.without(sets, set.name));
        ToastService.showInfo(tr("Removed wallpaper set") + " “" + set.name + "”");
    }

    // Thumbnails of one set, one per output, sized to each output's aspect
    // ratio and laid out in physical order.
    component SetPreview: Item {
        id: preview

        property var wallpapers: ({})
        property var layout: ({})
        property real maxHeight: DashMetrics.gridRowUnit

        readonly property var outputs: Sets.orderedOutputs(wallpapers, layout, Quickshell.screens)
        readonly property real aspectSum: {
            let sum = 0;
            for (const o of outputs)
                sum += Sets.aspectOf(o, layout, Quickshell.screens);
            return sum;
        }
        readonly property real gap: Theme.spacingXS
        readonly property real thumbHeight: aspectSum > 0 ? Math.min(maxHeight, (width - gap * Math.max(0, outputs.length - 1)) / aspectSum) : maxHeight

        implicitHeight: thumbHeight

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: preview.gap

            Repeater {
                model: preview.outputs

                ClippingRectangle {
                    id: thumb

                    required property string modelData
                    readonly property string path: preview.wallpapers[modelData] || ""
                    readonly property bool isColor: path.startsWith("#")
                    readonly property bool isVideo: Sets.isVideo(path)
                    // Dux 2.1+ plays video wallpapers and keeps one ffmpeg-extracted
                    // still per video; imageFor() returns it (or "" while it's being
                    // made, re-evaluating once it exists). 2.0 has no such service,
                    // so the typeof guard keeps image sets working there.
                    readonly property string stillPath: {
                        if (isColor || !path)
                            return "";
                        if (typeof VideoWallpaperService !== "undefined")
                            return VideoWallpaperService.imageFor(path);
                        return isVideo ? "" : path;
                    }

                    width: Math.round(preview.thumbHeight * Sets.aspectOf(modelData, preview.layout, Quickshell.screens))
                    height: Math.round(preview.thumbHeight)
                    radius: Theme.cornerRadiusS
                    color: isColor ? path : Theme.surfaceContainerHighest

                    CachingImage {
                        anchors.fill: parent
                        visible: thumb.stillPath !== ""
                        imagePath: thumb.stillPath
                        maxCacheSize: DashMetrics.wallpaperThumbCache
                        animate: false
                    }

                    DIcon {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingXS
                        visible: thumb.isVideo
                        name: "movie"
                        size: Theme.iconSizeSmall
                        color: "white"
                        filled: true
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacingXS
                        text: thumb.modelData
                        font.pixelSize: Theme.fontSizeSmall
                        color: "white"
                        style: Text.Outline
                        styleColor: "#80000000"
                    }
                }
            }
        }
    }

    DFlickable {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true

        Column {
            id: content

            width: parent.width
            spacing: Theme.spacingL

            Card {
                id: currentCard

                width: parent.width
                height: currentRow.implicitHeight + pad * 2

                Row {
                    id: currentRow

                    width: parent.width
                    spacing: Theme.spacingL

                    SetPreview {
                        id: currentPreview

                        width: Math.min(parent.width * 0.45, DashMetrics.gridRowUnit * 3.5)
                        anchors.verticalCenter: parent.verticalCenter
                        wallpapers: root.currentWallpapers
                        layout: root.currentLayout
                        maxHeight: DashMetrics.gridRowUnit * 1.2
                    }

                    Column {
                        width: parent.width - currentPreview.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        StyledText {
                            text: root.tr("Current displays")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Theme.fontWeightMedium
                            color: currentCard.contentColor
                        }

                        StyledText {
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: root.activeIndex >= 0 ? root.tr("Matches set") + " “" + root.sets[root.activeIndex].name + "”" : !SessionData.perMonitorWallpaper ? root.tr("Every display shows the same wallpaper. Pick one per display in the Wallpapers tab, then save the combination here.") : root.tr("Not saved as a set yet")
                            font.pixelSize: Theme.fontSizeSmall
                            color: currentCard.mutedColor
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            DTextField {
                                id: nameField

                                width: parent.width - saveButton.width - parent.spacing
                                placeholderText: root.tr("Set name")
                                hidePlaceholderOnFocus: false
                                maximumLength: 64
                                onAccepted: root.saveCurrent()
                            }

                            DButton {
                                id: saveButton

                                anchors.verticalCenter: nameField.verticalCenter
                                text: Sets.indexOf(root.sets, nameField.text) >= 0 ? root.tr("Update") : root.tr("Save")
                                reserveText: root.tr("Update")
                                iconName: "bookmark_add"
                                enabled: nameField.text.trim() !== ""
                                onClicked: root.saveCurrent()
                            }
                        }
                    }
                }
            }

            StyledText {
                visible: root.sets.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.tr("No saved sets. Give the current combination a name and save it.")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingM
                visible: root.sets.length > 0

                Repeater {
                    model: root.sets

                    Card {
                        id: setCard

                        required property int index
                        required property var modelData
                        readonly property bool active: index === root.activeIndex

                        width: root.cardWidth
                        height: setColumn.implicitHeight + pad * 2
                        clickable: true
                        tone: active ? "primary" : ""
                        onClicked: root.applySet(index)

                        Column {
                            id: setColumn

                            width: parent.width
                            spacing: Theme.spacingS

                            SetPreview {
                                width: parent.width
                                wallpapers: setCard.modelData.wallpapers
                                layout: setCard.modelData.layout
                                maxHeight: DashMetrics.gridRowUnit
                            }

                            Item {
                                width: parent.width
                                height: Math.max(nameLabel.implicitHeight, deleteButton.height)

                                DIcon {
                                    id: activeIcon

                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: setCard.active
                                    name: "check_circle"
                                    size: Theme.iconSizeSmall
                                    color: setCard.accentColor
                                    filled: true
                                }

                                StyledText {
                                    id: nameLabel

                                    anchors.left: setCard.active ? activeIcon.right : parent.left
                                    anchors.leftMargin: setCard.active ? Theme.spacingXS : 0
                                    anchors.right: deleteButton.left
                                    anchors.rightMargin: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: setCard.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Theme.fontWeightMedium
                                    color: setCard.contentColor
                                }

                                DActionButton {
                                    id: deleteButton

                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    iconName: "delete"
                                    iconColor: setCard.mutedColor
                                    tooltipText: root.tr("Remove set")
                                    onClicked: root.removeSet(setCard.index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
