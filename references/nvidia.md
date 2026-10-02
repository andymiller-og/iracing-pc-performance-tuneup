# NVIDIA specifics (NVIDIA app 11.x layout as verified Oct 2026; search before quoting a menu path)

## The Control Panel no longer ships with GeForce drivers

NVIDIA retired the classic NVIDIA Control Panel from GeForce drivers with 610.47 (May 2026); it remains on the Microsoft Store and is still supported for RTX PRO cards. A clean driver install removes the bundled copy, and users who then "can't find Control Panel" have not broken anything. The settings live in the **NVIDIA app**:

- **System → Displays**: G-SYNC, Surround, per-display properties.
- **Graphics → Program Settings / Global Settings**: the old 3D settings.
- **Drivers**: updates. Choose Custom and tick "clean installation" when changing major versions.
- **Settings (gear) → Features → NVIDIA Overlay**: off for racing; it holds some VRAM (measure with `Get-GpuMemoryByProcess.ps1`) and adds nothing during a race.

Confirm the installed driver with `nvidia-smi --query-gpu=driver_version --format=csv,noheader` and compare with the current Game Ready release (search; don't state a version from memory).

## Simultaneous Multi-Projection (SMP)

In the sim: Display → Monitor → **Nvidia Simultaneous Multi-Projection: On**, with Render Scene Using 3 Projections also On. Requires Pascal or newer. With 3 projections the sim submits the scene once per screen; SMP lets the GPU replicate the geometry across the three views in one pass, so the render thread's work per frame drops substantially. On a CPU-bound triple rig it is often the single largest gain available; on a GPU-bound rig it changes little. Test it **alone**. Failure modes to ask about after the test run: shimmering or misaligned shadows at the bezel seams, the virtual mirror rendering wrong, no change at all. If any appear, turn it back off.

Not applicable to single screens or AMD/Intel GPUs. VR's equivalent is Single Pass Stereo (see `vr.md`).

## G-SYNC, vsync, Reflex and the frame cap

1. NVIDIA app → System → Displays → G-SYNC: **On, full screen and windowed** (the sim runs borderless).
2. For non-validated (FreeSync) panels the global switch is **not enough**: select each racing display, and switch its own G-SYNC toggle on in Display Properties. "Not validated as G-SYNC compatible" is informational. Leave non-racing monitors off.
3. Graphics → Program Settings → add the sim's executable if it isn't listed (default `C:\Program Files (x86)\iRacing\iRacingSim64DX11.exe`). Set **Vertical Sync On**, **Low Latency Mode Off** (in-game Reflex supersedes it), **Power management: Prefer maximum performance**. Leave Max Frame Rate off.
4. In the sim: Vertical Sync Off, Reflex **Enabled**.

**The cap.** With G-SYNC + driver vsync + Reflex, **Reflex applies its own frame cap just below refresh** (roughly refresh − refresh²/3600: about 138 at 144 Hz, 157 at 165 Hz, 224 at 240 Hz). A sim cap above that does nothing; a sim cap a little below it is fine if the user wants a steadier ceiling. Read the cap the capture actually shows rather than assuming. Without Reflex (AMD, or Reflex off), cap in the sim about 3% below refresh.

**Reflex modes.** Enabled is the default. Enabled + Boost keeps GPU clocks up when the GPU is underused (CPU-bound or capped), at some power cost; Reflex reduces latency most when the GPU is the limit and does little for a CPU-bound sim.

**Competitive trade.** Uncapped with VRR off and vsync off gives the lowest input latency but tears. VRR + vsync + Reflex is the usual competitive choice: near-minimum latency without tearing. Present it as the user's choice.

Confirm the set-up took: the changed Program Settings rows appear without the "Global" prefix, and the monitor's own OSD or Monitor Technology reports VRR active.

### Flicker after enabling VRR

- **Brightness pumping on VRR panels, worst in menus and loading screens**: VA-panel VRR flicker at low or fluctuating frame rates. Options: per-display G-SYNC off, or accept it in menus; keep the frame cap.
- **Colour-tinted flicker on one display only, in a windowed app such as the sim's UI**: often multi-plane overlay (MPO) interacting with the driver. Rule out the cable first by swapping DisplayPort cables between two screens. Then disable MPO (reversible). NVIDIA's own fix (support article 5157, `mpo_disable.reg`) sets:
  ```
  reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f
  ```
  Reboot. Undo: `reg delete "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /f`, reboot.
  Since Windows 11 24H2 there are reports that this value alone no longer disables MPO. A community workaround (not NVIDIA-documented) adds `reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayMinFPS /t REG_DWORD /d 0 /f` (undo: `reg delete "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayMinFPS /f`). Search for current reports before suggesting it.
  Have the user run these themselves; they are system changes. Judge the fix by the symptom after a reboot and by the capture's present mode: "Hardware Composed: Independent Flip" means the sim is still on an overlay plane; "Hardware: Independent Flip" means it is not. A value set under any other key (for example `...\Windows\Dxgkrnl`) does nothing; tell the user it can be deleted.

## Power and throttling

- During a session: `nvidia-smi --query-gpu=power.draw,power.limit,clocks.gr,clocks_event_reasons.sw_power_cap,clocks_event_reasons.hw_thermal_slowdown,clocks_event_reasons.sw_thermal_slowdown,temperature.gpu --format=csv`.
- `sw_power_cap: Active` with the clock below normal boost = at the power limit. Consumer cards usually can't raise the limit beyond `power.max_limit`.
- **Judge thermal throttling by the throttle flags, not by a temperature.** GPU Boost sheds clock bins gradually as temperature rises, and hard limits differ by generation.

## Reflex and PresentMon

Reflex makes PresentMon's MsCPUBusy track the GPU time (see `diagnosis.md`); don't conclude "CPU-bound" from CPUBusy alone when Reflex is on.
