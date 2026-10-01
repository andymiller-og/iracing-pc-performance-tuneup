# AMD Radeon specifics

**Status: written from general knowledge, not from measurements with this skill.** Say so to the user. The measurement method (PresentMon, the analysis script, the batching loop) is vendor-neutral and fully applies; only the vendor-side steps below are untested here.

## What is different from NVIDIA

- **No Simultaneous Multi-Projection.** The biggest CPU-side win on NVIDIA triples does not exist on AMD. Leave "Nvidia Simultaneous Multi-Projection" Off; it does nothing. A CPU-bound AMD triple rig has to reduce draw submission the slow way: fewer cars drawn, lower Objects/Pit/Grandstand detail, no shadow maps, lower Dynamic LOD threshold, and Windows-side items (Memory Integrity, power mode). Be upfront that the ceiling is lower.
- **No Reflex.** The in-game NVIDIA Reflex setting is inert. AMD's equivalent is **Radeon Anti-Lag** in Adrenalin (per-game profile). Without Reflex, PresentMon's MsCPUBusy is not inflated, so CPU-bound vs GPU-bound reads more directly.
- **No nvidia-smi.** Power, clock and VRAM come from Adrenalin → Performance → Metrics, or from HWiNFO sensors logging. PresentMon still reports GPUPower/GPUFrequency/GPUMemorySizeUsed when its service is running.

## Adrenalin settings for the sim (Gaming → Games → iRacing profile)

- **Radeon Anti-Lag**: On (replaces Reflex).
- **Radeon Chill / Frame Rate Target Control**: Off; cap in the sim instead.
- **Radeon Boost / Radeon Super Resolution / Image Sharpening**: Off for racing (Boost changes resolution dynamically; the sim's own sharpening is enough).
- **Wait for Vertical Refresh**: "Enhanced Sync" or "Always on" together with FreeSync; test both, and keep the sim's own Vertical Sync Off.
- **Anti-aliasing / AF**: Use application settings.
- **Tessellation**: AMD optimised.

## FreeSync

Display → FreeSync Premium / AMD FreeSync: On per display in Adrenalin, and FreeSync enabled in each monitor's OSD (some monitors ship with it off). Eyefinity is not required for borderless triples; check the capture's present mode is Independent Flip.

## Driver

Confirm the installed Adrenalin version from Adrenalin → Settings → System, and compare with the current release on amd.com (search; do not state a version from memory).
