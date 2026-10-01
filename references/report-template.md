# Report template

Two documents are produced. The **tune-up log** is appended to throughout; the **final report** is written at the end from the log. Both live in `Documents\iRacing-tuneup\` (next to the captures) unless the user chooses elsewhere. Use plain Markdown; the user will paste parts into Discord or forums.

## Tune-up log (`tuneup-log.md`, append as you go)

```
# iRacing tune-up log — <date>

## Driver profile
<interview answers, verbatim where useful>

## Rig
<from Get-SystemSnapshot: CPU, RAM, GPU + driver, monitors, PSU if known, Windows items>

## Starting settings
<Find-IRacingConfig table, Driving column, plus geometry; anomalies flagged>

## Baseline
Scenario: <track, car, N AI, weather, time of day, what was captured (start + N laps)>
Capture: <file>
Result: avg / 1% low / 0.1% low, limiter verdict, GPU power/clock/VRAM, present mode
Reading: <two or three sentences on what limits the sim and why>

## Batch 1 — <theme>
Proposed:
| Setting | Page | From | To | Why | Expected |
Approved by user: yes/no, with any changes they made to the plan
Applied: <date/time>; verified on disk: yes/no
Capture: <file>
Result: avg / 1% low / 0.1% low vs previous
User's eyes: <what they said it looked/felt like>
Decision: keep / revert <item> because <reason>

## Batch 2 — ...

## Not changed, and why
<settings deliberately left alone, with the reason: user preference, security trade-off, no headroom, untested on this vendor>

## Open items
<things found but not resolved: hardware limits, flicker, housekeeping>
```

## Final report (`iRacing tune-up report <date>.md`)

Sections, in this order. Lead with the outcome; put method after results.

1. **Outcome** — one table: scenario × (before, after) for average, 1% low, 0.1% low; one sentence on image quality direction (same / better / traded).
2. **What was limiting the sim** — the verdict from the baseline with the evidence (the four PresentMon numbers), and whether it changed by the end.
3. **Changes made, ranked by impact** — each with page, from → to, measured effect, and any caveat. Include Windows and driver changes.
4. **Tried and reverted** — what, why it was tried, what the user saw, why it went back.
5. **Deliberately not changed** — with reasons tied to the driver profile.
6. **Hardware ceiling** — what the card/CPU/PSU limits now, and what an upgrade would need to be (only if the user asked or the evidence makes it the next step).
7. **Open items** — unresolved issues, housekeeping (telemetry folder size, drive health), and how to re-measure (the exact capture and analysis commands).
8. **Settings as they stand** — the Find-IRacingConfig Driving column at the end, so the report doubles as a backup.

Keep numbers in tables, not prose. Say what was measured and what was inferred. Where a recommendation came from general knowledge rather than this rig's measurements, say so.
