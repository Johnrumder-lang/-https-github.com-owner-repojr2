--@stubs world_stubs
--@server World, Build, Nature, CityKit, InteriorKit, CityBuildings, WorldPrologue
-- Smoke test: builds the modern-city prologue and checks the refs the chapter uses.
local S = {}
__mods["srv:S"] = function()
	return S
end
for _, name in { "World", "Build", "Nature" } do
	S[name] = require(Server[name])
end
S.WorldPrologue = require(Server.WorldPrologue)
local refs = S.WorldPrologue.build({ company = "Acme", club = "Club", friend = "Ken", hero = "Hero", bossName = "Boss", truck = "Truck", weekday = "Monday", breakfast = "toast", dinner = "noodles", coworkers = { "A", "B", "C" } }, 777)
for _, k in { "wakeCF", "ceilingCam", "plate", "aptDoor", "officeDoor", "officeInside", "coworkerSeats", "bossSpot", "myDesk", "mySeat", "deskCam", "fridge", "dinnerSpot", "aptCenter", "clubQueue", "bouncer", "clubDoor", "crossing", "truckFrom", "truckTo", "streetLights" } do
	assert(refs[k] ~= nil, "missing ref " .. k)
end
S.WorldPrologue.setNight(refs, true)
S.WorldPrologue.setNight(refs, false)
print(string.format("prologue: %d instances, %d coworker seats", INSTANCE_COUNT, #refs.coworkerSeats))
print("OK")
