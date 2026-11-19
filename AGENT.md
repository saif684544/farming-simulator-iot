# Multi-Platform Requirements: PC, Mobile and Web

The IoT Smart Farm Simulator must be developed as a cross-platform Godot 4.x game.

## Target Platforms

1. PC — Windows, with Linux/macOS compatibility where practical.
2. Mobile — Android and iOS.
3. Web — Modern desktop and mobile browsers using WebAssembly/WebGL export.

Use a single shared Godot project and codebase. Avoid maintaining separate game implementations.

## 1. Platform-Aware Controls

### PC

- WASD movement.
- Mouse camera control.
- E to interact.
- TAB to open the dashboard.
- ESC to pause or close panels.
- Mouse interaction with UI.

### Mobile

- On-screen virtual joystick.
- Touch-based camera rotation.
- Dedicated interaction button.
- Touch-friendly dashboard controls.
- Responsive UI for portrait and landscape layouts.

Prefer landscape orientation for the primary gameplay experience.

### Web

- Keyboard and mouse controls.
- Touch controls when accessed from mobile browsers.
- Browser-friendly UI scaling.
- Handle browser focus and input correctly.
- Provide a visible loading screen during initialization.

Create a centralized InputManager or equivalent abstraction so gameplay code does not depend directly on a particular input device.

## 2. Responsive UI

All interfaces must adapt to:

- Desktop resolutions.
- Tablet resolutions.
- Mobile phone resolutions.
- Browser viewport resizing.

Requirements:

- Use Godot Control containers and anchors.
- Avoid hardcoded screen coordinates.
- Use appropriate scaling and minimum sizes.
- Make buttons large enough for touch interaction.
- Keep the HUD readable on small screens.
- Ensure the dashboard works on both touch and mouse input.

Test at representative resolutions:

- 1920x1080.
- 1366x768.
- 1280x720.
- 800x600.
- 390x844.
- 844x390.

## 3. Rendering and Performance Strategy

Use a rendering configuration compatible with the intended export targets.

Do not assume desktop Forward+ rendering will work efficiently or reliably across all target platforms.

Evaluate Godot's Compatibility renderer as the baseline for Web and broader hardware support. Use a shared renderer configuration unless a separate configuration is demonstrably necessary.

Optimize the environment for lower-powered mobile devices and browsers.

### Performance requirements

- Reduce unnecessary real-time lights.
- Limit shadow-casting lights.
- Use baked lighting where practical.
- Use efficient materials.
- Limit transparent objects.
- Reduce particle counts on mobile.
- Use LOD or simplified meshes where beneficial.
- Avoid expensive shader effects.
- Limit unnecessary physics calculations.
- Optimize draw calls and scene complexity.
- Avoid excessive high-resolution textures.
- Provide quality settings.

### Quality presets

Implement three graphics presets:

**High**

- Higher shadow quality.
- More detailed effects.
- Higher texture quality.
- Increased environmental detail.

**Medium**

- Moderate shadow quality.
- Balanced effects.
- Reduced environmental complexity.

**Low**

- Minimal real-time shadows.
- Reduced particles.
- Simplified effects.
- Lower rendering resolution where appropriate.

Select sensible defaults for each platform, but allow users to change settings.

## 4. Platform-Specific Features

### PC

- High-quality graphical preset by default.
- Full mouse and keyboard controls.
- Configurable resolution where practical.

### Mobile

- Performance-oriented default settings.
- Touch controls.
- UI safe-area considerations.
- Handle application pause and resume.
- Handle orientation changes.
- Avoid excessive memory usage.

### Web

- Optimize initial download size.
- Avoid unnecessary external dependencies.
- Display loading progress.
- Handle browser resize and focus changes.
- Avoid relying on unsupported browser APIs.
- Test mouse, keyboard, and touch interactions.
- Document browser and hosting requirements.

Web exports must be tested using an HTTP server rather than assuming the exported HTML file will work when opened directly from the filesystem.

## 5. Export Configuration

Prepare export presets for:

- Windows Desktop.
- Android.
- iOS, if the required macOS/Xcode environment is available.
- Web.

Do not claim an export is successful unless it has actually been generated and tested.

For unavailable platform SDKs or export templates:

- Document the missing dependency.
- Provide the required setup instructions.
- Continue testing all platforms that are available.

## 6. Cross-Platform Testing

Test the following on every available target:

- Project launches.
- Main scene loads.
- Player controls work.
- Camera controls work.
- Device interactions work.
- Dashboard opens and closes.
- Automation scenarios work.
- UI scales correctly.
- No platform-specific script errors.
- Performance is acceptable.

Create a PLATFORM_TEST_REPORT.md with a separate section for PC, Android, iOS, and Web.

For each platform, record:

- Export status.
- Launch status.
- Controls tested.
- Automation tests.
- UI/resolution tests.
- Performance observations.
- Known limitations.

Clearly distinguish between:

- Tested successfully.
- Exported but not runtime-tested.
- Not tested due to missing hardware or SDK.
- Unsupported or blocked.

## 7. Cross-Platform Acceptance Criteria

The MVP is complete when:

1. One shared project supports all three target categories.
2. PC controls are functional.
3. Mobile touch controls are functional.
4. Web keyboard and mouse controls are functional.
5. Web touch controls work on supported mobile browsers.
6. The responsive UI works at desktop and mobile resolutions.
7. The three virtual IoT automation scenarios behave consistently.
8. Rendering quality is appropriate for each platform.
9. Platform export presets are configured.
10. Actual test results and limitations are documented.

Do not sacrifice the quality of the 3D showcase unnecessarily. Instead, create scalable visual quality settings while preserving the same gameplay experience across platforms.

# 1. Core Project Requirements

**Game name:** IoT Smart Farm Simulator
**Engine:** Godot 4.x
**Language:** GDScript
**Game type:** 3D simulation / interactive showcase
**Target platform:** PC
**Primary objective:** Showcase 3D development capabilities.

## Critical clarification: Virtual IoT only

All IoT devices must be simulated entirely inside the game.

- No physical ESP32 or Arduino.
- No real sensors.
- No MQTT.
- No physical irrigation controllers.
- No external SmartThings API integration.
- No actual SmartThings account connection.
- No internet dependency for gameplay.

Create a self-contained virtual IoT ecosystem inspired by Samsung SmartThings.

Use SmartThings-inspired device concepts and visual design, but do not falsely represent the game as an officially licensed Samsung product.

---

# 2. Development Philosophy

Follow these priorities in order:

1. High-quality 3D environment.
2. Excellent lighting, materials, shadows, and visual effects.
3. Interactive 3D devices.
4. Functional virtual IoT simulation.
5. Attractive and intuitive user interface.
6. Stable performance and reliable gameplay.

Avoid unnecessary complexity.

Do not implement multiplayer, large-scale economies, complicated inventory systems, advanced crop simulation, or procedural world generation.

Make sensible design decisions without repeatedly asking for approval.

If a requirement is ambiguous, choose the simplest solution that delivers a polished result.

---

# 3. Game Concept

The player explores a small modern smart farm.

The environment contains:

- Main farm area.
- Modern greenhouse.
- Crop growing area.
- Irrigation system.
- Smart IoT control station.
- Virtual SmartThings-inspired hub.
- Device installation locations.
- Environmental lighting.

The player can walk around, inspect devices, interact with them, and observe how automated systems control the farm.

The experience should feel like a professional interactive 3D product demonstration.

---

# 4. 3D Environment Development

Create a visually impressive, compact 3D environment.

## Farm environment

Implement:

- Detailed terrain.
- Grass and vegetation.
- Farm pathways.
- Crop beds.
- Greenhouse building.
- Water tank.
- Irrigation pipes.
- Small utility building.
- Decorative environmental objects.
- Fences and other environmental details.

## Greenhouse

The greenhouse should be one of the main visual attractions.

Include:

- Glass panels.
- Metallic structural frames.
- Crop growing beds.
- Irrigation pipes.
- Hanging lights.
- Ventilation fans.
- Environmental sensors.
- Water sprinklers.
- Interactive devices.

Use transparent materials carefully to avoid excessive rendering cost.

## 3D visual quality

Prioritize:

- PBR materials.
- Appropriate roughness and metallic values.
- Realistic object proportions.
- Detailed object modeling.
- Contact shadows.
- Ambient occlusion where appropriate.
- Reflection and environment lighting.
- High-quality directional lighting.
- Atmospheric depth.
- Professional camera composition.

Use Godot-compatible rendering features.

Prefer the Forward+ renderer for PC unless project constraints suggest otherwise.

## Day/night system

Implement a simple day/night cycle with:

- Directional light rotation.
- Sky and environment changes.
- Warm daylight.
- Evening transition.
- Night environment.
- Automatic greenhouse lighting activation.

The system should also allow the player to trigger a lighting scenario manually.

---

# 5. Player Controls

Implement a polished third-person character controller.

Required functionality:

- WASD movement.
- Mouse camera control.
- Smooth camera follow.
- Camera collision handling.
- Sprint.
- Gravity.
- Jumping if appropriate.
- Interaction detection.
- Interaction prompt.
- Sensible movement speed.

Use a spring-arm-based camera or an equivalent collision-aware camera system.

Add a clear interaction prompt when the player approaches an interactive device.

Example:

"Press E to interact"

Ensure that the camera and character controls feel responsive.

---

# 6. Virtual IoT Devices

Create the following virtual devices:

## A. Virtual Smart Hub

The central controller of the farm.

Features:

- Device connection status.
- Connected device count.
- Device overview.
- Automation overview.
- Connection/disconnection simulation.

## B. Soil Moisture Sensor

Features:

- Current moisture percentage.
- Live simulated moisture changes.
- Device status.
- Visual indicator.

## C. Temperature Sensor

Features:

- Current temperature.
- Live temperature simulation.
- Device status.
- Visual indicator.

## D. Smart Plug

Features:

- ON/OFF state.
- Connected equipment status.
- Power indicator.
- Controls the irrigation pump or other virtual equipment.

## E. Irrigation Pump

Features:

- ON/OFF state.
- Pump animation.
- Water flow visual effects.
- Sprinkler activation.
- Sound effects if suitable.

## F. Smart Lighting

Features:

- ON/OFF state.
- Emission materials.
- Realistic light activation.
- Nighttime lighting behavior.

All devices must have reusable, modular implementations.

Create a common virtual device base class.

Suggested device architecture:

- VirtualDevice.gd
- VirtualHub.gd
- DeviceManager.gd
- MoistureSensor.gd
- TemperatureSensor.gd
- SmartPlug.gd
- IrrigationPump.gd
- SmartLight.gd

Use signals for device state changes.

Avoid tightly coupling device scripts to UI scripts.

---

# 7. Automation System

Implement a simple but functional rule-based automation engine.

Do not build a complicated visual programming system.

Provide predefined automation scenarios.

## Scenario 1: Smart Irrigation

Rule:

IF soil moisture is below 30%
THEN activate smart plug and irrigation pump.

When moisture reaches 65%:

- Turn off the pump.
- Stop water particle effects.
- Update device status.

The moisture value should increase gradually while irrigation is active.

## Scenario 2: Smart Temperature Control

Rule:

IF temperature exceeds 32°C
THEN activate greenhouse ventilation fan.

When temperature drops below 28°C:

- Deactivate the fan.

Include a visible fan animation.

## Scenario 3: Smart Lighting

Rule:

IF ambient light is below the configured threshold
THEN activate greenhouse lights.

When ambient light becomes sufficient:

- Turn off greenhouse lights.

## Automation UI

Create an attractive automation dashboard showing:

- Automation name.
- Trigger condition.
- Action.
- Enabled/disabled state.
- Current execution status.

Allow the player to enable or disable each automation.

The automations must actually control the 3D objects, not just change text in the UI.

---

# 8. Gameplay Loop

Keep the gameplay simple.

The player should be able to:

1. Explore the farm.
2. Approach a virtual IoT device.
3. Press E to inspect it.
4. View its current status.
5. Toggle devices manually where appropriate.
6. Open the virtual Smart Farm dashboard.
7. Enable or disable automations.
8. Trigger irrigation, temperature, and lighting scenarios.
9. Observe the 3D environment responding to those changes.

Add a small introductory tutorial that explains the controls and the three automation scenarios.

Do not add unnecessary farming progression or complex management systems.

---

# 9. UI / UX Requirements

Create a professional, modern interface inspired by smart-home dashboards.

## Main HUD

Display:

- Farm name.
- Current simulated time.
- Temperature.
- Soil moisture.
- Device connection status.
- Interaction prompts.

## Device interaction panel

When interacting with a device, display:

- Device name.
- Device type.
- Connection status.
- Current sensor readings or device state.
- Available controls.

## Smart Farm Dashboard

Create a dashboard accessible using a keyboard shortcut such as TAB.

Include:

- Device overview.
- Sensor readings.
- Automation cards.
- System status.
- Device ON/OFF controls.

The interface should be clean and visually consistent.

Avoid excessive UI elements that obstruct the 3D environment.

---

# 10. Audio and Visual Effects

Add appropriate effects where feasible.

Visual effects:

- Water spray particles.
- Water flow animation.
- Pump operation animation.
- Fan rotation.
- Light activation.
- Device status LEDs.
- Sensor indicators.
- Subtle interaction highlights.

Audio:

- Ambient outdoor sounds.
- Greenhouse ambience.
- Irrigation water sound.
- Pump sound.
- Device interaction feedback.
- UI interaction sounds.

Audio must be optional and should not block development if suitable assets are unavailable.

---

# 11. Project Architecture

Use a clean and maintainable Godot project structure.

Suggested structure:

res://
├── project.godot
├── scenes/
│ ├── Main.tscn
│ ├── FarmEnvironment.tscn
│ ├── Greenhouse.tscn
│ ├── Player.tscn
│ ├── SmartHub.tscn
│ ├── Devices/
│ │ ├── MoistureSensor.tscn
│ │ ├── TemperatureSensor.tscn
│ │ ├── SmartPlug.tscn
│ │ ├── IrrigationPump.tscn
│ │ └── SmartLight.tscn
│ └── UI/
│ ├── MainHUD.tscn
│ ├── SmartFarmDashboard.tscn
│ ├── DevicePanel.tscn
│ └── AutomationPanel.tscn
├── scripts/
│ ├── managers/
│ │ ├── DeviceManager.gd
│ │ ├── AutomationManager.gd
│ │ └── EnvironmentManager.gd
│ ├── devices/
│ │ ├── VirtualDevice.gd
│ │ ├── VirtualHub.gd
│ │ ├── MoistureSensor.gd
│ │ ├── TemperatureSensor.gd
│ │ ├── SmartPlug.gd
│ │ ├── IrrigationPump.gd
│ │ └── SmartLight.gd
│ ├── player/
│ │ └── PlayerController.gd
│ └── ui/
│ ├── MainHUD.gd
│ ├── DevicePanel.gd
│ └── SmartFarmDashboard.gd
├── assets/
│ ├── models/
│ ├── materials/
│ ├── textures/
│ ├── audio/
│ └── particles/
└── tests/

You may adjust this structure when necessary, but maintain separation between gameplay, devices, automation, environment, and UI.

Use typed GDScript wherever practical.

Use signals and reusable scenes.

Avoid monolithic scripts.

---

# 12. Asset Creation Strategy

Do not leave the entire environment as primitive cubes and spheres.

Create visually attractive assets.

Use this priority:

1. Build the farm environment.
2. Build the greenhouse.
3. Create recognizable IoT device models.
4. Create crops and vegetation.
5. Create irrigation equipment.
6. Improve materials and lighting.
7. Add visual effects.

Use available local assets or procedural modeling where appropriate.

If external assets are needed, use legally usable resources and document their sources and licenses.

If Blender is available, it may be used to create or refine 3D assets.

If no external models are available, use Godot meshes and procedural geometry to construct attractive, coherent objects.

Do not use missing or fictional asset paths.

Do not leave placeholder assets in critical visual areas.

---

# 13. Testing Requirements

Testing is mandatory.

Do not stop after writing scripts.

First inspect the available environment:

- Check the installed Godot version.
- Inspect the current repository.
- Identify available assets.
- Check whether Blender is available.
- Understand existing project files before modifying them.

Then implement the game.

## Automated tests

Create tests for:

### Device tests

- Devices initialize correctly.
- Devices connect and disconnect.
- Device state changes emit signals.
- Sensor readings remain within valid ranges.

### Automation tests

- Moisture below 30% activates irrigation.
- Moisture reaching 65% deactivates irrigation.
- Temperature above 32°C activates the fan.
- Temperature below 28°C deactivates the fan.
- Low ambient light activates greenhouse lighting.

### Integration tests

- Smart hub recognizes devices.
- Device manager updates device status.
- Automation manager controls actual devices.
- UI reflects the real device state.
- Manual controls work correctly.

Use GUT if available, or create a lightweight automated test runner using Godot.

## Runtime testing

Run the project using the Godot executable in headless mode when possible.

Example:

godot --headless --path . --editor --quit

Run the game in headless mode to catch runtime errors where supported.

Example:

godot --headless --path . --quit-after 120

Adjust the commands for the installed executable and project.

Also perform a GUI test if a graphical environment is available.

Check:

- Main scene loads.
- No script parsing errors.
- No missing resources.
- Player movement works.
- Interaction prompts work.
- Devices can be inspected.
- Automation triggers work.
- Irrigation animation works.
- Fan animation works.
- Lighting changes work.
- Dashboard opens and closes.
- No critical runtime errors.

Do not claim a test passed unless you actually ran it.

If graphical testing cannot be performed, explicitly document that limitation.

---

# 14. Performance Requirements

Target a smooth PC experience.

Prioritize:

- Efficient mesh usage.
- Appropriate texture resolutions.
- Reusable materials.
- Limited particle counts.
- Efficient lighting.
- Reasonable shadow quality.
- Visibility optimization where useful.
- Avoiding unnecessary per-frame processing.

Aim for 60 FPS on a reasonable modern PC, but do not sacrifice visual quality unnecessarily.

---

# 15. Development Workflow

Work in these stages.

## Stage 1: Project inspection and planning

- Inspect the repository.
- Check Godot installation.
- Check existing project structure.
- Identify asset availability.
- Create an implementation plan.

## Stage 2: 3D environment

- Build the terrain.
- Build the greenhouse.
- Add vegetation and crops.
- Add irrigation infrastructure.
- Configure lighting and camera composition.

Run the project and verify that the environment loads.

## Stage 3: Player and interactions

- Implement the player controller.
- Implement camera movement.
- Add interaction detection.
- Add device interaction prompts.

Test movement and interactions.

## Stage 4: Virtual IoT ecosystem

- Implement the virtual hub.
- Implement the devices.
- Implement device state management.
- Implement sensor simulation.

Test individual devices.

## Stage 5: Automation

- Implement the three automation scenarios.
- Connect automation rules to actual device behavior.
- Add visual responses.

Test each scenario independently.

## Stage 6: UI

- Implement the HUD.
- Implement the device panel.
- Implement the dashboard.
- Connect the UI to actual simulation state.

Test UI interactions.

## Stage 7: Polish

- Improve materials.
- Improve lighting.
- Add particle effects.
- Add animations.
- Add sound.
- Optimize performance.

## Stage 8: Final QA

- Run automated tests.
- Run the game.
- Fix all critical errors.
- Verify the main gameplay loop.
- Document any remaining limitations.

---

# 16. Definition of Done

The MVP is complete only when:

- The project opens successfully in Godot 4.x.
- The main 3D farm environment is present.
- The greenhouse is visually complete enough for a showcase.
- The player can explore the environment.
- The player can interact with IoT devices.
- The virtual hub recognizes the devices.
- The moisture sensor simulation works.
- The temperature sensor simulation works.
- The irrigation automation works.
- The ventilation automation works.
- The lighting automation works.
- The 3D objects respond to automation.
- The dashboard displays actual simulation data.
- No critical script errors remain.
- Automated tests are executed and their results documented.

---

# 17. Final Deliverables

Provide:

1. Complete Godot project.
2. All required GDScript files.
3. All required scenes.
4. 3D assets and materials.
5. UI implementation.
6. Automation system.
7. Automated tests.
8. README.md with setup and run instructions.
9. TEST_REPORT.md with actual test results.
10. DEVELOPMENT_NOTES.md documenting architecture and known limitations.

The README must explain:

- Required Godot version.
- How to open the project.
- How to run the game.
- Controls.
- Available devices.
- Automation scenarios.
- How to run automated tests.

The test report must distinguish between:

- Tests passed.
- Tests failed.
- Tests not executed.
- Tests blocked by environment limitations.

---

# 18. Important Execution Instructions

You are expected to actually develop the game inside the current workspace.

Do not merely provide tutorials, pseudocode, architecture diagrams, or code snippets.

Create and modify the real project files.

Do not stop after creating a basic prototype if additional work is needed to satisfy the MVP requirements.

Do not ask for approval after every stage.

Use your available tools to inspect files, write code, run Godot, execute tests, inspect errors, and fix problems.

When a dependency or asset is unavailable, implement a reasonable alternative and document it.

If a feature cannot be completed, explain exactly what is missing rather than pretending it works.

**Start by inspecting the current workspace and available development tools. Then create an implementation plan and proceed to build the playable MVP.**
