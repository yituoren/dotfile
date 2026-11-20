pragma Singleton
pragma ComponentBehavior: Bound

// Weather service
//
// Data flow:
//   1. At startup and every 30 minutes, get coordinates with the GeoClue where-am-i demo.
//      Fall back to ipapi.co/json on failure.
//   2. Fetch current, hourly and daily Open-Meteo data with timezone=auto.
//   Fall back to an NMC city station when location or Open-Meteo is unavailable.
//   3. Decode JSON into current conditions, 48 hourly entries and seven daily entries.
//
// Map WMO codes (0-99) to Material Symbols Rounded icons and weather labels.
// Expose precipitation, snow and thunder flags for WeatherEffects.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ============ Location ============
    property real lat: 0
    property real lon: 0
    property string locationName: ""   // IP geolocation may return a city name. GeoClue may supply only coordinates.
    property string locationSource: "" // "geoclue" | "ipapi"
    readonly property bool hasLocation: root.lat !== 0 || root.lon !== 0

    // ============ Current conditions ============
    property var current: null         // {temp, feels, humidity, wind, code, isDay, precip, time}

    // Up to 48 entries: {time: Date, temp, code, precipProb}
    property var hourly: []

    // Keep the next 24 hours from now and skip hours that have already passed.
    readonly property var hourlyNext24: {
        const now = new Date()
        const out = []
        for (let i = 0; i < root.hourly.length && out.length < 24; i++) {
            const delta = root.hourly[i].time.getTime() - now.getTime()
            if (delta >= -30 * 60 * 1000 && delta < 24 * 60 * 60 * 1000) {
                out.push(root.hourly[i])
            }
        }
        return out
    }

    // Seven entries: {date: Date, code, tmax, tmin, sunrise, sunset}
    property var daily: []

    property string status: "idle"     // "idle" | "loading" | "ok" | "error"
    property string updatedAt: ""      // Human-readable time of the most recent update

    // Particle effect triggers
    readonly property int currentCode: root.current ? root.current.code : -1
    readonly property bool isPrecip: [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].indexOf(root.currentCode) >= 0
    readonly property bool isSnow: [71, 73, 75, 77, 85, 86].indexOf(root.currentCode) >= 0
    readonly property bool isThunder: [95, 96, 99].indexOf(root.currentCode) >= 0
    readonly property bool isFog: [45, 48].indexOf(root.currentCode) >= 0
    readonly property bool isClear: [0, 1].indexOf(root.currentCode) >= 0

    // ============ WMO icons and descriptions ============
    // Use weather ligatures from Material Symbols Rounded, with fallback names as needed.
    function codeIcon(code: int, isDay: bool): string {
        switch (code) {
        case 0: return isDay ? "clear_day" : "clear_night"
        case 1: return isDay ? "clear_day" : "clear_night"
        case 2: return isDay ? "partly_cloudy_day" : "partly_cloudy_night"
        case 3: return "cloudy"
        case 45: case 48: return "foggy"
        case 51: case 53: case 55: return "rainy_light"
        case 56: case 57: return "weather_mix"
        case 61: case 63: case 80: case 81: return "rainy"
        case 65: case 82: return "rainy_heavy"
        case 66: case 67: return "weather_mix"
        case 71: case 73: case 85: return "cloudy_snowing"
        case 75: case 86: return "snowing_heavy"
        case 77: return "snowing"
        case 95: return "thunderstorm"
        case 96: case 99: return "thunderstorm"
        }
        return "cloudy"
    }

    function codeLabel(code: int): string {
        switch (code) {
        case 0: return "Clear"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45: return "Fog"
        case 48: return "Rime fog"
        case 51: return "Light drizzle"
        case 53: return "Drizzle"
        case 55: return "Heavy drizzle"
        case 56: case 57: return "Freezing drizzle"
        case 61: return "Light rain"
        case 63: return "Rain"
        case 65: return "Heavy rain"
        case 66: case 67: return "Freezing rain"
        case 71: return "Light snow"
        case 73: return "Snow"
        case 75: return "Heavy snow"
        case 77: return "Snow grains"
        case 80: return "Rain showers"
        case 81: return "Heavy showers"
        case 82: return "Violent showers"
        case 85: return "Snow showers"
        case 86: return "Heavy snow showers"
        case 95: return "Thunderstorm"
        case 96: case 99: return "Thunderstorm w/ hail"
        }
        return "—"
    }

    // ============ Location lookup ============
    Process {
        id: geoProc
        command: ["/usr/lib/geoclue-2.0/demos/where-am-i", "--timeout", "8"]
        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text || ""
                const latM = text.match(/Latitude:\s+(-?\d+(?:\.\d+)?)/)
                const lonM = text.match(/Longitude:\s+(-?\d+(?:\.\d+)?)/)
                if (latM && lonM) {
                    root.lat = parseFloat(latM[1])
                    root.lon = parseFloat(lonM[1])
                    root.locationSource = "geoclue"
                    root.fetchWeather()
                } else {
                    console.warn("Weather: geoclue parse failed, fallback to IP")
                    ipProc.running = true
                }
            }
        }
    }

    Process {
        id: ipProc
        command: ["curl", "-fsSL", "--max-time", "6", "-H", "Accept-Language: en", "https://ipapi.co/json/"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text || "{}")
                    if (Number.isFinite(d.latitude) && Number.isFinite(d.longitude)) {
                        root.lat = d.latitude
                        root.lon = d.longitude
                        root.locationName = d.city || ""
                        root.locationSource = "ipapi"
                        root.fetchWeather()
                    } else {
                        root.fetchStation()
                    }
                } catch (e) {
                    root.fetchStation()
                }
            }
        }
    }

    // ============ City name ============
    // Reuse ipapi.co/json because the proxy blocks reverse geocoders such as Nominatim.
    // IP geolocation is less precise than GeoClue but usually sufficient for the city label.
    Process {
        id: cityProc
        command: ["curl", "-fsSL", "--max-time", "6", "-H", "Accept-Language: en", "https://ipapi.co/json/"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text || "{}")
                    if (d.city) root.locationName = d.city
                } catch (e) {
                    // Ignore lookup failures.
                }
            }
        }
    }

    function fetchCity(): void {
        if (cityProc.running) return
        cityProc.running = true
    }

    // ============ Open-Meteo ============
    Process {
        id: forecastProc
        property bool station: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text || "{}")
                    if (!d.current) {
                        root.forecastFailed()
                        return
                    }
                    root.current = {
                        time: d.current.time,
                        temp: d.current.temperature_2m,
                        feels: d.current.apparent_temperature,
                        humidity: d.current.relative_humidity_2m,
                        wind: d.current.wind_speed_10m,
                        precip: d.current.precipitation,
                        code: d.current.weather_code,
                        isDay: d.current.is_day === 1
                    }
                    // Read up to 48 forecast hours.
                    const hh = []
                    if (d.hourly && d.hourly.time) {
                        const n = Math.min(48, d.hourly.time.length)
                        for (let i = 0; i < n; i++) {
                            hh.push({
                                time: new Date(d.hourly.time[i]),
                                temp: d.hourly.temperature_2m[i],
                                code: d.hourly.weather_code[i],
                                precipProb: d.hourly.precipitation_probability ? d.hourly.precipitation_probability[i] : 0
                            })
                        }
                    }
                    root.hourly = hh
                    // Read seven forecast days.
                    const dd = []
                    if (d.daily && d.daily.time) {
                        for (let i = 0; i < d.daily.time.length; i++) {
                            dd.push({
                                date: new Date(d.daily.time[i]),
                                code: d.daily.weather_code[i],
                                tmax: d.daily.temperature_2m_max[i],
                                tmin: d.daily.temperature_2m_min[i],
                                sunrise: d.daily.sunrise ? d.daily.sunrise[i] : "",
                                sunset: d.daily.sunset ? d.daily.sunset[i] : ""
                            })
                        }
                    }
                    root.daily = dd
                    if (forecastProc.station) {
                        root.locationName = d.city
                        root.locationSource = "nmc"
                    }
                    root.status = "ok"
                    console.info("Weather:", root.locationSource, root.locationName, root.current.temp,
                                 "°C,", root.hourlyNext24.length, "forecast points,", dd.length, "days")
                    root.updatedAt = Qt.formatDateTime(new Date(), "HH:mm")
                    // Look up a city name if the coordinates are already available.
                    if (!root.locationName && root.hasLocation) root.fetchCity()
                } catch (e) {
                    console.warn("Weather: forecast parse failed", e)
                    root.forecastFailed()
                }
            }
        }
    }

    function forecastFailed(): void {
        if (!forecastProc.station) {
            Qt.callLater(root.fetchStation)
        } else {
            root.status = "error"
        }
    }

    function fetchStation(): void {
        root.status = "loading"
        forecastProc.station = true
        forecastProc.command = ["python3", Quickshell.shellPath("scripts/nmc-weather.py")]
        forecastProc.running = true
    }

    function fetchWeather(): void {
        if (!root.hasLocation) return
        root.status = "loading"
        const params = [
            "latitude=" + root.lat,
            "longitude=" + root.lon,
            "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m",
            "hourly=temperature_2m,precipitation_probability,weather_code",
            "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset",
            "timezone=auto",
            "forecast_days=7"
        ]
        const url = "https://api.open-meteo.com/v1/forecast?" + params.join("&")
        forecastProc.station = false
        forecastProc.command = ["curl", "-fsSL", "--max-time", "10", url]
        forecastProc.running = true
    }

    function refresh(): void {
        if (geoProc.running || ipProc.running || forecastProc.running) return
        if (root.locationSource === "nmc") {
            root.fetchStation()
        } else if (root.hasLocation) {
            // Refresh the forecast at the known location. Recheck location every 30 minutes.
            root.fetchWeather()
        } else {
            geoProc.running = true
        }
    }

    // Refresh the weather every 15 minutes.
    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // Recheck location every 30 minutes and fetch a new forecast if it changes.
    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        onTriggered: { if (!geoProc.running && !ipProc.running && !forecastProc.running) geoProc.running = true }
    }
}
