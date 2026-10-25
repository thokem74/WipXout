# Neon Vector Racing

A single-player anti-gravity arcade racer built with Godot 4.7.2 and GDScript.
Race two AI pilots through a neon wireframe city over three laps. The project uses
Godot's **Mobile** renderer on desktop and Android.

The 8.89 km circuit has a 180 m opening straight, repeated flowing S-bends, and
three smooth climbs and descents with 64 m of elevation change. The steepest
grade is approximately 11.6%; near-straight sections stay below 200 m, including
across the lap seam. Ships hover along the road through hills, and the chase
camera follows its slope. Three laps take roughly 5–6 minutes in automated runs.

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
  editing the curve to regenerate its geometry.
- `scripts/racer.gd` implements spline progress, lateral drift, analytical wall
  boundaries, hover, boost, recovery, and AI. `scripts/race_progress.gd` validates
  forward movement and ordered checkpoints before awarding laps.
- `resources/default_tuning.tres` exposes handling, boost, camera, and AI values.
  Mesh strips and emissive shaders provide open wireframe geometry independently
  of desktop wireframe rasterization. Dark road geometry occludes scenery below.
- Original audio is in `assets/audio`; regenerate it with
  `python3 tools/generate_audio.py`. No downloaded assets or plugins are needed.

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
godot --headless --path . --script tests/desktop_input_runner.gd
godot --path . --script tests/visual_runner.gd
```

For isolated test saves on Linux, prefix headless test commands with
`XDG_DATA_HOME=/tmp/neon-vector-tests`. The visual runner needs a display/GPU and
writes screenshots to `/tmp/neon-*.png`, including climbs, descents, crests, dips,
and S-bends in the fixed High/Bloom mode.

Tests cover complete three-lap races and both AI finishes, checkpoint rejection,
wall recovery, boost, persistence, keyboard input, pad edges and all diagonals,
proportional input, independent touch release, cancellation, extra fingers,
mouse interaction, focus loss, and pause/restart resets. Layout checks and rendered
inspection cover 1280×720 and 1600×720. Track checks cover
frame continuity, straight length, elevation, grade, alternating bends, section
clearance, and camera clearance over full normal-speed and boost-speed laps.
A clean simulated race takes **5:04.911**; the AI racers finish in **5:38.715** and
**5:34.619**. These are gameplay timings, not device performance measurements.

Verified on 2026-10-25 with Godot 4.7.2: clean headless import, **564 automated
checks with zero failures**, seven keyboard-input checks, and rendered HUD checks
at both aspect ratios. The 0.1.1 debug APK was built, installed,
and launched on a Samsung SM-A176B (Mali-G68, Vulkan Mobile). Tests cover fixed HDR/MSAA/bloom
configuration and compatibility with older saves containing a Low preference.
Android menu/race screenshots and touch navigation were checked with High/Bloom.
Simultaneous two-finger input is covered by synthetic touch tests; physical comfort
and the complete device interaction checklist below still need hands-on testing.

On a phone, verify upper/lower pad input, both steering directions, combined
cornering/throttle, a separate Boost finger, off-pad dragging, pause/resume, and
app background/foreground. Check cutout margins and rendering performance. Debug
builds print `NVR_METRICS` frame-timing samples during races; short samples do not
establish sustained thermal performance.

## Limitations

One circuit and one ship geometry in three colors; no multiplayer, weapons, or
full vehicle physics. Best times are local. Physical comfort and sustained Android
performance require hands-on testing on the intended phone.
