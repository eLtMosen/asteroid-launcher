/*
 * Copyright (C) 2015 Florent Revest <revestflo@gmail.com>
 *               2014 Aleksi Suomalainen <suomalainen.aleksi@gmail.com>
 * All rights reserved.
 *
 * You may use this file under the terms of BSD license as follows:
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the author nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import QtQuick 2.9
import Nemo.Mce 1.0
import Nemo.DBus 2.0
import org.nemomobile.systemsettings 1.0
import Nemo.Ngf 1.0
import org.asteroid.controls 1.0
import org.asteroid.utils 1.0
import Connman 0.2
import QtGraphicalEffects 1.15
import Qt.labs.settings 1.0

Item {
    id: rootitem
    width: parent.width
    height: parent.height

    property bool forbidLeft: true
    property bool forbidRight: true
    property int toggleSize: Dims.l(30)  // Increased toggle size
    property real chargecolor: Math.floor(batteryChargePercentage.percent / 33.35)
    readonly property var colorArray: [ "red", "yellow", Qt.rgba(.318, 1, .051, .9)]

    Item { Settings { fileName: "/etc/asteroid/machine.conf" Component.onCompleted: console.log(value("Capabilities/HAS_WLAN")) } }

    MceBatteryLevel {
        id: batteryChargePercentage
    }

    MceBatteryState {
        id: batteryChargeState
    }

    MceChargerType {
        id: mceChargerType
    }

    // Sync brightness toggle with display settings
    DisplaySettings {
        id: displaySettings
        onBrightnessChanged: updateBrightnessToggle()
    }

    NonGraphicalFeedback {
        id: feedback
        event: "press"
    }

    ProfileControl {
        id: profileControl
    }

    // Haptic feedback delay timer
    Timer {
        id: delayTimer
        interval: 125
        repeat: false
        onTriggered: feedback.play()
    }

    BluetoothStatus {
        id: btStatus
        onPoweredChanged: bluetoothToggle.toggled = btStatus.powered
    }

    NetworkTechnology {
        id: wifiStatus
        path: "/net/connman/technology/wifi"
    }

    function updateBrightnessToggle() {
        brightnessToggle.toggled = displaySettings.brightness > 80
    }

    ListView {
        id: quickSettingsView
        anchors.centerIn: parent
        width: toggleSize * 3 + spacing * 2  // Width for 3 toggles + spacing
        height: toggleSize
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        clip: true
        interactive: true  // Enable swiping
        boundsBehavior: Flickable.StopAtBounds

        spacing: Dims.l(2)

        // All toggles in a flat list with availability flags
        property var allToggles: [
            { component: brightnessToggleComponent, toggleAvailable: true },
            { component: bluetoothToggleComponent, toggleAvailable: true },
            { component: hapticsToggleComponent, toggleAvailable: true },
            { component: wifiToggleComponent, toggleAvailable: DeviceInfo.hasWlan }, //DeviceInfo.hasWlan
            { component: soundToggleComponent, toggleAvailable: true }, //DeviceInfo.hasSpeaker
            { component: settingsButtonComponent, toggleAvailable: true }
        ]

        // Filter available toggles and chunk into rows of 3
        property var availableToggles: allToggles.filter(toggle => toggle.toggleAvailable)
        property int rowCount: Math.ceil(availableToggles.length / 3)

        model: {
            var rows = []
            for (var i = 0; i < availableToggles.length; i += 3) {
                rows.push(availableToggles.slice(i, i + 3))
            }
            return rows
        }

        contentWidth: width * rowCount  // Width for actual rows only

        delegate: Item {
            id: pageItem
            width: quickSettingsView.width
            height: quickSettingsView.height

            Row {
                id: toggleRow
                spacing: quickSettingsView.spacing

                Repeater {
                    model: modelData
                    delegate: Loader {
                        width: toggleSize
                        height: toggleSize
                        sourceComponent: modelData.component
                    }
                }

                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // Start at the first row
        Component.onCompleted: positionViewAtBeginning()

        // Sync currentIndex with visible item
        onContentXChanged: {
            var newIndex = Math.round(contentX / width)
            if (newIndex >= 0 && newIndex < rowCount) {
                currentIndex = newIndex
            }
        }
    }

    Item {
        id: batteryMeter
        width: toggleSize * 1.4  // 2x wider than height
        height: toggleSize * 0.6
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: quickSettingsView.bottom
        anchors.topMargin: quickSettingsView.spacing * 3

        Rectangle {
            id: batteryOutline
            width: parent.width
            height: parent.height
            color: "#222222"
            opacity: 0.75
            radius: height / 2  // Rounded edges, adjusted for aesthetics
        }
        Rectangle {
            id: batteryFill
            width: parent.width * (batteryChargePercentage.percent / 100)
            height: parent.height
            color: colorArray[chargecolor]
            anchors.left: parent.left
            opacity: 0.95
        }

        // Clip the fill to the rounded rectangle outline
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Item {
                width: batteryMeter.width
                height: batteryMeter.height
                Rectangle {
                    anchors.fill: parent
                    radius: batteryOutline.radius
                }
            }
        }
    }

    Item {
        id: batteryPercent
        anchors.centerIn: batteryMeter
        height: batteryMeter.height / 2  // Adjusted to fit nicely
        width: batteryIndicator.width
        opacity: mceChargerType.type == MceChargerType.None ? 0.9 : 1

        Label {
            id: batteryPercentText
            font {
                pixelSize: parent.height * 1  // Scaled to fit
                family: "Noto Sans"
                styleName: "Condensed Bold"
            }
            text: batteryChargePercentage.percent + "%"
            anchors.centerIn: parent
        }
    }

    Item {
        id: batteryChargeIndicator
        anchors.horizontalCenter: batteryMeter.horizontalCenter
        anchors.top: batteryMeter.bottom
        anchors.topMargin: quickSettingsView.spacing
        height: parent.height / 4
        width: batteryIndicator.width
        opacity: mceChargerType.type == MceChargerType.None ? 0.4 : 0.8

        Label {
            id: batteryChargeText
            font {
                pixelSize: parent.height / 2  // Adjusted for size
                bold: true
            }
            text: mceChargerType.type == MceChargerType.None ? "Discharging" : "Charging"
            anchors.centerIn: parent
        }
    }

    PageDot {
        id: pageDots
        height: Dims.h(3)
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: Dims.h(3.8)
        }
        currentIndex: quickSettingsView.currentIndex
        dotNumber: quickSettingsView.rowCount
        opacity: 0.5  // Base opacity for inactive dots
    }

    // Toggle components
    Component {
        id: brightnessToggleComponent
        QuickSettingsToggle {
            icon: "ios-sunny"
            onChecked: displaySettings.brightness = 100
            onUnchecked: displaySettings.brightness = 0
            Component.onCompleted: updateBrightnessToggle()
        }
    }

    Component {
        id: soundToggleComponent
        QuickSettingsToggle {
            icon: "ios-sound-indicator-high"
            toggled: true
        }
    }

    Component {
        id: hapticsToggleComponent
        QuickSettingsToggle {
            icon: "ios-watch-vibrating"
            onChecked: {
                profileControl.profile = "general"
                delayTimer.start()
            }
            onUnchecked: profileControl.profile = "silent"
            Component.onCompleted: toggled = profileControl.profile == "general"
        }
    }

    Component {
        id: wifiToggleComponent
        QuickSettingsToggle {
            icon: wifiStatus.connected ? "ios-wifi" : "ios-wifi-outline"
            toggled: wifiStatus.powered
            onChecked: wifiStatus.powered = true
            onUnchecked: wifiStatus.powered = false
            Component.onCompleted: Qt.callLater(function() { toggled = wifiStatus.powered })
            Connections {
                target: wifiStatus
                function onPoweredChanged() { toggled = wifiStatus.powered }
            }
        }
    }

    Component {
        id: bluetoothToggleComponent
        QuickSettingsToggle {
            icon: btStatus.connected ? "ios-bluetooth-connected" : "ios-bluetooth"
            onChecked: btStatus.powered = true
            onUnchecked: btStatus.powered = false
            Component.onCompleted: toggled = btStatus.powered
        }
    }

    Component {
        id: settingsButtonComponent
        QuickSettingsToggle {
            icon: "ios-settings"
        }
    }
}
