# Worked example: a triple-screen GT3 rig, September–October 2026

Included so you can see what good diagnosis looks like, including the mistakes. The owner races 30–50 car GT3 grids, mostly dry, values image quality, and refused to lose distant-car visibility, readable mirrors or cockpit text.

## Rig
Alienware Aurora R16 (Dell Outlet), i7-14700F, RTX 4070 12 GB (200 W cap), 32 GB DDR5-5600, 3× Gigabyte G32QC A 2560×1440 165 Hz 1500R on DisplayPort, a 4th 1080p 60 Hz monitor for apps. 7680×1440 borderless, three projections. 500 W Platinum PSU (the order sheet said so; inferring "1000 W because it has a 4070" was wrong).

## Starting state
Monitor geometry: width 23.98 in (a 27" value for 31.5" panels), viewing distance 2.05 in (typo for 25), radius 1000 mm (panel is 1500R), FOV 179° (the clamp). No anti-aliasing. Draw Cars 20/8. Frame cap 232 on 165 Hz panels. SMP off. World detail already Low/Off. Shadow maps off. Memory Integrity on, Balanced power. Driver three releases old.

## Baseline captures and what they taught

**Capture 1: a saved replay of a 40-car Silverstone race, 5 minutes.** 94 fps avg, 69 1% low. CPUBusy 10.5 ms of a 10.6 ms frame, GPUBusy 6.9 ms, GPUWait 3.8 ms, GPU 67%, 148 W of 200 W, 2,895 MHz, 70 °C. 28,920 of 28,931 frames CPU-bound. Verdict: render thread. Not GPU, not RAM, not thermal, not power.

Mistake avoided late: an earlier hardware-report-only analysis had called it "GPU" from a cumulative time-at-power-cap counter. Per-frame data overruled it.

Mistake made: treating the replay as a stand-in for driving. Replays use the Replays settings column and TV cameras. Verified later: the same rig drove a dry race at 84 fps while the replay ran 137.

## Batches

**1. Geometry.** Width 27.97 in and bezel 0.26 in from the spec sheet (710.5 mm outer, 697 mm active), viewing distance 25 in measured, radius 1500. Compute → 167°. FPS unchanged. The user noticed things looked "zoomed in" for a session, then not.

**2. SMP On, Memory Integrity Off, Best performance power mode (applied together; SMP tested first in hindsight would have been better).** Replay: 94 → 137 fps, 1% low 69 → 100. CPUBusy 10.5 → 7.1 ms, GPUBusy unchanged, GPUWait 3.8 → 0.8 ms. Limiter went to 50/50. No artifacts.

**3. SMAA, Sharpening On, Virtual Mirror FOV 100, Sky Medium, cap 160.** Then the first real driving test: **Spa, 39 AI, rain**: 60 fps avg, 47 1% low, 89% GPU-bound, GPU 97–98% at only 163 W, VRAM 12.7 GB of 12.3 GB. The low power at high utilisation plus full VRAM said memory stall, not compute. Per-process: sim 9.9 GB, Windows compositor 1.85 GB (four monitors, many windows), Racelab 0.23, NVIDIA overlay 0.2.

**4. Particles Full Resolution Off, Dynamic LOD threshold 60 → 80, NVIDIA overlay Off.** Rain: 60 → 65 avg, 47 → 51 1% low. VRAM still full because the sim grew into the freed memory, but GPU power rose 163 → 171 W (less stalling).

**5. Driver 610.60 → 617.14 clean; G-SYNC per-display on the three panels; sim profile vsync On / Low Latency Off / Prefer max performance.** The Control Panel "disappeared" (retired in 610.47; everything is in the NVIDIA app). Side effect: bluish flicker on the primary display in the iRacing UI only; present mode changed to "Hardware Composed: Independent Flip". Multi-plane overlay suspected; registry fix applied by the user.

**Dry driving baseline, Spa, 39 AI, clear**: 87 fps avg, 68 1% low, 86% GPU-bound, GPU 99% with the power cap active (184 W, clock 2,700 vs 2,880 boost), VRAM 12.6 GB. The user said it "looked worse, edges around the dash". Cause: the Dynamic LOD threshold at 80 was above the running fps, so the sim was stripping car detail all lap; sharpening amplified the residual aliasing.

**6. Dynamic LOD back to 60, Draw Cars 20/8 → 40/12.** Dry: 87 → 84 fps, 68 → 67 1% low. Full field drawn for 3%. Sharpening tested off by the user: no visible difference, left on.

**Final like-for-like replay re-run**: 127 fps avg, 102 1% low, 91 0.1% low (from 94 / 69 / ~33). Lower average than the 137 midpoint because the freed GPU time now pays for SMAA; better lows.

## Not changed, and why
Shadow Maps (no headroom on either side in real driving), Cars High and 2048 textures (VRAM full), MSAA (GPU-bound), Resolution Scaling (user chose native sharpness over shadows), replay settings (user doesn't care), Crowds/Grandstands (user's stated sacrifice).

## Hardware conclusion
In every real driving scenario the RTX 4070 is the limiter at 7680×1440, at its power cap with VRAM full. A GPU upgrade on this chassis requires Dell's proprietary 1000 W PSU first (the 500 W unit has one 8-pin and one 6-pin lead), so the recommendation was to stop here.

## Lessons that generalise
1. Per-frame data beats inventory reports. The hardware report alone produced the wrong verdict.
2. Benchmark a race start in the cockpit, in the user's typical conditions. Never a replay.
3. Test the risky change alone (SMP) so the result can be attributed.
4. A setting that "should" help can look worse: the Dynamic LOD threshold must sit below the running fps.
5. The sim grows into free VRAM; freeing memory shows up as higher GPU power and better lows, not as a lower VRAM number.
6. Don't infer hardware (PSU) from configuration logic; find the label, the BIOS page or the order sheet.
7. Driver and vendor-app UI changes faster than training data; verify with a search before telling the user where a setting lives.
