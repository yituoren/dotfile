"""Return the NMC station forecast in the format consumed by Weather.qml."""

from datetime import datetime, timedelta, timezone
import json
import re
import subprocess
import sys
from urllib.parse import urlencode

BASE = "https://www.nmc.cn"
CST = timezone(timedelta(hours=8))
# NMC weather icon index -> WMO weather code.
CODES = [0, 2, 3, 80, 95, 96, 68, 61, 63, 65, 65, 65, 65, 85, 71, 73,
         75, 75, 45, 66, 48, 63, 65, 65, 65, 65, 73, 75, 75, 48, 48, 48]


def get(path):
    return subprocess.check_output(
        ["curl", "-fsSL", "--max-time", "10", "-H", "Accept-Language: en", BASE + path], text=True)


def value(raw):
    if raw in (None, "", "-"):
        return None
    n = float(raw)
    return n if abs(n) < 9999 else None


def code(raw):
    i = int(raw) if str(raw).isdigit() else -1
    return CODES[i] if 0 <= i < len(CODES) else -1


def forecast():
    station = json.loads(get("/rest/position"))
    data = json.loads(get("/rest/weather?" + urlencode({"stationid": station["code"]})))["data"]
    real, predict = data["real"], data["predict"]
    observed = real["publish_time"]
    day = real["sunriseSunset"]["sunrise"] <= observed < real["sunriseSunset"]["sunset"]
    w = real["weather"]
    current_code = code(w["img"])
    if current_code < 0:
        period = predict["detail"][0]["day" if day else "night"]
        current_code = code(period["weather"]["img"])
    speed = value(real["wind"]["speed"])
    current = dict(time=observed, temperature_2m=value(w["temperature"]),
                   apparent_temperature=value(w["feelst"]), relative_humidity_2m=value(w["humidity"]),
                   wind_speed_10m=None if speed is None else speed * 3.6,
                   precipitation=value(w["rain"]), weather_code=current_code, is_day=int(day))
    if current["temperature_2m"] is None:
        raise ValueError("missing station temperature")

    daily = dict(time=[], weather_code=[], temperature_2m_max=[], temperature_2m_min=[])
    extrema = {row["time"].replace("/", "-"): row for row in data["tempchart"]}
    for row in predict["detail"][:7]:
        date = row["date"]
        high, low = row["day"]["weather"], row["night"]["weather"]
        chart = extrema.get(date, {})
        daily["time"].append(date)
        daily["weather_code"].append(code(low["img"] if code(high["img"]) < 0 else high["img"]))
        for key, raw, fallback in (("temperature_2m_max", high["temperature"], "max_temp"),
                                   ("temperature_2m_min", low["temperature"], "min_temp")):
            temp = value(raw)
            daily[key].append(temp if temp is not None else value(chart.get(fallback)))

    # The station page publishes future temperatures at three-hour intervals.
    # Use the actual times, including day rollovers, without inventing intervening values.
    hourly = dict(time=[], temperature_2m=[], weather_code=[])
    previous = datetime.fromisoformat(predict["publish_time"]).replace(tzinfo=CST)
    html = get(station["url"]).split("id=hourValues>", 1)[-1]
    for block in re.split(r'<div class="hour3[^"]*">', html)[1:]:
        match = re.search(r'<div>\s*(?:\d+日)?(\d\d):(\d\d)\s*</div>.*?/([0-9]+)\.png.*?>(?:\s*)(-?\d+(?:\.\d+)?)℃', block, re.S)
        if not match:
            continue
        hh, mm, icon, temp = match.groups()
        at = previous.replace(hour=int(hh), minute=int(mm))
        if at < previous:
            at += timedelta(days=1)
        previous = at
        hourly["time"].append(at.isoformat())
        hourly["temperature_2m"].append(float(temp))
        hourly["weather_code"].append(code(icon))
    if not hourly["time"] or not daily["time"]:
        raise ValueError("missing station forecast")
    return dict(city=real["station"]["city"], current=current, hourly=hourly, daily=daily)


if __name__ == "__main__":
    try:
        print(json.dumps(forecast(), ensure_ascii=False))
    except (KeyError, ValueError, TypeError, IndexError, subprocess.SubprocessError) as error:
        sys.exit(f"NMC weather: {error}")
