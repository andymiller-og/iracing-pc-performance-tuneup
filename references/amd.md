# AMD Radeon specifics

**Status: written from public sources and general knowledge, not from measurements with this skill.** Say so to the user. The measurement method (PresentMon, the analysis script, the batching loop) is vendor-neutral and fully applies; only the vendor-side steps below are untested here. Adrenalin's menus and feature names change between releases: search before naming a menu path.

## What is different from NVIDIA

- **No Simultaneous Multi-Projection.** The biggest CPU-side win on NVIDIA triples does not exist on AMD; the setting does nothing. A CPU-bound AMD triple rig reduces draw submission the slow way: fewer cars in mirrors, lower Objects/Pit/Grandstand detail, no shadow maps, no dynamic cubemaps, and Windows-side items (Memory Integrity, power mode). Be upfront that the ceiling is lower.
- **No Reflex.** The in-game Reflex setting is inert. AMD's driver-level equivalent is **Radeon Anti-Lag** (the original Anti-Lag; Anti-Lag 2 needs in-game integration, which iRacing doesn't have). Anti-Lag also delays the CPU's frame start, so PresentMon's MsCPUBusy may still be partly inflated: use GPUWait and the GPU-bound frame count as the tie-breaker, as on NVIDIA.
- **No sim foveated rendering in VR.** The sim's fixed and eye-tracked foveation need an NVIDIA RTX GPU. AMD VR users have to get their savings from render resolution, anti-aliasing and the usual GPU-heavy settings.
- **No nvidia-smi.** Power, clock and VRAM come from Adrenalin's performance metrics or HWiNFO sensor logging. PresentMon still reports GPU power, clock and VRAM when its service is running.
- **Driver version.** Windows reports a driver version like 31.0.xxxxx; that is **not** the Adrenalin version (e.g. 25.x). Ask the user for the Adrenalin version, or map the Windows number with a search, before calling a driver old.

## Adrenalin settings for the sim (per-game profile)

- **Radeon Anti-Lag**: On.
- **Radeon Chill / Frame Rate Target Control**: Off; cap in the sim instead.
- **Radeon Boost / Radeon Super Resolution / driver sharpening**: Off for racing (Boost changes resolution dynamically; the sim has its own sharpening and FSR).
- **Wait for Vertical Refresh**: Always on, paired with FreeSync (the equivalent of NVIDIA's driver vsync with G-SYNC). **Enhanced Sync: Off**; it is unstable on some set-ups. Keep the sim's own Vertical Sync Off.
- **Frame cap**: in the sim, about 3% below the panel refresh (there is no Reflex auto-cap on AMD).
- **Anti-aliasing / anisotropic filtering**: application settings.

## FreeSync

FreeSync on per display in Adrenalin, and enabled in each monitor's on-screen menu (some ship with it off). Eyefinity is not required for borderless triples; check the capture's present mode is Independent Flip.

## Driver

Confirm the installed Adrenalin version (Adrenalin → Settings → System) and compare with the current release on amd.com (search; don't state a version from memory).
