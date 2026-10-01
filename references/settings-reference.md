# iRacing graphics settings: what each one costs and what it buys

Names are as they appear in the sim's Options (build 2.61, 2026). The ini key is in `Documents\iRacing\rendererDX11Monitor.ini` (or the VR renderer file). Costs are relative judgements from measurement and experience, labelled CPU (render thread), GPU (shading/fill) or VRAM. The Driving and Replays columns are independent; tune Driving for racing and leave Replays alone unless the user cares about replays.

Guiding principle: when the capture says CPU-bound, spend on GPU-only items (anti-aliasing, sharpening, sky, particles) for free; when it says GPU-bound, spend on CPU-only items (cars drawn) for free. Nothing is free when balanced.

## Display tab

| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Resolution | windowedWidth/Height | GPU, VRAM | Triples = 3× panel width, e.g. 7680×1440 (11 MP). |
| Resolution Scaling | ResolutionScaling | GPU −, VRAM − | Renders at a percentage and upscales. 90% ≈ −19% pixels ≈ +15% fps when GPU-bound. Softens distant cars; last resort, or rain-only. |
| Full Screen | fullScreen | none | Borderless (Off) is fine when the capture shows Independent Flip. Exclusive fullscreen on triples needs Surround/Eyefinity. |
| Monitor Type / Width / Bezel / Viewing Distance / Radius / Compute | MonitorSetup section | none | Correctness, not fps. See monitor-geometry.md. FOV 179 = clamped = inputs wrong. |
| Render Scene Using 3 Projections | RenderViewPerMonitor | CPU +++ | Required for correct side-screen geometry on triples. Triples the draw submission. |
| Nvidia Simultaneous Multi-Projection | EnableSMPSurround | CPU −−− | NVIDIA only. GPU replicates geometry across the three projections in one pass. Measured −32% CPU time per frame, +45% fps when CPU-bound. Test alone; check seams, shadows, mirror. |

## Graphics tab

### World Detail
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Sky and Clouds | SkyRefreshRate | GPU (small) | Low looks flat; Medium is nearly free. |
| Cars | CarDetail | GPU, VRAM | Model detail of other cars. High adds VRAM; keep Medium on 12 GB cards running triples. |
| Pit Objects / Event / Grandstands / Crowds / Objects / Foliage | *Detail keys | CPU + GPU | Draw calls on the render thread plus shading. Crowds and grandstands are the usual sacrifice; Objects Low removes trackside clutter. |
| Two Pass Trees / High Quality Trees | TwoPassTrees / LowQualityTrees | GPU | Cosmetic. |

### Your Car Detail
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Steering Wheel / Hide Obstructions | SteeringWheel / HideCockpitObstructions | tiny | Preference. |
| Headlight Details | HeadlightLevel | GPU (night) | Disabled/Low for day racing is free. Night with 40 cars and High is a known hit. |

### Mirrors
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Cockpit Mirrors Max | MaxCockpitMirrors | CPU + GPU per mirror | Each cockpit mirror is another scene render. Virtual mirror alone is cheapest. |
| Higher Detail in Mirrors | MirrorDetail | CPU + GPU | Clearer mirror image; modest cost. |
| Virtual Mirror / Virtual Mirror FOV | VirtualMirrors / app.ini virtualMirrorFOV | none | Lower FOV (100 vs 125) makes cars behind larger. Free. |
| Headlights On Track in Mirrors | HeadlightsInMirrors | GPU | Off unless night racing. |

### Other Cars Detail
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Draw Cars (view/mirrors) | MaxCarsToDraw / MaxCarsToDrawInMirrors | CPU + GPU | Cars beyond the count are **not drawn at all**. With 20/8 in a 40-car race, half the field is invisible at the start. Measured cost of 20→40 on a GPU-bound rig: ~3%. Match it to the user's typical grid. |
| Draw Pits | MaxPitObjsToDraw | CPU | Pit-lane clutter. |
| Max Cars | app.ini serverTransmitMaxCars | network/CPU | Cars transmitted from the server; leave at 63 unless the user has network issues. |

### Dynamic LOD
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Dynamic LOD Frame Rate Threshold | LODMinFPSTarget | quality − when below | Below this fps the sim progressively lowers car/world LOD. Set it **below** the user's typical 1% low, not above it. A threshold above the running fps strips detail all lap and the user reports "it looks worse" (worked example: 80 on an 84-fps rig). 60 is a safe default. |
| Car / World LOD Behavior | LODPct* | | "Only Decrease" is the sane choice. |

### Image Quality
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Shader Quality | ShaderQuality | GPU | Max vs High is visible mainly in wet-track and car-paint shading. High is the balance point. |
| HDR | EnableHDR | GPU (small), needs HDR panels | Off unless the panels are HDR and the user wants it. |

### Particles
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Particles details | ParticleDetail | CPU threads + GPU | Spray, dust, smoke density. |
| Full Resolution | ParticlesFullRes | GPU ++ (rain) | The largest GPU cost in heavy spray. Off = particles rendered at reduced resolution. Measured +8% in a 40-car rain start, zero cost in the dry. |

### Shadows and Lighting
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Shadow Maps | ShadowMapType | CPU ++ GPU ++ VRAM + | The biggest visual upgrade in the sim (cars, cockpit and track objects cast real shadows) and the most expensive: extra render passes, so it costs CPU too. Only when both sides have headroom. |
| Dynamic Objects | DynamicShadowMaps + ShadowDetail | CPU + GPU | Car shadows. Low when enabling shadow maps. |
| Night Shadow Maps / Walls / Shadowmap Filter / Number of Lights | DNSM* | GPU (night) | Night racing only. |

### Post-Processing Effects
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Motion Blur | MotionBlur* | GPU | Off for racing. |
| Sharpening | Sharpening (+Amount) | GPU (tiny) | Pairs with SMAA/FXAA to recover crispness. Amplifies aliasing if no AA is on. Some users can't tell; test on/off on the dash. |
| SSAO / Distortion / Heat Haze / Depth of Field | respective keys | GPU | Cosmetic. Off for racing. |

### Other Effects
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Screen Space Reflections | SSRLevel | GPU ++ | Wet-track reflections. Off unless GPU has large headroom. |
| Dynamic / Fixed Cubemaps | Num*Cubemaps | GPU ++ | Car reflections. 0 for racing on constrained GPUs. |

### Anti-Aliasing
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Anti-Aliasing Method | AntiAliasMethod (0 None, 1 MSAA + MSAASamples, 2 FXAA, 3 SMAA) | GPU only | None shimmers badly on fences and distant cars. **SMAA** is the best visibility-per-cost: ~0.5–1 ms at 11 MP. FXAA is cheaper and blurrier. MSAA 2x/4x is far heavier at triple resolution and adds VRAM; only for rigs with large GPU headroom. Zero CPU cost, so free on a CPU-bound rig. |

### Frame Rate
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Limit Frame Rate / Max Frames Per Second | LimitFrameRate / DesiredFPSLimit | none | Set 3–5 below the panel refresh (160 on 165 Hz) so VRR stays engaged and the GPU doesn't burn power on empty-track spikes. |
| NVIDIA Reflex | NvReflexMode | none | Enabled is right. Inflates MsCPUBusy in captures (see diagnosis.md). |
| Max Pre-Rendered Frames | MaxPreRenderedFrames | latency | 1. Greyed out when Reflex is on. |
| Vertical Sync (in-game) | VerticalSync | | Off. Use the driver's vsync with G-SYNC/FreeSync instead. |

### Video Memory
| Setting | ini key | Cost | Notes |
|---|---|---|---|
| Video Memory Swap High-Res Cars | CacheSwap3HighResCars | VRAM | Nearest cars get higher-res textures. |
| 2048x2048 Car Textures | CarPaint2048x2048 | VRAM ++ | Doubles car paint memory. Off on any card that reads full in captures. |
| (not in UI) Video memory budget | VidMemToUseMB | | Auto-set at ~78% of VRAM. The sim grows into free memory beyond it. Don't hand-edit. |

## Windows and driver items that interact with the sim

| Item | Where | Effect |
|---|---|---|
| Memory Integrity (HVCI) | Windows Security → Core isolation | Kernel protection with a CPU cost; matters most when CPU-bound. Security trade-off: present it as the user's choice, never apply silently. |
| Power mode | Settings → System → Power | Best performance keeps the render thread's core boosted. Small. |
| Multi-plane overlay | registry OverlayTestMode=5 | Disabling fixes colour-tinted flicker on the primary display with some driver/VRR combinations. No performance cost. |
| Overlays (vendor app, Discord, Racelab, SimHub) | each app | VRAM and compositor cost; a full-size transparent overlay over the sim can also break Independent Flip. |
| Background apps | Task Manager | On a 20+ thread CPU they rarely matter for fps, but a telemetry dashboard at 0.6 of a core adds heat and can hitch. |
