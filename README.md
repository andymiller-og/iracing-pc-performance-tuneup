# iRacing PC performance tune-up (an agent skill)

A measure-first tune-up for iRacing graphics and performance that an AI coding agent runs with you on your own PC. It reads your sim settings and hardware itself (no screenshots), interviews you about how you race and what you care about, drives Intel PresentMon captures of a repeatable AI race, tells you whether the CPU, GPU, memory or thermals are the limit and why, then changes settings in small approved batches with a measurement after each, and writes a report at the end, including what it deliberately didn't change.

It came out of one real tune-up on a triple-screen GT3 rig (RTX 4070, i7-14700F) that went from a CPU-choked 94 fps to 127 fps on the same replay with better image quality, and the whole run with its mistakes is included as the worked example. The idea to do it this way, with an AI agent reading the hardware and measuring instead of following a generic settings guide, came from F1GamerDad's video [Your iRacing Settings Are Wrong (And It's Not Your Hardware's Fault)](https://youtu.be/ZMgnmJRoGVk).

## What it needs

- Windows 10/11, iRacing installed, PowerShell (5.1 is fine)
- [Intel PresentMon](https://game.intel.com/us/stories/intel-presentmon/) for per-frame CPU/GPU timing: `winget install --id Intel.PresentMon -e`
- An agent harness that supports the [Agent Skills](https://agentskills.io) format (`SKILL.md`): Claude Code, Claude Desktop, and others that read `SKILL.md` folders
- Optional: HWiNFO64 (`winget install --id REALiX.HWiNFO -e`)

NVIDIA on flat screens is measured. AMD and VR guidance is included but comes from general knowledge, and the skill says so when it applies. The skill also expects the agent to have web search: driver versions, vendor-app menus, monitor spec sheets and VR headset specifics are looked up live rather than recalled, because they change faster than any model's training data.

## Install

No git required. Pick one:

**Option 1, one line in PowerShell (recommended).** Downloads the latest version and puts it in your personal Claude skills folder. Re-run the same line to update.

```powershell
irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1 | iex
```

**Option 2, download the ZIP.** Click the green **Code** button above → **Download ZIP**. Unzip it, rename the folder from `iracing-pc-performance-tuneup-main` to `iracing-pc-performance-tuneup`, and move it to:

```
C:\Users\<you>\.claude\skills\iracing-pc-performance-tuneup
```

(Create the `.claude\skills` folders if they don't exist. `SKILL.md` must end up directly inside that folder.)

**Option 3, the `.skill` file.** On the [Releases](https://github.com/andymiller-og/iracing-pc-performance-tuneup/releases) page, download `iracing-pc-performance-tuneup.skill`. Drop it into a Claude Code or Claude Desktop conversation and use **Save skill** on the file card, or unzip it (it is a zip) into the folder above.

**Option 4, git**, if you have it: `git clone https://github.com/andymiller-og/iracing-pc-performance-tuneup "$env:USERPROFILE\.claude\skills\iracing-pc-performance-tuneup"` and `git pull` to update.

Then start a new Claude Code session and type `/iracing-pc-performance-tuneup`, or just ask "help me tune my iRacing graphics settings".

**Project-scoped instead:** use `<your-project>\.claude\skills\iracing-pc-performance-tuneup` as the destination (Option 1 accepts `-Dest`: download `install.ps1` and run `.\install.ps1 -Dest <path>`).

**Any other harness:** point it at `SKILL.md`, or paste `PROMPT.md` (a single-prompt version that references the same scripts) into a session started in this folder.

## What a run looks like

1. **Preflight**: finds the sim, settings folder, PresentMon, GPU vendor; prints install commands for anything missing.
2. **Interview**: eight questions about what you race, grid sizes, rain, screens, priorities, what you won't give up, and whether security trade-offs are OK.
3. **Read the machine**: hardware, Windows power/security state, monitors, current sim settings in the sim's own words, plus anomalies (clamped FOV, cap above refresh, cars not drawn, old driver).
4. **Baseline**: an offline AI race in your typical conditions, captured from the lights through a lap with PresentMon. The analysis says CPU-bound, GPU-bound (compute or memory) or balanced, with the numbers.
5. **Batches**: three or four changes at a time, each with page, setting, value, why and expected gain. You approve, apply in the sim's UI, the skill verifies the values saved, re-captures, compares, and you keep or revert.
6. **Report**: before/after tables, what changed, what was tried and reverted, what was left alone and why, the hardware ceiling, open items.

## Running the scripts by hand

All scripts are in `scripts/` and are read-only except the capture one.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Prerequisites.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Get-SystemSnapshot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Find-IRacingConfig.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Capture-PresentMon.ps1 -Label baseline-dry
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Analyze-PresentMon.ps1 -Path "$env:USERPROFILE\Documents\iRacing-tuneup\captures\<file>.csv" -PowerLimitW 200
```

## Contributing

Measurements from other rigs are the most valuable contribution, especially AMD and VR. Open an issue with the `Analyze-PresentMon.ps1` output, the `Find-IRacingConfig.ps1` output and what you changed. Corrections to UI labels and vendor-app paths are welcome; those drift with every release.

## License

MIT. See LICENSE.
