# Intake interview

Ask these in **one message** (or one AskUserQuestion with several questions if the harness has it), grouped, with short options where options make sense. Eight questions at the start saves twenty later. Don't ask what the scripts can find out (CPU, GPU, RAM, driver, monitor model, current settings); run those first and confirm rather than ask.

## 1. How they race (shapes the baseline scenario)
- What they mostly drive: series or car class, and typical grid size (8, 20, 30, 40, 60).
- Official, league, or hosted; night racing or not.
- Rain: never, occasionally, regularly. (Decides whether rain gets its own baseline and whether particle settings matter.)
- Display setup: single, ultrawide, triples, VR. If triples: monitor model, and ask them to **measure eye-to-centre-screen distance** now; it is the one geometry input that cannot be looked up.
- If VR: headset model, how it connects (DisplayPort native, USB link cable, Wi-Fi via Air Link / Virtual Desktop / Steam Link / ALVR, or another streaming app), which runtime (Meta, SteamVR, Virtual Desktop, Pimax Play, Varjo, WMR), target refresh, and any extra layers (OpenXR Toolkit, foveated rendering). These decide the frame budget, where resolution is set and what to research; see references/vr.md.

## 2. What they want (shapes every trade)
- Priority on a 1–5 scale from "max frame rate" to "best image", or in their words.
- Things they refuse to lose. Typical answers: distant-car visibility, readable mirrors, cockpit text, shadows, their current FOV.
- Things they are happy to sacrifice. Typical: crowds, grandstands, pit objects, trackside clutter, replay quality.
- A frame-rate floor they consider acceptable, if they have one (many don't; offer "the 1% low stays above X").

## 3. Constraints
- Are they willing to change Windows security settings (Memory Integrity) for performance? Present it as a real trade-off, not a recommendation.
- Are they willing to install Intel PresentMon (and optionally HWiNFO)? Required for measurement.
- Can they run an offline AI race for testing (needs owned content for the track/car)? If not, which hosted/practice session can serve as a repeatable test?
- Any known problem they want solved: stutter, tearing, flicker, long loads, crashes. (These may redirect the diagnosis.)
- Overlays and background apps they run while racing (Racelab, SimHub, Crew Chief, Discord, streaming). Not to remove them; to account for them.

## 4. Record the answers

Write them to the tune-up log as the "Driver profile" section before doing anything else. Every later recommendation should be traceable to a line in it ("you said you never race in rain, so…").

## Example of a well-formed interview message

> Before I touch anything I need to know how you race and what you care about, so every change can be judged against it. A few quick ones:
> 1. What do you mostly run, and how big are the grids? (e.g. "GT3 officials, 30–40 cars")
> 2. Rain: never / sometimes / often? Night: yes / no?
> 3. Screens: single / ultrawide / triples / VR? If triples, the monitor model, and please measure from your eye to the centre of the middle screen in your seat. If VR, which headset, how it connects (cable, Wi-Fi via Virtual Desktop/Air Link, DisplayPort), which runtime, and what refresh you run.
> 4. On a scale from "frame rate above all" to "make it beautiful", where are you?
> 5. What must not get worse? (distant cars, mirrors, cockpit text, shadows…)
> 6. What are you happy to give up? (crowds, grandstands, pit objects…)
> 7. OK to change Windows security settings such as Memory Integrity for performance, if it turns out to matter? OK to install Intel PresentMon for measuring?
> 8. Any specific problem you want fixed (stutter, tearing, flicker), and which overlays/apps run while you race?
