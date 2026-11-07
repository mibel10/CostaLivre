# Performance measurements

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
