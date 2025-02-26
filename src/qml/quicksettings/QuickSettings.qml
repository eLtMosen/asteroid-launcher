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

Item {
    id: rootitem
    width: parent.width
    height: parent.height

    property bool forbidLeft:  true
    property bool forbidRight: true
property int toggleSize: Dims.l(28)

    MceBatteryLevel {
        id: batteryChargePercentage
    }

    MceBatteryState {
        id: batteryChargeState
    }

    // Moved components outside Grid
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

    Grid {
        id: quickSettingsGrid
        anchors.centerIn: parent
        rows: 2
        columns: 3
        spacing: Dims.l(2)

        // Row 1, Column 1: brightness Toggle
        QuickSettingsToggle {
            id: brightnessToggle
            width: toggleSize
            height: toggleSize
            icon: "ios-sunny"
            onChecked: displaySettings.brightness = 100
            onUnchecked: displaySettings.brightness = 0
            Component.onCompleted: updateBrightnessToggle()
        }

        // Row 1, Column 2: Sound Toggle (dummy)
        QuickSettingsToggle {
            id: soundToggle
            width: toggleSize
            height: toggleSize
            icon: "ios-sound-indicator-high"
        }

        // Row 1, Column 3: Haptics Toggle
        QuickSettingsToggle {
            id: hapticsToggle
            width: toggleSize
            height: toggleSize
            icon: "ios-watch-vibrating"
            onChecked: {
                profileControl.profile = "general";
                delayTimer.start();
            }
            onUnchecked: profileControl.profile = "silent";
            Component.onCompleted: toggled = profileControl.profile == "general"
        }

        // Row 2, Column 1: WiFi Toggle
        QuickSettingsToggle {
            id: wifiToggle
            width: toggleSize
            height: toggleSize
            icon: wifiStatus.connected ? "ios-wifi" : "ios-wifi-outline"
            onChecked:   wifiStatus.powered = true
            onUnchecked: wifiStatus.powered = false
            Component.onCompleted: toggled = wifiStatus.powered
        }

        // Row 2, Column 2: Bluetooth Toggle
        QuickSettingsToggle {
            id: bluetoothToggle
            width: toggleSize
            height: toggleSize
            icon: btStatus.connected ? "ios-bluetooth-connected" : "ios-bluetooth"
            onChecked:   btStatus.powered = true
            onUnchecked: btStatus.powered = false
            Component.onCompleted: toggled = btStatus.powered
        }

        // Row 2, Column 3: settings button
        QuickSettingsToggle {
            id: settingsButton
            width: toggleSize
            height: toggleSize
            icon: "ios-settings"
        }
    }

    Item {
        id: battery
        anchors.horizontalCenter: rootitem.horizontalCenter
        anchors.bottom: rootitem.bottom
        height: parent.height/3
        width: batteryIcon.width + batteryIndicator.width

        Icon {
            id: batteryIcon
            name: {
                if(batteryChargeState.value == MceBatteryState.Charging) return "ios-battery-charging"
                else if(batteryChargePercentage.percent > 15)            return "ios-battery-full"
                else                                                     return "ios-battery-dead"
            }
            width:  parent.height/2
            height: width
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            id: batteryIndicator
            font.pixelSize: parent.height/4
            text: batteryChargePercentage.percent + "%"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
