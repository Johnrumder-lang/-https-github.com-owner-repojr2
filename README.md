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

## v5 additions

- **Horse** (H): whistle for a saddled horse and ride it (1.9x speed, SHIFT to
  gallop; legs trot and gallop, the head nods, the tail swishes). The stable
  master at the capital's gate plaza sells a courser and a barded destrier.
  Cutscenes, ragdolls and death throw you off; no horses underground or indoors.
- **Abyss**: every layer ends in a guardian arena and only the guardian has to
  die - walk past the rest. Much easier (fewer, weaker monsters) and poorer loot
  (wooden chests, mostly Common).
- **Grathul**: 1.6x bigger with a detailed model (plates, horns, jaw, claws,
  city chunks on its shoulders); it stands on the real ground; when it's down,
  the eye and the brow gem are within reach. The Proving Pit arena is much bigger
  with an invisible wall during the fight; the PvP arena is bigger too.
- **Bigger blades**: weapons are drawn 1.35x in every hand, so swords stop
  reading as daggers (reach +12% to match).
- **Grass everywhere**: swaying pointed tufts and wildflowers close by, clumps out
  to the horizon, on every grassy ground part; birds cross the sky, butterflies
  over the meadows, fireflies at night. Trees are ~1.55x taller.
- **Wilds**: packs keep spawning around you out in the countryside (capital and
  lands 2-5), tougher the farther you ride, now and then a named beast.
- **Capital (free roam)**: a bounty board (cull the wilds, hunt a named beast,
  break a raid on a village), weaponsmith and armourer at the great market, an
  inn at the tavern square. The streets are busy wherever you walk (crowds are
  kept around each player), the watch patrols, the villages are fuller.
