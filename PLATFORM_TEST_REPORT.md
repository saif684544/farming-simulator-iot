# Platform test report

Date: 2026-11-20 (re-run after adding 11 smart-home devices and 5 automations) · Godot 4.7.2-stable · official export templates 4.7.2 · one shared project, Compatibility renderer on every target.

| Platform | Status |
|---|---|
| PC (Windows) | **Tested successfully**: exported and runtime-tested |
| Web | **Tested successfully** in desktop Chrome: exported, served over HTTP, runtime-tested. Mobile browsers not tested |
| Android | **Exported but not runtime-tested**: signed debug APK built; no device or emulator available |
| iOS | **Blocked**: requires an Apple Developer Team ID and macOS + Xcode |

---

## PC (Windows 10, GTX 1660 SUPER)

- **Export status:** ✅ `build/windows/IoTSmartFarm.exe` (109 MB single file, PCK embedded; final export 2026-11-20) via
  `--export-release "Windows Desktop"`, with no errors.
- **Launch status:** ✅ The exported exe launches, the loading screen appears, and the main scene loads.
- **Controls tested:**
  - Movement, sprint, camera look, interact, dashboard and pause were driven through
    `InputManager` (autotest), which is the path keyboard, mouse and gamepad events take: ✅
  - Real keyboard/mouse hardware events, including OS mouse capture, were not exercised by a human.
- **Automation tests:** ✅ **44 / 44 autotest checks in the exported exe.** All eight automations
  fired and controlled the 3D objects:
  - pump, sprinklers and pipe flow
  - fan blades and grow lights
  - HVAC heating
  - shade screen
  - leak spray, valve closing and reopening
  - floodlight triggered by real player movement, camera recording
  - night lockdown
  - smoke, siren and unlock
  - Offline-device handling ✅
- **UI/resolution tests:** ✅ 1920x1080, 1600x900, 1366x768, 1280x720 and 800x600. HUD,
  device panel, dashboard (all tabs) and tutorial were checked from screenshots.
- **Performance:**
  - Exported build, vsync off, two runs: Low 153–203, Medium 137–160, High 129–157 FPS.
  - The first version measured 275 / 216 / 214. An A/B test with the new devices hidden or freed
    showed no difference beyond run-to-run noise. See `TEST_REPORT.md`.
  - Vsync on: a steady 60 FPS in every probed view on High.
- **Linux/macOS:** not built or tested (no templates installed for them, and no hardware).
  The code is platform-neutral; the presets would need adding.
- **Known limitations:** On PC the default preset is High. An in-game resolution selector is not
  provided; the window is freely resizable and the UI adapts.

## Web (WebAssembly / WebGL 2)

- **Export status:** ✅ `build/web/` via `--export-release "Web"`. The build is single-threaded,
  so no COOP/COEP headers are needed. Download size: `index.wasm` 39.5 MB (Godot engine),
  `index.pck` **0.31 MB** (all game content, since everything is procedural), `index.js` 0.28 MB.
- **Launch status:** ✅ Served with `python -m http.server` and opened in **Google Chrome
  (desktop, Windows)**:
  - The engine reported `WebGL 2.0 … Compatibility`.
  - The Godot loading bar, then the in-game loading screen ("Building the farm…"), were shown.
  - The main scene loaded.
- **Controls tested:** ✅ Movement, sprint, camera, interaction, dashboard and pause, driven through
  `InputManager` by the autotest inside the browser. Real pointer lock, keyboard focus and touch in
  a browser were not exercised by a human.
- **Automation tests:** ✅ **44 / 44 autotest checks passed in Chrome** on the final export,
  including all eight automations. The camera's `SubViewport` night-vision feed also works under
  WebGL 2 (the autotest opens the camera panel).
- **UI/resolution tests:** ✅ The HUD rendered correctly in a 1280x800 browser window (screenshot
  `docs/screenshots/web_chrome.png`). The adaptive canvas resize policy is enabled.
- **Performance:**
  - 55–56 FPS (browser vsync) in every probed view on the default Medium preset, including the
    night floodlight view.
  - Uncapped numbers aren't meaningful in a browser, because `requestAnimationFrame` is
    vsync-locked. The Low-preset sample (39 FPS) was taken while the preset was being switched
    and is not representative.
- **Known limitations:**
  - Browsers block audio until the first user click or tap. The console warning
    "AudioContext was not allowed to start" is expected before that.
  - After `quit()` at the end of the autotest, the browser logged
    `TypeError: … 'currentTime'` from the engine's audio teardown. This only happens after the
    engine exits.
  - Mobile browsers (Android Chrome, iOS Safari) were **not tested**. Touch controls are
    implemented and were tested via desktop touch emulation.
  - The page must be served over HTTP(S); opening the file directly does not work.
- **Hosting:** any static web server, with no special headers. WebGL 2 is required.

## Android

- **Export status:** ✅ `build/android/IoTSmartFarm.apk` (28.7 MB, re-exported 2026-11-20, arm64-v8a, debug-signed with
  the Godot debug keystore). `apksigner verify` succeeded. The SDK at
  `%LOCALAPPDATA%/Android/Sdk` (build-tools 36/37) and OpenJDK 25 were used. The JDK 25
  "restricted method" warnings from apksigner are harmless.
- **Launch status:** ❌ **Not tested.** `adb devices` listed no devices and no emulator AVD is
  configured.
- **Controls tested (emulated on PC with `--touch`):**
  - Virtual joystick, look-drag, INTERACT/JUMP/SPRINT buttons and multi-touch routing are
    implemented.
  - Layout was verified at 390x844 (portrait) and 844x390 (landscape).
  - Real finger input on a device: **not tested**.
- **Automation tests:** not run on device. They are the same code as PC and Web, where they passed.
- **UI/resolution tests:** emulated phone layouts only.
- **Performance:** unknown on device. Mobile defaults to the **Low** preset: no real-time
  shadows, 75 % render scale, 30 % grass, 35 % particles, no greenhouse OmniLights.
- **Known limitations:** pause/resume and safe-area handling are implemented but unverified
  on hardware. Orientation is set to *sensor landscape*, and the UI also supports portrait.
- **To test:** enable USB debugging on a phone and run
  `adb install build/android/IoTSmartFarm.apk`. Or create an AVD in Android Studio
  (an arm64/x86_64 image with GLES3), then use one-click deploy from the editor.

## iOS

- **Export status:** ⛔ **Blocked.** The Godot export reported:
  `Cannot export project with preset "iOS" … App Store Team ID not specified.`
  Building and running also requires macOS with Xcode, which is not available.
- **Launch / controls / automation / UI / performance:** not tested (blocked).
- **Setup instructions:**
  1. On a Mac with Xcode, install the 4.7.2 templates.
  2. Set `application/app_store_team_id` (and optionally a provisioning profile) in the iOS
     preset. It is set to *export project only*.
  3. Export, open the generated `.xcodeproj`, then build to a device.

  The project needs no iOS-specific code changes: touch controls, safe-area margins and the
  Low default preset already apply to `OS.has_feature("mobile")`.

---

### Cross-platform acceptance checklist

| # | Criterion | Status |
|---|---|---|
| 1 | One shared project supports PC, mobile and web | ✅ one project, one renderer, one codebase |
| 2 | PC controls functional | ✅ via InputManager (exported .exe) |
| 3 | Mobile touch controls functional | ⚠️ implemented and tested with desktop touch emulation only |
| 4 | Web keyboard and mouse functional | ✅ input path tested in Chrome; real pointer lock not tested by a human |
| 5 | Web touch on mobile browsers | ❌ not tested (no mobile browser available) |
| 6 | Responsive UI at desktop and mobile resolutions | ✅ all six required resolutions |
| 7 | All eight automations consistent across platforms | ✅ editor runtime, exported Windows, Web: identical 44/44 |
| 8 | Rendering quality appropriate per platform | ✅ High/Medium/Low presets with platform defaults |
| 9 | Export presets configured | ✅ Windows, Web, Android, iOS (iOS needs a Team ID) |
| 10 | Actual results and limitations documented | ✅ this file and `TEST_REPORT.md` |
