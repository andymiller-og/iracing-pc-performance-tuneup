# VR specifics

**Status: written from iRacing's release notes and public sources, not from measurements with this skill.** Tell the user. The capture and analysis method applies, with the differences below. Headsets, runtimes and streaming apps change monthly: research the user's exact combination before advising (see below), and say which advice came from that research.

## Find out exactly how they run VR, then research that setup

Ask these first (skip any the user already answered), then **web-search the combination** (headset + connection + runtime + "iRacing") for current recommended settings and known issues.

| Ask | Why it matters |
|---|---|
| Headset model | Native resolution, refresh options, lens sweet spot, and **whether it has eye tracking** (needed for the sim's dynamic foveated rendering). Current examples: with eye tracking: Pimax Crystal / Crystal Super, Varjo Aero / XR-series, Bigscreen Beyond 2e, Quest Pro, Steam Frame (2026); without: Quest 3 / 3S, Pico 4, Bigscreen Beyond 2, Valve Index. Windows Mixed Reality was removed in Windows 11 24H2, so a Reverb G2 only works through a community SteamVR driver; search before advising one. |
| Connection | DisplayPort-native (Pimax, Beyond, Varjo, Index), USB link cable (Quest Link), or Wi-Fi streaming (Virtual Desktop, Air Link, Steam Link, Steam Frame's own streaming). Streamed headsets add encode, network and decode stages that PresentMon cannot see; bitrate, codec, router and Wi-Fi band matter as much as fps. |
| Runtime | Meta/Oculus OpenXR, SteamVR, Virtual Desktop's VDXR, Pimax Play, Varjo Base. Decides which renderer file the sim writes, where render resolution is set, and which motion smoothing exists (ASW, SteamVR motion smoothing, VD SSW, Pimax smart smoothing). iRacing notes that SteamVR handles eye tracking poorly on some headsets; Pimax and Varjo owners should use the vendor's OpenXR runtime. |
| Refresh and render resolution | The frame budget (90 Hz = 11.1 ms, 120 Hz = 8.3 ms) and the pixel count are set here, not in the sim. |
| Extra layers | **OpenXR Toolkit**: iRacing's November 2025 notice says to uninstall it (unsupported since 2024, causes performance and display problems); the sim now has its own foveated rendering. Also ask about OpenComposite and any external quad-views layer, which can conflict with the sim's own foveation. |

Record it in the driver profile. A plan written for "VR" without this is a plan for nobody's headset.

## Which file

VR sessions write to `rendererDX11OpenXR.ini` (most headsets), `rendererDX11OpenVR.ini` (SteamVR) or `rendererDX11Oculus.ini`. `Find-IRacingConfig.ps1` picks the most recently written renderer file; check it chose the VR one, or pass `-Path`. Since 2026 S3 the OpenXR file also has a resolution-scale percentage of its own; read it before changing resolution elsewhere.

## Foveated rendering (the sim's own)

- **Fixed foveated rendering (quad views)**: any OpenXR headset with an NVIDIA RTX 2000-series or newer GPU. The sim renders a sharp centre inset and a lower-resolution periphery. **Percentage Resolution to Keep** (periphery resolution) and **Inset Size** are the main GPU levers in VR; put them early in a GPU-bound plan.
- **Dynamic (eye-tracked) foveated rendering**: added in 2025 S4 (**Allow Eye Tracking**, **Show Eye Tracking**). Needs an RTX 2000+ GPU, a headset with eye tracking, and a runtime that exposes eye gaze to OpenXR.
- **Neither is available on AMD GPUs.** Say so to AMD VR users; it is a real gap.
- Turn off external quad-views layers when using the sim's own foveation.
- Steam Frame's foveated *streaming* is different: it spends encoder bitrate where you look and needs no game support. It can be combined with the sim's foveated rendering; research current guidance.

## What changes in the analysis

- **The target is the headset refresh, every frame.** There is no VRR to hide misses: a frame over the refresh interval is felt as reprojection or judder. Averages are nearly meaningless; run `Analyze-PresentMon.ps1 -TargetHz <refresh>` and report the share of frames over budget.
- **Present mode** shows the runtime's compositor, not Independent Flip; that is normal in VR.
- **Streamed headsets: PresentMon sees only the sim.** Capture with PresentMon **and** have the user read the streamer's own performance overlay (Virtual Desktop's shows game, encode, network and decode latency) at the same moment. If the sim's frame time stays inside the refresh interval while the user still sees stutter, the problem is the link (Wi-Fi channel, router placement, bitrate, codec), not the sim's settings.
- **Captures in a headset**: use timed mode with a long enough `-Delay` to get into the car, and start the capture from the desktop before putting the headset on, so the elevation prompt doesn't appear inside the headset view.
- **Motion smoothing**: decide with the user first whether they run locked at refresh or accept reprojection (ASW / SSW / motion smoothing at half rate). The plan then targets "frames inside the interval" for that mode.

## Sim settings that matter more in VR

- **VR mode** (Display page): Single Pass Stereo on NVIDIA renders both eyes in one geometry pass, the VR analogue of SMP. Keep it on unless the user is on the quad-views path.
- **Anti-aliasing**: VR needs it badly; MSAA (with the resolve filter) or SMAA. Measure the cost.
- **Shadow maps, Shader Quality Max, full-resolution particles, cubemaps**: GPU-heavy items hurt twice over.
- **Mirrors**: real cockpit mirrors are the VR way (the virtual mirror is a flat overlay); each is a scene render. One or two is the usual compromise.
- **Resolution scaling (FSR)** in the sim: iRacing's notes reported it misbehaving in VR in 2025; research the current state before using it.

## Runtime-side items to check

- The OpenXR runtime is set to the one the user intends (vendor or SteamVR).
- Refresh and render resolution are set deliberately; "auto" resolution on some runtimes picks a value far above native.
- For streamed headsets: PC wired to the router, a dedicated 5 or 6 GHz access point near the play space, and a bitrate and codec the GPU's encoder handles without missing frames. Research the headset's current recommendations.

Sources: iRacing support "Notice Regarding OpenXR Toolkit" (article 31000177470, Nov 2025); 2025 Season 4 release notes (article 31000177148, eye-tracked foveated rendering); 2026 Season 3 release notes (OpenXR resolution scale); Windows 11 24H2 removal of Windows Mixed Reality (Microsoft, 2024).
