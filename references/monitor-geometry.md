# Monitor geometry: getting Display → Monitor right

iRacing computes the driving field of view from the physical size and position of the screens. Wrong inputs give a wrong world scale (cars look smaller and closer than they are, braking markers mislead) and kinked lines at the bezels. The frame-rate effect is small; the correctness effect is large. Do this first, before any performance batch, because it changes how much of the world is drawn.

## The fields

| Field | What it is | How to get it |
|---|---|---|
| Monitor Type | 1 or 3 screens, flat or curved | From the user. |
| Monitor Width | Outer width of one screen including the plastic frame | Manufacturer spec sheet "dimensions without stand", width. Do not use the diagonal. |
| Bezel Width | One side, from the outer plastic edge to where the picture starts, including the black inactive border | (Outer width − active width) / 2. Active width for a 16:9 panel = diagonal(in) × 0.8716 × 25.4 mm. Reviews often quote a slightly larger figure; either is fine. |
| Viewing Distance | Eye to the centre of the middle screen, seated in the driving position | Tape measure. Typical 24–32 in (600–800 mm) for 32" triples. **Cannot be looked up.** |
| Radius of Curvature | The panel's curve: 1000R, 1500R, 1800R are mm | Model name or spec sheet. Flat panels ignore it. |
| Compute | Writes drivingCamFOV to app.ini | Press after entering the above. |

## Sanity checks

- The sim stores everything in mm in `[MonitorSetup]`: MonitorWidth, ScreenWidth (active), ViewingDist, RadiusOfCurvature. ViewingDist under 300 mm or over 1500 mm is a typo or a unit mix-up (a common one: "2.05 in" typed where 25 in was meant, stored as 52 mm).
- `drivingCamFOV=179` in app.ini is the clamp. A real computed value for 32" triples at 25–30 in is 150–175°.
- Per-screen horizontal FOV ≈ 2·atan(active width / 2 / viewing distance). Total ≈ 3× that for angled triples, slightly more for curved panels. Use this to tell the user what to expect before they press Compute.
- Side screens must be physically angled so the three form an arc around the eye point. Check: a pit wall or the horizon should run across each bezel without a kink. Bending outward at the seam = angle the side screen in more.

## Looking up the panel

Search "<model> specifications dimensions" and read the manufacturer page or displayspecifications.com. The EDID name reported by Windows can differ from the retail name (a model code or abbreviated name rather than the marketing name). Confirm the model with the user; `scripts/Get-SystemSnapshot.ps1` prints the EDID name and approximate diagonal.

## What the user will notice after the fix

Going from a clamped 179° to a correct value in the 160s on 32" triples: everything about 7–10% larger, slightly less at the extreme edges, a lower sense of speed for a session, braking markers appearing a touch closer. Advise them to drive two or three sessions before judging and not to type a larger number back into the FOV box.

## Single screens and ultrawides

Same fields, Monitor Type 1 Flat/Curved. The computed FOV will be far narrower (40–60°) than most people run; many single-screen users deliberately run a wider FOV than the geometric one for peripheral awareness. Present the computed value as the geometrically correct one and let the user choose; don't insist.
