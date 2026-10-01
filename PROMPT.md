# Single-prompt version

For harnesses that don't load `SKILL.md` skills. Start your agent in this folder (so it can run the scripts) and paste the text below.

---

You are helping me tune iRacing graphics and performance on this Windows PC, measure-first. Follow this order and do not skip the measurement steps.

1. **Preflight.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Prerequisites.ps1`. If Intel PresentMon is missing, tell me the winget command and wait; it is required.
2. **Interview me first.** Read `references/interview.md` and ask me its questions in one message: what I race and grid sizes, rain/night frequency, screens and monitor model (and my measured eye-to-screen distance for triples), where I sit between frame rate and image quality, what I refuse to lose, what I'll sacrifice, whether Windows security trade-offs are acceptable, whether I can run an offline AI race, which overlays I run, and any specific problem. Save my answers as the driver profile in `Documents\iRacing-tuneup\tuneup-log.md`.
3. **Read the machine and the sim.** Run `scripts\Get-SystemSnapshot.ps1` and `scripts\Find-IRacingConfig.ps1`. Read `references/settings-reference.md` and, for triples, `references/monitor-geometry.md`. Tell me what looks wrong, what is fine, and what you cannot determine (don't infer my PSU from my GPU).
4. **Baseline.** Design one repeatable offline AI race in my typical conditions (and a rain one only if I race in rain). Have me grid up and run `scripts\Capture-PresentMon.ps1 -Label baseline`; run `scripts\Read-IRacingSession.ps1` to record what was captured. Analyse with `scripts\Analyze-PresentMon.ps1 -Path <csv> -PowerLimitW <my GPU power limit>` and read `references/diagnosis.md`. Tell me whether the limit is CPU, GPU (compute or memory) or balanced, with the numbers. Never use a replay as a driving benchmark.
5. **Plan batches** of 3–4 changes with page, setting, value, why and expected effect, ordered by the verdict, using `references/nvidia.md` (or `amd.md`, `vr.md`, saying they are from general knowledge). Test the one risky change alone. Wait for my approval.
6. **For each batch:** walk me through the sim UI, verify the values saved with `Find-IRacingConfig.ps1` after I leave Options, re-capture the same scenario, compare, ask what it looked like, decide keep/revert per item, and log it.
7. **Report** using `references/report-template.md`, including what you deliberately did not change and why.

Read `references/worked-example.md` once before planning; it is a full run with the mistakes left in.
