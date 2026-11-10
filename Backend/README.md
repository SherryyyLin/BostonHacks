# Scheduled public event collector

This is a separate Python backend extension beyond the SwiftUI course. It produces the app-compatible **top-level JSON event array**, automatically discovers new listings and refreshes registration states where the source publishes them. No API key or paid account is required.

**Deployed:** [SherryyyLin/BostonHacks](https://github.com/SherryyyLin/BostonHacks). The first [GitHub Actions run](https://github.com/SherryyyLin/BostonHacks/actions/runs/42716474929) succeeded on November 9, 2026 at 5:58 PM Eastern: 15 tests passed, all seven source jobs succeeded, and 16 event records were committed. The workflow is enabled on the default branch with a three-hour schedule. GitHub may queue or delay scheduled runs.

## Sources and update rules

- **Luma Boston public discovery:** paginated chronological discovery plus keyword queries for hackathon, datathon and game jam. Publishes real dates, public addresses/coordinates and machine-readable admission availability. It follows returned cursors, rather than treating the first page as the whole dataset.
- **The Open Accelerator:** public iCalendar subscription; filters actual hackathon titles and local/explicitly online locations. iCalendar has no reliable ticket inventory, so it never fabricates an open/sold-out state.
- **MIT and Northeastern public Localist search APIs:** query a rolling date window, follow pages and accept actual hackathon event titles. An information session or class mentioning a hackathon is excluded. A successful empty response does not create activities.
- **Reviewed snapshot:** `App/verified-events.json` supplies researched listings as a fallback. Those records keep their **original `checkedAt`** until an actual source fetch updates the matching event. The run timestamp in `status.json` is not a claim that every static row was reverified.

Only publicly shown Luma coordinates become map pins. Obfuscated locations can establish the city scope but are not published as exact pins. Events outside approximately 55 km of central Boston are excluded; clearly online events discovered in this regional source can remain. This is not exhaustive coverage of all Boston events.

Ended records remain for 30 days, labeled Ended; future events continue to accumulate as sources publish them. Records disappearing from a feed are retained until expiry rather than incorrectly treated as cancelled. Explicit source cancellations are preserved. A source error preserves its previous records and their verification timestamps. If every source fails, an existing `events.json` stays byte-for-byte unchanged and the process returns a nonzero result.

## Run locally

Requires **Python 3.11+** with its standard library and time-zone database. No package installation is required.

From the project root (the directory containing `App/` and `Backend/`):

```sh
python3 -m unittest discover -s Backend/tests -v
python3 Backend/collector.py
```

Outputs:

- `Backend/feeds/events.json`: `[DiscoveredEvent]` records, with ISO 8601 timestamps and optional public latitude/longitude. This is the URL to enter in the app’s remote-feed setting.
- `Backend/feeds/status.json`: source-by-source success/failure, accepted counts, page counts and last run time. The app event array stays simple; health metadata is a separate file.

The collector uses HTTPS, timeouts, response-size bounds and atomic output replacement. Partial failures are visible in `status.json`. It does not send messages, join waitlists or register anyone.

## Existing deployment and setup for another repository

Live event feed: `https://raw.githubusercontent.com/SherryyyLin/BostonHacks/main/Backend/feeds/events.json`

Source health: `https://raw.githubusercontent.com/SherryyyLin/BostonHacks/main/Backend/feeds/status.json`

The following steps document how to reproduce the deployment in another repository.

1. Copy the **project directory contents** to a public GitHub repository you control, with `App/`, `Backend/` and `.github/workflows/update-events.yml` at its root. For a feed-only repository, include the reviewed snapshot at `App/verified-events.json`; the iOS project is optional.
2. Open the repository’s **Actions** tab and enable workflows if GitHub asks. Allow GitHub Actions to write repository contents under **Settings → Actions → General → Workflow permissions**. No personal access token needs to be put in a file.
3. Run **Update public hackathon feed → Run workflow** once, inspect the generated JSON and health report, then let the cron schedule run every three hours at minute 17 UTC.
4. In the native app, use the raw JSON endpoint for your repository:

   ```text
   https://raw.githubusercontent.com/OWNER/REPOSITORY/main/Backend/feeds/events.json
   ```

   Replace OWNER, REPOSITORY and branch with the actual published values. This is a template, not an already deployed endpoint.

5. Verify that the app can load the feed and that its source timestamps and admission states update after a later workflow run. GitHub may delay scheduled jobs, and schedules in inactive public repositories may be disabled; monitor the Actions history and `status.json`.

Only event data is needed for hosting. Do not copy your local address, signing material, account credentials or private source files into the repository. Public repositories expose the committed JSON and its history. This project’s public repository contains only the app/backend deliverables and public event data; the course archive, exams, local account credentials and personal starting addresses were excluded.

GitHub Pages is unnecessary for the raw endpoint. If you prefer Pages or another static host, publish the same two JSON files with HTTPS and point the app to the direct `events.json` URL. Keep the collector schedule running separately.

## Offline fixtures

The tests build minimal source fixtures locally and make **zero network requests**. To replay a larger captured source set:

```sh
python3 Backend/collector.py \
  --fixture-dir /path/to/public-source-fixtures \
  --output /tmp/boston-events.json \
  --status /tmp/boston-status.json \
  --now 2026-11-09T22:19:44Z
```

Expected filenames: `luma-all-1.json`, `luma-hackathon-1.json`, `luma-datathon-1.json`, `luma-game-jam-1.json`, `toa.ics`, `mit-1.json`, `northeastern-1.json`; add `-2`, etc. if source metadata returns another page. Missing fixtures count as failed sources, exercising preservation logic. A fixture health report is explicitly marked `mode: fixtures`, so it cannot be mistaken for a fresh online check.

Public endpoints and schemas can change. A parser failure is reported instead of silently replacing good data with an empty feed. Add a new source only after inspecting its actual published format and eligibility/status semantics.
