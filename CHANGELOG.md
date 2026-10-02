# Changelog

## 0.3.0 (Oct 2026)

- Entry routing: quick check, bring-your-own captures, targeted symptom fixes, known bottleneck, or the full tune-up. The skill no longer re-asks what the user already said, and matches the user's level (terse page > setting: value for experienced drivers).
- Interview reads the PC first and asks clickable multiple-choice questions (harness question tool, e.g. AskUserQuestion) with detected guesses pre-selected and a free-text answer on every question; compact numbered fallback for harnesses without one.
- Dynamic LOD threshold explained as a choice (iRacing's "minimum acceptable fps"), flagged as wrong only when it sits above the fps the rig normally runs.
- Competitive profile (latency, frame-time consistency, visibility), a myths-and-tweaks table, and guidance for overlays, telemetry apps, streaming, endurance/night events and large league fields.
- Frame cap guidance accounts for the NVIDIA Reflex automatic cap with G-SYNC and driver vsync; Reflex Boost; AMD: Enhanced Sync off, Anti-Lag (not Anti-Lag 2), Adrenalin vs Windows driver version.
- VR: OpenXR Toolkit flagged for removal (iRacing notice, Nov 2025); the sim's fixed and eye-tracked foveated rendering (NVIDIA RTX only); headset list updated (WMR removed in 24H2, Steam Frame); streamed-headset diagnosis with the streamer's latency overlay.
- Restart rule is per batch (one relaunch covers all changes); verify and capture in the same turn.
- Ini-only settings: file, section, key and value; edits only on explicit request, sim closed, after a .bak copy.
- Capture guidance for agents: elevation prompt timing, tool timeouts, VR timed captures, run-to-run noise, AI starts as a proxy for online starts.
- Short report by default plus a team benchmark line; README section on what the skill reads, writes and sends, and team rollout notes.
- Scripts:
  - Analyze-PresentMon: `-TargetHz` (frames over budget), `-Process`, pacing metrics (frame-time SD, frame-to-frame change), frame-cap verdict, CPU-bound test relative to frame time; handles PresentMon app/console column variants, non-zero start times, other processes' rows, NA/nan cells and Excel comma-decimal files; about 10x faster on long captures.
  - Capture-PresentMon: prints the expected duration, writes a `.status.json`, ends with `CAPTURE RESULT:` and an exit code; `-OutFile`; `--terminate_after_timed`; PS 7.3+ quoting fix.
  - Find-IRacingConfig: VR files without a Replays section, a clear error when no renderer file exists, windowed flag fix, untruncated output.
  - Read-IRacingSession: correct player car; warns when the sim isn't connected.
  - Get-SystemSnapshot / Get-GpuMemoryByProcess: locale-independent GPU memory counters per adapter; `-MinMB`; wording fixes for hybrid CPUs and RAM channels.
  - Test-Prerequisites: execution policy and winget checks.
  - install.ps1: `-Version <tag>`; refuses to clear unrelated folders; no settings leaked into the caller's session; temp cleanup on failure.
  - Eval fixtures: edge-case variants in `evals/eval-files/edge/`.

## 0.2.0 (Oct 2026)

- Hardware-neutral rework: removed the single-rig worked example; added hardware triage; settings reference rewritten from public sources; restart rule; MPO key fixed; analyzer start window and short-capture warning; synthetic eval fixtures.

## 0.1.0 (Oct 2026)

- First release.
