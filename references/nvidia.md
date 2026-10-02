# NVIDIA specifics (NVIDIA app 11.x layout, late 2026; verify menus with a search)

## The Control Panel is gone

NVIDIA retired the classic NVIDIA Control Panel with driver 610.47 (May 2026). A clean driver install removes any leftover copy, and users who then "can't find Control Panel" have not broken anything. Everything lives in the **NVIDIA app** (Start → "NVIDIA app", or the tray icon):

- **System → Displays**: G-SYNC, Surround, per-display properties.
- **Graphics → Program Settings / Global Settings**: the old 3D settings.
- **Drivers**: updates. Choose Custom and tick "clean installation" when changing major versions.
- **Settings (gear) → Features → NVIDIA Overlay**: turn Off for racing; it holds ~200 MB VRAM and does nothing useful here.

Confirm the installed driver with `nvidia-smi --query-gpu=driver_version --format=csv,noheader` and compare with the current Game Ready release (web search "GeForce Game Ready driver" for the current version and date; do not state a version from memory).

## Simultaneous Multi-Projection (SMP)

In the sim: Display → Monitor → **Nvidia Simultaneous Multi-Projection: On**, with Render Scene Using 3 Projections also On. Requires Pascal or newer. On a triple rig that the capture shows as CPU-bound, this is the first change to make and the one to test **alone**. With 3 projections the sim submits the scene once per screen; SMP lets the GPU replicate the geometry across the three views in one pass, so the render thread's work per frame drops substantially. On a CPU-bound triple rig it is often the single largest gain available; on a GPU-bound rig it changes little. Known failure modes to ask about after the test run: shimmering or misaligned shadows at the bezel seams, virtual mirror rendering wrong, no change at all. If any appear, turn it back off; not every build behaves.

Not applicable to single screens (nothing to multi-project) or AMD/Intel GPUs.

## G-SYNC on FreeSync (non-validated) panels

1. NVIDIA app → System → Displays → G-SYNC and Surround: set G-SYNC to **On, Full screen and windowed** (the sim runs borderless, so "full screen only" would not apply).
2. This global setting is **not enough** for non-validated panels. Select each display in the diagram, scroll to Display Properties, and switch that display's own **G-SYNC** toggle On. The caption "Selected display is not validated as G-SYNC compatible" is informational. Repeat for every racing display; leave non-racing monitors off.
3. Graphics → Program Settings → add the sim's executable (default `C:\Program Files (x86)\iRacing\iRacingSim64DX11.exe`) (the sim is not auto-detected; "Program doesn't support optimization" is harmless). Set **Vertical Sync On**, **Low Latency Mode Off** (in-game Reflex already does this), **Power management mode Prefer maximum performance**. Leave Max Frame Rate Off and cap in the sim instead.
4. In the sim: Vertical Sync stays Off; Max Frames Per Second 3–5 below the panel refresh.

Confirm it took: Program Settings shows the changed rows in bold without the "Global" prefix, and Monitor Technology reads "G-SYNC Compatible".

### Flicker after enabling VRR

- **Brightness pumping on all VRR panels, worst in menus and loading screens**: VA-panel VRR flicker. Fix: per-display G-SYNC off and driver vsync off; keep the frame cap.
- **Colour-tinted (bluish) flicker on the primary display only, in a windowed app such as the iRacing UI**: multi-plane overlay interacting with the driver. Rule out the cable by swapping DisplayPort cables between two screens, then disable MPO (reversible, no performance cost). NVIDIA's own fix (support article 5157, `mpo_disable.reg`) sets this value:
  ```
  reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f
  ```
  Reboot. Undo with `reg delete "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /f` and reboot. Have the user run the command themselves; it is a system change. Search for current reports before recommending it: on Windows 11 25H2 there are reports that this value no longer fully disables MPO. Judge the fix by the symptom after a reboot and by the capture: a present mode of "Hardware Composed: Independent Flip" means the sim is still on an overlay plane; "Hardware: Independent Flip" means it is not. A value set under any other key (for example `...\Windows\Dxgkrnl`) does nothing; if you find one, tell the user it can be deleted.

## Power and thermal reading

- `nvidia-smi --query-gpu=power.draw,power.limit,clocks.gr,clocks_event_reasons.sw_power_cap,temperature.gpu --format=csv` during a session. `sw_power_cap: Active` with the clock below normal boost = at the power limit. Consumer cards cannot usually raise the limit beyond `power.max_limit`.
- Below 80 °C is not thermal throttling.

## Reflex

Enabled in-game is correct. It makes PresentMon's MsCPUBusy track the GPU time (see diagnosis.md); do not conclude "CPU-bound" from CPUBusy alone when Reflex is on.
