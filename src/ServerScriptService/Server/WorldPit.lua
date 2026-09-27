--!nonstrict
-- THE ABYSS beneath the castle: ten generated underground floors (and the land
-- dungeons, which reuse this builder with their own theme). Each floor is a
-- complex of monumental rooms (catacomb halls with galleries, crypts, bone
-- cathedrals, flooded cisterns, caverns, mines, chasms with broken bridges,
-- forges) joined by vaulted corridors, lit by torches, braziers and candles,
-- with a light shaft at the spawn, a sealed monumental exit gate and round boss
-- arenas on the big floors. Builders live in Dungeon*.luau next to this file.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)
local K = require(script.Parent.DungeonKit)
local Layout = require(script.Parent.DungeonLayout)
local Rooms = require(script.Parent.DungeonRooms)

local Pit = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material

Pit.ORIGIN = V(0, -1400, 0)

-- 1-4 are also used by the land dungeons (Chapters/World: neutral, wet, bone, fire)
Pit.THEMES = {
	{
		name = "The Shallow Crypts",
		flavor = "crypt",
		wall = { rgb(80, 74, 70), rgb(72, 67, 64), rgb(88, 81, 75), rgb(76, 72, 72) },
		floor = { rgb(64, 60, 58), rgb(58, 54, 52), rgb(70, 65, 60), rgb(60, 58, 58) },
		trim = { rgb(98, 92, 84), rgb(90, 85, 78), rgb(104, 97, 88) },
		vault = { rgb(66, 62, 60), rgb(60, 57, 56), rgb(70, 66, 62) },
		rock = { rgb(62, 58, 56), rgb(56, 52, 50), rgb(68, 62, 58) },
		statue = { rgb(118, 112, 104), rgb(110, 106, 100) },
		mat = M.Slate,
		wallMat = M.Slate,
		trimMat = M.Limestone,
		floorMat = M.Slate,
		roughMat = M.Rock,
		glow = rgb(176, 130, 255),
		grateGlow = rgb(255, 120, 50),
		accent = rgb(122, 26, 32),
		banner = rgb(112, 24, 30),
		emblem = rgb(170, 140, 80),
		water = rgb(34, 48, 56),
		kinds = { { "hall", 3 }, { "crypt", 3 }, { "cathedral", 1 }, { "chasm", 2 }, { "cavern", 1 } },
	},
	{
		name = "The Weeping Cisterns",
		flavor = "cistern",
		wall = { rgb(70, 78, 72), rgb(63, 70, 65), rgb(78, 86, 78), rgb(66, 74, 70) },
		floor = { rgb(58, 64, 60), rgb(52, 58, 54), rgb(64, 70, 64) },
		trim = { rgb(88, 96, 88), rgb(82, 90, 82), rgb(94, 100, 90) },
		vault = { rgb(60, 68, 62), rgb(56, 62, 58) },
		rock = { rgb(56, 64, 58), rgb(50, 58, 52), rgb(62, 70, 62) },
		statue = { rgb(104, 112, 104) },
		mat = M.Slate,
		wallMat = M.Cobblestone,
		trimMat = M.Granite,
		floorMat = M.Slate,
		roughMat = M.Rock,
		glow = rgb(110, 255, 170),
		grateGlow = rgb(90, 220, 150),
		accent = rgb(60, 110, 90),
		banner = rgb(46, 74, 70),
		emblem = rgb(150, 170, 120),
		water = rgb(30, 56, 54),
		kinds = { { "cistern", 4 }, { "cavern", 3 }, { "hall", 1 }, { "chasm", 2 }, { "crypt", 1 } },
	},
	{
		name = "The Bone Cathedral",
		flavor = "bone",
		wall = { rgb(102, 90, 78), rgb(94, 83, 72), rgb(110, 97, 84), rgb(98, 88, 80) },
		floor = { rgb(78, 68, 60), rgb(72, 63, 56), rgb(84, 74, 64) },
		trim = { rgb(142, 130, 110), rgb(134, 122, 104), rgb(150, 138, 116) },
		vault = { rgb(90, 80, 70), rgb(84, 74, 66) },
		rock = { rgb(80, 70, 62), rgb(72, 64, 56) },
		statue = { rgb(160, 150, 130), rgb(150, 142, 124) },
		mat = M.Limestone,
		wallMat = M.Limestone,
		trimMat = M.Marble,
		floorMat = M.Slate,
		roughMat = M.Rock,
		glow = rgb(255, 186, 110),
		grateGlow = rgb(255, 110, 50),
		accent = rgb(132, 22, 30),
		banner = rgb(120, 20, 28),
		emblem = rgb(214, 204, 176),
		water = rgb(50, 40, 36),
		kinds = { { "cathedral", 3 }, { "hall", 3 }, { "crypt", 2 }, { "chasm", 2 } },
	},
	{
		name = "The Molten Throat",
		flavor = "forge",
		wallStyle = "brick",
		wall = { rgb(56, 48, 46), rgb(50, 43, 42), rgb(62, 53, 50), rgb(54, 46, 46) },
		floor = { rgb(46, 40, 40), rgb(42, 36, 36), rgb(52, 45, 44) },
		trim = { rgb(74, 62, 58), rgb(68, 57, 54), rgb(80, 66, 60) },
		vault = { rgb(46, 40, 40), rgb(42, 36, 36) },
		rock = { rgb(42, 36, 36), rgb(38, 32, 32), rgb(48, 40, 38) },
		statue = { rgb(70, 62, 60), rgb(64, 58, 56) },
		mat = M.Basalt,
		wallMat = M.Brick,
		trimMat = M.Basalt,
		floorMat = M.Basalt,
		roughMat = M.Basalt,
		glow = rgb(255, 110, 30),
		grateGlow = rgb(255, 96, 24),
		accent = rgb(150, 30, 20),
		banner = rgb(108, 20, 22),
		emblem = rgb(200, 150, 70),
		water = rgb(255, 90, 20),
		lava = true,
		kinds = { { "forge", 4 }, { "hall", 2 }, { "chasm", 2 }, { "cathedral", 1 }, { "cavern", 1 } },
	},
	{
		name = "The Collapsed Mines",
		flavor = "mine",
		wall = { rgb(86, 72, 58), rgb(78, 65, 52), rgb(94, 79, 63), rgb(82, 70, 60) },
		floor = { rgb(70, 60, 50), rgb(64, 55, 46), rgb(76, 65, 54) },
		trim = { rgb(100, 88, 72), rgb(94, 82, 68) },
		vault = { rgb(76, 64, 52), rgb(70, 60, 50) },
		rock = { rgb(80, 67, 54), rgb(72, 60, 49), rgb(88, 74, 60), rgb(66, 58, 52) },
		statue = { rgb(110, 100, 88) },
		mat = M.Slate,
		wallMat = M.Cobblestone,
		trimMat = M.Granite,
		floorMat = M.Slate,
		roughMat = M.Rock,
		glow = rgb(110, 190, 255),
		grateGlow = rgb(255, 130, 60),
		accent = rgb(104, 60, 36),
		banner = rgb(92, 38, 30),
		emblem = rgb(170, 140, 80),
		water = rgb(40, 50, 56),
		kinds = { { "mine", 4 }, { "cavern", 2 }, { "chasm", 2 }, { "hall", 1 } },
	},
}

function Pit.theme(level: number)
	if level >= 10 then
		return Pit.THEMES[4]
	elseif level >= 8 then
		return Pit.THEMES[3]
	elseif level >= 6 then
		return Pit.THEMES[5]
	elseif level >= 4 then
		return Pit.THEMES[2]
	end
	return Pit.THEMES[1]
end

-- Greedy rectangles over a keyed tile map (kept for other builders).
function Pit.greedy(nx, nz, key, emit)
	local used = {}
	for x = 1, nx do
		used[x] = {}
	end
	for z = 1, nz do
		for x = 1, nx do
			local k = key(x, z)
			if k ~= nil and not used[x][z] then
				local w = 1
				while x + w <= nx and not used[x + w][z] and key(x + w, z) == k do
					w += 1
				end
				local d = 1
				local ok = true
				while ok and z + d <= nz do
					for xx = x, x + w - 1 do
						if used[xx][z + d] or key(xx, z + d) ~= k then
							ok = false
							break
						end
					end
					if ok then
						d += 1
					end
				end
				for xx = x, x + w - 1 do
					for zz = z, z + d - 1 do
						used[xx][zz] = true
					end
				end
				emit(x, z, w, d, k)
			end
		end
	end
end

local BUILD = {
	hall = Rooms.hall,
	crypt = Rooms.crypt,
	cathedral = Rooms.cathedral,
	cistern = Rooms.cistern,
	cavern = Rooms.cavern,
	mine = Rooms.mine,
	chasm = Rooms.chasm,
	forge = Rooms.forge,
}

-- opts: {level, seed, theme?, folderName?, origin?, grid?, big?}
function Pit.build(opts)
	local W = S.World
	local level = opts.level or 1
	local rng = RNG.new(opts.seed or 1):fork("pit", level, opts.folderName or "Pit")
	local theme = opts.theme or Pit.theme(level)
	local folderName = opts.folderName or "Pit"
	local isPit = folderName == "Pit"
	local folder = W.sub(folderName)
	local origin = opts.origin or Pit.ORIGIN
	local G = opts.grid or math.clamp(2 + math.ceil(level / 3), 3, 5)
	local nRooms = if isPit then 6 + math.floor(level * 0.5) else 8
	local ctx = K.context(folder, rng, theme)
	local plan = Layout.plan(rng, origin, {
		G = G,
		rooms = nRooms,
		big = opts.big,
		throne = opts.big and isPit and level >= 10,
		kinds = theme.kinds,
		loops = 0.3,
	})
	local refs: any = { rooms = {}, spawnPoints = {}, chestSpots = {}, theme = theme, plan = plan }

	-- the exit gate goes opposite the entrance of the exit room
	local ex = plan.exit
	local entry = nil
	for _, side in Layout.SIDES do
		if #ex.doors[side] > 0 then
			entry = side
		end
	end
	local gateSide = if entry then Layout.OPP[entry] else "zp"
	if #ex.doors[gateSide] > 0 then
		for _, side in Layout.SIDES do
			if #ex.doors[side] == 0 then
				gateSide = side
			end
		end
	end
	Rooms.gatePlan(ex, gateSide)

	-- rooms
	for _, room in plan.rooms do
		local kind = room.kind
		local n0 = ctx.n
		if kind == "spawn" then
			Rooms.spawn(ctx, room, refs, { tutorial = isPit and level == 1 })
		elseif kind == "exit" then
			Rooms.exit(ctx, room, refs)
		elseif kind == "arena" or kind == "throne" then
			Rooms.arena(ctx, room, refs, kind == "throne")
		else
			(BUILD[kind] or Rooms.hall)(ctx, room)
		end
		room.parts = ctx.n - n0
		table.insert(refs.rooms, { center = V(room.cx, room.y, room.cz), size = V(room.sx, room.h, room.sz), room = room, kind = kind })
	end
	-- corridors
	local n1 = ctx.n
	for _, c in plan.cors do
		Rooms.corridor(ctx, c)
	end
	refs.corridorParts = ctx.n - n1

	-- spawn points (never in the spawn room), chest spots
	for _, room in plan.rooms do
		if room ~= plan.spawn then
			for _, p in room.spots do
				table.insert(refs.spawnPoints, p)
			end
		end
	end
	for _, c in plan.cors do
		if c.spot and c.a ~= plan.spawn and c.b ~= plan.spawn then
			table.insert(refs.spawnPoints, c.spot)
		end
	end
	if #refs.spawnPoints == 0 then
		table.insert(refs.spawnPoints, refs.exitCenter + V(0, 3, 30))
	end
	local function chestIn(room)
		if room.chest then
			return room.chest
		end
		local p = Layout.spot(rng, room, 2.5, 6, true)
		if p then
			local look = V(room.cx, p.Y, room.cz)
			if (look - p).Magnitude < 1 then
				look = p + V(0, 0, -1)
			end
			return CFrame.lookAt(p, look)
		end
		return nil
	end
	for _, room in plan.rooms do
		if #room.links == 1 and room ~= plan.spawn and room ~= plan.exit then
			local cf = chestIn(room)
			if cf then
				table.insert(refs.chestSpots, cf)
			end
		end
	end
	local guard = 0
	while #refs.chestSpots < 3 and guard < 20 do
		guard += 1
		local room = plan.rooms[rng:int(1, #plan.rooms)]
		if room ~= plan.spawn and room ~= plan.exit then
			local cf = chestIn(room)
			if cf then
				table.insert(refs.chestSpots, cf)
			end
		end
	end
	refs.spawnRoom = plan.spawn
	refs.exitRoom = plan.exit
	refs.lights = ctx.lights
	refs.parts = ctx.n
	if not opts.big then
		refs.bossCenter = nil
	end
	return refs
end

function Pit.clear(folderName: string?)
	local w = workspace:FindFirstChild("World")
	local f = w and w:FindFirstChild(folderName or "Pit")
	if f then
		f:Destroy()
	end
end

local _ = CF
local _a = ANG

return Pit
