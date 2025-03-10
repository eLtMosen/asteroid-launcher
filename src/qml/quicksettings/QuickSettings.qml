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

    // Add a property to track charge animation state
    property bool chargeAnimationsCompleted: false

    MceBatteryLevel { id: batteryChargePercentage }
    MceBatteryState { id: batteryChargeState }
    MceChargerType { id: mceChargerType }

    DisplaySettings {
        id: displaySettings
        onBrightnessChanged: updateBrightnessToggle()
    }

    NonGraphicalFeedback { id: feedback; event: "press" }

    ProfileControl { id: profileControl }

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
        if (brightnessToggle) brightnessToggle.toggled = displaySettings.brightness > 80  // Check if defined
    }

    Item {
        id: batteryMeter
        width: toggleSize * 1.5
        height: toggleSize * 0.5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: quickSettingsView.top
        anchors.bottomMargin: quickSettingsView.spacing * 4

        Rectangle {
            id: batteryOutline
            width: parent.width
            height: parent.height
            color: "#222222"
            opacity: 0.75
            radius: height / 2
        }

        Rectangle {
            id: batteryFill
            height: parent.height
            width: {
                var baseWidth = parent.width * (batteryChargePercentage.percent / 100)
                if (mceChargerType.type != MceChargerType.None && chargeAnimationsCompleted) {
                    var waveAmplitude = parent.width * 0.05
                    return baseWidth + waveAmplitude * Math.sin(waveTime)
                }
                return baseWidth
            }
            color: colorArray[chargecolor]
            anchors.left: parent.left
            opacity: mceChargerType.type == MceChargerType.None ? 0.3 : 0.4

            property real waveTime: 0

            // Wave animation that only starts when chargeAnimationsCompleted is true
            NumberAnimation on waveTime {
                id: waveAnimation
                running: mceChargerType.type != MceChargerType.None && chargeAnimationsCompleted
                from: 0
                to: 2 * Math.PI
                duration: 1500
                loops: Animation.Infinite
            }
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Item {
                width: batteryMeter.width
                height: batteryMeter.height
                Rectangle { anchors.fill: parent; radius: batteryOutline.radius }
            }
        }
    }

    Item {
        id: batteryPercent
        anchors.centerIn: batteryMeter
        height: batteryMeter.height / 2
        width: toggleSize  // Replaced batteryIndicator.width with a fixed value
        opacity: mceChargerType.type == MceChargerType.None ? 0.8 : 0.9

        Label {
            id: batteryPercentText
            font {
                pixelSize: parent.height * 1
                family: "Noto Sans"
                styleName: "Condensed Medium"
            }
            text: batteryChargePercentage.percent + "%"
            anchors.centerIn: parent
        }
    }

    PageDot {
        id: pageDots
        height: Dims.h(3)
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: Dims.h(3.8)
        }
        currentIndex: quickSettingsView.currentIndex
        dotNumber: quickSettingsView.rowCount
        opacity: 0.5
    }

    ListView {
        id: quickSettingsView
        anchors.centerIn: parent
        width: toggleSize * 3 + spacing * 2
        height: toggleSize
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: Dims.l(2)

        property var allToggles: [
            { component: brightnessToggleComponent, toggleAvailable: true },
            { component: bluetoothToggleComponent, toggleAvailable: true },
            { component: hapticsToggleComponent, toggleAvailable: true },
            { component: wifiToggleComponent, toggleAvailable: true }, //DeviceInfo.hasWlan
            { component: soundToggleComponent, toggleAvailable: true }, //DeviceInfo.hasSound
            { component: settingsButtonComponent, toggleAvailable: true }
        ]

        property var availableToggles: allToggles.filter(toggle => toggle.toggleAvailable)
        property int rowCount: Math.ceil(availableToggles.length / 3)

        model: {
            var rows = []
            for (var i = 0; i < availableToggles.length; i += 3) {
                rows.push(availableToggles.slice(i, i + 3))
            }
            return rows
        }

        contentWidth: width * rowCount

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

        Component.onCompleted: positionViewAtBeginning()

        onContentXChanged: {
            var newIndex = Math.round(contentX / width)
            if (newIndex >= 0 && newIndex < rowCount) currentIndex = newIndex
        }
    }

    Item {
        id: chargeAnimationContainer
        anchors.fill: parent
        z: 100

        Connections {
            target: mceChargerType
            function onTypeChanged() {
                console.log("Charger type changed to:", mceChargerType.type, "Charging:", mceChargerType.type != MceChargerType.None)
                chargeAnimationsCompleted = false // Reset animation state
                chargeAnimationContainer.state = (mceChargerType.type != MceChargerType.None) ? "charging" : "discharging"
            }
        }

        states: [
            State {
                name: "charging"
                PropertyChanges {
                    target: flashIcon
                    y: Dims.l(7)
                }
                PropertyChanges {
                    target: chargeRectangle
                    height: Dims.l(12)
                }
            },
            State {
                name: "discharging"
                PropertyChanges {
                    target: flashIcon
                    y: -flashIcon.height
                }
                PropertyChanges {
                    target: chargeRectangle
                    height: 0
                }
            }
        ]

        transitions: [
            Transition {
                from: "discharging"
                to: "charging"
                SequentialAnimation {
                    // Parallel animation for the charge animations
                    ParallelAnimation {
                        NumberAnimation { target: flashIcon; property: "y"; duration: 1000; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: chargeRectangle; property: "height"; duration: 1000; easing.type: Easing.InOutQuad }
                    }
                    // Pause for a moment
                    PauseAnimation { duration: 200 }
                    // Set the completed flag to true
                    ScriptAction { script: { chargeAnimationsCompleted = true; } }
                }
            },
            Transition {
                from: "charging"
                to: "discharging"
                SequentialAnimation {
                    // Reset completed flag first
                    ScriptAction { script: { chargeAnimationsCompleted = false; } }
                    // Then run the animations
                    ParallelAnimation {
                        NumberAnimation { target: flashIcon; property: "y"; duration: 1000; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: chargeRectangle; property: "height"; duration: 1000; easing.type: Easing.InOutQuad }
                    }
                }
            }
        ]

        Rectangle {
            id: chargeRectangle
            width: Dims.l(6)
            height: 0
            color: "#222222"
            opacity: 0.75
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
        }

        Icon {
            id: flashIcon
            width: Dims.l(10)
            height: Dims.l(10)
            name: "ios-flash"
            anchors.horizontalCenter: parent.horizontalCenter
            y: -Dims.l(10)
        }

        Component.onCompleted: {
            console.log("Initial charger state:", mceChargerType.type, "Screen height:", rootitem.height)
            chargeAnimationContainer.state = (mceChargerType.type != MceChargerType.None) ? "charging" : "discharging"
        }

        onStateChanged: {
            console.log("Animation state changed to:", state, "Flash y:", flashIcon.y, "Rect height:", chargeRectangle.height)
        }
    }

    // Toggle components
    Component {
        id: brightnessToggleComponent
        QuickSettingsToggle {
            id: brightnessToggle  // Added id
            icon: "ios-sunny"
            onChecked: displaySettings.brightness = 100
            onUnchecked: displaySettings.brightness = 0
            Component.onCompleted: updateBrightnessToggle()
        }
    }

    Component { id: soundToggleComponent; QuickSettingsToggle { icon: "ios-sound-indicator-high"; toggled: true } }

    Component {
        id: hapticsToggleComponent
        QuickSettingsToggle {
            icon: "ios-watch-vibrating"
            onChecked: { profileControl.profile = "general"; delayTimer.start() }
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
            Connections { target: wifiStatus; function onPoweredChanged() { toggled = wifiStatus.powered } }
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

    Component { id: settingsButtonComponent; QuickSettingsToggle { icon: "ios-settings" } }
}
