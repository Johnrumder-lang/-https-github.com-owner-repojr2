# Headless tests

The game can't run outside Roblox, so these tests execute the pure-logic and
world-building code in the standalone Luau interpreter against stubs.

    python3 tools/test/run.py tools/test/<test>.luau [path/to/luau]

| test | what it runs |
| --- | --- |
| `beasts_test.luau` | random trait bestiary: body plans, stats |
| `ground_test.luau` | countryside plan, height function ranges, the part-built ground (part count) |
| `capital_test.luau` | the whole v4 capital build (city, castle, countryside, villages) + interiors |
| `prologue_test.luau` | the modern-city prologue build |
| `worlds_test.luau` | every Abyss theme, the five Abyss layers (guardian arenas), lands 2-5, the PvP arena |
| `mount_test.luau` | the saddled horse and the summon / ride / dismount flow on a fake character |

Header lines in a test pick extra stubs and server modules:
`--@stubs world_stubs` (fake Instance / Terrain / services) and
`--@server A, B, C` (bundles `ServerScriptService/Server/A.lua` ...). Geometry
in the stubs ignores rotation: these are smoke tests for errors and refs, not a
renderer.
