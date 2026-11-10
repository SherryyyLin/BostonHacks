#!/usr/bin/env python3
"""Collect public Greater Boston hackathon listings. Python 3.11+, stdlib only.

Writes the native app's [DiscoveredEvent] JSON plus a separate source-health report.
No credentials, logins, registrations, or invented recurring event dates.
"""
from __future__ import annotations

import argparse
import html
import json
import math
import os
from pathlib import Path
import re
import sys
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode, urlparse
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo

ET = ZoneInfo("America/New_York")
MAX_BYTES = 8_000_000
MAX_PAGES = 20
TOA_URL = "https://api.lu.ma/ics/get?entity=calendar&id=cal-qk07YDF6ZivCcE0"
TOA_PAGE = "https://the-open-accelerator.com/calendar/"
LUMA_API = "https://api.luma.com/discover/get-paginated-events"
LUMA_PLACE = "discplace-VWeZ1zUvnawYHMj"
LOCALIST = {"mit": "https://calendar.mit.edu", "northeastern": "https://calendar.northeastern.edu"}
REQUIRED = ("id name organizer startDate endDate schedule venue address cost eligibility notes website sourceURL status format checkedAt").split()


def stamp(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_time(value: str) -> datetime:
    result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if result.tzinfo is None:
        raise ValueError("Timestamp must include a time zone")
    return result


def web_url(value: str) -> bool:
    try:
        p = urlparse(value)
        return p.scheme in ("https", "http") and bool(p.hostname) and not p.username and not p.password
    except ValueError:
        return False


def canonical_url(value: str) -> str:
    if not web_url(value):
        raise ValueError("Missing valid public source URL")
    return value.strip().replace("https://lu.ma/", "https://luma.com/").split("#", 1)[0]


def is_hackathon(title: str) -> bool:
    if re.search(r"\b(info(?:rmation)?\s*session|planning|after.?party|pre.?drinks|recap|orientation|office hours|interest meeting|application workshop|archive)\b", title, re.I):
        return False
    return bool(re.search(r"hack.?a?.?thon|datathon|buildathon|game\s*jam|code\s*jam|hack\s*(?:night|day)|build\s*day|\bhack\b|\bhacks\b", title, re.I))


def coordinates(value) -> tuple[float, float] | None:
    try:
        a, b = float(value["latitude"]), float(value["longitude"])
        if not (math.isfinite(a) and math.isfinite(b) and -90 <= a <= 90 and -180 <= b <= 180):
            return None
        return a, b
    except (TypeError, KeyError, ValueError):
        return None


def local_location(point, address: str, online: bool = False) -> bool:
    if online:
        return True
    if point:
        a, b = point
        p1, p2 = math.radians(42.3601), math.radians(a)
        dlat, dlon = math.radians(a - 42.3601), math.radians(b + 71.0589)
        h = math.sin(dlat / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlon / 2) ** 2
        return 6371 * 2 * math.asin(math.sqrt(min(1, h))) <= 55
    # A bare Cambridge name is ambiguous; require Massachusetts context.
    return bool(re.search(r"\b(boston|cambridge|somerville|medford|wellesley|brookline|chestnut hill|newton|watertown|waltham|quincy|burlington)\b", address, re.I)
                and re.search(r"\b(MA|Massachusetts)\b", address, re.I))


def plain(value: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]*>", " ", value))).strip()


def schedule(start: datetime, end: datetime, all_day: bool = False) -> str:
    a, b = start.astimezone(ET), end.astimezone(ET)
    if all_day:
        b = (end - timedelta(seconds=1)).astimezone(ET)
        return f"{a:%b %d, %Y} – {b:%b %d, %Y} · exact hours on organizer page"
    return f"{a:%b %d, %Y %I:%M %p} – {b:%b %d, %Y %I:%M %p} ET"


def record(*, uid, name, organizer, start, end, venue, address, source, now,
           status="Check organizer page", cost="Check organizer", eligibility="See organizer eligibility",
           notes="See the original organizer page for event details.", fmt="In person", point=None, all_day=False, website=None):
    if end < start:
        raise ValueError(f"Event ends before it starts: {name}")
    item = dict(id=uid, name=name.strip(), organizer=organizer, startDate=stamp(start), endDate=stamp(end),
                schedule=schedule(start, end, all_day), venue=venue or "See organizer location", address=address,
                cost=cost, eligibility=eligibility, notes=notes, website=website or source, sourceURL=source,
                status=status if status == "Cancelled" else "Ended" if end <= now else status, format=fmt, checkedAt=stamp(now))
    if point:
        item.update(latitude=point[0], longitude=point[1])
    return item


def luma_status(entry: dict) -> str:
    event, ticket = entry.get("event", {}), entry.get("ticket_info") or {}
    availability = entry.get("registration_availability", "").lower()
    if event.get("cancelled_at") or event.get("status") in ("cancelled", "canceled"):
        return "Cancelled"
    if availability == "waitlist" or entry.get("waitlist_active"):
        return "Waitlist available"
    if ticket.get("is_sold_out"):
        return "Sold out"
    if availability in ("closed", "unavailable", "disabled"):
        return "Registration closed"
    if availability == "open":
        return "Approval required" if ticket.get("require_approval") else "Registration open"
    return "Check organizer page"


def parse_luma(payload: dict, now: datetime) -> list[dict]:
    if not isinstance(payload.get("entries"), list):
        raise ValueError("Luma response is missing entries")
    result = []
    for entry in payload["entries"]:
        e = entry.get("event") or {}
        if e.get("visibility", "public") != "public":
            continue
        title = e.get("name", "")
        if not is_hackathon(title):
            continue
        start, end = parse_time(e["start_at"]), parse_time(e["end_at"])
        info = e.get("geo_address_info") or {}
        shown = info.get("mode") == "shown" and e.get("geo_address_visibility", "public") == "public"
        online = e.get("location_type") in ("online", "virtual")
        point = coordinates(e.get("coordinate") or info.get("place_coordinate"))
        region = " ".join(str(info.get(k, "")) for k in ("city", "region", "region_short", "country"))
        if not local_location(point, region, online):
            continue
        # Obfuscated coordinates may establish city scope, but never become a map pin.
        public_point = point if shown and not online else None
        address = str(info.get("full_address", "")) if shown and not online else ""
        slug = e.get("url", "")
        source = canonical_url(slug if web_url(slug) else "https://luma.com/" + slug)
        calendar = entry.get("calendar") or {}
        organizer = calendar.get("name")
        if not organizer or organizer.lower() == "personal":
            organizer = " · ".join(dict.fromkeys(h.get("name", "") for h in entry.get("hosts", []) if h.get("name"))) or "Luma event organizer"
        ticket = entry.get("ticket_info") or {}
        cost = "Free" if ticket.get("is_free") is True else "See organizer ticket options"
        venue = "Online" if online else (info.get("description") or info.get("address") or "Location shared by organizer")
        result.append(record(uid=source, name=title, organizer=organizer, start=start, end=end,
                             venue=venue, address=address, source=source, now=now, status=luma_status(entry), cost=cost,
                             notes="Discovered from Luma’s public Boston event index. Open the organizer page for the full brief, eligibility and current admission terms. A public listing does not guarantee admission.",
                             fmt="Online" if online else "In person", point=public_point))
    return result


def unescape_ics(value: str) -> str:
    return re.sub(r"\\([nN,;\\])", lambda m: "\n" if m[1] in ("n", "N") else m[1], value)


def ics_date(head: str, value: str) -> datetime:
    if "VALUE=DATE" in head.upper():
        return datetime.strptime(value, "%Y%m%d").replace(tzinfo=ET)
    if value.endswith("Z"):
        return datetime.strptime(value, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    zone = re.search(r'(?:^|;)TZID="?([^;"\s]+)', head, re.I)
    return datetime.strptime(value, "%Y%m%dT%H%M%S").replace(tzinfo=ZoneInfo(zone[1]) if zone else ET)


def parse_ics(raw: bytes, now: datetime) -> list[dict]:
    text = raw.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
    if "BEGIN:VCALENDAR" not in text or "END:VCALENDAR" not in text:
        raise ValueError("Incomplete iCalendar response")
    text = re.sub(r"\n[ \t]", "", text)
    result = []
    blocks = re.findall(r"BEGIN:VEVENT\n(.*?)\nEND:VEVENT", text, re.S)
    if text.count("BEGIN:VEVENT") != len(blocks):
        raise ValueError("Malformed VEVENT boundaries")
    for block in blocks:
        props = {}
        for line in block.splitlines():
            if ":" in line:
                head, value = line.split(":", 1)
                props[head.split(";", 1)[0].upper()] = (head, unescape_ics(value))
        name = props.get("SUMMARY", ("", ""))[1]
        if not is_hackathon(name):
            continue
        start = ics_date(*props["DTSTART"])
        end = ics_date(*props["DTEND"])
        description = props.get("DESCRIPTION", ("", ""))[1]
        location = props.get("LOCATION", ("", ""))[1]
        online = location.lower() in ("online", "virtual") or "zoom.us/" in location
        fmt = "Online" if online else "Hybrid" if "hybrid" in location.lower() else "In person"
        point = None
        if "GEO" in props:
            a, b = props["GEO"][1].split(";", 1)
            point = coordinates(dict(latitude=a, longitude=b))
        if not local_location(point, location, online):
            continue
        links = re.findall(r"https?://[^\s<>]+", description)
        candidates = [props.get("URL", ("", ""))[1]] + links + [location]
        source = next((canonical_url(u.rstrip(".,)")) for u in candidates if web_url(u.rstrip(".,)"))), TOA_PAGE)
        uid = source if source != TOA_PAGE else "toa:" + props.get("UID", ("", ""))[1]
        if uid == "toa:":
            raise ValueError("Calendar event has no stable URL or UID")
        result.append(record(uid=uid, name=name, organizer="The Open Accelerator", start=start, end=end,
                             venue=location if not web_url(location) else "Location on organizer page",
                             address="" if online or web_url(location) else location, source=source, now=now,
                             status="Cancelled" if props.get("STATUS", ("", ""))[1] == "CANCELLED" else "Check organizer page",
                             notes=plain(description)[:2500], fmt=fmt, point=point,
                             all_day="VALUE=DATE" in props["DTSTART"][0].upper()))
    return result


def parse_localist(payload: dict, base: str, now: datetime) -> list[dict]:
    if not isinstance(payload.get("events"), list):
        raise ValueError("University response is missing events")
    result = []
    for wrapped in payload["events"]:
        event = wrapped.get("event", {})
        title = event.get("title", "")
        # An info session, talk, or course about a hackathon is not the hackathon itself.
        if not is_hackathon(title):
            continue
        desc = plain(event.get("description_text") or event.get("description") or "")
        point = coordinates(event.get("geo"))
        address = event.get("address") or ""
        experience = event.get("experience", "")
        online = experience in ("virtual", "online")
        if not local_location(point, address + " " + (event.get("location_name") or ""), online):
            continue
        source = canonical_url(event.get("localist_url") or base + "/event/" + event["urlname"])
        website = event.get("ticket_url") or event.get("url") or source
        if not web_url(website) or "/edit" in website:
            website = source
        audience = event.get("filters", {}).get("event_audience", [])
        eligibility = "Calendar audience: " + ", ".join(a["name"] for a in audience if a.get("name")) if audience else "See organizer eligibility"
        organizer = " · ".join(d["name"] for d in event.get("departments", []) if d.get("name")) or ("MIT Events" if "mit.edu" in base else "Northeastern Events")
        for item in event.get("event_instances", []):
            instance = item.get("event_instance", {})
            if not instance.get("start") or not instance.get("end"):
                continue  # Do not invent a missing end time.
            start, end = parse_time(instance["start"]), parse_time(instance["end"])
            instances = event.get("event_instances", [])
            uid = source if len(instances) == 1 else source + "?instance=" + str(instance["id"])
            result.append(record(uid=uid, name=title, organizer=organizer, start=start, end=end,
                                 venue=" · ".join(v for v in (event.get("location_name"), event.get("room_number")) if v),
                                 address="" if online else address, source=source, website=website, now=now,
                                 status="Cancelled" if event.get("status") in ("canceled", "cancelled") else "See organizer registration",
                                 cost="Free" if event.get("free") is True else event.get("ticket_cost") or "Check organizer",
                                 eligibility=eligibility + "; confirm detailed admission requirements with organizer.", notes=desc[:2500],
                                 fmt="Online" if online else "Hybrid" if experience == "hybrid" else "In person", point=None if online else point,
                                 all_day=bool(instance.get("all_day"))))
    return result


class Fetcher:
    def __init__(self, fixture_dir: Path | None = None):
        self.fixture_dir = fixture_dir

    def read(self, url: str, fixture_name: str) -> bytes:
        if self.fixture_dir:
            return (self.fixture_dir / fixture_name).read_bytes()
        if urlparse(url).scheme != "https":
            raise ValueError("Source must use HTTPS")
        request = Request(url, headers={"User-Agent": "BostonHacksPublicCalendar/1.0", "Accept": "application/json,text/calendar,text/html;q=0.5"})
        with urlopen(request, timeout=25) as response:
            if urlparse(response.url).scheme != "https":
                raise ValueError("Source redirected to insecure HTTP")
            raw = response.read(MAX_BYTES + 1)
        if len(raw) > MAX_BYTES:
            raise ValueError("Source exceeded 8 MB")
        return raw


def collect_luma(fetcher: Fetcher, query: str, now: datetime) -> tuple[list[dict], int]:
    result, cursor, seen = [], None, set()
    for page in range(1, MAX_PAGES + 1):
        params = dict(discover_place_api_id=LUMA_PLACE, pagination_limit=25, query=query)
        if cursor:
            params["pagination_cursor"] = cursor
        raw = fetcher.read(LUMA_API + "?" + urlencode(params), f"luma-{query.replace(' ', '-') or 'all'}-{page}.json")
        payload = json.loads(raw)
        result.extend(parse_luma(payload, now))
        cursor = payload.get("next_cursor")
        if not cursor:
            return result, page
        if cursor in seen:
            raise ValueError("Luma repeated pagination cursor")
        seen.add(cursor)
    raise ValueError("Luma pagination exceeded safety limit; previous source data preserved")


def collect_localist(fetcher: Fetcher, key: str, now: datetime) -> tuple[list[dict], int]:
    result = []
    base = LOCALIST[key]
    for page in range(1, MAX_PAGES + 1):
        params = dict(search="hackathon", start=(now - timedelta(days=30)).date().isoformat(),
                      end=(now + timedelta(days=335)).date().isoformat(), pp=100, page=page)
        payload = json.loads(fetcher.read(base + "/api/2/events/search?" + urlencode(params), f"{key}-{page}.json"))
        result.extend(parse_localist(payload, base, now))
        if not payload.get("page", {}).get("next_page"):
            return result, page
    raise ValueError("University pagination exceeded safety limit; previous source data preserved")


def validate_event(item: dict):
    if any(not isinstance(item.get(k), str) for k in REQUIRED):
        raise ValueError("Event schema has missing/non-string fields")
    if not item["id"] or not item["name"] or not web_url(item["sourceURL"]) or not web_url(item["website"]):
        raise ValueError("Invalid event identity/source URL")
    if parse_time(item["endDate"]) < parse_time(item["startDate"]):
        raise ValueError("Reversed date range")
    parse_time(item["checkedAt"])
    if item["format"] not in ("In person", "Hybrid", "Online"):
        raise ValueError("Unknown event format")
    for key in ("latitude", "longitude"):
        if key in item and item[key] is not None and not isinstance(item[key], (int, float)):
            raise ValueError("Invalid coordinates")


def atomic_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def read_events(path: Path) -> list[dict]:
    if not path.exists():
        return []
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError(f"Expected event array: {path}")
    for item in payload:
        validate_event(item)
    return payload


def run(args) -> int:
    now = parse_time(args.now) if args.now else datetime.now(timezone.utc)
    fetcher = Fetcher(args.fixture_dir)
    # Starting from previous output protects all old listings if any source fails.
    # Curated rows are only replaced by a newer curated snapshot or actual live data.
    merged = {e["id"]: e for e in read_events(args.output)}
    for event in read_events(args.snapshot):
        old = merged.get(event["id"])
        if old is None or parse_time(event["checkedAt"]) > parse_time(old["checkedAt"]):
            merged[event["id"]] = event
    reports = []
    jobs = [("luma-" + (q or "all"), lambda q=q: collect_luma(fetcher, q, now)) for q in ("", "hackathon", "datathon", "game jam")]
    jobs += [("toa", lambda: (parse_ics(fetcher.read(TOA_URL, "toa.ics"), now), 1))]
    jobs += [(key, lambda key=key: collect_localist(fetcher, key, now)) for key in LOCALIST]
    succeeded = 0
    for source, job in jobs:
        try:
            events, pages = job()
            # Validate the entire source before mutation: malformed data cannot partially replace it.
            for event in events:
                validate_event(event)
            for event in events:
                old = merged.get(event["id"])
                if old:
                    # Preserve research eligibility/notes where the listing feed is less detailed.
                    if event["eligibility"] == "See organizer eligibility":
                        event["eligibility"] = old["eligibility"]
                    if event["notes"].startswith("Discovered from Luma") and old.get("notes"):
                        if not old["notes"].startswith("Discovered from Luma"):
                            event["notes"] += f" Previous researched detail (checked {old['checkedAt'][:10]}): " + old["notes"][:2200]
                        elif "Previous researched detail" in old["notes"]:
                            event["notes"] = old["notes"]
                    # ICS has no ticket inventory; never overwrite verified registration with a guess.
                    if source == "toa" and event["status"] != "Cancelled":
                        event["status"] = old["status"]
                        event["cost"] = old["cost"]
                        event["eligibility"] = old["eligibility"]
                        event["notes"] += " Calendar subscriptions do not publish ticket inventory; retained admission terms require organizer confirmation."
                # Keep precise primary page data if a less precise ICS all-day copy arrives later.
                if old and source == "toa" and "exact hours" in event["schedule"]:
                    event["schedule"] = old["schedule"]
                    event["startDate"], event["endDate"] = old["startDate"], old["endDate"]
                merged[event["id"]] = event
            reports.append(dict(source=source, ok=True, checkedAt=stamp(now), matchingEvents=len(events), pages=pages))
            succeeded += 1
        except Exception as error:
            # No writes from this source; previous records retain their own checkedAt.
            reports.append(dict(source=source, ok=False, attemptedAt=stamp(now), error=str(error)[:500]))
            print(f"WARNING {source}: {error}", file=sys.stderr)
    if succeeded:
        events = [e for e in merged.values() if parse_time(e["endDate"]) >= now - timedelta(days=30)]
        events.sort(key=lambda e: (parse_time(e["startDate"]), e["id"]))
        for event in events:
            if parse_time(event["endDate"]) <= now and event["status"] != "Cancelled":
                event["status"] = "Ended"
            validate_event(event)
        atomic_json(args.output, events)
    else:
        events = list(merged.values())
        # Preserve an existing feed byte-for-byte when every source fails.
        # If first run, publish only the reviewed fallback without changing its checkedAt.
        if not args.output.exists() and events:
            atomic_json(args.output, events)
    status = dict(generatedAt=stamp(now), mode="fixtures" if args.fixture_dir else "live", eventCount=len(events),
                  sourcesSucceeded=succeeded, sourceCount=len(jobs), partialFailure=succeeded < len(jobs),
                  coverage="Public Luma Boston keyword discovery, TOA organizer ICS, MIT and Northeastern calendars; not exhaustive.",
                  staticSnapshot="Curated records retain original verification dates until an actual live source updates that event.",
                  sources=reports)
    atomic_json(args.status, status)
    print(json.dumps(dict(eventCount=len(events), successfulSources=succeeded, totalSources=len(jobs), output=str(args.output))))
    return 0 if succeeded else 2


def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, default=root / "App/verified-events.json")
    parser.add_argument("--output", type=Path, default=root / "Backend/feeds/events.json")
    parser.add_argument("--status", type=Path, default=root / "Backend/feeds/status.json")
    parser.add_argument("--fixture-dir", type=Path, help="Read source fixtures only, with zero network requests")
    parser.add_argument("--now", help="ISO 8601 clock override for reproducible offline verification")
    args = parser.parse_args()
    try:
        return run(args)
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
