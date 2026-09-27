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

## Tests

The game can't run outside Roblox, so `tools/test/` runs the logic and every
world builder in the standalone Luau interpreter against stub objects (see
`tools/test/README.md`):

```
python3 tools/test/run.py tools/test/capital_test.luau path/to/luau
```

## v4 at a glance

- **Feel**: lower gravity, longer directional air dashes, dash-stabs through
  enemies, slam, impact frames, motion blur, wider FOV, heavy-kill knockback,
  hurt/knockdown animations (ragdolls only on death), blood that sticks to walls.
- **Intro**: rebuilt apartment and office (TV faces the couch, workers sit on
  chairs, you sit during the typing minigame); guards shove you back to the
  crystal; the appraisal is a hologram above the crystal; two guards drag you to a
  real trapdoor and throw you down the shaft. Time stop starts at 2 seconds.
- **Enemies**: a random bestiary per run built from traits (size, movement,
  element, temperament ...), random bosses next to the story bosses, five Abyss
  layers, no more monsters inside walls.
- **World** (all parts, no Roblox terrain): the capital is ~2.8k studs across -
  four tiers, a big castle, a great market, eight ring streets of enterable
  terraced houses, a moat - inside a ~4.7k-stud countryside ring: terraced hills,
  massifs, a snowy rim with a pass, rivers and lakes, forests of big trees,
  villages with farm animals and farmers, swaying grass tufts and flowers, random
  landmarks. The ground is a greedy-merged heightfield of boxes (8-stud cells in
  the city, 16/32/64 outward); the controller steps up low ledges on its own.
- **Life**: townsfolk walk, chat in pairs, cry their wares and sometimes ask you
  something; mouths move when characters speak; interiors appear as you approach.
- **UI**: one monospaced font everywhere, flat panels, no gold ornaments.
