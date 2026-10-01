# Reading a PresentMon capture: how to decide what is limiting the sim

Run `scripts/Analyze-PresentMon.ps1 -Path <csv> -PowerLimitW <nvidia-smi power.limit>` and read the output against this guide. The script computes; you decide.

## The four numbers that matter

| Column | Meaning | What it tells you |
|---|---|---|
| MsBetweenPresents | frame time | 1000 / mean = average fps. The sorted top 1% and 0.1% give the lows, which is what the driver feels. |
| MsCPUBusy | time from the frame's start on the CPU to the Present call | If this tracks frame time and GPUWait is large, the CPU side is the limiter. |
| MsGPUBusy | time the GPU spent executing the frame | If this tracks frame time and GPUWait is ~0, the GPU is the limiter. |
| MsGPUWait | time within the frame the GPU sat idle waiting for the CPU | The cleanest single signal. Several ms per frame = GPU starved = CPU-bound. |

MsCPUWait (CPU waiting on the GPU in Present) is usually small either way in iRacing because Reflex and the frame limiter pace the CPU instead of blocking it.

## Verdicts

**CPU-bound (the sim's render thread).** CPUBusy ≈ frame time, GPUBusy well below it, GPUWait of 2–5 ms per frame, GPU utilisation 60–80%, GPU power well below its limit. iRacing is single-threaded on the render side; the classic cause on triples is "Render Scene Using 3 Projections", which submits the whole scene three times. Fixes are things that reduce draw submission: SMP on NVIDIA, fewer cars drawn, fewer world objects, no shadow maps (they add passes), lower LOD. Resolution and anti-aliasing changes do almost nothing here.

**GPU-bound.** GPUBusy ≈ frame time, GPUWait ≈ 0, utilisation 95–100%. Two sub-cases that look identical in utilisation but behave differently:
- *Compute-bound*: GPU power sits at or within ~8% of its limit and the clock sags below its normal boost. The card is working flat out. Fixes: anything that reduces pixels or shading (resolution scaling, lower shader quality, no full-res particles, no MSAA, fewer shadow passes).
- *Memory-bound / VRAM full*: utilisation 97–99% but power noticeably **lower** than the same card draws when compute-bound, with total VRAM in use at the card's capacity. The GPU is stalling on memory, not computing. Fixes: free VRAM (close overlays and browser windows, fewer monitors' worth of compositor buffers), lower texture settings, lower resolution. Confirm with `scripts/Get-GpuMemoryByProcess.ps1` during a session.

**Balanced.** GPU-bound and CPU-bound frame counts both substantial, GPUWait under ~1 ms. Any further change costs something; pick by what the user values.

## The Reflex caveat

With NVIDIA Reflex enabled in-game, the driver delays the CPU's frame start so the CPU finishes just as the GPU is ready. That inflates MsCPUBusy to roughly match the GPU time, so a purely GPU-bound capture also shows CPUBusy ≈ frame time. Do not read that as "both are limiting". Use the GPU-bound frame count and GPUWait to break the tie. The worked example's dry test showed CPUBusy 11.3 ms, GPUBusy 11.45 ms, GPUWait 0.02 ms: GPU-bound, not balanced.

## What else to check in the output

- **Present mode.** "Hardware: Independent Flip" or "Hardware Composed: Independent Flip" means frames go straight to the display and the Windows compositor is not in the path; a borderless window in this mode performs like exclusive fullscreen. "Composed: Flip" on most frames means something (an overlay, a window on top, a windowed mode without flip) forced compositor involvement. Don't theorise about compositor stutter when the mode says independent flip.
- **GPU clock vs power.** A clock below the card's normal boost while power is pinned = power cap active. On NVIDIA confirm live with `nvidia-smi --query-gpu=clocks_event_reasons.sw_power_cap --format=csv`.
- **Temperature.** NVIDIA cards start pulling clocks hard around 83 °C; sub-80 is not thermal throttling even if it looks warm.
- **Long frames.** A single 100–900 ms frame at the start is a load or camera cut; ignore it. Repeated 20–40 ms frames through a lap are stutter worth chasing. Read the signature of each long frame: if MsGPUWait ≈ the whole frame (GPU idle) while MsCPUBusy spans it, the sim stopped submitting work, which points at a load, texture eviction under full VRAM, a reset, or UI; if MsGPUBusy spans it, the GPU itself hitched (shader compile, memory thrash). Ask the user what happened at that timestamp before theorising.
- **Percentiles can be skewed by the pre-start.** Grid and formation seconds often run faster and at higher GPU power than the race. If the time-series buckets show a clear change at the lights, judge the limiter and the power-cap question on the racing buckets, not the whole-capture percentiles.
- **VRAM over time.** Flat at a value well below the card's total = fine. Pinned within ~0.3 GB of total for the whole capture = full, regardless of what the sim's own budget says.

## What was captured matters more than the numbers

Before trusting a capture, run `scripts/Read-IRacingSession.ps1` (while the sim is still in the session) or ask the user:

- **Replay or live?** A replay uses the **Replays** settings column and typically TV cameras: no cockpit, no virtual mirror, and often a single view instead of three projections. In the worked example a replay ran at 137 fps while the same rig drove a dry race at 84 fps. Replays are useful for strict like-for-like comparisons between two settings states, and useless as an estimate of driving fps.
- **How many cars, which track, what weather.** A 40-car start at Spa in rain and a 12-car practice at Lime Rock are different machines.
- **Which renderer file.** VR sessions write to the OpenXR/OpenVR renderer file; flat sessions to rendererDX11Monitor.ini. Settings read from the wrong file explain nothing.

## Interpreting the frame-rate target

With variable refresh rate working, 70–90 fps feels smooth on a 144–165 Hz panel. Without VRR, the same fps on a high-refresh panel tears (vsync off) or judders (vsync on). The 1% low is the number to protect; an average of 85 with a 1% low of 67 is a good racing state, an average of 110 with a 1% low of 40 is not.
