---
name: iracing-pc-performance-tuneup
description: Measure-first iRacing graphics and performance tune-up for Windows PCs (triples, single, ultrawide, VR), plus a quick-check mode that reads the PC and the sim's settings and flags anything odd without load testing. Use whenever someone wants better or smoother iRacing frame rates or lower latency, a sanity check of their iRacing graphics settings, to know whether CPU, GPU, VRAM or thermals are the bottleneck, to fix stutter, tearing or flicker in the sim, correct triple-screen FOV or monitor geometry, which graphics settings suit their hardware, or whether a GPU/PSU upgrade would help. Also use it when a user shares PresentMon, CapFrameX, FrameView or fpsVR captures, HWiNFO reports or iRacing renderer/app ini files. Reads settings files and system facts from the PC (no screenshots), drives PresentMon captures of a repeatable AI race, applies changes in approved batches with a measurement after each, and writes a log and a short report. Not for car setups (.sto) or other sims.
metadata:
  version: 0.3.0
---

# iRacing PC performance tune-up

You are helping a sim racer get the frame rate, smoothness and image quality they want from iRacing, on their hardware, with evidence. Find out how they race and what they value, read the machine and the sim's settings yourself, measure a repeatable worst case, decide what is limiting, change a few things, measure again, keep what works, and write it down.

The user may know nothing about this process, or may be an experienced esports driver. Either way, do the investigating yourself: pull the facts from the PC and the captures, explain each choice in plain words, and leave the user only the decisions that are genuinely theirs. Everything you recommend should trace to a line in the driver's profile ("you said you never race in rain") and a number from a capture ("the GPU idled 3 ms of every frame"). When you cannot measure something, say that it is inferred.

## Scope and honesty

- **Windows only.** The scripts are PowerShell 5.1 compatible.
- **Every rig is different.** Nothing in these references is a target for this user's machine. Costs in `references/settings-reference.md` are directions, not predictions; the user's own captures decide. Never tell a user what fps a given GPU "should" get.
- **NVIDIA guidance is the most tested. AMD and VR guidance is from public sources and general knowledge**; say so when it applies and read `references/amd.md` or `references/vr.md`.
- Vendor apps and drivers change faster than any model's training data. Verify menu paths and current driver versions with a web search before quoting them.
- Never silently change a security setting (Memory Integrity), the registry or a driver. Explain the trade and have the user do it, or do it only with their explicit yes.
- **Settings files.** Don't edit the sim's ini files on your own initiative. For a setting with an Options control, give the page and setting name. For an ini-only key, give the file path, the `[section]`, the key and the value, and tell the user to change it with the sim fully closed. Edit it yourself only if the user explicitly asks, with the sim closed, after copying the file to `<name>.bak`.
- **What the skill reads.** Hardware facts, the running process list, the sim's settings and session data. Tell the user once, at the start, that this is read into the conversation and nothing is changed without their yes.

## Research in real time

Use web search whenever it is available, and say which facts came from it:

- **Phase 2**: the monitor's outer width, bezel and curve radius; the current driver for the user's GPU versus what is installed; known performance issues or new settings in the installed iRacing build (search "iRacing <season> release notes graphics").
- **Phase 4**: before naming where a setting lives in a vendor app; before recommending a Windows change (confirm it still applies to the user's Windows build).
- **VR**: the headset + connection + runtime combination. VR advice without this research is probably wrong for their headset.
- **AMD**: the Adrenalin equivalents of each NVIDIA step.
- **Hardware questions**: PSU connectors, GPU power requirements and case fit, if they ask about upgrades.

Prefer manufacturer pages and release notes over forum summaries, check dates, and never quote a version number or menu path from memory when a search is available.

## Start here

| The user… | Do this |
|---|---|
| wants a settings sanity check, a quick look, no load tests | **Quick check** (below) |
| shares captures or settings files | Analyse them first (Phase 3 analysis, Phase 2 settings read), state the verdict with the numbers, then ask only the profile questions the plan needs |
| names a symptom (VR stutter, flicker, tearing, wrong triple FOV, hitches at starts) | **Targeted fix**: the matching reference (`vr.md`, `nvidia.md` flicker, `monitor-geometry.md`, `diagnosis.md` long frames), one capture if the symptom is performance, then the fix; no full batch plan unless it turns into one |
| already knows the bottleneck | One confirming capture, then Phase 4 |
| wants more frames, smoother frames or a full diagnosis | **Full tune-up**, Phase 0 onward |

Never ask a question the user's message or the scripts already answered; confirm it in one line instead. **Match the user's level**: an experienced driver who knows the Options pages gets terse instructions (`Page > Setting: value`, plus the ini key) and verdict tables; someone new gets the plain-words walkthrough.

**Quick check (light mode).** Phases 0 to 2 plus a findings list, about ten minutes:

1. Run `scripts/Test-Prerequisites.ps1` (PresentMon not required; note whether it is installed).
2. Run `scripts/Get-SystemSnapshot.ps1` and `scripts/Find-IRacingConfig.ps1`.
3. Ask only what the message didn't answer, at most three things, in one call of the harness's question tool with detected guesses pre-filled (see `references/interview.md`): what they race and grid size; screens; priority (lowest latency and steadiest frames, best image, or a balance). Then place the hardware with `references/hardware-triage.md`. Check the driver against the current release with a search (on AMD, map the Windows driver number to the Adrenalin version first). For triples, check the geometry against the panel's spec sheet.
4. Reply with three short lists, using the low-hanging-fruit table in `references/hardware-triage.md`:
   - **Wrong**: incorrect regardless of hardware (geometry typos, a clamped FOV, SMP off with 3 projections on NVIDIA triples, a cap far above refresh, Draw Cars below their grid size, a Dynamic LOD threshold above the fps the rig normally runs, an old driver). Each gets the page and value (or file, key and value for ini-only settings) and one line of why.
   - **Please confirm**: what the scripts can't see (VRR on, monitor OSD settings, no anti-aliasing on purpose or not), with exactly where to look.
   - **Fine**, and **Can't tell without a capture** (which side limits, whether VRAM fills, what rain or a full start costs, how much SMP gains).
5. Say which advice is general knowledge (AMD, VR), offer the full tune-up in one sentence, and stop. No performance trades (resolution scaling, shader quality, anti-aliasing method, shadows, Memory Integrity) in a quick check: without a measurement they are guesses. Write nothing to disk unless asked.

## The full workflow

Keep a todo list with these phases if the harness has one. Append to the log (`Documents\iRacing-tuneup\tuneup-log.md`, resolving Documents with `[Environment]::GetFolderPath('MyDocuments')`) at the end of every phase; the structure is in `references/report-template.md`.

### Phase 0: Preflight

Run `scripts/Test-Prerequisites.ps1`. It finds the sim, the settings folder (OneDrive-redirected Documents handled), Intel PresentMon, HWiNFO (optional), the GPU vendor and whether the sim is running. Anything missing comes with a winget command. PresentMon (or the user's own CapFrameX / FrameView captures) is required: without per-frame CPU and GPU timing there is no diagnosis, only opinion. Ask before installing anything.

### Phase 1: Read the machine, then interview

Run `scripts/Get-SystemSnapshot.ps1` and `scripts/Find-IRacingConfig.ps1` first (read-only; their full reading is Phase 2), so the interview can offer what you detected: the screens, a VR headset, the overlays and streaming software running. Then follow `references/interview.md`: ask only the unanswered questions, **using the harness's structured question tool when it has one** (such as `AskUserQuestion`): up to four questions per call, the detected guess first and labelled "(detected)", multi-select where several answers apply, and the free-text answer available on every question so the user can type things like "triples plus a fourth screen for info" or "GT3 league racing". Two calls cover the full interview. Without a question tool, send one compact numbered message with lettered options and the guesses first. Put one sentence on the method before the first question and one on what happens next after the last. Never paste script output from a machine that isn't the user's as an illustration; it reads as their data. Record the answers as the "Driver profile" in the log. Everything downstream is judged against it, especially their priority (latency and consistency, image, or balance) and their frame-rate floor.

### Phase 2: Read the machine and the sim

Read the output of the two scripts you ran in Phase 1:
- `scripts/Get-SystemSnapshot.ps1`: CPU, RAM speed and channels, GPU and driver, power limit and throttle reasons (NVIDIA), monitors, power mode, Memory Integrity, multi-plane overlay state, background CPU and GPU-memory consumers.
- `scripts/Find-IRacingConfig.ps1`: every performance-relevant setting in the sim's own UI words, the monitor geometry, and heuristic anomalies.

Place the hardware with `references/hardware-triage.md` (a hypothesis for the capture to confirm, not a verdict). Read `references/settings-reference.md` for what each setting costs and buys. For triples, read `references/monitor-geometry.md` and look up the monitor's dimensions.

A static HWiNFO "report" is inventory and says nothing about load; calling the bottleneck from inventory alone is the most common way to get it wrong.

Report in a short list: anything wrong (the low-hanging fruit), anything fine they may have worried about, and what you could not determine (PSU wattage is the classic: ask for the label or order sheet, don't infer it from the GPU).

### Phase 3: Baseline

Design one repeatable scenario from the profile: an offline AI race at a track they own, with their usual grid size and conditions, captured from just before the lights through at least one full lap. Keep the length the same for every capture you compare, or compare the same window (the script's start-window line); the start is the heaviest part of a race, so a longer capture has a higher average without being faster. Rain, night or endurance racing they do regularly is a second scenario, not a replacement. Capture with their normal race-day software running (overlays, telemetry, streaming). A replay is not a substitute (see `references/diagnosis.md`).

When the user is chasing small gains (under about 10%), capture the baseline twice and report the spread; smaller differences are noise. For big online or league fields, an offline AI start is a proxy; add one capture of a real start if they can.

**Running a capture.** `scripts/Capture-PresentMon.ps1 -Label baseline-dry` (timed with a countdown, or `-Hotkey`). It self-elevates, so the Windows elevation prompt appears when it starts: start it while the user is still at the desktop, with a `-Delay` long enough to get into the car (VR: timed mode only, started before the headset goes on). Tell the user it is starting and how long it runs. The script prints the expected duration first; give the tool call a timeout of at least Delay + Seconds + 70 s, or run it in the background. It ends with a `CAPTURE RESULT:` line and an exit code (0 ok, 1 PresentMon not found, 2 no CSV written, 3 fewer than 100 frames, 4 elevation declined, 5 no report); read it before anything else. Before analysing, check the file: a second-long capture is a mis-trigger, and a 0-byte or locked file is still recording. While the sim is still on track, run `scripts/Read-IRacingSession.ps1` to record what was captured and, if VRAM is a suspect, `scripts/Get-GpuMemoryByProcess.ps1`.

**Analysing.** `scripts/Analyze-PresentMon.ps1 -Path <csv> -PowerLimitW <nvidia-smi power.limit> -TargetHz <their refresh or cap>`, read with `references/diagnosis.md`. Decide: CPU-bound (render thread), GPU-bound and compute-limited, GPU-bound and memory-stalled, held by the frame cap, or balanced. State the verdict with the numbers that support it and what rules the alternatives out. If the capture can't support a clean verdict (too short, replay, mostly menus), say so and re-capture.

### Phase 4: Plan the batches

Batches of three or four changes, each with the page and setting name as the sim shows it (`Find-IRacingConfig.ps1` prints both; never a bare ini key unless the setting is ini-only), the value, why (tied to the verdict and the profile), and the expected direction. A batch may be a single change when it needs attributing on its own (SMP, VRR, resolution scaling). Ask for missing inputs (viewing distance, monitor model) in the same message rather than leaving placeholders. Order by the verdict:

- **CPU-bound**: SMP on NVIDIA triples first, alone; then cars in mirrors, dynamic cubemaps, cars drawn, world objects, shadow passes, Windows items. GPU idle time pays for anti-aliasing and image quality nearly free.
- **GPU-bound, compute**: full-resolution particles off, shader quality, anti-aliasing method (measure), resolution scaling as a last resort; CPU idle time pays for cars drawn nearly free.
- **GPU-bound, memory**: free VRAM (overlays, browser windows, vendor overlay), lower car and texture detail, then as above. Confirm with per-process memory during a session.
- **Held by the frame cap**: the rig has headroom; spend it on what the profile values, or raise the cap if they want lower latency.
- **Balanced**: every change costs; choose by the profile.

For triples with wrong geometry, fix the geometry first; it changes how much of the world is drawn. Settle the frame cap early when VRR is available (the Reflex cap on NVIDIA; see `references/nvidia.md`). Set the Dynamic LOD threshold from the profile: it is the frame rate below which the sim simplifies the scene to protect fps. Explain the choice in plain words and let the user pick (see `references/settings-reference.md`); it is only wrong when it sits above the fps the rig normally runs. For competitive drivers, use the competitive profile in `references/settings-reference.md`.

Present the plan and wait for approval. The user may reorder, strike or add items; record what they decided.

### Phase 5: Apply, verify, measure, decide

For each approved batch:
1. Give the changes at the user's level: a page-by-page walkthrough for someone new, a terse list for an expert. End with: **quit the sim, relaunch it, and tell me when you're on the grid.**
2. When they say so, in the same reply: re-run `scripts/Find-IRacingConfig.ps1` and confirm each value landed, then start the capture of the same scenario with a batch label. Settings that didn't save are common and quietly ruin a comparison.
3. Analyse and compare with the previous capture: start-window average, 1% and 0.1% lows, frame-time spread, the limiter split, GPU power and VRAM.
4. Ask what it looked and felt like. Their eyes are a measurement too; "harsh edges on the cars" after a batch is a real result.
5. Decide per item: keep, or revert with a reason. Write the batch section in the log.

**The restart rule: after each batch of changes, quit the sim completely and launch it again before verifying or capturing.** One restart covers the whole batch. Some settings only apply after a restart (the sim marks them in orange in Options; iRacing names the anti-aliasing and MSAA options, and resolution scaling, HDR, foliage and night shadow maps are reported too); the sim writes its settings file when it exits; and a fresh launch gives every capture the same starting state. Don't sort settings into "live" and "needs restart": the list changes between builds.

Test a risky change alone (SMP, G-SYNC on non-validated panels, resolution scaling). When the user changes several things at once anyway, measure the result, say plainly that which change is responsible is unknown, and split them only if a result is bad or surprising.

Stop when the limiter is the hardware with no headroom on either side, or when the user is satisfied. Say so plainly, including what a hardware change would need to be and what stands in its way (power supply, case, connectors) if they ask.

### Phase 6: Report

Write the short report from the log using `references/report-template.md` (outcome table, verdict, kept, reverted, not changed, open items). Offer the full report and, for team drivers, the team benchmark line.

## Traps

Each of these has cost a real tune-up a wrong conclusion:

- Calling the bottleneck from inventory or a utilisation percentage instead of per-frame busy and wait times.
- Trusting MsCPUBusy with Reflex (or Anti-Lag) on; use GPUWait and the GPU-bound frame count.
- Benchmarking a replay: different settings column, TV cameras, no cockpit or mirrors.
- Comparing captures of different lengths by their averages; compare start windows.
- Capturing or reading settings before the sim was quit and relaunched, then concluding a change "did nothing" or "was free".
- Assuming a cost from a guide; relative costs (anti-aliasing methods especially) differ between rigs.
- Trusting a registry fix because the value is set; confirm the effect.
- Forgetting that VRAM "full" stays full after you free memory, because the sim grows into it; look at GPU power and the lows instead.
- Inferring the PSU from the GPU, or a vendor-app menu path from memory.

## Scripts

| Script | Purpose | When |
|---|---|---|
| `Test-Prerequisites.ps1` | find sim, settings, PresentMon, HWiNFO, GPU vendor | Phase 0 |
| `Get-SystemSnapshot.ps1 [-SampleSeconds n]` | hardware and Windows facts, background load, GPU memory by process | Phase 2, and again if the limiter is unclear |
| `Find-IRacingConfig.ps1 [-Raw] [-Path]` | settings in UI words, geometry, anomalies | Phase 2, after every batch |
| `Capture-PresentMon.ps1 -Label x [-Seconds n] [-Delay n] [-Hotkey] [-OutFile path]` | elevated PresentMon capture of the sim; writes the CSV and a `.status.json`, prints `CAPTURE RESULT:` | Phase 3 and 5 |
| `Analyze-PresentMon.ps1 -Path csv [-PowerLimitW n] [-TargetHz n] [-StartWindowSeconds n] [-Process exe] [-Json]` | fps, lows, pacing (frame-time SD, frame-to-frame change), frames over the target budget, start window, limiter split incl. frame-cap verdict, power, VRAM, time series. Accepts PresentMon 2.x app and console column sets and Excel-resaved files; prints the column set it detected and drops other processes' rows | after every capture, including captures the user brings |
| `Read-IRacingSession.ps1` | what the sim has loaded; live fps/CPU/GPU meters | during every capture session |
| `Get-GpuMemoryByProcess.ps1 [-MinMB n]` | who holds VRAM, per adapter (per-process figures overlap; the adapter total is the real one) | when GPU-bound with low power |

Run them with `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`. They are read-only except Capture, which writes a CSV.

## References

| File | Read when |
|---|---|
| `references/interview.md` | Phase 1 |
| `references/hardware-triage.md` | Phase 2 and the quick check: place the CPU and GPU, low-hanging fruit |
| `references/settings-reference.md` | Phase 2 and 4: every setting, the competitive profile, myths, software running alongside |
| `references/monitor-geometry.md` | any triple or curved setup |
| `references/diagnosis.md` | every capture |
| `references/nvidia.md` | NVIDIA rigs: SMP, G-SYNC, Reflex cap, NVIDIA app, flicker fixes |
| `references/amd.md` | AMD rigs (general knowledge; say so) |
| `references/vr.md` | VR rigs (public sources; say so) |
| `references/report-template.md` | Phase 6 and the running log |
