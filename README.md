# Neon Vector Racing

A single-player anti-gravity arcade racer built with Godot 4.7.2 and GDScript.
Race five AI pilots through a neon wireframe city over three laps. The project uses
Godot's **Mobile** renderer on desktop and Android.

The 9.66 km circuit alternates true straights and tight 95 m-radius corners,
with direct changes in cornering demand. About two thirds is level and one third
is uphill/downhill (measured 66.5% / 33.5%). Four climb/descent pairs have about
10% gradient, 40 m of elevation range, and hard transitions to level road.
Near-straight sections stay below 180 m. Three enclosed neon tunnels are 650,
750, and 700 m long. Two marked ramps launch ships above continuous road, with
broad landing corridors. Magenta curve arrows face approaching racers and stay
steadily illuminated. Six-racer automated races take roughly eight minutes.

The six pilots are **VECTOR** (player, magenta), **ION** (cyan), **EMBER** (orange),
**VENOM** (lime), **NOVA** (violet), and **SOL** (gold). Their colors match their
hulls, exhaust, trails, and minimap markers. AI cruise speeds are 84, 86, 82, 85,
and 87 m/s respectively. Three staggered rows of two form the starting grid.

## Run

Open `project.godot` in the installed stable Godot 4.7.x editor and press **F6**
with `scenes/main.tscn` open, or **F5** to run the project. From this directory:

```sh
godot --path .
```

Choose **Play** to enter the countdown. Restart starts a new race; Resume returns
to the paused race or countdown. No sensor setup or calibration is needed.

## Controls

The fixed **240 × 240 touchpad at the bottom right** uses the finger's position
across its whole surface:

| Position | Action |
| --- | --- |
| Left / right | Proportional steering |
| Above center | Acceleration |
| Below center | Braking |
| Diagonal | Steering plus acceleration or braking |
| Center / released | Neutral steering and coasting |

Each axis has a 10% center dead zone and reaches full input at its edge. The pad
captures one finger until release or cancellation, even when dragged outside its
bounds; outside positions clamp to the edges. Other driving fingers cannot take
it over. A marker shows the captured position.

Hold **Boost at the bottom left** with a second finger while driving. The meter
below it shows available charge. Leaving the Boost button releases it. Braking
prevents boost activation. Charge recovers after a short cooldown.

The two orange **JUMP** ramps launch automatically above 25 m/s. At normal and
boost speed, airtime is roughly 1.9–2.2 seconds and peak height is 7–10 m above
the road. Steering acceleration is halved in flight; throttle, brake, and Boost
continue working. Slow ships roll over safely. Landings preserve speed, and
continuous road remains beneath each jump. Pausing freezes the flight arc.

The fixed overhead **minimap below the lap display** shows the entire course.
Colored dots mark earned track positions; the numbered colored badges show live
race ranks **1–6**, rather than permanent racer IDs. Short leader lines keep the
numbers readable when racers cluster, while dots stay on their real track positions.
A white outline identifies the player. Rankings account for laps and finish order;
the map wraps positions around the course. It does not capture driving touches.

Arcade acceleration and braking are 32 and 65 m/s². Boost recharges at 0.14 per
second after a 1.2-second cooldown; normal and boost limits remain 88 and 116 m/s.
Boost strengthens the exhaust, adds edge streaks, and widens the camera FOV by up
to four extra degrees. Brief colored bursts mark takeoff, landing, and collisions.
New wind, boost-engagement, jump, landing, and position-gain sounds reinforce these
events. Engine/wind reverberation fades in through tunnels. Camera impulses honor
the existing Camera shake setting; pause, menus, restart, and finish clear effects.

Desktop: **WASD or arrow keys** steer, accelerate, and brake; **Space** boosts;
**Escape** pauses/resumes. You can also click and drag the pad with the mouse and
hold Space for boost.

Pause, focus loss, restart, menu transitions, canceled touches, and layout changes
clear captured input. Resuming requires a fresh touch; held keyboard keys must be
released before they can drive again. Motion sensors are disabled.

Settings include sound volume, camera shake, and **Steering
sensitivity**. Sensitivity adjusts the pad's horizontal response. Settings and local
best race/lap times persist in `user://neon_vector.cfg`; the existing sensitivity
save key is retained.

## Architecture

- `scenes/main.tscn` composes the circuit, racers, chase camera, HUD, audio, and
  driving-input controller. `scripts/main.gd` manages race states and results.
- `scripts/driving_input.gd` owns pointer capture, independent pad axes, Boost,
  keyboard input, and reset behavior. Its `Vector3` output is steering, signed
  throttle (negative means brake), and boost. The pad's scene nodes live in
  `scenes/game_ui.tscn`; `scripts/driving_pad.gd` moves its visual marker.
- `resources/city_circuit.tres` is the authored closed Curve3D. Track mesh, grid,
  rails, racer frames, and checkpoints use the same path. Reload the scene after
  editing the curve to regenerate its geometry. `python3 tools/generate_circuit.py`
  rebuilds the authored route from its rounded city-block layout and piecewise linear ten-percent hill
  profile; this overwrites manual Curve3D edits. Runtime uses the saved resource,
  with no Python dependency.
- `scenes/track_tunnel.tscn` contains the reusable opaque shell and neon outline
  mesh nodes. Its three instances under Circuit → Tunnels expose placement in
  metres and length. `scripts/track_tunnel.gd` samples the road frames once on
  scene load, keeping walls and ceilings aligned through bends and slopes.
  Tunnel interiors are 34 m wide with a 13 m ceiling, chamfered shoulders, and
  an opaque floor beneath the road; the existing rails remain the driving boundary.
- `scenes/track_jump.tscn` exposes takeoff distance and launch strength, with
  editor-visible orange markings and a warning label. Its low approach and return
  ramp offset the road, grid, and rails through `Circuit.surface_frame()`; the
  base Curve3D remains the source of race distance. `Racer` adds a ballistic height
  above that road corridor, with shared gravity and air steering settings in the
  tuning resource. Jump crossings are committed after racer contacts constrain
  movement, so a blocked ship cannot launch early. Both AI pilots use the same
  flight behavior and look ahead across upcoming bends before braking.
- The six `PilotProfile` resources in `scenes/main.tscn` own names, colors, and
  cruise speeds. `scripts/race_standings.gd` provides the common ordering for the
  HUD, minimap, and position-gain feedback, using validated unwrapped progress and
  stable roster order for ties. The original two-entry AI tuning vector is removed.
- `scenes/race_minimap.tscn` authors the panel and six rank labels. Its script caches
  a 257-point course outline and projects dots at the HUD's existing 0.08-second
  refresh cadence. The 240 × 210 panel sits 12 logical pixels below the lap display.
- `scenes/ship_effects.tscn` owns two low-poly thrusters, a 24-particle trail and a
  reused 16-particle burst per ship. Effects never spawn nodes during racing.
  `resources/race_feedback.gdshader` draws boost/impact feedback at screen edges;
  the minimap and driving controls draw above it.
- `scripts/racer.gd` implements spline progress, lateral drift, analytical wall
  boundaries, hover, boost, recovery, and AI. `scripts/race_progress.gd` validates
  forward movement and ordered checkpoints before awarding laps.
- Each racer scene contains an editor-visible box hull covering the ship.
  `scripts/racer_contacts.gd` sweeps hulls in track coordinates before movement
  is committed: rear impacts block overtaking through another ship, while side
  impacts separate racers and rebound lateral motion. The Area3D hull is used
  as authored geometry, with engine overlap monitoring disabled; spline movement
  needs its own contact response. Contacts wrap across the lap seam, respect
  rail bounds using the full hull width, and cannot grant checkpoints. Sweeps also
  compare road-relative flight height: separated airborne ships can overtake,
  while overlapping flight paths and landing contacts still resolve. Finished
  ships no longer block racers.
- `resources/default_tuning.tres` exposes handling, boost, camera, and AI values.
  Mesh strips and emissive shaders provide open wireframe geometry independently
  of desktop wireframe rasterization. Dark road geometry occludes scenery below.
- Processed audio is in `assets/audio`. With Python 3 and FFmpeg installed, run
  `python3 tools/generate_audio.py --preview` to rebuild it and create a stereo
  comparison reel at `builds/pod-race-audio-preview.wav`. Retained CC0 recordings,
  source hashes, and licenses are under `tools/audio_sources`; see [CREDITS.md](CREDITS.md).
  Regeneration is offline. VECTOR and ION share the same deep rhythmic chug;
  EMBER retains its turbine whine. Idle/loaded recordings crossfade with throttle;
  speed and load affect RPM, boost adds a roar, and passing rivals change pitch
  in 3D. Countdown, GO, wall impacts, and finish use mechanical racing cues.
  Engines idle during countdown; pause, restart, menus, and exit stop playback.
  The player's engine is non-positional and stays prominent on phone speakers;
  all five rivals retain 3D positioning and fade out between 90 and 120 m, stopping
  distant playback with a small restart hysteresis. Countdown/GO briefly duck the engines,
  and new jump/position signals duck them slightly. The RaceEngines bus provides
  smooth tunnel reverb, and the Master limiter preserves headroom and volume control.

## Visual quality

**High / Bloom** is the fixed rendering mode on desktop and Android: native 3D
resolution, 4× MSAA, building detail, HDR rendering, and restrained bloom. Rendering
defaults live in `project.godot` and the scene environment. There is no quality
selector or saved quality preference; older Low preferences are ignored.
Android devices need a suitable Vulkan driver; the intended renderer is Mobile.

## Android debug export

Install matching Godot 4.7.2 export templates, Android SDK platform-tools and
compatible build tools, and Java 17. Set Android SDK and Java paths in **Editor Settings →
Export → Android** on your machine. Machine-specific paths and signing credentials
are not stored in this repository.

The `Android` preset targets landscape ARM64, the official prebuilt template’s minimum API 24 and target API 36,
package `org.thokem.neonvectorracing`, and version 0.1.1. Build using:

```sh
mkdir -p builds
godot --headless --path . --export-debug Android builds/neon-vector-debug.apk
adb install -r builds/neon-vector-debug.apk
adb shell am start -n org.thokem.neonvectorracing/com.godot.game.GodotAppLauncher
```

Generated APKs, keystores, and export credentials are ignored by Git. Use a local
debug keystore for testing; production signing is outside this prototype.

## Validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_runner.gd
godot --headless --path . --script tests/racer_contacts_runner.gd
godot --headless --path . --script tests/jumps_runner.gd
godot --headless --path . --script tests/arcade_runner.gd
godot --headless --path . --script tests/desktop_input_runner.gd
godot --headless --audio-driver PulseAudio --path . --script tests/audio_output_runner.gd
godot --path . --script tests/visual_runner.gd
```

For isolated test saves on Linux, prefix headless test commands with
`XDG_DATA_HOME=/tmp/neon-vector-tests`. The visual runner needs a display/GPU and
writes screenshots to `/tmp/neon-*.png`, including climbs, descents, crests, dips,
S-bends, every tunnel entrance/interior/exit, and both jumps during approach,
takeoff, flight, and landing at both aspect ratios in the fixed High/Bloom mode.

Tests cover complete three-lap races and all five AI finishes, checkpoint rejection,
wall recovery, boost, persistence, keyboard input, pad edges and all diagonals,
proportional input, independent touch release, cancellation, extra fingers,
mouse interaction, focus loss, and pause/restart resets. Layout checks and rendered
inspection cover 1280×720 and 1600×720. Track checks cover
frame continuity, short straights, sustained slopes, elevation, grade, corner radii,
section clearance, tunnel placement, and camera clearance in the center and both
outer lanes over full normal-speed and boost-speed laps.
On 2026-10-26, the final circuit passed **622 main checks**, **43 arcade checks**,
**28 contact checks**, **85 jump checks**, and **seven keyboard checks**. All six
racers finish three laps and take both jumps on every lap. Rendered inspection
covers both aspect ratios, all six colors, clustered and spread-out map markers,
boost, impact, both jumps, hills, and tunnels using the Mobile renderer. The
unboosted demo player finishes in **8:02.731**; ION and EMBER finish in **7:26.701**
and **7:35.107**. These are gameplay timings, not device performance measurements.

The real PulseAudio mixer runner passed **seven checks**, including six nearby
engines, boost, wind, simultaneous cues, and tunnel entry/exit. Combined peak was
0.583 (about -4.7 dBFS), below the -1 dB limiter ceiling. These samples verify output
and mix headroom, rather than phone-speaker loudness.

The Android debug APK builds successfully. The connected Samsung SM-A176B
(Mali-G68, Vulkan Mobile) disconnected during the baseline comparison, so this
six-racer build still needs installation and device verification. Prior device
measurements apply to earlier builds and do not validate these effects or this layout.
The broader audio/UI validation below was performed
on 2026-10-25 with Godot 4.7.2. Tests cover fixed HDR/MSAA/bloom
configuration and compatibility with older saves containing a Low preference.
Audio checks cover full loop boundaries, the shared VECTOR/ION profile, throttle load,
crossfades, countdown idle, cue separation, boost fades, bounded pass-by pitch,
volume control, and pause/restart/finish cleanup. The generator also checks
source fingerprints, loop seams, output uniqueness, and clipping headroom.
The audio-output runner needs a real audio backend (the command above uses Linux
PulseAudio). It captures actual mixer samples for player idle/load and nearby
rivals, and checks combined racer/boost/cue peak headroom. Playback flags alone
are insufficient to verify audible output.
Jump checks cover low/normal/boost-speed crossings, repeated laps, long frames,
midair braking, half-strength steering, blocked takeoffs, pause/resume, recovery,
restart, finish cleanup, and camera clearance in all lanes through both flight arcs.
Contact checks cover boosted rear impacts at normal and long frame steps, swept
side crossings, rails, clear-lane overtakes, recovery, lap seams, lapped racers,
three-ship overlaps, finish blocking, and restart cleanup.
Android menu/race screenshots and touch navigation were checked with High/Bloom.
Simultaneous two-finger input is covered by synthetic touch tests; physical comfort
and the complete device interaction checklist below still need hands-on testing.

On a phone, verify upper/lower pad input, both steering directions, combined
cornering/throttle, a separate Boost finger, off-pad dragging, pause/resume, and
app background/foreground. Check cutout margins and rendering performance. Debug
builds print `NVR_METRICS` frame-timing and mixed-audio peak samples during races; short samples do not
establish sustained thermal performance.

## Limitations

One circuit and one ship geometry in six colors; no multiplayer, weapons, or
full vehicle physics. Flight stays within the spline corridor, with a ballistic
road-relative height rather than free-flight rigid-body simulation. Best times
are local. Physical comfort and sustained Android performance require hands-on
testing on the intended phone.
