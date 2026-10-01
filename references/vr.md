# VR specifics

**Status: written from general knowledge, not from measurements with this skill.** Tell the user. The capture and analysis method applies, with the differences below.

## Which file

VR sessions write to `rendererDX11OpenXR.ini` (most headsets today), `rendererDX11OpenVR.ini` (SteamVR) or `rendererDX11Oculus.ini`. `scripts/Find-IRacingConfig.ps1` picks the most recently written renderer file; check it chose the VR one, or pass the path.

## What changes in the analysis

- **The target is the headset refresh, every frame.** 90 Hz means 11.1 ms, with no VRR to hide misses. A 1% low below the refresh is felt as reprojection or judder. Averages are nearly meaningless in VR; the fraction of frames over the refresh interval is the number to report (Analyze-PresentMon prints frames >16.7 ms; for 90 Hz count frames >11.1 ms from the frame-time distribution, or re-run with a smaller BucketSeconds and read p99).
- **Present mode** will show the runtime's compositor, not Independent Flip; that is normal in VR.
- **Two eyes.** Resolution is set by the runtime's render scale (OpenXR Toolkit, SteamVR per-app resolution, the headset's software), not only by the sim. "Percentage Resolution to Keep" and "Inset Size Percentage" in the sim apply to foveated quad views, not to plain rendering.

## Sim settings that matter more in VR

- **VR Mode** (Display → VR): Single Pass Stereo on NVIDIA is the VR analogue of SMP; renders both eyes in one geometry pass. Keep On. Quad view with eye tracking only on headsets that support it.
- **Anti-Aliasing**: VR needs it badly; SMAA at minimum, MSAA 2x if GPU allows. Sharpening helps compensate for the headset's optics.
- **Shadow Maps, Shader Quality Max, Full-res Particles, Cubemaps**: the usual GPU-heavy items hurt twice as much.
- **Mirrors**: real cockpit mirrors are the VR way (virtual mirror in VR is a flat overlay); each costs a scene render. 1–2 is the common compromise.
- **UI**: 3D Screen Width/Depth control the UI panel placement; cosmetic.

## Runtime-side items to check

- OpenXR runtime set correctly (headset vendor's or SteamVR) in the headset software.
- Headset refresh (72/80/90/120 Hz) and render resolution set deliberately; the "auto" resolution on some runtimes picks a value far above native.
- Motion smoothing / ASW / reprojection: decide with the user whether to run locked at refresh or allow reprojection; the batching loop must then target "frames under refresh interval", not fps.
