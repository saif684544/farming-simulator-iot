# Test report

Date: 2026-11-20 (updated after adding the smart-home devices) · Godot 4.7.2-stable (official) · Windows 10 Pro · NVIDIA GeForce GTX 1660 SUPER (OpenGL 3.3, Compatibility renderer)

Everything marked **PASSED** below was actually executed, and the output was captured.

## Summary

| Suite | How it was run | Result |
|---|---|---|
| Project import / script parsing | `godot --headless --path . --editor --quit` | **PASSED**: 0 parse errors, all 36 script classes registered |
| Headless runtime smoke test | `godot --headless --path . --quit-after 400 -- --skip-tutorial` | **PASSED**: no script or runtime errors |
| Automated unit + integration tests (42) | `godot --headless --path . res://tests/TestRunner.tscn` | **PASSED: 42 / 42** (≈ 4.2 s) |
| GUI autotest in the editor runtime (44 checks + screenshots), High and Low | `godot --path . --resolution 1920x1080 -- --autotest --skip-tutorial [--quality=high]` | **PASSED: 44 / 44** (both runs) |
| GUI autotest, **exported Windows build** (final export) | `build/windows/IoTSmartFarm.exe --resolution 1600x900 -- --autotest --quality=high` | **PASSED: 44 / 44** |
| GUI autotest, **exported Web build in Chrome** (final export, served over HTTP) | Chrome + `python -m http.server`, engine args `-- --autotest --skip-tutorial` | **PASSED: 44 / 44** |
| Responsive layout screenshots (HUD, hub / HVAC / camera panels, dashboard tabs, tutorial) | `--autotest --layout` at 1920x1080, 1366x768, 800x600, 390x844, 844x390 | **PASSED** (reviewed by eye) |
| Android APK signature | `apksigner verify build/android/IoTSmartFarm.apk` | **PASSED** |

The 26-check results from the first version (before the smart-home devices) were replaced by
the runs above. All earlier checks are still part of the suites.

**Tests failed:** none in the final run.
**Tests not executed:** physical Android device and iOS (see `PLATFORM_TEST_REPORT.md`).
**Blocked by environment:** iOS export (no Apple Team ID / macOS); Android runtime (no device or emulator image).

## 1. Automated tests (tests/)

The project uses a custom lightweight runner (GUT is not installed): `tests/TestRunner.tscn`.
`spawn_all()` builds the 8 core farm devices; `spawn_everything()` adds the 11 smart-home devices.
The latest output is saved to `tests/last_test_results.txt`.

```
== test_devices.gd
  PASS  test_devices_initialize
  PASS  test_connect_and_disconnect
  PASS  test_state_change_emits_signals
  PASS  test_sensor_readings_emit_signal
  PASS  test_sensor_readings_stay_in_valid_ranges
  PASS  test_light_sensor_follows_time_of_day
  PASS  test_pump_needs_plug_power
  PASS  test_moisture_dries_and_rises_with_irrigation
  PASS  test_fan_cools_greenhouse
== test_automation.gd
  PASS  test_moisture_below_30_activates_irrigation
  PASS  test_moisture_reaching_65_deactivates_irrigation
  PASS  test_temperature_above_32_activates_fan
  PASS  test_temperature_exactly_32_does_not_trigger
  PASS  test_temperature_below_28_deactivates_fan
  PASS  test_low_ambient_light_activates_lighting
  PASS  test_disabled_rule_does_not_act_and_releases_devices
  PASS  test_offline_sensor_pauses_rule
  PASS  test_hub_offline_pauses_all_rules
  PASS  test_manual_override_between_thresholds_is_respected
  PASS  test_scenarios_trigger_rules
== test_integration.gd
  PASS  test_hub_recognizes_devices
  PASS  test_device_manager_tracks_status
  PASS  test_automation_controls_real_devices_closed_loop
  PASS  test_ui_reflects_device_state
  PASS  test_manual_controls
  PASS  test_main_scene_loads
== test_smart_devices.gd
  PASS  test_new_devices_initialize
  PASS  test_devices_can_go_offline
  PASS  test_hvac_heats_a_cold_greenhouse
  PASS  test_hvac_modes_and_setpoints
  PASS  test_strong_sun_closes_shade
  PASS  test_irrigation_waits_for_closed_valve
  PASS  test_leak_closes_valve_and_reopens_after_repair
  PASS  test_motion_sensor_field_of_view
  PASS  test_motion_at_night_turns_floodlight_on_then_off
  PASS  test_motion_in_daylight_keeps_floodlight_off
  PASS  test_lock_and_door_rules
  PASS  test_night_lockdown_waits_for_door_to_close
  PASS  test_smoke_alarm_sounds_siren_and_unlocks
  PASS  test_disabling_rules_releases_devices
  PASS  test_dashboard_groups_devices_and_uses_device_wording
  PASS  test_device_panel_renders_choice_stepper_and_camera
RESULT: 42 passed, 0 failed
```

How the required checks are covered:

| Requirement | Test(s) |
|---|---|
| Devices initialise correctly | `test_devices_initialize` |
| Devices connect and disconnect | `test_connect_and_disconnect` |
| State changes emit signals | `test_state_change_emits_signals`, `test_sensor_readings_emit_signal` |
| Sensor readings stay within valid ranges | `test_sensor_readings_stay_in_valid_ranges` (9 000 ticks, saturating and drying out, heat wave) |
| Moisture < 30 % activates irrigation | `test_moisture_below_30_activates_irrigation` |
| Moisture reaching 65 % deactivates irrigation | `test_moisture_reaching_65_deactivates_irrigation` (closed loop: rises gradually, stops at 65–68 %) |
| Temperature > 32 °C activates the fan | `test_temperature_above_32_activates_fan`, `..._exactly_32_does_not_trigger` |
| Temperature < 28 °C deactivates the fan | `test_temperature_below_28_deactivates_fan` (checks the hysteresis band too) |
| Low ambient light activates lighting | `test_low_ambient_light_activates_lighting` |
| Smart hub recognises devices | `test_hub_recognizes_devices` |
| Device manager updates device status | `test_device_manager_tracks_status` |
| Automation manager controls actual devices | `test_automation_controls_real_devices_closed_loop` |
| UI reflects the real device state | `test_ui_reflects_device_state` (dashboard cards, tiles, automation card, device panel button → real plug) |
| Manual controls work | `test_manual_controls` |
| Main scene loads | `test_main_scene_loads` (19 devices, player, terrain, 8 sprinklers, UI) |
| HVAC thermostat heats/cools, modes, setpoints, off/offline behaviour | `test_hvac_heats_a_cold_greenhouse`, `test_hvac_modes_and_setpoints` |
| Shade closes in strong sun, opens below 60 %, reduces solar gain | `test_strong_sun_closes_shade` |
| Leak closes valve + stops pump, reopens only after drying **and** repair | `test_leak_closes_valve_and_reopens_after_repair`, `test_irrigation_waits_for_closed_valve` |
| Motion sensor range / field of view; floodlight at night only, 30 s hold; camera records | `test_motion_sensor_field_of_view`, `test_motion_at_night_turns_floodlight_on_then_off`, `test_motion_in_daylight_keeps_floodlight_off` |
| Lock/door physics, contact sensor, night lockdown waits for closed door | `test_lock_and_door_rules`, `test_night_lockdown_waits_for_door_to_close` |
| Smoke alarm → siren + unlock, auto-clear | `test_smoke_alarm_sounds_siren_and_unlocks` |
| Disabling rules releases devices; offline devices refuse commands | `test_disabling_rules_releases_devices`, `test_devices_can_go_offline` |
| UI: category grouping, device wording, choice/stepper controls, live camera feed on/off | `test_dashboard_groups_devices_and_uses_device_wording`, `test_device_panel_renders_choice_stepper_and_camera` |

## 2. GUI autotest (scripts/AutoTest.gd)

This test drives the real game through `InputManager`, the same code path as the keyboard, gamepad
and touch controls. Final run at 1920x1080, High preset (44 checks, all PASS):

| Check | Result |
|---|---|
| Main scene loads, 8 devices registered | PASS |
| Player movement (1.2 s forward input) | PASS: 4.85 m |
| Camera rotation from look input | PASS |
| Sprint | PASS: 5.7 m in 0.8 s |
| Interaction target detected (hub) | PASS |
| Device panel opens / closes via the interact action | PASS / PASS |
| Irrigation scenario starts plug + pump | PASS |
| All sprinklers emitting | PASS: 8/8 |
| Pipe water-flow animation | PASS: flow = 1.0 |
| Moisture rises while irrigating | PASS |
| Irrigation stops at 65 % | PASS |
| Heat wave turns the fans on, blades spin up | PASS / PASS: speed 1.0 |
| Fans off below 28 °C | PASS |
| Dusk turns grow lights on / daylight turns them off | PASS / PASS |
| Offline sensor pauses the automation | PASS: "Waiting - Soil Moisture Sensor offline" |
| Dashboard opens / reflects device state / closes | PASS / PASS / PASS |
| HVAC heats a cold greenhouse / idles at temperature | PASS: "AUTO - heating to 18 °C" / PASS |
| Strong sun closes the shade / fully closed | PASS / PASS: 100 % |
| Burst fitting sprays / leak detected / main valve closed / reopens after repair | PASS / PASS / PASS / PASS |
| Floodlight off before motion | PASS |
| **Motion sensor detects the player walking** (real movement through `InputManager`) | PASS: "Person (you)" |
| Motion after dark turns the floodlight on / camera records | PASS / PASS |
| Night lockdown waits for the open door / locks when the door closes | PASS: "Waiting - shed door open" / PASS |
| Smoke detector alarms / siren sounds / shed unlocked / siren off when clear | PASS / PASS / PASS / PASS |
| Pause menu pauses the tree / resume | PASS / PASS |
| Low / Medium / High presets apply | PASS |

Screenshots of the tour are in `docs/screenshots/` (new: `14_hvac_heating`, `15_shade_closed`,
`16_leak_spray`, `18_night_floodlight`, `19_camera_feed`, `20_shed_door_open`, `21_smoke_alarm`,
`dashboard_devices_by_category`, `phone_portrait_hvac_panel`). I also reviewed them by eye: the irrigation
pump with glowing pipe flow, the sprinkler spray, the spinning greenhouse fans, the dusk grow
lights, the night sky with stars, and the dashboard tabs.

## 3. Performance (measured, dev PC, 1920x1080)

| Preset | Spawn view, vsync off (editor runtime, 3 runs) | Spawn view, vsync off (exported .exe at 1600x900, 2 runs) |
|---|---|---|
| Low | 181 – 217 FPS | 153 – 203 FPS |
| Medium | 142 – 163 FPS | 137 – 160 FPS |
| High | 148 – 163 FPS | 129 – 157 FPS |

Uncapped numbers on this PC vary by up to ±20 % between identical runs (GPU clocks, background
apps). The first version measured Low/Medium/High ≈ 215/165/165 (editor) and ≈ 275/216/214 (exe).
To isolate the cost of the 11 new devices, an A/B run hid and then freed them in the same session
on Low. The difference was within run-to-run noise (≈ 200–231 FPS either way). Device meshes are
baked to cut draw calls (see `DEVELOPMENT_NOTES.md`).

With vsync on, every probed view held **60 FPS** on High: spawn, pump + sprinklers, greenhouse
while irrigating, greenhouse with fans, night with grow lights, and **night at the shed with the
floodlight on**. In Chrome the probed views ran at 55–56 FPS on the default Medium preset. The only >100 ms frames
were caused by the test's own screenshot readbacks.

## 4. Bugs found by testing and fixed
1. **UI collapsed to a narrow column.** `set_anchors_preset()` doesn't reset offsets. Fixed by
   switching to `set_anchors_and_offsets_preset()` on all full-screen UI roots.
2. **Device panel crash: "Attempted to free a locked object".** Pressing a control rebuilt
   (freed) the pressed button during its own signal. The rebuild is now deferred. Found by
   `test_ui_reflects_device_state`.
3. **Grass blades rendered black on their back faces.** Double-sided normals were flipped
   downward. The shader now uses an up-facing normal for both faces.
4. **Camera clipped through the control-station roof.** Added roof collision for the spring arm.
5. **Device labels filled the screen when the camera was close.** Added a near visibility range.
6. **Portrait phone layout.** The long interaction prompt widened the HUD past the screen edge
   and overlapped the Sprint button. The prompt width is now bounded (with an ellipsis) and
   portrait gets extra bottom margin.
7. **800x600.** The device panel overlapped the wrapped HUD buttons. The panel top now adapts.
8. **"Jump to dusk" landed after nightfall (19:12).** It now jumps to real twilight (17:36).
9. **Test timing.** The first 1080p runs had two wall-clock-dependent checks fail. The checks now
   wait on physics/simulation time, so they are frame-rate independent.
10. **Dashboard device cards were rebuilt on every refresh** after grouping by category (card order
    no longer matched the registry order), so a held reference pointed at a freed button. Found by
    `test_ui_reflects_device_state`. Fixed by remembering the card id list.
11. **"Hub offline pauses all rules"** failed for rules whose devices were absent. The hub check now
    runs first.
12. **Web export bloat.** The "all resources" export packed the PNG screenshots in `docs/`, which
    grew `index.pck` to 8.8 MB. `docs/` and `build/` are now excluded and `.gdignore`d, bringing it
    back to 0.31 MB.
13. **Visual issues caught in screenshots:**
    - Smoke particles rendered as hard squares; they now use a radial soft texture.
    - The opaque shade cast a full shadow that turned the greenhouse blue; it is now translucent.
    - Night vision was blown out.
    - Device labels overlapped or were clipped by the shed eaves.
    - The security chip crowded portrait phones; it now shows there only during alerts.

## 5. Not tested / limitations
- No human play-test with a real mouse, keyboard or touchscreen. Input was driven through
  `InputManager`, which is the same path the devices use, but raw OS mouse capture and pointer
  lock were not exercised automatically.
- Audio was generated and played, but nobody listened to it during automated runs (including the
  new siren and smoke-alarm sounds).
- Web testing note: Chrome stops rendering a window that is fully covered by other windows, which
  froze one automated run mid-way. The passing run used
  `--disable-backgrounding-occluded-windows`. This is browser behaviour, not a game fault.
- Mobile hardware: see `PLATFORM_TEST_REPORT.md`.
