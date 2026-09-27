--@stubs world_stubs
--@server World, Build, Nature, DungeonKit, DungeonLayout, DungeonProps, DungeonRooms, WorldPit, WorldLand, WorldArena, WorldTower
-- Smoke test: builds every pit theme, every land and the PvP arena.
local S = {}
__mods["srv:S"] = function()
	return S
end
for _, name in { "World", "Build", "Nature", "WorldPit", "WorldLand", "WorldArena", "WorldTower" } do
	S[name] = require(Server[name])
end
for theme = 1, #S.WorldPit.THEMES do
	local r = S.WorldPit.build({ level = 3, seed = 100 + theme, theme = S.WorldPit.THEMES[theme] })
	assert(r.spawnCF and r.spawnPoints, "pit refs")
	S.WorldPit.clear()
end
print("pit themes OK: " .. #S.WorldPit.THEMES)
-- the five Abyss layers exactly as Chapters/Pit builds them: every one must have
-- a guardian arena (bossCenter) in front of the seal
local layerThemes = { 1, 2, 5, 3, 4 }
for floor = 1, 5 do
	local r = S.WorldPit.build({ level = if floor == 1 then 1 else floor * 2, seed = 777, big = true, theme = S.WorldPit.THEMES[layerThemes[floor]] })
	assert(r.bossCenter, "layer " .. floor .. " has no guardian arena")
	assert(r.barrier and r.portalFilm, "layer " .. floor .. " has no seal")
	S.WorldPit.clear()
end
print("abyss layers OK")
local bible = { lands = {} }
local biomes = { "Meadow", "Autumn", "Frost", "Swamp", "Volcanic", "Evil" }
for i = 1, 6 do
	bible.lands[i] = { name = "Land " .. i, short = "L" .. i, town = "Town" .. i, biome = biomes[i], level = i * 8 }
end
for L = 2, 5 do
	local ok, err = pcall(S.WorldLand.build, L, bible, 555)
	print(string.format("land %d: %s", L, if ok then "OK" else tostring(err)))
	S.World.clear()
end
local ok, err = pcall(S.WorldArena.build, 9)
print("arena: " .. (if ok then "OK" else tostring(err)))
print("DONE")
