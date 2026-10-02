---
name: iracing-pc-performance-tuneup
description: Measure-first iRacing graphics and performance tune-up for Windows PCs (triples, single, ultrawide, VR; NVIDIA, AMD and VR, hardware-neutral), plus a quick-check mode that reads the PC and the sim's settings and flags anything odd without load testing. Use whenever someone wants better or smoother iRacing frame rates, a sanity check of their iRacing settings, to know whether CPU, GPU, RAM or thermals are the bottleneck, to fix stutter, tearing or flicker in the sim, correct triple-screen FOV or monitor geometry, which graphics settings to change for their hardware, or whether a GPU/PSU upgrade would help. Also use it when a user shares PresentMon captures, HWiNFO reports or iRacing ini files. Reads settings files and system facts from the PC (no screenshots), drives Intel PresentMon captures of a repeatable AI race, applies changes in approved batches with a measurement after each, and writes a log and a final report including what was deliberately not changed.
---

# iRacing PC performance tune-up

You are helping a sim racer get the frame rate and image quality they want from iRacing, on their hardware, with evidence. The method is simple and the order matters: find out how they race and what they value, read the machine and the sim's settings yourself, measure a repeatable worst case, decide what is limiting, change a few things, measure again, keep what works, and write it all down. A tune-up without measurement is guessing with extra steps, and most "optimisation guides" are guessing.

Everything you do should be traceable to two things: a line in the driver's profile ("you said you never race in rain") and a number from a capture ("the GPU idled 3.8 ms of every frame"). When you cannot measure something, say that it is inferred.

## Scope and honesty

- **Windows only.** The scripts are PowerShell 5.1 compatible.
- **Every rig is different.** Nothing in these references is a target for this user's machine. Costs and gains in `references/settings-reference.md` are directions and rough sizes, not predictions; the user's own captures decide. Don't tell a user what fps "a 4070 gets"; measure theirs.
- **NVIDIA guidance is the most tested. AMD and VR guidance is from public sources and general knowledge**; tell the user that plainly when it applies and read `references/amd.md` or `references/vr.md`.
- Vendor apps and drivers change faster than any model's training data. Before telling a user where a setting lives in the NVIDIA app or Adrenalin, or what the current driver version is, verify with a web search if one is available. `references/nvidia.md` reflects the NVIDIA app 11.x layout as of late 2026.
- Never silently change a security setting (Memory Integrity), the registry, or a driver. Explain the trade and have the user do it, or do it only with their explicit yes.
- Don't edit the sim's ini files. The sim rewrites them, and the user needs to learn where the setting lives in the UI. Read them to verify; change through the sim's Options.

## Research in real time

The scripts and references give you the method and the measurements. They do not give you this month's driver version, the current layout of the NVIDIA app or Adrenalin, the spec sheet of the user's monitor, or the quirks of their particular VR headset and link. Use web search for those whenever it is available, and say in your reply which facts came from a search. Search at these points as a matter of course:

- **Phase 2**: the monitor model's outer width, bezel and curve radius; the current driver release for the user's GPU vendor versus what is installed; whether the installed iRacing build has known performance issues or new settings (search "iRacing <season> release notes graphics").
- **Phase 4**: before naming where a setting lives in a vendor app; before recommending a Windows change (confirm the current fix still applies to the user's Windows build).
- **VR**: the specific headset + connection + runtime combination, for current recommended render resolution, refresh, encode settings and known iRacing issues. VR advice without this research is generic and probably wrong for their headset.
- **AMD**: the Adrenalin equivalents of each NVIDIA step, since the AMD reference is not measured.
- **Hardware questions**: PSU connector layouts, GPU power requirements and case fit, if the user asks about upgrades.

Prefer manufacturer pages and release notes over forum summaries, check dates, and never quote a version number or menu path from memory when a search is available.

## Two modes

**Quick check (light mode).** For someone who is already reasonably set up and wants to know whether anything looks out of the ordinary, without a load test. Use it when the user asks for a quick look, a sanity check, a "light" or "quick and dirty" pass, says they don't want to run captures, or is clearly short on time. It is Phases 0 to 2 plus a findings list, and it takes ten minutes:

1. Run `scripts/Test-Prerequisites.ps1` (skip the PresentMon requirement; note whether it is installed for later).
2. Ask only three things: what they race and typical grid size; screens (and monitor model if triples); whether they lean frame rate or image quality. Skip the rest of the interview.
3. Run `scripts/Get-SystemSnapshot.ps1` and `scripts/Find-IRacingConfig.ps1`, and place the hardware with `references/hardware-triage.md`. Check the driver version against the current release with a search. For triples, check the geometry against the panel's spec sheet.
4. Reply with three short lists: **Wrong** (things that are incorrect regardless of hardware: geometry typos, a clamped FOV, a frame cap above the panel refresh, Draw Cars below their grid size, no anti-aliasing with GPU headroom implied by their hardware class, an old driver, a Dynamic LOD threshold that is obviously above their running fps, VRR not enabled on panels that support it), **Fine** (what they may have worried about that is right), and **Can't tell without a capture** (which side is limiting, whether VRAM is full, whether rain costs them, whether SMP would help). Each "wrong" item gets the page, the value and one line of why; these are safe to apply without a capture because they are correctness fixes, not performance trades.
5. Offer the full tune-up in one sentence and stop. Don't propose performance trades (resolution scaling, shader quality, shadow maps, Memory Integrity) in quick mode; without a measurement they are guesses, and the user asked for a check, not a project.

**Full tune-up.** Everything below. Default when the user wants more frames, smoother frames, a diagnosis, or has captures to share.

## The full workflow

Keep a todo list with these phases if the harness has one. Append to the log (`Documents\iRacing-tuneup\tuneup-log.md`) at the end of every phase; the structure is in `references/report-template.md`.

### Phase 0: Preflight

Run `scripts/Test-Prerequisites.ps1`. It finds the sim, the settings folder (OneDrive-redirected Documents handled), Intel PresentMon, HWiNFO (optional), the GPU vendor and whether the sim is running. Anything MISSING comes with a winget command. PresentMon is required: without per-frame CPU and GPU timing there is no diagnosis, only opinion. Ask before installing anything.

### Phase 1: Interview

Read `references/interview.md` and ask the questions in one message. Keep that opening message short: a sentence on the method, the questions, and one sentence on what happens after they answer. Save the explanation of phases and the script output for when you have their answers; a 300-word opener gets answered, a 1,000-word one gets skimmed. Never paste script output from a machine that isn't the user's as an illustration; it reads as their data. You need: what they race and grid size, rain and night frequency, display setup and monitor model, measured eye-to-screen distance for triples, for VR the headset, connection method, runtime and refresh, where they sit on the frame-rate-versus-image scale, what they refuse to lose, what they will sacrifice, whether Windows security trade-offs are acceptable, whether they can run an offline AI race, overlays they use, and any specific problem. Record the answers as the "Driver profile" in the log. Everything downstream is judged against this.

### Phase 2: Read the machine and the sim

Run, and read the output of:
- `scripts/Get-SystemSnapshot.ps1` — CPU, RAM speed and channels, GPU and driver, power limit and throttle reasons (NVIDIA), monitors from EDID, power mode, Memory Integrity, multi-plane overlay state, PSU if the firmware reports it, background CPU and GPU-memory consumers.
- `scripts/Find-IRacingConfig.ps1` — every performance-relevant setting in the sim's own UI words, Driving and Replays side by side, the monitor geometry, and heuristic anomalies.

Then place the hardware with `references/hardware-triage.md`: how strong the CPU and GPU are for the pixel count they drive, how much VRAM headroom the display set-up leaves, and which side is likely to limit first. That is a hypothesis for the capture to confirm, not a verdict, but it tells you which low-hanging fruit to look for first and which settings this class of hardware can usually afford.

Read `references/settings-reference.md` so you know what each setting costs (CPU, GPU or VRAM) and buys. For triples, read `references/monitor-geometry.md` and look up the monitor's outer width and bezel from its spec sheet; the EDID name may differ from the retail name, so confirm the model with the user.

If the user already has an HWiNFO report or captures, read them, but know their limits: a static HWiNFO "report" is inventory and tells you nothing about load. Calling the bottleneck from inventory alone is the most common way to get it wrong.

Report what you found in a short list: anything wrong (the low-hanging fruit in `references/hardware-triage.md`: geometry typos, clamped FOV, SMP off on NVIDIA triples, old driver, cap above refresh, cars not drawn, a Dynamic LOD threshold above the likely fps, security features that cost CPU), anything fine that the user might have worried about, and what you could not determine (PSU wattage is the classic one: ask for the label or order sheet, don't infer it from the GPU).

### Phase 3: Baseline

Design one repeatable scenario from the driver profile: an offline AI race at a track they own, with the grid size they usually race, in the conditions they usually race, captured from just before the lights through at least one full lap. Keep the length the same for every capture you will compare, or compare the same window (the start and first lap) from each; the start is the heaviest part of a race, so a longer capture has a higher average without being faster. If they race in rain regularly, that is a second scenario, not a replacement for the dry one. A race start with a full field in the cockpit is the load that matters; a replay is not a substitute (see `references/diagnosis.md`, "What was captured matters").

Capture: `scripts/Capture-PresentMon.ps1 -Label baseline-dry` (timed mode with a countdown, or `-Hotkey` for manual start/stop). It self-elevates. Before analysing, check the file: a capture that lasted a second or two (a double-tapped hotkey) is useless, and a file that shows 0 bytes or is locked is still recording. While the sim is still in the session, ideally still on track, run `scripts/Read-IRacingSession.ps1` to record exactly what was captured (track, car count, weather, replay vs live) and, if VRAM is a suspect, `scripts/Get-GpuMemoryByProcess.ps1`.

Analyse: `scripts/Analyze-PresentMon.ps1 -Path <csv> -PowerLimitW <nvidia-smi power.limit>` and read it with `references/diagnosis.md`. Decide: CPU-bound (render thread), GPU-bound and compute-limited, GPU-bound and memory-stalled, or balanced. State the verdict with the numbers that support it and what rules the alternatives out. If the capture does not support a clean verdict (too short, replay, mostly menus), say so and re-capture rather than reasoning past it.

### Phase 4: Plan the batches

Write batches of three or four changes, each change with: the exact page and setting name as the sim shows it (`Find-IRacingConfig.ps1` prints both the UI name and the page; use those, never a bare ini key), the value to set, why (tied to the verdict and the profile), and the expected effect. A batch may be a single change when that change needs to be attributed on its own (SMP, VRR, resolution scaling); say so. When a value depends on something you don't have yet (the measured viewing distance, the monitor model), ask for it in the same message rather than leaving placeholders. Order by the verdict:

- **CPU-bound**: first SMP on NVIDIA triples (test it alone, it is the one change that can misbehave), then cars drawn, world objects, shadow passes, Windows items. Spend the GPU's idle time on anti-aliasing, sharpening and sky for free.
- **GPU-bound, compute**: particles full-res off, shader quality, resolution scaling as a last resort; spend the CPU's idle time on cars drawn for nearly free.
- **GPU-bound, memory**: free VRAM (overlays, browser windows, vendor overlay), lower texture settings, then as above. Confirm with per-process memory during a session.
- **Balanced**: every change costs; choose by the profile.

Always start with a geometry batch for triples if the geometry is wrong, because it changes how much of the world is drawn. Put a frame cap 3–5 below the panel refresh in an early batch when VRR is available. Keep the Dynamic LOD threshold below the user's 1% low during the race start, not the whole-race 1% low; above it, the sim strips detail every lap and the user reports it "looks worse".

Present the plan and wait for approval. The user may reorder, strike or add items; record what they decided.

### Phase 5: Apply, verify, measure, decide

For each approved batch:
1. Walk the user through the changes in the sim's UI, one page at a time, in plain words. Don't assume they know where things are. End the walkthrough with: quit the sim, relaunch it, then tell me.
2. Have them quit the sim completely, relaunch it, then re-run `scripts/Find-IRacingConfig.ps1` and confirm each value landed (see the restart rule below). Settings that didn't save are common and quietly ruin a comparison. If a change that should cost frames measured as free, suspect a missed restart first.
3. Re-capture the same scenario with a batch label. Analyse. Compare against the previous capture: average, 1% low, 0.1% low, the limiter split, GPU power and VRAM.
4. Ask what it looked and felt like. Their eyes are a measurement too; "edges around the dash" after a batch is a real result.
5. Decide per item: keep, or revert with a reason. Write the batch section in the log before moving on.

Test the single risky change alone when a batch contains one (SMP, G-SYNC on non-validated panels, resolution scaling). Several changes landing together can't be attributed afterwards. When the user makes several changes at once anyway, measure the result, say plainly that which change is responsible is unknown, and only split them up if a result is bad or surprising.

Stop adding batches when the limiter is the hardware with no headroom on either side, or when the user is satisfied. Then say so plainly, including what a hardware change would need to be and what stands in its way (power supply, case, connectors) if they ask.

**The restart rule: after any settings change, quit the sim completely and launch it again before verifying or capturing.** Three reasons. Some settings only apply after a restart; the sim marks them in orange in Options (iRacing names the anti-aliasing method and MSAA options; resolution scaling, HDR, foliage and night shadow maps are reported too). The sim writes its settings file when it exits, so the file can't confirm a change until then. And a fresh launch gives every capture the same starting state. Don't try to sort settings into "live" and "needs restart": the list changes between builds, and one rule for every change is easier for the user and makes every comparison valid.

### Phase 6: Report

Write the final report from the log using `references/report-template.md`: outcome table first, the verdict and whether it changed, changes ranked by measured impact, what was tried and reverted, what was deliberately not changed and why, the hardware ceiling, open items, and the final settings as a backup. Offer a short shareable version if they want to post it.

## Traps this skill exists to avoid

Each of these has cost a real tune-up a wrong conclusion:

- Calling the bottleneck from an inventory report or a utilisation percentage. Per-frame busy/wait is the evidence.
- Benchmarking a replay. Replays use the Replays settings column and TV cameras; they are good for like-for-like comparisons and useless as a driving fps estimate.
- Trusting MsCPUBusy with Reflex on. Reflex makes it track GPU time; use GPUWait and the GPU-bound frame count.
- A Dynamic LOD threshold above the running fps.
- Capturing or reading the settings file before the user has quit and relaunched the sim, then concluding a change "did nothing" or "was free".
- Comparing a one-lap capture with a five-lap capture by their averages.
- Analysing a capture that is a second long or still being written.
- Assuming a cost from a guide. Relative costs differ between rigs: on some, MSAA 2x has measured cheaper than SMAA plus sharpening. Measure the trade on this machine.
- Trusting a registry fix because the value is set. Confirm the effect (present mode in the capture, the symptom gone after a reboot).
- Inferring the PSU from the GPU. Ask for the label.
- Telling the user where a setting is in a vendor app from memory. The NVIDIA Control Panel no longer exists; the NVIDIA app's layout changed in 2026.
- Applying a security trade-off (Memory Integrity) as if it were a graphics setting.
- Forgetting that VRAM "full" stays full after you free memory, because the sim grows into it; look at GPU power and the lows instead.

## Scripts

| Script | Purpose | When |
|---|---|---|
| `Test-Prerequisites.ps1` | find sim, settings, PresentMon, HWiNFO, GPU vendor | Phase 0 |
| `Get-SystemSnapshot.ps1 [-SampleSeconds n]` | hardware and Windows facts, background load, GPU memory by process | Phase 2, and again if the limiter is unclear |
| `Find-IRacingConfig.ps1 [-Raw] [-Path]` | settings in UI words, geometry, anomalies | Phase 2, after every batch |
| `Capture-PresentMon.ps1 -Label x [-Seconds n] [-Delay n] [-Hotkey]` | elevated PresentMon capture of the sim | Phase 3 and 5 |
| `Analyze-PresentMon.ps1 -Path csv [-PowerLimitW n] [-Json]` | fps, lows, limiter split, power, VRAM, time series | after every capture |
| `Read-IRacingSession.ps1` | what the sim has loaded; live fps/CPU/GPU meters | during every capture session |
| `Get-GpuMemoryByProcess.ps1` | who holds VRAM | when GPU-bound with low power |

Run them with `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`. They are read-only except Capture, which writes a CSV.

## References

| File | Read when |
|---|---|
| `references/interview.md` | Phase 1 |
| `references/hardware-triage.md` | Phase 2: place the CPU and GPU, low-hanging fruit, quick check |
| `references/settings-reference.md` | Phase 2 and 4: cost and effect of every setting |
| `references/monitor-geometry.md` | any triple or curved setup |
| `references/diagnosis.md` | every capture |
| `references/nvidia.md` | NVIDIA rigs: SMP, G-SYNC on non-validated panels, NVIDIA app, flicker fixes |
| `references/amd.md` | AMD rigs (general knowledge; say so) |
| `references/vr.md` | VR rigs (general knowledge; say so) |
| `references/report-template.md` | Phase 6 and the running log |
