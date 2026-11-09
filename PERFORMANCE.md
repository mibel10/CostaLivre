# Performance measurements

## Audit after item 32

The inventory covered all 244 tracked files. Godot loaded 124 game assets, scenes, shaders and scripts, including the test and tool scripts. Generated previews, import identifiers and binary metadata were inventoried separately. The runtime checks exercised 21 test scripts, including the full 25-chapter campaign, the expanded city, touch controls, vehicle handling and multiplayer sessions with an actual host and client. The GPU measurements below used the Windows build of the Godot editor executable. Android controls were simulated in tests.

### Rendering and simulation

- Split six oversized MultiMeshes into 84 m sectors. All 10,671 original transforms were verified against the previous scene. Collision data and other scene content were unchanged.
- Culled furnished rooms by local distance and floor. The separate exterior shells and fixed collisions remain in place. Road stripes and thin facade details no longer cast directional shadows.
- Rebuilt the two-surface distant vehicle mesh from 11,793 to 7,537 triangles. Police switch to the distant model after 14 m. Nearby civilian cars, players and NPCs retain detailed models, with engine LOD available on clothed characters.
- Kept Ultra textures, normal maps and view distance. Ultra now uses a single 512-pixel directional shadow map out to 35 m and has MSAA off by default. MSAA 2× and 4× are still available under custom settings. FXAA is disabled in the menu because the Compatibility renderer does not support it. [Godot shadow settings](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html)
- Avoided sorting the police fleet when dispatch has already filled its quota. The host suspends ordinary traffic physics beyond 180 m of every player and keeps mission vehicles active. Repeated campaign prop updates now run only when the visible state changes.

### Reproduced bugs

- Shortcuts 4 and 5 were equipping the wrong weapon slots.
- The old register marker at the bank entrance still paid out through the generic robbery code. The bank now uses the vault flow.
- A client driving a normal car lost vehicle synchronization above 4 m. The host now uses the same vertical bounds as vehicle recovery, which covers the favela road. It also rejects nonfinite speed and heading and ignores ram reports from a stopped car.
- The clinic and interception prompts could refer to a vehicle after it had been removed. Video settings now fall back safely when a saved value has the wrong type or the display reports no valid size.

### Measured on the user's PC

Godot 4.7.2, Compatibility through ANGLE, Intel HD Graphics Family (0x00000A16), output 1028×720, native 3D resolution, VSync and FPS cap off. Each row used a 4-second warmup and a 6-second live sample. The initial Ultra street profile was 11.1–14.6 FPS, roughly 730 draw calls and 600,000 triangles. The final street sample was 33.6 FPS, 378 calls and about 99,000 triangles.

| Scene | Average FPS | 1% low FPS |
| --- | ---: | ---: |
| Street | 33.6 | 25.2 |
| Driving | 29.9 | 16.9 |
| Bank | 49.6 | 28.4 |
| Pursuit | 33.1 | 18.6 |

These are short samples and varied between runs. They do not establish a 30 FPS minimum. In an intermediate driving profile, native runs at 60 m of shadow distance ranged from 28.4 to 29.6 FPS, Balanced at the same distance reached 18.3 FPS, and native at 35 m reached 30.2 FPS. The final preset uses the shorter shadow distance and leaves upscaling selectable.

```powershell
godot_console.exe --path . --script res://tools/profile_render.gd
godot_console.exe --path . --script res://tools/profile_render.gd -- --balanced
```

## Historical measurements

These measurements predate the latest map expansion and audio/combat additions; they remain a historical baseline, not a new performance guarantee for the expanded map.

Measured locally on Godot 4.7.2, Compatibility renderer, ANGLE / Intel HD Graphics Family (0x00000A16), at the actual window viewport **1028×720**. Debug runs, not exported release builds. Benchmarks run separately from the headless tests.

## Before optimization

`tools/profile_render.gd` measured the initial scene at median **51.64 ms** / p95 **58.13 ms**, with **668 draw calls** and about **365,000 triangles per frame**, including shadows. Temporarily disabling shadows reduced median frame time to 23.90 ms. Hiding vehicles reduced it further to 16.34 ms. This identified shadows and vehicle draw calls as the main costs.

## Changes

- Native distance-based HLOD: detailed vehicles remain near the camera, distant vehicles use a two-surface mesh with shared materials. All physics, missions and AI remain active.
- Shadow distance, antialiasing, normal maps, lighting and visibility depend on the selected graphics preset. Low and Potato disable dynamic shadows.
- Existing geometry batching remains in place.
- HUD redraws are throttled to 20 Hz; panel styles are reused. The pause UI uses native controls and the zoomable map redraws on interaction.
- The original high-detail vehicle source and unused surface maps are no longer loaded on the normal gameplay path.
- Low + 30 FPS is the initial default; changes persist through the native pause menu.

## After optimization

Preset **Baixo**. Warm-up: 45 frames per scene. Samples: 180 frames uncapped, 240 frames capped. Times include real rendering and normal scene updates. All values are from `benchmark_results.json`.

| Scene | Cap | Average FPS | Median ms | p95 ms | p99 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Street | Unlimited | 50.4 | 16.93 | 30.58 | 35.05 |
| Driving | Unlimited | 48.3 | 17.69 | 33.95 | 36.93 |
| Bank interior | Unlimited | 64.7 | 13.48 | 25.73 | 27.91 |
| Five-car police pursuit | Unlimited | 41.1 | 20.64 | 38.09 | 40.08 |
| Police pursuit | 30 | 30.0 | 33.37 | 35.73 | 38.38 |
| Street | 30 | 30.0 | 33.34 | 33.91 | 34.10 |

The capped samples maintained 30 FPS on average with small frame-time variations. These are short local samples, not a guarantee of an absolute 30 FPS minimum everywhere. Higher resolutions and Ultra/High settings can be slower, especially on the integrated GPU. Higher FPS limits are ceilings, not performance targets the game can guarantee.

## Reproduce

```powershell
& 'path/to/Godot_console.exe' --path . --script res://tools/benchmark_game.gd
```

This uses temporary runtime graphics changes without saving user preferences, then writes `benchmark_results.json`. Do not run concurrent rendering applications or tests while measuring. Headless tests validate gameplay and settings, not GPU performance.
