# Costa Livre 1.3.0

- `AGENTS.md` now requires future gameplay/content/UI changes to account for multiplayer, server authority, and PC/Android compatibility.
- Multiplayer protocol is now 3. Clients on 1.2.0 and 1.3.0 cannot join the same room.
- Police now select and track the nearest room player, spawn officers near that target, fire at wanted level 12 in multiplayer, apply health pressure when close, and arrest stopped/on-foot players. Line-of-sight checks run five times per second instead of every physics frame.
- Added three invitation-only co-op operations in the eight-floor commercial tower. Room members can accept or decline a 45-second invitation. Each mission has four stealth/hacking/data/exfiltration steps, a three-round server puzzle, and synchronized cutscenes.
- Added crouch on Z for PC and a movable/resizable Android crouch button. Multiplayer police detection respects crouch at range.
- Destroyed vehicles now burn, smoke, then explode after five seconds. The server applies a nine-meter area damage once; explosion state and sound replicate to clients.
- Added synthesized hacking and explosion cues.

## Validation and performance

- Police line-of-sight raycasts are cached for 0.2 seconds, reducing repeated physics queries.
- The commercial tower floors are batched through the existing room geometry path. Fire effects use small particle counts.
- No FPS benchmark was run, so this release makes no measured frame-rate claim.
- Godot 4.7.2 headless script parsing passed. Windows and Android exports succeeded; the Android package reports version 1.3.0. The game opened on PC and Android; startup logs showed no script errors. No gameplay session or FPS benchmark was run on the phone.
