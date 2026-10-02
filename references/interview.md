# Intake interview

**Read the machine first, then ask.** Run `Get-SystemSnapshot.ps1` and `Find-IRacingConfig.ps1` before the interview so every question can offer a detected guess the user just confirms. **Never ask what the user's message already answered or what the scripts can read** (CPU, GPU, RAM, driver, current settings); confirm those in one line instead.

## Use the harness's question UI

If the harness has a structured question tool (Claude Code's `AskUserQuestion`, or an equivalent that renders choices), use it instead of a wall of text:

- **At most 4 questions per call, 2–4 options each.** The tool adds a free-text "Other" answer to every question automatically; say in the question text that they can type their own answer (e.g. "or type it, like 'GT3 league racing'").
- **Put the detected guess first** and label it, e.g. `Triples, 2560×1440 ×3 (detected)`. Use the option description to say what you saw ("3 monitors at 2560×1440 plus a 1920×1080 screen").
- **Use multi-select** where several answers can be true (conditions, what they won't give up, what they'll sacrifice, permissions).
- **Short headers** (a chip of 12 characters or so: "Racing", "Grid size", "Screens", "Priority").
- Two calls cover the whole interview: round 1 "how you race", round 2 "what you want and what's OK". Ask the few free-text-only items (measured viewing distance, monitor model if the detected name is a code, a specific problem) in one short line after the second call, or as an "Other" prompt.

If the harness has no question tool, send one compact message in the same shape: numbered questions, lettered options with the detected guess first, and "reply like `1a 2c 3: triples + an info screen`".

## Where the guesses come from

| Question | Detect from |
|---|---|
| Screens | `Get-SystemSnapshot.ps1` monitors (count, names, resolution) and the sim's resolution in `Find-IRacingConfig.ps1`. Three matching panels plus one different = "triples plus an extra screen". A recently written VR renderer file = VR. |
| VR headset and runtime | Which VR renderer file is newest, and running processes (Virtual Desktop streamer, Meta/Oculus service, SteamVR, Pimax Play, Varjo Base). A background VR service only means the software is installed; offer VR as an alternative, not the detected answer, unless the VR renderer file is the newest. |
| Overlays and software running alongside | The process list: SimHub, Racelab, Kapps, Crew Chief, Garage61, Coach Dave Delta, VRS, Discord, OBS, NVIDIA/AMD capture. |
| What they race (optional) | Names of the newest files in `Documents\iRacing\telemetry` and replay folders usually contain the car and track. Use only as a hint ("your recent sessions look like GT3 cars"); don't list them back. |
| Grid size | The renderer's Draw Cars setting is a weak hint at best; ask. |

## Round 1: how they race

| Header | Question | Options (detected guess first when there is one) | Multi |
|---|---|---|---|
| Racing | What do you mostly race? (or type it, like "GT3 league racing") | GT3 / GT4 sports cars · Open-wheel · Oval / NASCAR · Multi-class or endurance | no |
| Grid size | How big are your grids, usually? Official or league? | Up to 20 · 20–35 · 35–50 · 50–60+ (league fields) | no |
| Screens | Your screens, as I read them. Right? (or type it, like "triples plus a fourth monitor for info") | the detected set-up first, then the likely alternatives (single, ultrawide, triples, VR) | no |
| Conditions | Do you race any of these regularly? | Rain · Night or day-to-night · Endurance (2 h+) · None, mostly dry daytime | yes |

## Round 2: what they want, and what's OK

| Header | Question | Options | Multi |
|---|---|---|---|
| Priority | What matters most when you race? | Lowest latency and steadiest frames · Best-looking image · A balance of both | no |
| Keep | What must not get worse? | Distant-car visibility · Readable mirrors · Cockpit and dash text · Shadows and lighting | yes |
| Give up | What are you happy to give up? | Crowds and grandstands · Trackside clutter and objects · Pit-lane objects · Replay quality | yes |
| OK to | Which of these are OK? | Install Intel PresentMon to measure · Consider Windows security trade-offs (Memory Integrity) · Run an offline AI race to test · I already have captures (CapFrameX, FrameView, fpsVR) | yes |

Then one short line for what only the user can give: for triples, "measure from your eye to the centre of the middle screen in your seat"; the retail monitor model if the detected name is a code; "I can see SimHub and Discord running; anything else during races, like streaming?"; and "any specific problem to fix?".

For VR, replace "Screens" in round 1 with the headset (detected guess first), and add a third call or a short line for connection, runtime and refresh (see `vr.md`).

For the **quick check**, ask only round 1's "Racing", "Screens" and round 2's "Priority", in one call, skipping any the message already answered.

## Record the answers

Write them to the tune-up log as the "Driver profile" before doing anything else, including what was detected and confirmed. Every later recommendation should be traceable to a line in it ("you said you never race in rain, so…").
