# Neon Vector Racing

A single-player anti-gravity arcade racer built with Godot 4.7.2 and GDScript.
Race five AI pilots through a neon wireframe city over three laps, using the
Mobile renderer on desktop and Android.

## Arcade circuit

The rebuilt **5.22 km** course concentrates the action into four sectors, each
with a long jump runway and linked sharp tunnel bends. The four tunnels have
cyan, magenta, violet, and orange lighting, repeated neon ribs, and opaque shells.
Their combined 2.2 km length covers **42.2% of the lap**. The final tunnel wraps
across the finish line; enclosure detection and audio also wrap across the seam.

Four smooth hills span **110 metres of elevation** and reach **27% grade**.
Sharp corners have approximately **70 metre radii**. Each of the four marked
ramps has at least **520 metres of gentle, uncovered landing corridor**. A
continuous road remains beneath every jump, including for ships too slow to launch.

Final tuning uses **90 m/s normal speed and 140 m/s boost**, acceleration of
45 m/s², braking of 85 m/s², and stronger 60 m/s² steering. The initial 100 m/s
normal-speed trial produced a 2:43 reference race; 90 m/s brings the final
unboosted reference race to **3:02.561**, within the three-to-four-minute target.
Wall hits retain 85% of speed and remain recoverable. Boost recharges after a
1.2-second cooldown. AI pilots anticipate linked corners and share the player's
jump and contact rules.

At normal and boost speeds, automatic launches reach approximately **22–28 metres**
above the road with **3.2–3.6 seconds of airtime**. Air steering retains 65% of
grounded steering strength. Throttle, braking, and boost work in flight; landings
preserve speed. Flight follows the track corridor rather than free rigid-body physics.

Boost strengthens exhaust, trails, edge streaks, and camera FOV. Separate pooled
particle emitters mark takeoff, heavy landing, and collisions. The camera looks
ahead along the actual road through hills and corners; bounded takeoff and landing
impulses honor the Camera shake setting. Engine load, boost roar, air rush, tunnel
reverb, takeoff whoosh, and layered landing impacts reinforce the action.

## Run and controls

Open `project.godot` in Godot 4.7.x and press **F5**, or run:

```sh
godot --path .
```

Choose **Play** to start the countdown. The bottom-right **240 × 240 touchpad**
provides proportional steering left/right, acceleration above center, and braking
below center. Diagonals combine steering with acceleration or braking. The center
and release coast. Each axis has a 10% dead zone; off-pad dragging clamps to its edge.
One finger owns the pad until release or cancellation. Hold **Boost** at the bottom
left with a second finger. Braking prevents boost; leaving the button releases it.

Desktop controls: **WASD / arrows**, **Space** for boost, **Escape** to pause/resume.
Mouse dragging also operates the pad. Pause, focus loss, restart, menu transitions,
canceled touches, and layout changes clear input. Resume requires fresh input;
held keyboard keys must be released first. Motion sensors are disabled.

The minimap shows the full circuit with colored ship dots and live rank badges
1–6. A white outline identifies the player. Rankings use validated progress, laps,
and finish order. The six pilots are VECTOR, ION, EMBER, VENOM, NOVA, and SOL.

Volume, camera shake, steering sensitivity, and local best times persist in
`user://neon_vector.cfg`. Records carry course ID `arcade_city_v2`; older course
records reset while user settings remain. There are no weapons, stunt scores,
multiplayer, music, or additional driving controls.

## Editing the game

- `scenes/main.tscn` composes the circuit, racers, camera, HUD, audio, and input.
  Race states and results are managed by its script.
- `resources/city_circuit.tres` is the editable closed Curve3D. Road geometry,
  rails, scenery, racer frames, checkpoints, and the minimap share this route.
  `python3 tools/generate_circuit.py` regenerates it offline and overwrites manual
  curve edits. Runtime has no Python dependency.
- `scenes/circuit.tscn` exposes four tunnel and four jump instances. Tunnel start,
  length, and neon color are editable. Jump takeoff distance, launch strength,
  approach length, landing length, and ramp height are editable. Reload the scene
  after route edits to rebuild geometry. Revalidate placement after regenerating.
- `resources/default_tuning.tres` uses the exported defaults from `RaceTuning`.
  Handling, flight, outward drift, camera anticipation/FOV/impulses, and boost
  flame/trail settings can be overridden in this resource through the inspector.
- Ship effects are authored in `scenes/ship_effects.tscn` and reused during racing.
  Each ship has a 40-particle trail, 16-particle collision burst, and separate
  24-particle takeoff and landing bursts. No effect nodes spawn during gameplay.
- Racers use spline progress, lateral steering, analytical rail boundaries, and
  ballistic road-relative flight. Swept ship contacts resolve before committing
  checkpoints and takeoffs. Airborne ships can pass when hull heights separate.
- Engines blend idle/load recordings; VECTOR and ION share the chug profile.
  Rivals use positional audio and distant-playback culling. Tunnel detection also
  changes air rush and shared engine reverb. The Master limiter reserves headroom.

With Python 3 and FFmpeg installed, regenerate licensed source recordings offline:

```sh
python3 tools/generate_audio.py --preview
```

The command validates source hashes, loop seams, unique outputs, and levels. It
writes game audio into `assets/audio` and a stereo preview to
`builds/pod-race-audio-preview.wav`. Retained sources and licenses live under
`tools/audio_sources`; see [CREDITS.md](CREDITS.md).

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

On Linux, prefix tests with `XDG_DATA_HOME=/tmp/neon-vector-tests` to isolate saves.
The visual runner requires a display/GPU and writes `/tmp/neon-*.png` at 1280×720
and 1600×720, covering hills, sharp bends, all tunnel portals/interiors, all four
jumps, and boost/impact feedback. Rendering uses fixed native resolution, 4× MSAA,
HDR, and bloom. Android needs a suitable Vulkan driver.

On 2026-10-28, the main runner passed **635 checks** and the jump runner passed
**155 checks**. Arcade effects passed **47 checks**, contacts passed **28**,
and all seven keyboard checks passed. All six racers complete three laps and take all four jumps each
lap. The unboosted reference player finishes in **3:02.561**, ION in **3:19.567**,
and EMBER in **3:16.993**. Minimum chase-camera road clearance is **5.25 metres**
across normal and boosted laps in all tested lanes. These are simulation results,
not device performance measurements.

The real PulseAudio mixer passed seven checks. Combined engine, boost, takeoff,
landing, finish, and position cues peaked at **0.764 (about −2.3 dBFS)**, below the
−1 dB limiter ceiling. Tests also cover current-course record persistence and old
record migration, contact-blocked launches, long frames, airborne contacts,
checkpoint validation, pause/restart cleanup, keyboard input, and touch capture.

## Android debug export

Install matching Godot 4.7.2 export templates, Android SDK tools, and Java 17.
Configure Android SDK and Java paths in Godot's editor settings. Machine-specific
paths and signing credentials are not committed.

```sh
mkdir -p builds
godot --headless --path . --export-debug Android builds/neon-vector-debug.apk
adb install -r builds/neon-vector-debug.apk
adb shell am start -n org.thokem.neonvectorracing/com.godot.game.GodotAppLauncher
```

The landscape ARM64 preset uses package `org.thokem.neonvectorracing` and version
0.1.1. APKs and signing credentials are ignored by Git. Production signing is
outside this prototype. The rebuilt debug APK was installed and launched on the
connected Android phone (Mali-G68, Vulkan Mobile). Race screenshots and touch
acceleration were checked. Short debug samples measured **37.9–38.7 FPS**, with
worst sampled frames of **31.9–41.9 ms**. These samples do not establish sustained
performance. Physical two-finger comfort and thermal behavior still require
hands-on testing. Synthetic tests cover simultaneous
pad/boost input, cancellation, focus loss, and layout changes.
