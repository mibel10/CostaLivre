# Project instructions

- Treat every gameplay, UI, networking, and content change as a multiplayer change: keep the host authoritative, replicate visible gameplay state, and keep PC/Android crossplay and single-player behavior compatible.
- Check campaign, sandbox, multiplayer and Android controls only in the code the task touches. Do not open other files just to verify.
- Smallest change that fully solves the task. Reuse what exists. No new abstraction, option or dependency.
- Find files through the "Mapa" section below. Do not scan the project or read files the task does not need.
- Mapa = uma linha por pasta + arquivos-chave (scripts .gd, cenas .tscn principais, autoloads, recursos .tres de dados). Sem assets nem arquivos gerados (.import, .uid, .godot/).
- Se o Mapa não cobrir a tarefa: busque por texto com `rg` se existir, senão `git grep -n "termo"` (no Windows não use grep nem findstr), e abra no máximo os arquivos que aparecerem. Para arquivo novo ainda não adicionado ao git, use `git grep -n --untracked "termo"`.
- Antes de criar arquivo, procure um existente que sirva. Edite o existente. Só crie se nenhum servir.
- Ao criar, mover ou apagar arquivo, atualize o Mapa na mesma tarefa.
- Na resposta, liste cada arquivo criado/movido/apagado com 1 linha de motivo.

# Mapa
- Raiz: `main.tscn` (mundo), `project.godot` (configuração, cena inicial e autoloads).
- `assets/`: recursos visuais; `assets/models/vehicle.tscn` (modelos de veículos).
- `scripts/`: `world.gd` (cidade, árvores, veículos, polícia/procurado); `activities.gd` (campanha, missões, economia); `bank.gd` (banco e roubo); `city_life.gd` (pedestres, prédios, elevadores); `player.gd` (movimento e armas); `car.gd` (direção e danos de veículos); `vehicle_catalog.gd` (veículos); `pedestrian.gd` (pedestres); `officer.gd` (polícia); `police_station.gd` (polícia/procurado); `lan_session.gd` (menu multiplayer, salas e conexão; chat); `session_rules.gd` (host, missões coop, economia, polícia/procurado); `internet_access.gd` (internet/UPnP); `remote_player.gd` (jogador remoto); `player_profile.gd` (perfil); `build_version.gd` (protocolo); `game_settings.gd` (gráficos e controles); `pause_menu.gd` (menu e campanha); `pause_map.gd` (mapa); `hud.gd` (objetivos e economia); `touch_controls.gd` (Android); `gameplay_extra.gd` (combate/áudio); `human_visual.gd` (personagem); `visuals.gd` (modelos, veículos e árvores); `interior_design.gd` (prédios); `atmosphere.gd` (céu); `campaign_cutscene.gd` (campanha); `title_backdrop.gd` (tela inicial); `fps_counter.gd` (FPS).
- `shaders/`: `water.gdshader`, `marble.gdshader`, `defeat.gdshader`.
- `tools/`: scripts de bake, benchmark, perfil, inspeção e preview; `bake_far_car.gd`, `bake_visuals.gd`, `benchmark_all_presets.gd`, `benchmark_game.gd`, `profile_render.gd`, `inspect_vehicle.gd`, `playthrough.gd`, `preview_fleet.gd`, `preview_multiplayer.gd`, `preview_profile.gd`, `preview_station.gd`, `fetch_android_templates.py`, `fetch_visual_assets.py`.
- `tests/`: verificações de campanha, banco, cidade, elevadores, sessão, multiplayer, controles Android, veículos e previews; arquivos `.gd` de teste.
- `assets/models/`, `assets/fonts/`, `assets/licenses/`, `assets/sky/`, `assets/textures/`, `assets/ui/`: modelos e recursos visuais por pasta.
- `.build-tools/`, `artifacts/`, `build/`: ferramentas, resultados e builds gerados.
