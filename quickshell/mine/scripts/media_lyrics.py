#!/usr/bin/python
"""Resolve the current MPRIS track without sending local paths or playlist URLs to a catalogue."""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import time
import unicodedata
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlencode, urlsplit
from urllib.request import Request, urlopen

MAX_BYTES = 1024 * 1024


def normalized(value):
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def key(parts):
    return hashlib.sha256(json.dumps(parts, ensure_ascii=False).encode()).hexdigest()


def save(path, data):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as f:
        json.dump(data, f, ensure_ascii=False)
    os.replace(f.name, path)


def stored(path, age):
    try:
        if time.time() - path.stat().st_mtime < age:
            return json.loads(path.read_text())
    except (ValueError, OSError):
        pass
    return None


def api(url, params):
    req = Request(url + "?" + urlencode(params), headers={"User-Agent": "mine-quickshell-lyrics/1.0"})
    with urlopen(req, timeout=4) as response:
        raw = response.read(MAX_BYTES + 1)
        if len(raw) > MAX_BYTES:
            raise ValueError("response too large")
        return json.loads(raw)


def parsed(text, source):
    rows = []
    pattern = r"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]"
    offset = re.search(r"\[offset:([+-]?\d+)\]", text, re.I)
    for line in text.splitlines():
        stamps = list(re.finditer(pattern, line))
        if stamps:
            body = line[stamps[-1].end():].strip()
            for m in stamps:
                sec = int(m[1]) * 60 + int(m[2]) + int((m[3] or "").ljust(3, "0")) / 1000
                rows.append({"time": max(0, sec - (int(offset[1]) / 1000 if offset else 0)), "text": body})
    if rows and any(r["text"] for r in rows):
        return {"status": "ok", "source": source, "lines": sorted(rows, key=lambda r: r["time"])}
    plain = [{"time": -1, "text": s.strip()} for s in text.splitlines() if s.strip() and not s.startswith("[")]
    if plain:
        return {"status": "plain", "source": source, "lines": plain}


def song_name(value):
    # Stores disagree about including guest credits in the title. Keep edition labels (Live, Remix, etc.).
    return re.sub(r"\s*[(\[]\s*(?:feat\.?|ft\.?)\s+[^)\]]+[)\]]\s*$", "", normalized(value)).strip()


def credits(values):
    names = set()
    for value in values:
        for part in re.split(r"\s+(?:&|x|feat\.?|ft\.?)\s+|\s*[,、;；]\s*", normalized(value)):
            if part.strip():
                names.add(part.strip())
                # Some catalogues append the Chinese artist name to a Latin stage name.
                alias = re.fullmatch(r"[a-z.\s]+([\u3400-\u9fff]{2,})", part.strip())
                if alias: names.add(alias[1])
    return names


def release_name(value):
    return song_name(re.sub(r"\s+-\s+(?:single|ep)$", "", normalized(value)))


def score(title, artists, album, duration, track):
    name, performer, release, seconds = track
    if song_name(title) != song_name(name): return None
    expected = credits([performer])
    overlap = expected & credits(artists)
    if not overlap: return None
    distance = abs(duration - seconds) if duration and seconds else None
    album_match = bool(release and release_name(album) == release_name(release))
    close_duration = distance is not None and distance <= 4
    if not close_duration and not album_match and expected != overlap: return None
    return (not close_duration, not album_match, len(expected - overlap), distance or 0)


def ranked(candidates):
    candidates.sort(key=lambda item: item[0])
    if candidates and candidates[0][0][0]:
        # An unreliable total cannot distinguish two releases with the same metadata.
        evidence = candidates[0][0][:-1]
        lengths = [d for rank, d, _ in candidates if rank[:-1] == evidence and d]
        if lengths and max(lengths) - min(lengths) > 4:
            return []
    return candidates


def lrclib(track):
    title, artist, album, seconds = track
    def lyrics(row):
        if row.get("instrumental"):
            return {"status": "instrumental", "source": "LRCLIB", "duration": row.get("duration"), "lines": []}
        result = parsed(row.get("syncedLyrics") or row.get("plainLyrics") or "", "LRCLIB")
        if result: result["duration"] = row.get("duration")
        return result
    if album and seconds:
        try:
            row = api("https://lrclib.net/api/get", dict(track_name=title, artist_name=artist,
                      album_name=album, duration=round(seconds)))
            result = lyrics(row)
            if result: return result
        except HTTPError as e:
            if e.code != 404: raise
    rows = api("https://lrclib.net/api/search", dict(track_name=song_name(title), artist_name=artist))
    if not rows and len(credits([artist])) > 1:
        rows = api("https://lrclib.net/api/search", dict(track_name=song_name(title)))
    candidates = []
    for row in rows:
        rank = score(row["trackName"], [row["artistName"]], row.get("albumName") or "", row.get("duration"), track)
        if rank is not None:
            candidates.append((rank, row.get("duration"), row))
    for _, _, row in ranked(candidates):
        result = lyrics(row)
        if result: return result


def netease_lyrics(song_id):
    row = api("https://music.163.com/api/song/lyric", dict(id=song_id, lv=-1, kv=-1, tv=-1))
    if row.get("nolyric"):
        return {"status": "instrumental", "source": "NetEase Cloud Music", "lines": []}
    return parsed((row.get("lrc") or {}).get("lyric", ""), "NetEase Cloud Music")


def netease(track):
    rows = api("https://music.163.com/api/search/get", {"s": song_name(track[0]) + " " + track[1], "type": 1, "limit": 12})
    candidates = []
    for row in (rows.get("result") or {}).get("songs", []):
        rank = score(row["name"], [a["name"] for a in row["artists"]], row["album"]["name"],
                     row["duration"] / 1000, track)
        if rank is not None: candidates.append((rank, row["duration"] / 1000, row["id"]))
    for _, duration, song_id in ranked(candidates)[:2]:
        result = netease_lyrics(song_id)
        if result:
            result["duration"] = duration
            return result


def resolve(track, url):
    title, artist, _, _ = track
    u = urlsplit(url)
    route = urlsplit(u.fragment) if u.fragment.startswith("/song") else u
    song_id = parse_qs(route.query).get("id", [""])[0] if (
        u.hostname in ("music.163.com", "y.music.163.com") and route.path.rstrip("/") in ("/song", "/m/song")) else ""
    if not song_id.isdecimal(): song_id = ""
    cache = Path(os.getenv("XDG_CACHE_HOME", Path.home() / ".cache")) / "quickshell/mine/lyrics" / key([3, *track, song_id])
    hit = stored(cache, 7 * 86400)
    if hit and hit.get("source") == "网易云音乐":
        hit["source"] = "NetEase Cloud Music"
    if hit and (hit["status"] != "miss" or (hit.get("matchVersion") == 4 and time.time() - cache.stat().st_mtime < 600)): return hit
    failures = []
    if song_id:
        try:
            result = netease_lyrics(song_id)
            if result:
                save(cache, result)
                return result
        except (OSError, ValueError, KeyError) as e: failures.append(type(e).__name__)
    if not title or not artist: return {"status": "miss", "lines": []}
    pool = concurrent.futures.ThreadPoolExecutor(max_workers=2)
    futures = [pool.submit(provider, track) for provider in (lrclib, netease)]
    best = None
    for future in concurrent.futures.as_completed(futures):
        try: result = future.result()
        except (OSError, ValueError, KeyError, TypeError) as e:
            failures.append(type(e).__name__)
            continue
        if result and (not best or result["status"] == "ok"):
            best = result
            if best["status"] == "ok": break
    pool.shutdown(wait=False, cancel_futures=True)
    result = best or {"status": "error" if failures else "miss", "lines": [], "matchVersion": 4}
    if best or not failures: save(cache, result)
    return result


if __name__ == "__main__":
    title, artist, album, duration, url = sys.argv[1:]
    try: result = resolve((title, artist, album, round(float(duration))), url)
    except (ValueError, OSError, KeyError): result = {"status": "error", "lines": []}
    # Publish before a slow secondary catalogue finishes its bounded request.
    print(json.dumps(result, ensure_ascii=False), flush=True)
