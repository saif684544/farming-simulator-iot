# Development notes

## Environment used
- Windows 10 Pro, NVIDIA GeForce GTX 1660 SUPER, OpenGL 3.3 driver 621.14
- Godot **4.7.2-stable** (official, `Godot_v4.7.2-stable_win64_console.exe`)
- Blender: **not installed**, so every asset is modelled procedurally in GDScript (see below)
- Android SDK + OpenJDK 25 present; no Android device or emulator was attached
- No macOS/Xcode, so iOS can't be built or tested

## Architecture

```
                 ┌──────────────────── autoloads (scripts/managers) ────────────────────┐
 keyboard/mouse  │ PlatformManager  pc/mobile/web detection, UI scale, safe area, app   │
 gamepad ───────►│                  pause/focus events                                  │
 TouchControls ─►│ InputManager     move vector, look delta, actions, mouse capture     │
                 │ GameSettings     persisted settings + Low/Medium/High quality presets│
                 │ AudioManager     procedurally synthesised loops & UI sounds          │
                 │ EnvironmentManager  time of day, ambient light, thermal model        │
                 │ DeviceManager    device registry + fixed 0.1 s simulation tick ──┐   │
                 │ AutomationManager  8 edge-triggered rules, scenarios          ◄──┘   │
                 └───────────────▲─────────────────────────▲─────────────────────────────┘
                                 │ register / signals      │ get_device(id), set_power()
                 ┌───────────────┴──────────┐   ┌───────────┴──────────────┐
                 │ VirtualDevice (base)     │   │ UI (HUD, DevicePanel,    │
                 │  online / power_on       │   │ Dashboard, Automation    │
                 │  state_changed, reading_ │   │ cards) reads devices via │
                 │  updated, connection_... │   │ generic get_readings()/  │
                 │  get_readings/controls   │   │ get_controls()           │
                 └──┬───────────────────────┘   └──────────────────────────┘
       VirtualHub, MoistureSensor, TemperatureSensor, LightSensor,
       SmartPlug, IrrigationPump(+Sprinklers), VentilationFan, SmartLight,
       SmartHVAC, SmartShade, SmartValve, LeakSensor, SmartLock, ContactSensor,
       MotionSensor, SmartFloodlight, SecurityCamera, SmokeDetector, SmartSiren
```

**Simulation loop.** `DeviceManager._process` gathers frame time and runs `step(0.1)` at a
fixed rate: `EnvironmentManager.advance` → each `device.simulate(dt)` → `AutomationManager.evaluate_all()`.
Tests set `auto_simulate = false` and call `step()` themselves, so results are deterministic and
don't depend on frame rate.

**Decoupling.**
- Devices never reference UI.
- The UI only uses the generic device API: `get_status_text`, `get_primary_reading`,
  `get_readings`, `get_controls` and `perform_control`. A new device type appears in the
  device panel and dashboard with no UI changes.
- Devices that depend on each other look each other up by id through `DeviceManager`. For
  example, the pump checks the plug, and the moisture sensor checks the pump and the temperature.

**Physical vs network state.**
- `online` is the network link to the hub.
- `power_on` is the physical switch.
- An offline device still physically runs. Soil keeps drying and a running pump keeps pumping,
  but the device can't be commanded and automations won't trust its readings. That is what the
  "disconnect" feature shows.

**Automations.**
- Each rule computes a zone from its reading (`dry/ok/wet`, `hot/ok/cool`, `dark/ok/bright`) and
  acts only when the zone *changes*. This edge triggering gives hysteresis and lets a manual
  override between thresholds stand. Example: lights switched on at noon stay on.
- Disabling a rule turns off anything it started.
- Rules report a live status: Monitoring, Active, Disabled, Waiting (device offline) or Paused
  (hub offline). They also report the last event and how many times they have fired.

**Game flow.**
- `Main.gd` owns a small UI state machine (PLAY / DEVICE / DASHBOARD / PAUSE / TUTORIAL) that
  decides who gets input.
- PAUSE pauses the `SceneTree`. The UI `CanvasLayer` uses `PROCESS_MODE_ALWAYS` so menus keep
  working while paused.

## Smart-home device extension (climate, water, security, safety)

Eleven devices were added from the most common SmartThings categories: HVAC thermostat, window
shade, water valve, leak sensor, lock, contact sensor, motion sensor, floodlight (switch), camera,
smoke/CO detector and siren. They plug into the same generic API, so the HUD, hub, device panel and
dashboard needed only small, generic additions:

- **Categories.** `VirtualDevice.category`, one of Hub, Climate, Water & irrigation, Lighting,
  Security or Safety. The dashboard's Devices tab groups cards by category.
- **Device-specific wording for the main switch.** `get_power_label()`,
  `get_power_state_text()` and `get_power_action_text()` change only the words. For a lock,
  `power_on` means *locked*; for a valve, *open*; for a shade, *closed*; for a siren, *sounding*.
  Automations and the dashboard keep using `set_power()`.
- **New control kinds** in `DevicePanel`:
  - `choice`: segmented buttons, for example thermostat mode Heat / Cool / Auto.
  - `stepper`: label with − value + buttons, for example setpoints.
- **`is_alert()`.** Paints the status red (leak, smoke, siren). The HUD's Security chip summarises
  alerts. In portrait it only appears when there is something to report.
- **Live camera preview.**
  - `get_preview_texture()` / `set_preview_active()`. The camera's `SubViewport` is
    `UPDATE_DISABLED` until the device panel shows it, so an unwatched camera costs nothing.
  - After dark, the feed switches to a duplicated environment with desaturated, brightened
    "night vision" adjustments.
- **Physical hazards live with the sensor that watches them.**
  - `LeakSensor` owns the burst fitting, spray and puddle.
  - `SmokeDetector` owns the smouldering cable and smoke particles.
  - This keeps the scenarios self-contained and the hazards testable without a scene.
- **Real interaction.** `MotionSensor` checks the player (group `player`) against its range and
  field of view every tick, so walking past the shed at night really switches the floodlight on.
- **Thermal coupling.** `DeviceManager.get_climate_offset()` sums `get_thermal_offset()` from the
  HVAC (+10 °C heating / −7 °C cooling) and the shade (up to −2.5 °C in full sun).
  `TemperatureSensor` adds it to its target. The HVAC's built-in thermostat reads the greenhouse
  air directly, so it keeps regulating while it is offline, as a real thermostat would.
- **Water coupling.** `IrrigationPump.is_running()` also requires `DeviceManager.is_water_valve_open()`.
  If the valve is closed, the irrigation rule reports *Waiting - main water valve closed*.
- **New rules.** `AutomationManager` keeps the same edge-triggered zone pattern, plus two additions:
  - `evaluate_all(dt)` now receives the tick, for the floodlight's 30 s hold timer.
  - The hub-offline check runs before the missing-device check, so an outage pauses every rule.
- **Defaults chosen so the rules don't fight.**
  - The HVAC starts in Auto with a cooling setpoint of 33 °C, above the fans' 32 °C. Ventilation
    stays the first line of cooling, and natural midday heat still triggers the fans.
  - Disabling *Night Lockdown* never unlocks a door.
  - Disabling *Leak Protection* reopens the valve.

## Rendering and performance decisions
- **Compatibility renderer everywhere.** The brief prefers Forward+ on PC, but the cross-platform
  section asks for one shared configuration that works on WebGL 2 and low-end mobile.
  Compatibility is the only renderer that covers Web, so it is the baseline. The PC look comes from
  the High preset instead: 4096 shadow map, MSAA 4x, glow, full grass and particle density.
- Features **not** available in Compatibility, and therefore not used: SSAO, SSR, SDFGI/VoxelGI,
  volumetric fog and contact shadows. Depth is provided instead by filmic tonemapping, glow,
  distance fog, sky-based ambient and reflections, shadowed sunlight and emissive lights.
- **Sky.** A custom `sky.gdshader` draws a gradient sky, a sun/moon disc and twinkling stars, driven by
  `DayNightController`. Sky uniforms are throttled (updated every 0.05 in-game hours), so radiance
  is not rebuilt every frame on mobile and web.
- **Draw calls.**
  - Grass (≈14 000 clumps), flowers, crops, trees and fence posts are MultiMeshes.
  - Crops and trees are merged multi-surface `ArrayMesh`es built by `ProcMesh.merge`.
  - Materials are shared through the cached `Mats` library.
  - Quality presets scale `visible_instance_count`, so detail drops without rebuilding anything.
- **Lighting.**
  - There is one directional light (sun by day, moon by night).
  - Greenhouse grow lights use 4 / 2 / 0 shadowless OmniLights by preset. Their emissive panels
    always glow, so Low still reads correctly.
  - Lamp-post OmniLights are High only. Otherwise the lamps are emissive.
- **Transparency.** The greenhouse glass is built from only 10 large panels (walls, gables, two roof
  planes), keeping transparent draw calls and overdraw low.
- **Particles.** `CPUParticles3D` is used, since it works on every renderer and on Web. Particle
  counts scale with the preset (100 % / 60 % / 35 %).
- **Device draw calls.** After `_build_model()`, `ProcMesh.bake_static()` merges each device's
  static primitive parts into one mesh per material (shadow and no-shadow kept separate). Parts held
  in script variables (animated or resized pieces) are found through the property list and left
  alone. Materials stay shared, so LEDs and glows still change colour after baking.
- **Exports exclude `docs/` and `build/`** (and both contain a `.gdignore`). Otherwise the
  "all resources" export would pack the documentation screenshots, which grew the web `.pck` from
  0.3 MB to 8.8 MB until this was fixed.
- **Per-frame work.**
  - Devices only enable `_process` while animating (fan spin-up/down, pump flow, light fade).
  - Player interaction detection runs every 0.1 s.
  - The HUD and dashboard refresh 4x per second.
- **Collisions.** Collision shapes are boxes and cylinders. The walkable ground is a single
  `WorldBoundaryShape3D`.
- **Measured on the dev PC** (GTX 1660 SUPER, 1920x1080): a steady 60 FPS with vsync in every
  tested view on High. Uncapped from the spawn view: Low ≈ 215 FPS, Medium ≈ 165 FPS,
  High ≈ 165 FPS. See `TEST_REPORT.md`.

## Responsive UI
- The project uses `canvas_items` stretch. `PlatformManager` sets `content_scale_factor` so the UI
  scales with the window's **short side**: a 720 px reference on PC, 500 px on touch devices for
  larger tap targets.
- All UI is built from containers and anchors, with no hard-coded screen coordinates:
  - `HFlowContainer` wraps HUD chips and dashboard cards.
  - The device panel is a right-side sheet in landscape and a bottom sheet in portrait or narrow
    windows.
  - The interaction prompt is width-limited, with an ellipsis.
- Safe-area margins come from `DisplayServer.get_display_safe_area()` on native mobile.
- Touch targets are at least 52 logical px (≈ 40–45 CSS px on a 390-px-wide phone).
- `TouchControls` tracks each finger by touch index, so the joystick, look-drag and buttons work at
  the same time.

## Asset strategy
- Blender wasn't available and no external assets were used, so everything is built in code:
  - `ProcMesh` helpers place primitives and merge them into multi-material meshes.
  - `Mats` builds PBR `StandardMaterial3D`s with world-triplanar `NoiseTexture2D` detail
    (wood, soil, gravel, concrete, bark, rock, foliage).
  - Five custom shaders: terrain, grass with wind, sky, pipe water flow and animated monitor screens.
- The style is a clean "stylised low-poly product demo".
- `AudioManager` synthesises the ambient wind and birds, water, pump hum, fan whoosh and UI
  clicks/beeps as `AudioStreamWAV` at startup. There are no audio files, which keeps the web
  download small.

## Known limitations
- **Visual fidelity.** The procedural low-poly models are coherent but not photoreal. There are no
  sculpted or textured hero assets, because Blender and an asset library weren't available. The
  Compatibility renderer also rules out SSAO, SSR and GI.
- **Baked lighting** is not used. The day/night cycle moves the sun continuously, which makes
  lightmaps unsuitable. The real-time light budget is kept small instead.
- **Character.** The farmer is a primitive-based figure with procedural walk animation
  (legs and arms swing). There is no skeletal rig or blend tree.
- **Mobile.** Touch controls, scaling, the portrait/landscape layouts and pause/resume handling were
  tested only through desktop emulation (`--touch`, phone resolutions). No physical Android or iOS
  device was available. See `PLATFORM_TEST_REPORT.md`.
- **Audio** is basic synthesised sound (including the siren and smoke-alarm beeps), not recorded foley.
- **Smart-home simulation scope.**
  - The motion sensor only detects the player. Scenarios simulate intruders.
  - The shed interior is not modelled: the open door shows a dark opening.
  - The camera feed is 480x270 and renders a second view only while its panel is open. That is an
    extra full scene render, which may be noticeable on low-end mobile.
- **Browser focus.** On the web, the first `Esc` press releases pointer lock (browser behaviour).
  The game then shows a "click the view" hint. Losing focus opens the pause menu.
- **Timing.** The GUI autotest waits on simulation and physics time, so its results don't depend on
  frame rate. Its screenshots cause ~130–150 ms readback hitches, which are a test artefact.

## Adding a new device (example)
1. Create `scripts/devices/MyDevice.gd` with `extends VirtualDevice` and `class_name MyDevice`.
   Override `_build_model`, `simulate`, `get_primary_reading`, `get_readings`, plus
   `is_controllable` / `_on_power_changed` if it can be switched.
2. Create `scenes/Devices/MyDevice.tscn` (a Node3D with the script and a unique `device_id`) and
   place it in `Main.tscn`.
3. It registers itself and appears in the HUD device count, the hub, the device panel and the dashboard.
4. Optionally add a rule in `AutomationManager._create_rules()`.
