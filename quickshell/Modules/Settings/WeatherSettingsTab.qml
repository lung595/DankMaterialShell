import QtQuick
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Settings.Widgets
import "../../Common/IslandWeather.js" as IslandWeather

Item {
    id: root

    property var parentModal: null
    readonly property var coordinates: SettingsData.weatherCoordinates.split(",")
    readonly property bool validCoordinates: latitude.text.trim() !== "" && longitude.text.trim() !== "" && Number.isFinite(Number(latitude.text)) && Number.isFinite(Number(longitude.text)) && Math.abs(Number(latitude.text)) <= 90 && Math.abs(Number(longitude.text)) <= 180

    function saveCoordinates() {
        if (!validCoordinates)
            return;
        SettingsData.setWeatherLocation("", Number(latitude.text) + "," + Number(longitude.text));
    }

    SettingsPage {
        SettingsCard {
            title: I18n.tr("General")
            tab: "weather"
            settingKey: "weather"

            SettingsToggleRow {
                tab: "weather"
                settingKey: "weatherEnabled"
                tags: ["weather", "enable", "forecast"]
                text: I18n.tr("Weather")
                checked: SettingsData.weatherEnabled
                onToggled: checked => SettingsData.set("weatherEnabled", checked)
            }

            SettingsToggleRow {
                tab: "weather"
                settingKey: "useFahrenheit"
                tags: ["weather", "imperial", "fahrenheit", "celsius", "units", "mph"]
                text: I18n.tr("Imperial units")
                checked: SettingsData.useFahrenheit
                onToggled: checked => SettingsData.set("useFahrenheit", checked)
            }

            SettingsToggleRow {
                enabled: !SettingsData.useFahrenheit
                tab: "weather"
                settingKey: "windSpeedUnit"
                tags: ["weather", "wind", "speed", "units", "metric"]
                text: I18n.tr("Wind speed in m/s")
                checked: SettingsData.windSpeedUnit === "ms"
                onToggled: checked => SettingsData.set("windSpeedUnit", checked ? "ms" : "kmh")
            }
        }

        // One box per island weather alert. An event the forecast cannot tell is greyed, never silently off: its row says
        // so.
        SettingsCard {
            id: alerts

            readonly property var gaps: IslandWeather.missing(SettingsData.weatherEnabled ? WeatherService.weather : null)
            readonly property var ticked: SettingsData.islandWeatherAlerts ?? []

            title: I18n.tr("Island alerts", "weather settings: the island's weather alerts")
            iconName: "rainy"
            tab: "weather"
            settingKey: "islandWeatherAlerts"
            tags: ["weather", "island", "alert", "rain", "hail", "snow", "ice", "storm", "wind", "fog", "heat", "uv"]

            Repeater {
                model: [
                    {
                        "id": "rain",
                        "icon": "rainy",
                        "text": I18n.tr("Rain", "island weather alert")
                    },
                    {
                        "id": "hail",
                        "icon": "weather_hail",
                        "text": I18n.tr("Hail", "island weather alert")
                    },
                    {
                        "id": "snow",
                        "icon": "weather_snowy",
                        "text": I18n.tr("Snow and ice", "island weather alert")
                    },
                    {
                        "id": "storm",
                        "icon": "thunderstorm",
                        "text": I18n.tr("Storm and strong wind", "island weather alert")
                    },
                    {
                        "id": "fog",
                        "icon": "foggy",
                        "text": I18n.tr("Fog", "island weather alert")
                    },
                    {
                        "id": "heat",
                        "icon": "sunny",
                        "text": I18n.tr("Heat and UV", "island weather alert")
                    }
                ]

                SettingsRow {
                    id: alertRow

                    required property var modelData
                    readonly property bool gap: alerts.gaps.indexOf(modelData.id) >= 0
                    readonly property bool on: alerts.ticked.indexOf(modelData.id) >= 0

                    tab: "weather"
                    tags: ["weather", "alert", modelData.id]
                    iconName: modelData.icon
                    title: modelData.text
                    titleColor: alertRow.gap ? Theme.surfaceVariantText : contentColor
                    iconColor: alertRow.gap ? Theme.surfaceVariantText : Theme.primary
                    subtitle: !alertRow.gap ? "" : SettingsData.weatherEnabled ? I18n.tr("Not in your forecast", "weather settings: an alert the forecast cannot give") : I18n.tr("Needs the weather on", "weather settings: alerts need the weather")
                    clickable: !alertRow.gap
                    onClicked: {
                        const rest = alerts.ticked.filter(e => e !== alertRow.modelData.id);
                        SettingsData.set("islandWeatherAlerts", alertRow.on ? rest : rest.concat([alertRow.modelData.id]));
                    }
                    Accessible.role: Accessible.CheckBox
                    Accessible.checkable: !alertRow.gap
                    Accessible.checked: alertRow.on && !alertRow.gap

                    DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: alertRow.on && !alertRow.gap ? "check_box" : "check_box_outline_blank"
                        size: Theme.iconSize
                        color: alertRow.gap ? Theme.withAlpha(Theme.surfaceText, 0.38) : alertRow.on ? Theme.primary : Theme.surfaceVariantText
                    }
                }
            }
        }

        SettingsCard {
            title: I18n.tr("Location")
            tab: "weather"
            settingKey: "weatherLocation"
            tags: ["weather", "location", "city", "coordinates"]

            SettingsToggleRow {
                tab: "weather"
                settingKey: "useAutoLocation"
                tags: ["weather", "location", "auto", "gps", "ip"]
                text: I18n.tr("Auto location")
                checked: SettingsData.useAutoLocation
                onToggled: checked => SettingsData.set("useAutoLocation", checked)
            }

            SettingsRow {
                enabled: !SettingsData.useAutoLocation
                title: I18n.tr("Location search")
                body: DLocationSearch {
                    width: parent.width
                    currentLocation: SettingsData.weatherLocation
                    placeholderText: I18n.tr("New York, NY")
                    onLocationSelected: (displayName, coordinates) => SettingsData.setWeatherLocation(displayName, coordinates)
                }
            }

            SettingsRow {
                enabled: !SettingsData.useAutoLocation
                title: I18n.tr("Custom location")
                body: Column {
                    width: parent.width
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        DTextField {
                            id: latitude
                            outlined: true
                            leftIconName: "location_on"
                            width: (parent.width - parent.spacing) / 2
                            labelText: I18n.tr("Latitude", "weather location coordinate text field label")
                            text: root.coordinates[0]?.trim() ?? ""
                            keyNavigationTab: longitude
                            onAccepted: root.saveCoordinates()
                        }

                        DTextField {
                            id: longitude
                            outlined: true
                            leftIconName: "location_on"
                            width: (parent.width - parent.spacing) / 2
                            labelText: I18n.tr("Longitude", "weather location coordinate text field label")
                            text: root.coordinates[1]?.trim() ?? ""
                            keyNavigationBacktab: latitude
                            onAccepted: root.saveCoordinates()
                        }
                    }

                    DButton {
                        text: I18n.tr("Apply", "verb, button that saves custom weather coordinates")
                        enabled: root.validCoordinates
                        onClicked: root.saveCoordinates()
                    }
                }
            }
        }

        SettingsCard {
            title: I18n.tr("Display")
            tab: "weather"
            settingKey: "weatherDisplay"

            SettingsToggleRow {
                readonly property var lockStatus: SettingsData.lockWidgetInstance("lockStatus")

                tab: "weather"
                settingKey: "lockStatusWeather"
                tags: ["weather", "lock", "screen"]
                visible: lockStatus !== null
                text: I18n.tr("Lock screen")
                checked: lockStatus?.config?.showWeather ?? true
                onToggled: checked => SettingsData.updateDesktopWidgetInstanceConfig(lockStatus.id, {
                        showWeather: checked
                    })
            }

            SettingsNavRow {
                title: I18n.tr("Dashboard")
                iconName: "space_dashboard"
                onClicked: keyboard => root.parentModal?.navigateTo("dank_dash", keyboard)
            }

            SettingsNavRow {
                title: I18n.tr("Bar widgets")
                iconName: "widgets"
                onClicked: keyboard => root.parentModal?.navigateTo("dankbar_widgets", keyboard)
            }
        }
    }
}
