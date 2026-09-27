# The Random Story

Open-world first-person hack-and-slash RPG for Roblox (reincarnation story, time stop, seeded worlds).

## Layout

- `src/` - every script, in Rojo layout (`*.server.lua` Script, `*.client.lua` LocalScript, `*.lua` ModuleScript).
  - `ReplicatedStorage/Shared` - config, rigs, weapons, enemies, story tables (used by client + server)
  - `ServerScriptService/Server` - world builders, AI, combat, story director and chapters
  - `StarterPlayer/StarterPlayerScripts/Client` - controller, viewmodel, HUD/menus, FX, cutscenes
- `tools/build.py` - packs `src/` into a place file without Rojo or Studio.

## Build

```
python3 tools/build.py            # -> build/TheRandomStory.rbxlx
```

Open the `.rbxlx` in Roblox Studio and press Play. Or use Rojo with `default.project.json`.
