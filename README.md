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

Works with **Claude Code**, **OpenAI Codex CLI** and **Cursor**. They all read the same `SKILL.md` format; only the folder differs. No git required.

### Option 1: one line in PowerShell (recommended)

Open PowerShell (Start → type "PowerShell"), paste the line, press Enter. It downloads the latest version and installs it for every one of the three tools it finds on your PC. Run the same line again later to update.

```powershell
irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1 | iex
```

To install for one tool only:

| Tool | One line |
|---|---|
| Claude Code / Claude Desktop | `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1))) -Harness claude` |
| Codex CLI | `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1))) -Harness codex` |
| Cursor | `& ([scriptblock]::Create((irm https://raw.githubusercontent.com/andymiller-og/iracing-pc-performance-tuneup/main/install.ps1))) -Harness cursor` |

Then start a **new** session and use it:

| Tool | How to start |
|---|---|
| Claude Code | type `/iracing-pc-performance-tuneup`, or ask "give my iRacing settings a quick check" |
| Codex CLI | type `$iracing-pc-performance-tuneup`, or just ask |
| Cursor | just ask; the agent picks the skill up from its description |

### Option 2: download the ZIP

Green **Code** button above → **Download ZIP**. Unzip, rename the folder from `iracing-pc-performance-tuneup-main` to `iracing-pc-performance-tuneup`, and move it so that `SKILL.md` sits directly inside:

| Tool | Folder |
|---|---|
| Claude Code | `C:\Users\<you>\.claude\skills\iracing-pc-performance-tuneup` |
| Codex CLI | `C:\Users\<you>\.codex\skills\iracing-pc-performance-tuneup` |
| Cursor | `C:\Users\<you>\.cursor\skills\iracing-pc-performance-tuneup` |

Create the `skills` folder if it doesn't exist. For a single project instead of your whole profile, use `<project>\.claude\skills\`, `<project>\.codex\skills\` or `<project>\.cursor\skills\`.

### Option 3: the `.skill` file

On the [Releases](https://github.com/andymiller-og/iracing-pc-performance-tuneup/releases) page, download `iracing-pc-performance-tuneup.skill`. In Claude Code or Claude Desktop, drop it into a conversation and use **Save skill** on the file card. For any tool, it is a zip: extract it into the folder above for your tool.

### Option 4: git

```powershell
git clone https://github.com/andymiller-og/iracing-pc-performance-tuneup "$env:USERPROFILE\.claude\skills\iracing-pc-performance-tuneup"
```

Swap `.claude` for `.codex` or `.cursor` as needed; `git pull` in that folder to update.

### Anything else

Point the agent at `SKILL.md`, or paste `PROMPT.md` (a single-prompt version that uses the same scripts) into a session started in this folder.

## Two ways to use it

**Quick check.** Ask for "a quick check of my iRacing settings". The agent reads your hardware and the sim's settings files, asks three questions, and tells you what is wrong (correctness fixes with page and value), what is fine, and what it can't judge without a capture. No load testing, about ten minutes. Good if you're already well set up.

**Full tune-up.** Ask to improve frame rate or smoothness, or share captures. The six-phase process below.

## What a full run looks like

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
