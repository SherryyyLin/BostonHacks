import argparse
from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
from datetime import datetime, timezone
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("collector", Path(__file__).parents[1] / "collector.py")
c = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(c)
NOW = datetime(2026, 11, 9, 22, 19, 44, tzinfo=timezone.utc)


def entry(title="Fixture Hackathon", slug="fixture-hack"):
    return {"event": {"name": title, "url": slug, "start_at": "2026-11-14T14:00:00Z", "end_at": "2026-11-15T03:00:00Z", "location_type": "offline", "geo_address_visibility": "public", "coordinate": {"latitude": 42.3501, "longitude": -71.1045}, "geo_address_info": {"mode": "shown", "full_address": "685 Commonwealth Ave, Boston, MA", "description": "CAS 313", "city": "Boston", "region_short": "MA"}}, "calendar": {"name": "Fixture organizer"}, "ticket_info": {"is_free": True, "is_sold_out": False, "require_approval": False}, "registration_availability": "open"}


def make_record(uid="https://example.org/researched"):
    return c.record(uid=uid, name="Previously researched hackathon", organizer="Fixture", start=c.parse_time("2026-11-14T14:00:00Z"), end=c.parse_time("2026-11-14T22:00:00Z"), venue="Fixture venue", address="Boston, MA", source=uid, now=c.parse_time("2026-11-01T12:00:00Z"))


class CollectorTests(unittest.TestCase):
    def test_new_luma_rows_are_not_limited_to_snapshot_ten(self):
        result = c.parse_luma({"entries": [entry(slug=f"new-{i}") for i in range(31)]}, NOW)
        self.assertEqual(len(result), 31)
        self.assertEqual(len({e["id"] for e in result}), 31)
        self.assertEqual(result[0]["startDate"], "2026-11-14T14:00:00Z")
        self.assertIn("09:00 AM", result[0]["schedule"])

    def test_real_admission_semantics(self):
        e = entry()
        self.assertEqual(c.luma_status(e), "Registration open")
        e["ticket_info"]["require_approval"] = True
        self.assertEqual(c.luma_status(e), "Approval required")
        e["ticket_info"]["is_sold_out"] = True
        self.assertEqual(c.luma_status(e), "Sold out")
        e["waitlist_active"] = True
        self.assertEqual(c.luma_status(e), "Waitlist available")
        e["event"]["cancelled_at"] = "2026-11-08T12:00:00Z"
        self.assertEqual(c.luma_status(e), "Cancelled")

    def test_nonpublic_discovery_row_is_not_republished(self):
        e = entry(); e["event"]["visibility"] = "private"
        self.assertEqual(c.parse_luma({"entries": [e]}, NOW), [])

    def test_hidden_location_never_becomes_pin_or_address(self):
        e = entry()
        e["event"]["geo_address_info"]["mode"] = "obfuscated"
        result = c.parse_luma({"entries": [e]}, NOW)[0]
        self.assertEqual(result["address"], "")
        self.assertNotIn("latitude", result)
        self.assertNotIn("longitude", result)

    def test_cambridge_uk_and_unknown_location_excluded(self):
        e = entry()
        e["event"]["coordinate"] = {"latitude": 52.2053, "longitude": 0.1218}
        self.assertEqual(c.parse_luma({"entries": [e]}, NOW), [])
        self.assertFalse(c.local_location(None, "Cambridge"))
        self.assertFalse(c.local_location(None, "Address shared after approval"))
        self.assertTrue(c.local_location(None, "Cambridge, MA"))

    def test_info_session_not_hackathon(self):
        for title in ["Build for Ukraine Hackathon 3.0 - Info Session", "Hackathon planning", "Hackathon afterparty", "IAP Build for Ukraine"]:
            self.assertFalse(c.is_hackathon(title))
        self.assertTrue(c.is_hackathon("MIT Energy & Climate Hack"))
        self.assertTrue(c.is_hackathon("Sustainability Datathon"))
        self.assertTrue(c.is_hackathon("Boston Hack-a-thon"))
        self.assertTrue(c.is_hackathon("Community Buildathon"))

    def test_all_day_ics_exclusive_end_and_folded_url(self):
        data = b"BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nDTSTART;VALUE=DATE:20261111\r\nDTEND;VALUE=DATE:20261115\r\nSUMMARY:Healthcare Hackathon\r\nDESCRIPTION:Source https://luma.com/toa-\r\n oncohack\\nDetails\r\nLOCATION:Hybrid - Boston, MA\r\nGEO:42.338;-71.09\r\nUID:fixture1\r\nSTATUS:CONFIRMED\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
        events = c.parse_ics(data, NOW)
        self.assertEqual(events[0]["id"], "https://luma.com/toa-oncohack")
        self.assertEqual(events[0]["endDate"], "2026-11-15T05:00:00Z")
        self.assertIn("Nov 14, 2026", events[0]["schedule"])
        self.assertEqual(events[0]["format"], "Hybrid")

    def test_bad_calendar_and_bad_timestamp_rejected(self):
        with self.assertRaises(ValueError):
            c.parse_ics(b"<html>blocked</html>", NOW)
        with self.assertRaises(ValueError):
            c.parse_ics(b"BEGIN:VCALENDAR\nBEGIN:VEVENT\nEND:VCALENDAR", NOW)
        with self.assertRaises(ValueError):
            c.parse_time("2026-11-14T10:00:00")

    def test_localist_exact_dates_and_registration_link_safety(self):
        obj = {"events": [{"event": {"title": "Fixture Hackathon", "localist_url": "https://calendar.mit.edu/event/fixture", "ticket_url": "https://forms.example.org/edit", "address": "84 Massachusetts Ave, Cambridge, MA", "location_name": "Building W20", "geo": {"latitude": "42.359083", "longitude": "-71.094761"}, "event_instances": [{"event_instance": {"id": 1, "start": "2026-11-13T15:30:00-05:00", "end": "2026-11-13T17:00:00-05:00"}}]}}]}
        result = c.parse_localist(obj, "https://calendar.mit.edu", NOW)
        self.assertEqual(result[0]["startDate"], "2026-11-13T20:30:00Z")
        self.assertEqual(result[0]["website"], "https://calendar.mit.edu/event/fixture")
        self.assertEqual(result[0]["cost"], "Check organizer")
        obj["events"][0]["event"]["event_instances"][0]["event_instance"]["end"] = None
        self.assertEqual(c.parse_localist(obj, "https://calendar.mit.edu", NOW), [])

    def test_pagination_cursor_followed_even_without_has_more(self):
        class Fixture:
            def __init__(self): self.urls = []
            def read(self, url, fixture_name):
                self.urls.append(url)
                if len(self.urls) == 1:
                    return json.dumps({"entries": [entry(slug="page1")], "has_more": False, "next_cursor": "cursor-two"}).encode()
                return json.dumps({"entries": [entry(slug="page2")], "has_more": False}).encode()
        f = Fixture()
        events, pages = c.collect_luma(f, "hackathon", NOW)
        self.assertEqual((len(events), pages), (2, 2))
        self.assertIn("pagination_cursor=cursor-two", f.urls[1])

    def test_localist_window_stays_under_verified_api_limit(self):
        from urllib.parse import parse_qs, urlparse
        class Fixture:
            def read(self, url, fixture_name):
                query = parse_qs(urlparse(url).query)
                first = datetime.fromisoformat(query["start"][0])
                last = datetime.fromisoformat(query["end"][0])
                if (last - first).days > 370:
                    raise ValueError("Localist maximum date range exceeded")
                return b'{"events": [], "page": {"next_page": null}}'
        self.assertEqual(c.collect_localist(Fixture(), "mit", NOW), ([], 1))

    def setup_run(self, root, make_fixtures=True):
        fixtures = root / "fixtures"; fixtures.mkdir()
        snapshot = root / "snapshot.json"
        snapshot.write_text(json.dumps([make_record()]))
        if make_fixtures:
            for q in ("all", "hackathon", "datathon", "game-jam"):
                (fixtures / f"luma-{q}-1.json").write_text(json.dumps({"entries": [entry()] if q == "hackathon" else []}))
            (fixtures / "toa.ics").write_text("BEGIN:VCALENDAR\nEND:VCALENDAR\n")
            for key in ("mit", "northeastern"):
                (fixtures / f"{key}-1.json").write_text('{"events": [], "page": {"next_page": null}}')
        return argparse.Namespace(snapshot=snapshot, output=root / "events.json", status=root / "status.json", fixture_dir=fixtures, now=c.stamp(NOW))

    def test_successful_run_publishes_new_rows_and_preserves_original_checked_at(self):
        with tempfile.TemporaryDirectory() as tmp:
            args = self.setup_run(Path(tmp))
            with redirect_stdout(io.StringIO()): self.assertEqual(c.run(args), 0)
            events = json.loads(args.output.read_text())
            self.assertEqual(len(events), 2)
            old = next(e for e in events if e["id"] == "https://example.org/researched")
            self.assertEqual(old["checkedAt"], "2026-11-01T12:00:00Z")
            self.assertEqual(json.loads(args.status.read_text())["mode"], "fixtures")
            for e in events: c.validate_event(e)

    def test_total_failure_keeps_previous_feed_byte_for_byte(self):
        with tempfile.TemporaryDirectory() as tmp:
            args = self.setup_run(Path(tmp), make_fixtures=False)
            original = json.dumps([make_record()], indent=4) + "\n"
            args.output.write_text(original)
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()): self.assertEqual(c.run(args), 2)
            self.assertEqual(args.output.read_text(), original)
            report = json.loads(args.status.read_text())
            self.assertEqual(report["sourcesSucceeded"], 0)
            self.assertTrue(report["partialFailure"])

    def test_partial_failure_retains_previous_source_rows(self):
        with tempfile.TemporaryDirectory() as tmp:
            args = self.setup_run(Path(tmp))
            (args.fixture_dir / "mit-1.json").write_text("not json")
            old = make_record("https://calendar.mit.edu/event/previous")
            args.output.write_text(json.dumps([old]))
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()): self.assertEqual(c.run(args), 0)
            events = json.loads(args.output.read_text())
            self.assertTrue(any(e["id"] == old["id"] and e["checkedAt"] == old["checkedAt"] for e in events))
            self.assertTrue(json.loads(args.status.read_text())["partialFailure"])

    def test_ended_records_cannot_remain_registration_open(self):
        e = entry(); e["event"]["start_at"] = "2026-11-01T12:00:00Z"; e["event"]["end_at"] = "2026-11-01T18:00:00Z"
        self.assertEqual(c.parse_luma({"entries": [e]}, NOW)[0]["status"], "Ended")

    def test_no_address_or_credentials_in_source_url(self):
        self.assertFalse(c.web_url("https://user:secret@example.org/event"))
        self.assertFalse(c.web_url("javascript:alert(1)"))
        self.assertFalse(c.web_url("/relative"))
        self.assertEqual(c.canonical_url("https://lu.ma/event1#details"), "https://luma.com/event1")


if __name__ == "__main__":
    unittest.main()
