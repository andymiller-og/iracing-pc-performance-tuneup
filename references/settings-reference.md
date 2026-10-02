# iRacing graphics settings: what each one does, costs and buys

Written for the DX11 renderer as of the 2026 Season 4 build. Descriptions are in this skill's own words, drawn from the ini files' notes, iRacing's release notes and support articles, and community guides (sources at the end). Three cautions:

- **Costs are directions, not numbers.** "GPU ++" means "a large GPU cost on most rigs", not a percentage. Relative costs differ between rigs and builds; the anti-aliasing methods are a known case where the ranking can flip. The user's captures decide.
- **Page names move.** The 2025 S4 rebuild put the Driving and Replay graphics options in one panel with per-setting help text, and 2026 S1 moved several options and added an **Options search box**. `Find-IRacingConfig.ps1` prints a page for each setting; if the user can't find it there, tell them to type the setting name into the Options search. The help text the sim shows when a setting is selected is the current authority on what it does in that build.
- **Quit and relaunch after each batch of changes** before verifying or capturing (the restart rule in SKILL.md). The "restart" notes below mark where iRacing documents that a setting needs it.
- **Driving and Replays are separate values.** Tune the driving values for racing. Replays only matter if the user cares about replays, and a replay is never a driving benchmark.

The ini key is in `Documents\iRacing\rendererDX11Monitor.ini` (VR: the OpenXR/OpenVR/Oculus renderer file) unless marked app.ini. "ini only" means there is no Options control: the user changes it with the sim closed, or leaves it alone. Don't edit ini files for the user.

Guiding principle: when the capture says CPU-bound, GPU-only settings (anti-aliasing, post-processing, sky, particle resolution) are nearly free; when it says GPU-bound, CPU-side settings (cars drawn) are nearly free. Nothing is free when balanced.

## Display

| Setting | ini key | Cost | What it does, when to use it |
|---|---|---|---|
| Resolution | windowedWidth/Height, fullScreenWidth/Height | GPU, VRAM | Pixels drawn. Triples = three panels wide (e.g. 7680×1440, 11 MP). See `hardware-triage.md` for pixel counts. |
| Full Screen / Border | fullScreen, border | none | Borderless windowed is normally equivalent to exclusive fullscreen when the capture's present mode is an Independent Flip. Exclusive fullscreen on triples needs NVIDIA Surround / AMD Eyefinity. |
| Resolution Scaling (AMD FSR) | ResolutionScaling | GPU −, VRAM − | Renders below native and upscales with AMD FSR (works on NVIDIA and AMD). Quality presets from Ultra Quality to Performance. Only active when an anti-aliasing mode is on. Restart (documented). Reduces GPU load only, never CPU load. Softens distant cars; a last resort when GPU-bound, or a rain-only trade. For VR see `vr.md`. FSRSharpness (ini only) adjusts the upscaler's sharpening. |
| Brightness / Contrast / Gamma | BrightnessAdj / ContrastAdj / GammaAdj (−6…+6) | none | Tone adjustment. Leave at 0 unless the monitor is mis-calibrated. |
| Monitor setup: number, type, width, bezel, viewing distance, curve radius, angles | `[MonitorSetup]` | none | Correctness, not fps, but wrong values draw more world than needed. FOV 179 = clamped = inputs wrong. See `monitor-geometry.md`. |
| Render Scene Using 3 Projections | RenderViewPerMonitor | CPU +++ | One camera per screen: geometrically correct side screens on triples, but the scene is submitted once per screen. |
| Nvidia Simultaneous Multi-Projection | EnableSMPSurround | CPU −−− | NVIDIA (Pascal or newer) only. The GPU replicates geometry across the three projections in one pass, so draw submission doesn't triple. The largest single CPU-side gain on CPU-bound NVIDIA triples; little change when GPU-bound. Test alone; look for shadow or mirror artefacts at the seams. iRacing disables these multi-view paths for particles by default because of driver crashes. |
| Relax angles when zoomed | Min3ViewZoomDistortion (ini only) | none | Relaxes screen angles when a TV camera zooms in. Replays only. |

## Anti-aliasing and image quality

| Setting | ini key | Cost | What it does, when to use it |
|---|---|---|---|
| Anti-Aliasing Method: Off / FXAA / SMAA / MSAA | AntiAliasMethod (0 none, 1 MSAA, 2 FXAA, 3 SMAA), MSAASamples 2/4/8 | GPU only | Off shimmers on fences, wires and distant cars. FXAA and SMAA are post-process passes over the finished image: cheap, but weaker on thin geometry and on edges in motion. MSAA samples the geometry itself, so it is the method that properly cleans up car silhouettes, fences and panel lines; its cost scales with pixel count and samples, and it adds VRAM. **Don't assume the ranking**: on some rigs MSAA 2x has measured cheaper than SMAA plus sharpening. Measure both on the user's machine. Zero CPU cost, so free on a CPU-bound rig. Restart (documented, shown in orange since 2025 S1). |
| MSAA filter: Simple / Soft / Neutral / Sharp | MSAAUseFilter (0 soft, 1 neutral, 2 sharp, 3 simple/legacy) | GPU (small) | Added in 2025 S1. A resolve filter that uses the MSAA samples better; iRacing states filtered 2x usually matches the old unfiltered 4x and that it doesn't add geometry cost. Simple is the legacy behaviour. Sharp offsets softness, Soft reduces shimmer. Try it before raising the sample count. |
| Shader Quality: Low / Medium / High / Max | ShaderQuality 0–3 | GPU | Medium or higher is required for anti-aliasing and FSR. Max has historically mattered mainly at night (more per-pixel lights from track lighting); its current effect after the 2025–26 lighting work is not documented. High is a sensible default; Max is a measured trade. |
| HDR | EnableHDR, HDRFormat | GPU (small) | For HDR panels. Also required for auto-exposure (AutoExposure, ini only). Off on SDR panels. |
| Anisotropic filtering | — | — | Removed in 2025 S1; always 16x. Ignore old guides that mention it. |

## Post-processing and other effects

| Setting | ini key | Cost | What it does, when to use it |
|---|---|---|---|
| Sharpening (+ amount) | Sharpening, SharpeningAmount (10–300, default 125), SharpeningClamp | GPU (small, but measure) | Restores crispness lost to FXAA/SMAA blur. It also raises edge contrast, so it can bring back the stair-stepping anti-aliasing removed; with MSAA it is often unnecessary. If the user complains about harsh or jagged car edges, try it off. |
| SSAO | SSAO | GPU | Contact shadows and depth. Heavily optimised in 2025 S1; older "very expensive" claims are out of date. A measured trade. |
| Heat Haze / Distortion / Depth of Field | HeatHaze / Distortion / DepthOfField | GPU | Cosmetic; depth of field is for replays and screenshots. Off for racing is the usual choice. |
| Motion Blur | MotionBlurStrength (0–4), MotionBlurDrivingCams, MotionBlurBroadcastCams | GPU | Separate for driving and broadcast cameras. Off for driving. |
| Screen Space Reflections | SSRLevel (off/low/high), SSRRainOnly | GPU ++ at high resolutions | Wet-track reflections. **Rain only** gives the wet look with no dry-session cost; Low on triples or 4K. |
| Dynamic Cubemaps | NumDynamicCubemaps (100 = one per frame) | CPU ++ | Reflections of other cars on your car. Mostly a CPU cost; 0 on CPU-bound rigs. |
| Fixed Cubemaps | NumFixedCubemaps | lower | Reflections of the track environment on cars. |
| Tire marks | EnableTireMarks | small | Rubber and skid marks. |
| Track displacement | TrackDisplacementEnable (ini only) | GPU | Displacement shaders on the track surface. Leave on. |

## World detail

| Setting | ini key | Cost | What it does, when to use it |
|---|---|---|---|
| Sky and Clouds | SkyRefreshRate | GPU (small) | Low looks flat; Medium is usually close to free. |
| Cars | CarDetail | GPU, VRAM | Model detail of other cars. High is visibly rounder up close but needs VRAM; check VRAM headroom in the capture before raising it on 12 GB or smaller cards at high pixel counts. |
| Pit Objects / Event / Grandstands / Crowds / Objects / Foliage | PitObjectDetail / WeekendDetail / GrandstandDetail / CrowdDetail / ObjectDetail / FoliageDetail | CPU + GPU | Draw calls on the render thread plus shading. Crowds and grandstands are the usual sacrifice; Objects Low removes trackside clutter. Several of these show Off/Low/High in the UI while the ini note says low/med/high. |
| Trees (two-pass, high quality, self-shadowing, sway) | TwoPassTrees, LowQualityTrees, EnableSwayTrees | GPU | Cosmetic. iRacing's beginner guide suggests turning tree options down for performance. |

## Your car

| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Steering wheel / driver arms / hide obstructions | SteeringWheel, DriverHands, HideCockpitObstructions | tiny | Preference. |
| Headlight details | HeadlightLevel | GPU (night) | Irrelevant in the day. Night with a full field and high headlight detail is a known cost. MonochromeHeadlights (ini only) renders all-white headlights with less banding. |

## Mirrors

| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Cockpit mirrors max | MaxCockpitMirrors | CPU + GPU per mirror | Each cockpit mirror is another scene render. The virtual mirror alone is the cheapest way to see behind. |
| Higher detail in mirrors | MirrorDetail | CPU + GPU | Clearer mirror image, modest cost. |
| Virtual mirror / FOV | VirtualMirrors, app.ini virtualMirrorFOV | none | A lower FOV makes cars behind larger. The virtual mirror's render resolution follows the UI scale (2026 S1). |
| Headlights on track in mirrors | HeadlightsInMirrors | GPU | Night only. |
| Draw cars / pits in mirrors | MaxCarsToDrawInMirrors, MaxPitObjsToDrawInMirrors | CPU + GPU | Fewer cars in mirrors is one of the cheapest CPU savings in big fields. |

## Other cars

| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Draw Cars (view) | MaxCarsToDraw | CPU + GPU | Cars beyond the count are **not drawn at all**. Below the user's grid size, part of the field is invisible at the start. Match it to the grid; on a GPU-bound rig the cost is usually small. |
| Draw Pits | MaxPitObjsToDraw | CPU | Pit-lane clutter. |
| Max Cars (transmitted) | app.ini serverTransmitMaxCars | network, CPU | Cars the server sends. Leave at the default unless the user has network trouble. |
| Video Memory Swap High-Res Cars | CacheSwap3HighResCars | VRAM − | Only the nearest few cars keep high-res textures. For VRAM-limited cards; otherwise off. |
| 2048×2048 car textures | CarPaint2048x2048 | VRAM + | Sharper car paint. Off on any card that reads full in captures. |

## Dynamic LOD

| Setting | ini key | Cost | What it does, when to use it |
|---|---|---|---|
| Dynamic LOD frame-rate threshold | LODMinFPSTarget | trades detail for fps below it | iRacing designed it as **the minimum frame rate the user will accept**: when fps drops below it, the sim lowers model detail (cars, crew, objects, track surface, walls, fences; polygon LOD only, not shaders or shadows) to protect the frame rate, and raises detail again as fps recovers. It is a **choice, set from the profile**: a driver who puts smoothness first sets it at their floor and lets the sim simplify the scene in a packed start; a driver who puts detail first sets it lower so it rarely acts. It is only **wrong** when it sits above the fps the rig normally runs, so the sim is simplifying the scene all the time; "it looks worse than it should" is the typical report. Detail changes mid-braking-zone bother some competitive drivers; ask. |
| Car / World LOD behaviour | LODPctMin/Max (world), LODPctDynoMin/Max (cars), …Mirrors… variants | | UI presets that write these percentages; they scale the distance used to pick a level of detail. "Only decrease" (minimum at 100%) never raises detail above normal and is the sane default. AutoAddNoDynOnEmptyLOD (2025 S1) allows dropping further under load. |

## Particles

| Setting | ini key | Cost | What it does, when to use it |
|---|---|---|---|
| Particle detail | ParticleDetail | CPU + GPU | Density of spray, dust and smoke. Since 2026 S4, smoke, dust and water puffs use the PopcornFX system that already handled rain and spray; iRacing reports better performance and appearance, with no new options. |
| Full resolution particles | ParticlesFullRes | GPU ++ in rain | Off renders particles at reduced resolution. The largest GPU cost in heavy spray; nearly free in the dry. |
| Particle threads | app.ini maxParticleThreads, particleThreadPriorityAdjust | CPU | Worker threads for particle simulation. Old documentation; relevance since GPU particles became mandatory is uncertain. Leave alone. |

## Shadows and lighting

| Setting | ini key | Cost | What it does, when to use it |
|---|---|---|---|
| Shadow Maps (and cloud shadows) | ShadowMapType | CPU ++, GPU ++, VRAM + | Real shadows from the track, cars and objects; the biggest single realism upgrade in daytime racing and the most expensive, because the extra passes load the render thread too, multiplied by projections on triples. Only when both sides have headroom. |
| Dynamic objects (car shadows), shadow detail | DynamicShadowMaps, ShadowDetail | CPU + GPU | Car shadows; Low when first enabling shadow maps. |
| Objects self-shadowing | AllowTSOSelfShadows | CPU + GPU | Walls and trackside objects shadow themselves and each other. Needs shadow maps. |
| Shadow resolutions and counts | DynamicShadowRes, StaticShadowRes, StaticShadowNumber, DynamicShadowTrim (ini only) | GPU, VRAM | Map sizes behind the UI settings. Undocumented beyond the ini notes; leave alone. |
| Night shadow maps, walls/objects cast shadows, number of lights, filter | DNSMEnable, DNSMWallsCastShadows, DNSMTSOsCastShadows, DNSMNumLights, DNSMFilter, DNSMMaxLightsPerPass, DNSMDownsampleFirst, DNSMShadowFadeTime | GPU ++ at night | Night racing only. Cost grows roughly with the number of shadow-casting lights and the filter level. Downsample-first shades per pixel rather than per MSAA sample: cheaper with MSAA on. |

## Frame rate

| Setting | ini key | Cost | What it does, when to use it |
|---|---|---|---|
| Limit frame rate / max fps | LimitFrameRate, DesiredFPSLimit | none | With NVIDIA G-SYNC + driver vsync + Reflex, Reflex caps just below refresh by itself (about 138 at 144 Hz); a sim cap at or a little below that is fine, above it does nothing. Without Reflex (AMD), cap about 3% below refresh so VRR stays engaged. A cap far above refresh with VRR on is wrong. See `nvidia.md` and `amd.md`. |
| NVIDIA Reflex | NvReflexMode | none | Enabled is right; Enabled + Boost keeps GPU clocks up when the GPU is underused. Reflex helps latency most when GPU-bound. It makes PresentMon's CPU-busy figure track GPU time (see `diagnosis.md`). |
| Max pre-rendered frames | MaxPreRenderedFrames | latency | 1. Greyed out when Reflex is on. |
| Vertical sync (in-game) | VerticalSync | | Off; use the driver's vsync with G-SYNC/FreeSync instead. |
| Reduce frame rate when focus is lost | reduceFramerate_WhenFocusLost (ini only) | | 1 = the sim slows down while another program has keyboard focus. Set 0 if overlays or companion apps take focus during races. |

## Memory and engine internals (ini only; leave alone unless diagnosing)

| ini key | What it does |
|---|---|
| VidMemToUseMB / SysMemToUseMB | Video and system memory budgets. Auto-set; the sim grows into free memory beyond the budget. iRacing suggests lowering the video budget if a VRAM-limited card stutters. Don't hand-edit otherwise. |
| ParallelSorting, OcclusionCull | Multithreaded scene sorting and skipping hidden objects. Both on; they reduce render-thread work. |
| VisibilityFrameDelay | Frames between visibility re-tests. Higher saves CPU but can cause pop-in. |
| CompressTextures*, CompressedVertices | Texture and vertex compression. Keep the defaults (compressed). |
| MipLODBias | Texture sharpness bias: positive is blurrier with less shimmer, negative is sharper with more. |
| WorldNearPlaneDistance, ZBuffer32Bits, ReduceCockpitFlicker | Depth precision and near-clip tweaks for z-fighting and cockpit flicker. |
| LoadTexturesWhenDriving | 0 loads textures only out of the car, avoiding in-car stutter. |
| UIScale, DriveUIFullScreen, SessionUIFullScreen, BezelProtectionPct | Interface scaling and how the UI spreads across triples. No performance effect except that the virtual mirror resolution follows the UI scale. |

## Competitive profile

For drivers who put latency and consistency first (most esports drivers). Present as a starting direction; measure each trade.

- **Protect the lows, not the average.** Judge every batch on the start-window 1% and 0.1% lows and the frame-time spread (`Analyze-PresentMon.ps1 -TargetHz`).
- **Latency chain:** Reflex Enabled (Boost if CPU-bound or capped), VRR + driver vsync with the Reflex cap, or uncapped without VRR if they accept tearing for the lowest latency.
- **Visibility over beauty:** anti-aliasing that keeps distant-car silhouettes readable (MSAA with the resolve filter is the usual pick; measure against SMAA), correct FOV, mirrors readable, sharpening only if edges stay clean.
- **No mid-corner surprises:** Dynamic LOD set so it rarely acts during racing (or at their floor, if they prefer the sim to protect frame rate), no motion blur, depth of field or heat haze.
- **CPU headroom for starts:** fewer cars in mirrors, dynamic cubemaps 0, no shadow maps on CPU-bound rigs, SMP on NVIDIA triples.

## Running alongside the sim

Capture with the user's normal race-day software running, because that is the load that matters. If a result looks poor, one capture with it closed shows the cost.

- **Overlays** (SimHub, Racelab, Kapps and similar): transparent windows over the sim. They use VRAM and compositor time and can knock the sim out of Independent Flip; check the present mode in the capture with them running.
- **Telemetry and coaching apps** (Garage61, Coach Dave Delta, VRS, Crew Chief and similar): usually small CPU cost; disk logging of telemetry files adds I/O. Rarely the limit; check background CPU in `Get-SystemSnapshot.ps1`.
- **Streaming or recording** (OBS, NVIDIA/AMD capture): the hardware encoder costs a little GPU time and VRAM; display capture costs more than game capture. If the user streams races, the baseline must be captured with the stream running.
- **Endurance and night events:** VRAM can creep over hours, and the day-to-night transition changes the limiter (headlights, night shadow maps). If they race these, add a dusk-to-night scenario with a full multi-class field.
- **Large league fields (50-60 cars):** the offline AI grid may not reach the league's size; check Max Cars (transmitted) and Draw Cars; mirror car count is the cheapest CPU saving at a packed start.

## Myths and tweaks: check, don't apply

None of these is a default recommendation. If the user asks, or has already applied one, explain it and measure it; revert if the capture shows nothing.

| Tweak | What to tell the user |
|---|---|
| CPU affinity, Process Lasso, "pin the sim to the V-Cache CCD" | Only relevant on dual-CCD X3D CPUs, where the chipset driver and Game Mode are meant to handle it. Check those are current first; measure before keeping any manual affinity. |
| Process priority High / Realtime | High rarely changes anything measurable; Realtime can starve input, audio and the OS. Don't. |
| Core-parking tools | Only matter on power plans that park cores; set Best performance instead. |
| Hardware-accelerated GPU scheduling (HAGS) | No universal answer for the sim; measure on and off if the user is curious. |
| Game Mode | Leave it on. |
| Disable fullscreen optimisations | Irrelevant when the capture shows Independent Flip in borderless. |
| Timer resolution, HPET, bcdedit tweaks | No reliable benefit; risk of side effects. Don't apply. |
| NVIDIA Ultra low-latency mode on top of Reflex | Redundant; Reflex supersedes it. |
| Driver shader-cache size changes | Only relevant to first-run stutter; leave at driver default. |
| Forum ini lists | Many keys are obsolete or removed (see this file). Change settings through Options; ini-only keys one at a time with a reason. |

## Windows and driver items that interact with the sim

| Item | Where | Effect |
|---|---|---|
| Memory Integrity (HVCI) | Windows Security → Device security → Core isolation | Kernel protection with a CPU cost; matters most when CPU-bound. A security trade-off: present it as the user's choice, never apply it silently. |
| Power mode | Settings → System → Power | Best performance keeps the render thread's core boosted. Small on desktops, larger on laptops. |
| Multi-plane overlay | registry `HKLM\SOFTWARE\Microsoft\Windows\Dwm` OverlayTestMode=5 (see `nvidia.md`) | Disabling can fix colour-tinted flicker on the primary display with some driver/VRR combinations. May not take effect on newer Windows builds; confirm by the symptom and the capture's present mode. |
| Overlays (vendor app, Discord, telemetry dashboards) | each app | VRAM and compositor cost; a full-screen transparent overlay over the sim can also break Independent Flip. |
| Background apps | Task Manager | On modern many-core CPUs they rarely cost fps, but a busy dashboard or browser adds heat and can cause hitches. |

## Sources

iRacing support articles (`https://support.iracing.com/support/solutions/articles/<id>`):
- 31000167510 Understanding Resolution Scaling (2025)
- 31000174324 2025 Season 1 release notes (anti-aliasing redesign, MSAA filter, anisotropic removal, SSAO optimisation)
- 31000177148 2025 Season 4 release notes (settings UI rebuild); 31000177221 2025 S4 Patch 2
- 31000177717 2026 Season 1 release notes (options moved, search added, mirror resolution follows UI scale)
- 31000178217 2026 Season 2, 31000179016 2026 Season 3, 31000179517 2026 Season 4 release notes (PopcornFX smoke)
- 31000172630 2024 Season 2 (SSR, particle resolution); 31000173378 2024 Season 3; 31000173510 2024 S3 Patch 2 (multi-view paths off for particles)
- 31000172032 RAM and VRAM settings; 31000168572 Beginner's guide; 31000171395 Setting up three monitors

Community references used for descriptions only (their fps numbers are not used): simracingcockpit.gg iRacing graphics settings guide; byteinsight.co.uk iRacing graphics optimisation and triple set-up articles; the commented `rendererDX11.ini` and `app.ini` reference pages at edracing.com.

Re-verify against the current season's release notes when the sim changes; iRacing's next-generation renderer is rolling out and will rename or replace many of these keys.
