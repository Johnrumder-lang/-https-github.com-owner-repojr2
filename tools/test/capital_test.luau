--@stubs world_stubs
--@server World, Build, Nature, Fauna, Interiors, Townlife, CapitalLand, WorldCapital
-- Smoke test: runs the whole v4 capital build (terrain plan + city + castle +
-- countryside) against the fake object model and checks the refs the chapters use.
local S = {}
__mods["srv:S"] = function()
	return S
end
for _, name in { "World", "Build", "Nature", "Fauna", "Interiors", "Townlife" } do
	S[name] = require(Server[name])
end
S.WorldCapital = require(Server.WorldCapital)
local t0 = os.clock()
local refs = S.WorldCapital.build({}, 424242)
local dt = os.clock() - t0
print(string.format("capital built in %.2fs: %d instances", dt, INSTANCE_COUNT))
local need = {
	"ritualCenter", "crystal", "trapdoor", "trapLeaves", "shaftBottom", "mageSpots", "nobleSpots", "guardSpots", "archmageSpot", "kingSpot", "leashR",
	"castleGate", "castleSpawns", "courtyardSpawns", "keepSpawns", "wallSpawns", "crownRoom", "throne", "floor1",
	"arenaCenter", "arenaGate2", "arenaGate6", "arenaGateModel6", "royalBox", "arenaSpectators", "prisonCenter", "cellCF", "neighborCell", "cellDoor",
	"lowerHouses", "middleHouses", "upperHouses", "spawnsLower", "lowerSquare", "lowerVillageEdge", "middleGate", "burstPoint", "fieldsSpawn",
	"northPass", "center", "wilds", "villages", "townSets", "marketVendors",
}
for _, k in need do
	assert(refs[k] ~= nil, "missing ref " .. k)
end
print(string.format("houses: lower %d, middle %d, upper %d, villages %d (%d village houses)", #refs.lowerHouses, #refs.middleHouses, #refs.upperHouses, #refs.villages, #refs.villageHouses))
print(string.format("interiors registered: %d, town sets: %d, critters: %d, sway parts: %d", #S.Interiors.list, #refs.townSets, TAG_COUNT("Critter"), TAG_COUNT("Sway")))
local parts = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end
print("parts in workspace: " .. parts)
-- the Breakout spawn must be outside the wall and the pass far north
assert(refs.burstPoint.Z > 1450, "burst point inside the wall")
assert(refs.northPass.Z < -4000, "pass too close")
print("OK")
local world = workspace:FindFirstChild("World")
for _, f in world:GetChildren() do
	local n = 0
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	print(string.format("  %-8s %6d parts", f.Name, n))
end
-- furnish a sample of every interior kind
local kinds = {}
local before = INSTANCE_COUNT
for _, info in S.Interiors.list do
	kinds[info.kind] = (kinds[info.kind] or 0) + 1
	if kinds[info.kind] <= 6 then
		S.Interiors.buildNow(info)
		assert(info.built and info.built.Parent == info.model, "interior not attached")
	end
end
local ks = {}
for k, n in kinds do
	table.insert(ks, k .. "=" .. n)
end
table.sort(ks)
print("interior kinds: " .. table.concat(ks, " ") .. string.format("  (%d instances for the samples)", INSTANCE_COUNT - before))
print("OK interiors")
