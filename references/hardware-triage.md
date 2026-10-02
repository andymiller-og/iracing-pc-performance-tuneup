# Hardware triage and low-hanging fruit

Use this in Phase 2 (and in the quick check) to place the user's hardware before any capture. The output is a hypothesis about which side will limit and a list of things that are wrong regardless of hardware. The capture confirms or overturns the hypothesis; never present it as a verdict, and never quote an fps figure the user "should" get. Two PCs with the same GPU can differ by a third in the sim depending on CPU, screens, grid size and settings.

## 1. How many pixels the GPU has to fill

| Display set-up | Resolution | Megapixels | Notes |
|---|---|---|---|
| Single 1080p | 1920×1080 | 2.1 | Almost any current GPU; usually CPU-limited at the start of big races. |
| Single 1440p | 2560×1440 | 3.7 | |
| Ultrawide 1440p | 3440×1440 | 5.0 | |
| Single 4K | 3840×2160 | 8.3 | |
| Triple 1080p | 5760×1080 | 6.2 | Three projections multiply CPU work (see below). |
| Triple 1440p | 7680×1440 | 11.1 | The heaviest common flat set-up: GPU fill, VRAM and CPU all under pressure. |
| VR | per-eye target × 2 | often 8–20+ | Depends on headset and render resolution; read `vr.md` and research the headset. |

Supersampling or resolution scaling above 100% multiplies these; scaling below 100% divides them.

## 2. The CPU side

- The sim's **render thread** is the CPU limit in most CPU-bound captures. Single-thread speed and large L3 cache matter far more than core count. Large-cache CPUs (AMD X3D parts) have a strong reputation in the sim for this reason.
- What loads the render thread: cars drawn (view and mirrors), world object detail, shadow-map passes, each cockpit mirror, and **Render Scene Using 3 Projections** on triples, which submits the scene once per screen.
- **Simultaneous Multi-Projection** (NVIDIA, Pascal or newer) lets the GPU replicate geometry across the three projections in one pass. On NVIDIA triples with 3 projections on and SMP off, the render thread is doing up to three times the necessary submission work. That is the largest single piece of low-hanging fruit for NVIDIA triples. Test it alone.
- Race starts with a full field are the CPU's worst case. A rig can be GPU-bound mid-race and CPU-bound for the first minute.
- Laptop CPUs and older desktop CPUs on power-saving plans lose boost clock. Check the power mode before blaming the chip.

Rough placement (a hypothesis only; verify with the capture):

| CPU | Expectation |
|---|---|
| Recent large-cache desktop parts (AMD X3D) and recent high-end Intel/AMD desktop parts | Rarely the limit except at big-field starts or with 3 projections and no SMP |
| Mid-range desktop parts from the last few generations | Fine at low pixel counts; can limit triples and 40+ car fields |
| Older (roughly 5+ years) or low-power mobile parts | Likely the limit with big fields or triples; spend GPU headroom on anti-aliasing and image quality, cut cars and objects only as far as the profile allows |

## 3. The GPU side

- GPU cost scales with pixels (section 1) times per-pixel work: anti-aliasing, shader quality, shadows, reflections, particles at full resolution, post-processing.
- **VRAM** is the most common hidden limit on triples and VR. When it fills, the result is stutter and low lows rather than a lower average. The Windows compositor holds memory for every monitor and open window, so extra monitors, browsers and overlays cost VRAM the sim could have used. As a rough guide: 8 GB is tight for triple 1440p or high VR resolutions; 12 GB is workable at triple 1440p but leaves little room for higher car detail and 2048 textures; 16 GB or more is comfortable. Confirm with VRAM in the capture and `Get-GpuMemoryByProcess.ps1`.
- **Power limit**: a GPU at its board power limit with the clock below normal boost is working flat out (compute-bound). The same utilisation at noticeably lower power, with VRAM full, is memory-stalled. See `diagnosis.md`.

## 4. Likely limiter, before measuring

| Combination | Likely limiter | First things to look at |
|---|---|---|
| Strong CPU, modest GPU, high pixel count (triples, 4K, VR) | GPU, or VRAM | Per-pixel settings, VRAM consumers, resolution scaling as a last resort |
| Weak or older CPU, strong GPU, low pixel count | CPU | Cars drawn, objects, shadows, mirrors; spend GPU headroom on anti-aliasing |
| NVIDIA triples, 3 projections on, SMP off | CPU (render thread) | SMP alone, then re-measure before anything else |
| Small VRAM (8 GB or less) on triples or VR | VRAM | Texture and car-detail settings, overlays, background windows |
| Balanced class (both mid-range) | Mixed | Every change costs; let the profile choose |

## 5. Low-hanging fruit: wrong regardless of hardware

These are correctness fixes. They are safe to recommend in a quick check without a capture. Each needs the page, the value and one line of why.

| Check | Where to see it | Why it matters |
|---|---|---|
| Triple-screen geometry wrong (viewing distance typo, monitor width not the outer width, wrong curve radius) or FOV at the 179° clamp | `Find-IRacingConfig.ps1` geometry section; `monitor-geometry.md` | Wrong FOV draws more world than the eye can see and distorts speed and distance |
| SMP off on NVIDIA triples with 3 projections on | Display > Monitor | Up to three times the render-thread submission work |
| Frame cap far above the panel refresh with VRR on (on NVIDIA with Reflex + driver vsync, no sim cap is fine: Reflex caps itself) | Graphics > Frame Rate | VRR disengages above refresh; tearing or judder, wasted GPU power |
| VRR (G-SYNC / FreeSync): **ask, don't assume**. The scripts can't see it; tell the user exactly where to check | Vendor app, monitor OSD | Without VRR, any fps below refresh tears or judders |
| Draw Cars below the user's typical grid size | Graphics > Other Cars Detail | Cars beyond the count are not drawn at all |
| Dynamic LOD Frame Rate Threshold above the fps the rig normally runs (not merely above the start lows, which is a choice; see `settings-reference.md`) | Graphics > Dynamic LOD | The sim simplifies cars and scenery all the time; the user reports "it looks worse" |
| No anti-aliasing at all: **ask** whether shimmer bothers them (some competitive drivers run it off deliberately); otherwise list under "can't tell without a capture" | Graphics > Anti-Aliasing | Shimmer on fences and distant cars; makes distant cars harder to read |
| Driver well behind the current release. On AMD, map the Windows driver number to the Adrenalin version first (`amd.md`) | `nvidia-smi` or the vendor app, versus a web search for the current release | Performance and VRR fixes |
| Power mode not on Best performance (desktop) | Windows Settings > System > Power | The render thread's core loses boost |
| Vendor overlay running while racing (NVIDIA app overlay, Adrenalin overlay) | Vendor app | VRAM and compositor cost for nothing during a race |
| 2048x2048 car textures or high car detail on a card already near full VRAM | Graphics > Video Memory / World Detail | Stutter at starts |
| HDR on with non-HDR panels | Graphics > Image Quality | Cost with no benefit |
| Sim set to reduce frame rate when it loses keyboard focus, with overlays or tools that take focus | renderer file `reduceFramerate_WhenFocusLost` | Frame rate drops while another program has focus |

Not low-hanging fruit, and never applied in a quick check: Memory Integrity (a security trade-off for the user to choose), resolution scaling, shadow maps, shader quality, anti-aliasing method changes. These are performance trades; measure them.

## 6. What only a capture can tell you

Which side is actually limiting, and in which part of the race; whether VRAM is full; whether the GPU is at its power limit; whether rain or night changes the picture; how much a trade really costs on this machine. Published costs, including the ones in `settings-reference.md`, are directions; relative costs differ between rigs and builds.

## Sources

- iRacing support, "Setting Up Three Monitors": https://support.iracing.com/support/solutions/articles/31000171395-setting-up-three-monitors
- iRacing support, "Graphics performance tip for increased FPS": https://support.iracing.com/support/solutions/articles/31000133465-graphics-performance-tip-for-increased-fps
- iRacing support, "Dealing with Freezing and/or Stuttering Issues": https://support.iracing.com/support/solutions/articles/31000141916-dealing-with-freezing-and-or-stuttering-issues
- NVIDIA support article 5157 (multi-plane overlay): https://nvidia.custhelp.com/app/answers/detail/a_id/5157

Re-check these when the sim's Options change; search the current season's release notes for new or renamed settings.
