--!nonstrict
-- THE KINGDOM'S COUNTRYSIDE: the ring of real terrain around the walled capital
-- (the city is ~2800 studs across, the ring reaches ~4800 studs from its centre,
-- about ten times the city's area). Rolling hills, mountain massifs, a snowy
-- mountain rim with a pass to the north, two rivers (one feeds the moat, one a
-- lake), forests of big trees, villages with fields, pens and farmers, flowers
-- and reeds that sway in the wind, and a handful of random landmarks. Everything
-- here is seeded: another run gets another countryside.
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)

local Land: any = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material
local sqrt, abs, noise, floor = math.sqrt, math.abs, math.noise, math.floor

Land.WL = 4 -- water level (moat, rivers, lakes)
Land.OUTER_Y = 14 -- ground just outside the Great Wall
Land.MOAT_R = 1478
Land.MOAT_W = 20
Land.EDGE_R = 4680 -- how far the terrain goes (just past the ridge of the rim)
Land.MOUNT_R = 4000 -- where the mountain rim starts
Land.BARRIER_R = 4560
Land.PASS_R = 4300

-- terrain tags (height function -> paint)
local T_GRASS, T_ROAD, T_SAND, T_MUD, T_FOREST, T_STREET, T_PLAZA, T_GARDEN, T_VILLAGE, T_CASTLE, T_FIELD = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
Land.T = { GRASS = T_GRASS, ROAD = T_ROAD, SAND = T_SAND, MUD = T_MUD, FOREST = T_FOREST, STREET = T_STREET, PLAZA = T_PLAZA, GARDEN = T_GARDEN, VILLAGE = T_VILLAGE, CASTLE = T_CASTLE, FIELD = T_FIELD }

local function smooth01(t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end
Land.smooth01 = smooth01

-- ------------------------------------------------------------------ segment hash
local HCELL = 256
local function newHash()
	return {}
end
local function hashAdd(hash, seg, margin: number)
	local x0 = floor((math.min(seg[1], seg[3]) - margin) / HCELL)
	local x1 = floor((math.max(seg[1], seg[3]) + margin) / HCELL)
	local z0 = floor((math.min(seg[2], seg[4]) - margin) / HCELL)
	local z1 = floor((math.max(seg[2], seg[4]) + margin) / HCELL)
	for i = x0, x1 do
		for k = z0, z1 do
			local key = i * 4096 + k
			local list = hash[key]
			if not list then
				list = {}
				hash[key] = list
			end
			table.insert(list, seg)
		end
	end
end
-- distance from (x, z) to the nearest segment in the hash (+ that segment)
local function hashDist(hash, x: number, z: number): (number, any)
	local list = hash[floor(x / HCELL) * 4096 + floor(z / HCELL)]
	if not list then
		return math.huge, nil
	end
	local best, bs = math.huge, nil
	for _, s in list do
		local ax, az, bx, bz = s[1], s[2], s[3], s[4]
		local dx, dz = bx - ax, bz - az
		local len2 = dx * dx + dz * dz
		local t = if len2 > 0 then ((x - ax) * dx + (z - az) * dz) / len2 else 0
		if t < 0 then
			t = 0
		elseif t > 1 then
			t = 1
		end
		local px, pz = ax + dx * t - x, az + dz * t - z
		local d = px * px + pz * pz
		if d < best then
			best, bs = d, s
		end
	end
	return sqrt(best), bs
end
Land.hashDist = hashDist

local function segDist(s, x: number, z: number): number
	local ax, az, bx, bz = s[1], s[2], s[3], s[4]
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((x - ax) * dx + (z - az) * dz) / len2, 0, 1) else 0
	local px, pz = ax + dx * t - x, az + dz * t - z
	return sqrt(px * px + pz * pz)
end

local function polar(a: number, r: number): (number, number)
	return math.sin(a) * r, math.cos(a) * r
end

-- ------------------------------------------------------------------ the plan
-- (angles: 0 = +Z / south, pi = north, where the pass is)
function Land.plan(seed: number)
	local rng = RNG.new(seed):fork("countryside")
	local P = {
		seed = seed,
		seeds = {},
		massifs = {},
		villages = {},
		forests = {},
		lakes = {},
		rivers = {},
		riverHash = newHash(),
		roadHash = newHash(),
		roads = {},
		wilds = {},
		landmarks = {},
	}
	for i = 1, 8 do
		P.seeds[i] = (seed % 997) + i * 17.31 + rng:float(0, 5)
	end
	local function farFromList(x, z, list, d)
		for _, o in list do
			local dx, dz = x - o.x, z - o.z
			if dx * dx + dz * dz < d * d then
				return false
			end
		end
		return true
	end
	local function nearPass(a: number): boolean
		return abs(((a - math.pi + math.pi) % (2 * math.pi)) - math.pi) < 0.3
	end
	-- two rivers from the mountain rim: A into the moat, B into a lake
	local function river(a0: number, rEnd: number, drift: number)
		local pts = {}
		local n = 44
		for i = 0, n do
			local t = i / n
			local r = 4350 + (rEnd - 4350) * t
			local a = a0 + math.sin(t * 7.3 + a0 * 3) * 0.1 * (1 - t * 0.5) + drift * t
			local x, z = polar(a, r)
			table.insert(pts, { x, z })
		end
		return pts
	end
	local aA = rng:float(0.5, 2.5) -- south-east quarter ... south-west
	local aB = aA + rng:float(2.0, 3.0)
	if nearPass(aB) then
		aB += 0.7
	end
	local rivA = river(aA, Land.MOAT_R, rng:float(-0.25, 0.25))
	local lakeR = rng:float(2200, 2700)
	local rivB = river(aB, lakeR + 120, rng:float(-0.2, 0.2))
	local lx, lz = rivB[#rivB][1], rivB[#rivB][2]
	local ldir = V(lx, 0, lz).Unit
	table.insert(P.lakes, { x = lx - ldir.X * 150, z = lz - ldir.Z * 150, R = rng:float(170, 230), ph = rng:float(0, 6) })
	local l2a = aA + rng:float(1.0, 1.6)
	local l2x, l2z = polar(l2a, rng:float(2800, 3400))
	table.insert(P.lakes, { x = l2x, z = l2z, R = rng:float(120, 170), ph = rng:float(0, 6) })
	for ri, pts in { rivA, rivB } do
		local segs = {}
		for i = 1, #pts - 1 do
			local s = { pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], w = 13 + (i / #pts) * 7 }
			table.insert(segs, s)
			hashAdd(P.riverHash, s, 190)
		end
		P.rivers[ri] = { pts = pts, segs = segs }
	end
	local function nearWater(x, z, d)
		local rd = hashDist(P.riverHash, x, z)
		if rd < d then
			return true
		end
		for _, l in P.lakes do
			local dx, dz = x - l.x, z - l.z
			if dx * dx + dz * dz < (l.R + d) ^ 2 then
				return true
			end
		end
		return false
	end
	-- villages on the plains between the roads
	local tries = 0
	while #P.villages < 7 and tries < 400 do
		tries += 1
		local a = rng:angle()
		local r = rng:float(2150, 3500)
		local onRoadAngle = false
		for _, ra in { 0, math.pi / 2, math.pi, math.pi * 1.5 } do
			if abs(((a - ra + math.pi) % (2 * math.pi)) - math.pi) * r < 180 then
				onRoadAngle = true
			end
		end
		local x, z = polar(a, r)
		if not nearPass(a) and not onRoadAngle and farFromList(x, z, P.villages, 900) and not nearWater(x, z, 280) then
			table.insert(P.villages, { x = x, z = z, a = a, r = r, R = 150, blend = 90, id = #P.villages + 1 })
		end
	end
	-- mountain massifs (landmarks inside the ring), away from villages and water
	tries = 0
	while #P.massifs < 5 and tries < 300 do
		tries += 1
		local a = rng:angle()
		local r = rng:float(2300, 3500)
		local x, z = polar(a, r)
		local R = rng:float(300, 470)
		if not nearPass(a) and farFromList(x, z, P.villages, R + 300) and farFromList(x, z, P.massifs, R + 500) and not nearWater(x, z, R + 60) then
			table.insert(P.massifs, { x = x, z = z, R = R, R2 = R * R, H = rng:float(170, 340) })
		end
	end
	-- roads: four radial roads out of the gates, a ring road, spurs to every village
	local function addRoad(ax, az, bx, bz, w)
		local s = { ax, az, bx, bz, w = w }
		table.insert(P.roads, s)
		hashAdd(P.roadHash, s, 20)
	end
	for _, a in { 0, math.pi / 2, math.pi, math.pi * 1.5 } do
		local rEnd = if a == math.pi then Land.PASS_R + 60 else 3950
		local step = 150
		local r = Land.MOAT_R - 40
		while r < rEnd do
			local r2 = math.min(rEnd, r + step)
			local x0, z0 = polar(a, r)
			local x1, z1 = polar(a, r2)
			addRoad(x0, z0, x1, z1, 9)
			r = r2
		end
	end
	local RING = 2650
	P.ringRoad = RING
	for i = 0, 63 do
		local x0, z0 = polar(i / 64 * math.pi * 2, RING)
		local x1, z1 = polar((i + 1) / 64 * math.pi * 2, RING)
		addRoad(x0, z0, x1, z1, 7)
	end
	for _, v in P.villages do
		local rx, rz = polar(v.a, RING)
		addRoad(v.x, v.z, rx, rz, 6)
	end
	-- height of each village plateau (from the unflattened land)
	for _, v in P.villages do
		v.outer2 = (v.R + v.blend) ^ 2
	end
	-- forests
	tries = 0
	while #P.forests < 15 and tries < 400 do
		tries += 1
		local a = rng:angle()
		local r = rng:float(1750, 4050)
		local x, z = polar(a, r)
		local R = rng:float(170, 360)
		if farFromList(x, z, P.villages, R + 200) and farFromList(x, z, P.forests, R + 120) and not (nearPass(a) and r > 3600) then
			table.insert(P.forests, { x = x, z = z, R = R, R2 = (R * 1.2) ^ 2, ph = rng:float(0, 6), giant = #P.forests == 0 })
		end
	end
	-- monster ground: spots in the wilds, away from villages and the city
	tries = 0
	while #P.wilds < 16 and tries < 400 do
		tries += 1
		local a = rng:angle()
		local r = rng:float(1900, 3900)
		local x, z = polar(a, r)
		if farFromList(x, z, P.villages, 380) and not nearWater(x, z, 60) then
			table.insert(P.wilds, { x = x, z = z })
		end
	end
	-- random landmarks
	local kinds = { "watchtower", "ruin", "stones", "shrine", "camp", "graveyard", "ruin", "watchtower", "stones", "windmill", "shrine" }
	tries = 0
	while #P.landmarks < 11 and tries < 400 do
		tries += 1
		local a = rng:angle()
		local r = rng:float(1800, 3900)
		local x, z = polar(a, r)
		if farFromList(x, z, P.villages, 320) and farFromList(x, z, P.landmarks, 400) and not nearWater(x, z, 90) and hashDist(P.roadHash, x, z) > 30 then
			table.insert(P.landmarks, { x = x, z = z, kind = kinds[#P.landmarks + 1] or rng:pick(kinds) })
		end
	end
	Land.P = P
	-- now the villages know how high the land is around them
	for _, v in P.villages do
		v.y = math.max(Land.WL + 7, Land.baseHeight(v.x, v.z, sqrt(v.x * v.x + v.z * v.z)))
	end
	return P
end

-- ------------------------------------------------------------------ heights
-- hills, massifs and the mountain rim (no water, no villages)
function Land.baseHeight(x: number, z: number, r: number): number
	local P = Land.P
	local s = P.seeds
	local k = smooth01((r - 1520) / 900)
	local n1 = noise(x / 1300, z / 1300, s[1])
	local n2 = noise(x / 420, z / 420, s[2])
	local n3 = noise(x / 140, z / 140, s[3])
	local h = Land.OUTER_Y + k * (100 * (n1 + 0.3) + 36 * n2) + (0.3 + 0.7 * k) * 6 * n3
	for _, m in P.massifs do
		local dx, dz = x - m.x, z - m.z
		local d2 = dx * dx + dz * dz
		if d2 < m.R2 then
			local f = 1 - sqrt(d2) / m.R
			local ridge = 1 - abs(noise(x / 150, z / 150, s[4])) * 2
			h += m.H * f ^ 1.6 * (0.7 + 0.3 * ridge) + 24 * f * noise(x / 55, z / 55, s[5])
		end
	end
	if r > Land.MOUNT_R then
		local kk = smooth01((r - Land.MOUNT_R) / 650)
		local ridge = 1 - abs(noise(x / 280, z / 280, s[6])) * 2
		local pass = 1
		if z < 0 then
			pass = 0.05 + 0.95 * smooth01((abs(x) - 45) / 170)
		end
		h += kk * pass * (230 + 330 * ridge + 60 * n2 + 20 * noise(x / 50, z / 50, s[7]))
	end
	if h < 8 then
		h = 8
	end
	return h
end

-- the countryside surface (r >= the wall): returns height, tag
function Land.height(x: number, z: number, r: number): (number, number)
	local P = Land.P
	local WL = Land.WL
	local h = Land.baseHeight(x, z, r)
	local tag = T_GRASS
	-- flat apron between the Great Wall and the moat
	if r < Land.MOAT_R + 60 then
		local k = smooth01((r - (Land.MOAT_R + 30)) / 30)
		h = Land.OUTER_Y + (h - Land.OUTER_Y) * k
	end
	-- villages sit on flattened plateaus
	for _, v in P.villages do
		local dx, dz = x - v.x, z - v.z
		local d2 = dx * dx + dz * dz
		if d2 < v.outer2 then
			local d = sqrt(d2)
			if d < v.R then
				h = v.y
				tag = if d < 26 then T_PLAZA else T_VILLAGE
			else
				local k = smooth01((d - v.R) / v.blend)
				h = v.y + (h - v.y) * k
			end
		end
	end
	-- forests
	if tag == T_GRASS then
		for _, f in P.forests do
			local dx, dz = x - f.x, z - f.z
			local d2 = dx * dx + dz * dz
			if d2 < f.R2 then
				local wob = f.R * (1 + 0.18 * noise(dx / 90, dz / 90, f.ph))
				if d2 < wob * wob then
					tag = T_FOREST
				end
				break
			end
		end
	end
	-- roads (dirt tracks follow the land)
	local rd, rs = hashDist(P.roadHash, x, z)
	if rs and rd < rs.w then
		tag = T_ROAD
	end
	-- water: the moat, rivers, lakes
	local wet = false
	local dm = abs(r - Land.MOAT_R)
	if dm < Land.MOAT_W + 12 then
		if dm < Land.MOAT_W then
			h = WL - 7 + (dm / Land.MOAT_W) ^ 2 * 4
			tag = T_MUD
		else
			h = WL - 1 + (dm - Land.MOAT_W) / 12 * (Land.OUTER_Y - WL + 1)
			tag = T_SAND
		end
		wet = true
	end
	if not wet then
		local d, s = hashDist(P.riverHash, x, z)
		if s then
			local rw = s.w
			local valley = 45 + math.max(0, h - WL) * 1.3
			if d < rw then
				h = WL - 3 - 3 * (1 - d / rw)
				tag = T_MUD
			elseif d < rw + 9 then
				h = WL - 1 + (d - rw) / 9 * 3.5
				tag = T_SAND
			elseif d < rw + 9 + valley and h > WL + 2.5 then
				local k = smooth01((d - rw - 9) / valley)
				h = WL + 2.5 + (h - WL - 2.5) * k
				if k < 0.25 and tag == T_GRASS then
					tag = T_MUD
				end
			end
		end
		for _, l in P.lakes do
			local dx, dz = x - l.x, z - l.z
			local d0 = sqrt(dx * dx + dz * dz)
			if d0 < l.R * 1.25 + 140 then
				local a = math.atan2(dx, dz)
				local d = d0 - l.R * (1 + 0.16 * math.sin(a * 3 + l.ph) + 0.08 * math.sin(a * 7 + l.ph * 2))
				if d < 0 then
					h = WL - 3 - math.min(9, -d * 0.09)
					tag = T_MUD
				elseif d < 12 then
					h = WL - 1 + d / 12 * 3.5
					tag = T_SAND
				elseif d < 12 + 80 and h > WL + 2.5 then
					local k = smooth01((d - 12) / 80)
					h = WL + 2.5 + (h - WL - 2.5) * k
				end
			end
		end
	end
	return h, tag
end

local SNOW = M.Snow
function Land.paint(x: number, z: number, h: number, slope: number, tag: number): Enum.Material
	if tag == T_STREET then
		return M.Cobblestone
	elseif tag == T_CASTLE then
		return if slope > 1 then M.Rock else M.Slate
	elseif tag == T_PLAZA then
		return if slope > 1 then M.Rock else M.Pavement
	end
	if slope > 1.3 then
		return if h > 360 then M.Glacier else M.Rock
	end
	local snowLine = 330 + noise(x / 200, z / 200, 3.3) * 50
	if h > snowLine then
		return if slope > 0.9 then M.Rock else SNOW
	end
	if h > 200 then
		return if slope > 0.55 then M.Rock elseif h > 250 then M.Slate else M.Ground
	end
	if tag == T_SAND then
		return M.Sand
	elseif tag == T_MUD then
		return M.Mud
	elseif tag == T_ROAD then
		return if slope > 0.7 then M.Rock else M.Ground
	end
	if slope > 0.85 then
		return M.Rock
	elseif slope > 0.6 then
		return M.Ground
	end
	if tag == T_FOREST then
		return M.LeafyGrass
	elseif tag == T_FIELD then
		return M.Ground
	end
	return M.Grass
end

-- ------------------------------------------------------------------ dressing helpers
local function sway(p: BasePart, pivotBelow: number, amp: number?)
	p:SetAttribute("SwayPivot", pivotBelow)
	if amp then
		p:SetAttribute("SwayA", amp)
	end
	CollectionService:AddTag(p, "Sway")
end

-- a patch of swaying flowers around `pos` (ground point)
function Land.flowers(parent: Instance, pos: Vector3, rng, colors, n: number?)
	for _ = 1, n or rng:int(4, 7) do
		local p = pos + V(rng:float(-2.5, 2.5), 0, rng:float(-2.5, 2.5))
		local h = rng:float(0.8, 1.6)
		local stem = Kit.deco(parent, V(0.14, h, 0.14), CF(p + V(0, h / 2, 0)), rgb(70, 130, 50), M.SmoothPlastic, { CastShadow = false })
		sway(stem, h / 2, 0.16)
		local s = rng:float(0.35, 0.55)
		local head = Kit.deco(parent, V(s, s * 0.6, s), CF(p + V(0, h + s * 0.2, 0)) * ANG(0, rng:angle(), 0), colors[rng:int(1, #colors)], M.SmoothPlastic, { CastShadow = false })
		sway(head, h + s * 0.2, 0.16)
	end
end

function Land.reeds(parent: Instance, pos: Vector3, rng)
	for _ = 1, rng:int(4, 7) do
		local h = rng:float(2.5, 4.5)
		local p = pos + V(rng:float(-2, 2), 0, rng:float(-2, 2))
		local r = Kit.deco(parent, V(0.22, h, 0.22), CF(p + V(0, h / 2 - 0.4, 0)) * ANG(rng:float(-0.1, 0.1), 0, rng:float(-0.1, 0.1)), Palette.jitter(rgb(120, 140, 70), 0.1, rng:float()), M.Grass, { CastShadow = false })
		sway(r, h / 2, 0.1)
		if rng:chance(0.4) then
			local top = Kit.deco(parent, V(0.34, 0.9, 0.34), CF(p + V(0, h - 0.2, 0)), rgb(110, 76, 50), M.SmoothPlastic, { CastShadow = false })
			sway(top, h - 0.2, 0.1)
		end
	end
end

-- simple street lamp: lit ones carry a light (no shadows, they're everywhere)
function Land.lamp(parent: Instance, pos: Vector3, lit: boolean)
	Kit.part(parent, V(0.5, 8, 0.5), CF(pos + V(0, 4, 0)), rgb(46, 40, 36), M.Metal)
	Kit.deco(parent, V(2, 0.3, 0.3), CF(pos + V(0.8, 7.8, 0)), rgb(46, 40, 36), M.Metal)
	local lamp = Kit.deco(parent, V(0.9, 1.1, 0.9), CF(pos + V(1.5, 7.1, 0)), rgb(255, 206, 130), M.Neon)
	if lit then
		Kit.pointLight(lamp, rgb(255, 190, 120), 26, 1.1, false)
	end
	return lamp
end

-- ------------------------------------------------------------------ landmarks
local function landmark(parent: Instance, kind: string, pos: Vector3, rng)
	local W, B = S.World, S.Build
	local m = Kit.model("Landmark_" .. kind, parent)
	local stone = rgb(150, 146, 140)
	if kind == "watchtower" then
		B.watchtower(m, pos, { height = rng:float(18, 26) })
	elseif kind == "ruin" then
		-- a broken round keep: jagged wall stubs, rubble, a lonely arch
		local R = rng:float(9, 14)
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2
			local h = rng:float(3, 22) * (if i % 5 == 0 then 0.2 else 1)
			local p = pos + V(math.cos(a) * R, 0, math.sin(a) * R)
			W.solid(m, V(4.8, h, 3), CFrame.lookAt(p + V(0, h / 2 - 1, 0), pos + V(0, h / 2 - 1, 0)), Palette.jitter(stone, 0.08, rng:float()), M.Cobblestone)
		end
		for _ = 1, 10 do
			local s = rng:float(1, 3)
			W.solid(m, V(s, s, s), CF(pos + V(rng:float(-R, R), s / 2 - 0.3, rng:float(-R, R))) * ANG(rng:angle(), rng:angle(), 0), Palette.jitter(stone, 0.1, rng:float()), M.Cobblestone)
		end
		W.solid(m, V(3, 16, 3), CF(pos + V(R + 6, 7, 0)), stone, M.Cobblestone)
		W.solid(m, V(3, 16, 3), CF(pos + V(R + 6, 7, 9)), stone, M.Cobblestone)
		W.solid(m, V(3, 3, 12), CF(pos + V(R + 6, 16, 4.5)), stone, M.Cobblestone)
	elseif kind == "stones" then
		local R = rng:float(10, 15)
		local n = rng:int(7, 11)
		for i = 1, n do
			local a = i / n * math.pi * 2
			local h = rng:float(7, 13)
			local p = pos + V(math.cos(a) * R, 0, math.sin(a) * R)
			W.solid(m, V(3, h, 1.8), CFrame.lookAt(p + V(0, h / 2 - 1, 0), pos + V(0, h / 2 - 1, 0)) * ANG(rng:float(-0.08, 0.08), 0, rng:float(-0.08, 0.08)), Palette.jitter(rgb(120, 118, 114), 0.1, rng:float()), M.Slate)
		end
		W.solid(m, V(5, 2, 3), CF(pos + V(0, 0.6, 0)), rgb(110, 108, 104), M.Slate)
	elseif kind == "shrine" then
		W.solid(m, V(8, 1, 8), CF(pos + V(0, 0.4, 0)), stone, M.Slate)
		W.solid(m, V(3, 3.4, 2), CF(pos + V(0, 2.6, 0)), Palette.shade(stone, 1.1), M.Limestone)
		for _, sx in { -1, 1 } do
			local c = Kit.deco(m, V(0.4, 0.8, 0.4), CF(pos + V(sx * 1, 4.7, 0)), rgb(240, 236, 220), M.SmoothPlastic)
			local f = Kit.deco(m, V(0.3, 0.3, 0.3), CF(pos + V(sx * 1, 5.3, 0)), rgb(255, 190, 90), M.Neon)
			Kit.pointLight(f, rgb(255, 190, 110), 12, 0.6, false)
		end
		Land.flowers(m, pos + V(0, 0.9, 3), rng, { rgb(240, 240, 250), rgb(250, 220, 80) }, 4)
	elseif kind == "camp" then
		-- an abandoned camp: collapsed tents, a cold fire pit, scattered crates
		for i = 1, 3 do
			local a = i * 2.1
			W.tent(m, CF(pos + V(math.cos(a) * 9, 0, math.sin(a) * 9)) * ANG(0, a, 0.12), rng:pick({ rgb(120, 100, 70), rgb(90, 80, 70) }))
		end
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			Kit.deco(m, V(0.8, 0.6, 0.8), CF(pos + V(math.cos(a) * 1.4, 0.3, math.sin(a) * 1.4)), rgb(90, 90, 94))
		end
		W.crate(m, CF(pos + V(5, 0, -6)) * ANG(0, 0.4, 0))
		W.barrel(m, CF(pos + V(-6, 0, 5)))
	elseif kind == "graveyard" then
		for i = 0, 3 do
			for k = 0, 2 do
				local p = pos + V(-9 + i * 6, 0, -5 + k * 5) + V(rng:float(-0.8, 0.8), 0, 0)
				W.solid(m, V(2.2, rng:float(2.4, 3.6), 0.6), CF(p + V(0, 1.2, 0)) * ANG(rng:float(-0.12, 0.12), rng:float(-0.2, 0.2), rng:float(-0.1, 0.1)), Palette.jitter(rgb(140, 138, 134), 0.1, rng:float()), M.Slate)
				Kit.deco(m, V(2, 0.3, 4), CF(p + V(0, 0.1, 2.4)), rgb(90, 70, 52), M.Ground)
			end
		end
		W.fence(m, pos + V(-13, 0, -9), pos + V(13, 0, -9))
		W.fence(m, pos + V(-13, 0, 11), pos + V(13, 0, 11))
	elseif kind == "windmill" then
		B.windmill(m, pos, rng:angle())
	end
	return m
end

-- ------------------------------------------------------------------ villages
local HOUSE_ROOFS = { rgb(150, 70, 50), rgb(120, 56, 44), rgb(170, 90, 60), rgb(110, 76, 56) }
local function village(folders, v, rng, refs, ground)
	local W, B, N = S.World, S.Build, S.Nature
	local vm = Kit.model("Village" .. v.id, folders.houses)
	local c = V(v.x, v.y, v.z)
	local pal = Palette.biomes.Meadow
	local points = { c }
	-- the green: a well or a shrine, benches, a notice board
	if rng:chance(0.6) then
		W.well(vm, c)
	else
		B.fountain(vm, c)
	end
	for i = 1, 3 do
		local a = i * 2.1 + 0.4
		B.bench(vm, CFrame.lookAt(c + V(math.cos(a) * 10, 0, math.sin(a) * 10), c))
	end
	-- houses around the green, facing it (with a few gaps for lanes)
	local n = rng:int(9, 14)
	local placed = {}
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:float(-0.12, 0.12)
		local r = rng:float(38, 70)
		local p = c + V(math.cos(a) * r, 0, math.sin(a) * r)
		local ok = true
		for _, q in placed do
			if (q - p).Magnitude < 20 then
				ok = false
			end
		end
		if ok then
			table.insert(placed, p)
			local face = CFrame.lookAt(p, V(c.X, p.Y, c.Z))
			local roll = rng:float()
			local w, d = rng:int(12, 16), rng:int(10, 13)
			local model, door
			if roll < 0.22 then
				model, door = B.longhouse(vm, face, { rng = rng, turf = rng:chance(0.5), shields = false })
			else
				local floors = if rng:chance(0.7) then 1 else 2
				model, door = B.halfTimber(vm, face, { rng = rng, w = w, d = d, floors = floors, roof = rng:pick(HOUSE_ROOFS), sign = rng:chance(0.1) })
				S.Interiors.register(model, { kind = if rng:chance(0.12) then "shop" else "cottage", cf = face, w = w, d = d, floors = floors, fh = 9, plinth = 1.2, t = 0.8, seed = rng:int(1, 1e6), upper = floors > 1 })
			end
			if door then
				table.insert(points, door)
			end
			table.insert(refs.villageHouses, model)
		end
	end
	-- fields, pens with animals, a barn and haystacks on the edge of the plateau
	local pensMade = 0
	for i = 1, rng:int(4, 6) do
		local a = rng:angle()
		local r = rng:float(95, 128)
		local p = c + V(math.cos(a) * r, 0, math.sin(a) * r)
		local cf = CFrame.lookAt(p, V(c.X, p.Y, c.Z))
		if pensMade < 2 and i <= 2 then
			pensMade += 1
			local pw, pd = rng:int(22, 32), rng:int(18, 26)
			local corners = { (cf * CF(-pw / 2, 0, -pd / 2)).Position, (cf * CF(pw / 2, 0, -pd / 2)).Position, (cf * CF(pw / 2, 0, pd / 2)).Position, (cf * CF(-pw / 2, 0, pd / 2)).Position }
			for k = 1, 4 do
				W.fence(folders.farms, corners[k], corners[k % 4 + 1])
			end
			local kinds = { rng:pick({ "cow", "sheep", "pig", "goat", "horse" }), rng:pick({ "sheep", "pig", "goat", "chicken" }) }
			for k = 1, rng:int(4, 7) do
				local kind = kinds[(k % 2) + 1]
				local ap = (cf * CF(rng:float(-pw / 2 + 3, pw / 2 - 3), 0, rng:float(-pd / 2 + 3, pd / 2 - 3))).Position
				S.Fauna.animal(folders.farms, kind, CF(ap) * ANG(0, rng:angle(), 0), rng, { wander = math.min(pw, pd) / 2 - 3 })
			end
			B.hayBale(folders.farms, cf * CF(pw / 2 - 2, 0, pd / 2 - 2))
		else
			local fw, fd = rng:int(30, 46), rng:int(24, 36)
			N.field(folders.fields, cf, fw, fd, rng:pick({ "wheat", "wheat", "green", "flax" }), rng)
			if rng:chance(0.5) then
				B.haystack(folders.fields, (cf * CF(fw / 2 + 5, 0, 0)).Position, 0.8)
			end
		end
	end
	-- chickens and geese roam the green
	for _ = 1, rng:int(3, 6) do
		local a = rng:angle()
		S.Fauna.animal(folders.farms, rng:pick({ "chicken", "chicken", "goose", "rabbit" }), CF(c + V(math.cos(a) * 18, 0, math.sin(a) * 18)), rng, { wander = 22 })
	end
	if rng:chance(0.55) then
		local a = rng:angle()
		B.windmill(vm, c + V(math.cos(a) * 135, 0, math.sin(a) * 135), rng:angle())
	end
	B.longhouse(vm, CF(c + V(rng:float(-1, 1) * 90, 0, rng:float(-1, 1) * 90)) * ANG(0, rng:angle(), 0), { rng = rng, turf = false, shields = false, name = "Barn" })
	for _ = 1, 4 do
		local a = rng:angle()
		local p = c + V(math.cos(a) * rng:float(24, 34), 0, math.sin(a) * rng:float(24, 34))
		local roll = rng:float()
		if roll < 0.3 then
			B.cart(vm, CF(p) * ANG(0, rng:angle(), 0))
		elseif roll < 0.55 then
			B.woodpile(vm, CF(p) * ANG(0, rng:angle(), 0))
		elseif roll < 0.8 then
			B.laundry(vm, p, p + V(rng:float(-7, 7), 0, rng:float(-7, 7)))
		else
			W.barrel(vm, CF(p))
		end
	end
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + 0.3
		Land.lamp(vm, c + V(math.cos(a) * 30, 0, math.sin(a) * 30), i % 2 == 0)
	end
	for _ = 1, 6 do
		local a = rng:angle()
		Land.flowers(folders.props, c + V(math.cos(a) * rng:float(12, 36), 0, math.sin(a) * rng:float(12, 36)), rng, pal.flowers)
	end
	-- a signpost where the spur leaves the village
	local rx, rz = polar(v.a, Land.P.ringRoad)
	local toRing = V(rx - v.x, 0, rz - v.z).Unit
	B.signpost(vm, c + toRing * (v.R - 10), math.atan2(toRing.X, toRing.Z))
	-- ambient life
	S.Townlife.define({
		name = "village" .. v.id,
		center = c,
		radius = 150,
		points = points,
		count = rng:int(4, 6),
		farmers = rng:int(2, 3),
		races = { "Human", "Human", "Beastkin" },
		outfits = { "peasant", "peasant", "peasant", "merchant" },
		level = 6,
		ask = true,
		askEvery = 150,
	})
	table.insert(refs.villages, { center = c, name = "village" .. v.id, points = points })
end

-- ------------------------------------------------------------------ dress the land
-- folders = {props, fields, farms, houses, city}; ground(x, z) -> surface height
function Land.dress(folders, rng, refs, ground)
	local P = Land.P
	local W, B, N = S.World, S.Build, S.Nature
	local pal = Palette.biomes.Meadow
	local counter = { n = 0 }
	refs.villages = {}
	refs.villageHouses = {}
	for _, v in P.villages do
		village(folders, v, rng:fork("village", v.id), refs, ground)
		W.yield(counter)
	end
	local function slopeAt(x, z)
		local h0 = ground(x, z)
		return math.max(abs(ground(x + 3, z) - h0), abs(ground(x, z + 3) - h0)) / 3, h0
	end
	local function clearOf(x, z, roadPad, waterPad)
		if hashDist(P.roadHash, x, z) < roadPad then
			return false
		end
		if hashDist(P.riverHash, x, z) < waterPad then
			return false
		end
		for _, l in P.lakes do
			if sqrt((x - l.x) ^ 2 + (z - l.z) ^ 2) < l.R * 1.25 + waterPad then
				return false
			end
		end
		for _, v in P.villages do
			if sqrt((x - v.x) ^ 2 + (z - v.z) ^ 2) < v.R + 10 then
				return false
			end
		end
		local r = sqrt(x * x + z * z)
		return r > Land.MOAT_R + 50 and r < Land.BARRIER_R - 60
	end
	-- forests: big trees on a jittered grid (the inner ones are cheaper LOD trees)
	local lod = table.clone(pal)
	lod.lod = true
	for _, f in P.forests do
		local spacing = if f.giant then 60 else 31
		for gx = -f.R, f.R, spacing do
			for gz = -f.R, f.R, spacing do
				local x = f.x + gx + rng:float(-spacing * 0.4, spacing * 0.4)
				local z = f.z + gz + rng:float(-spacing * 0.4, spacing * 0.4)
				local dx, dz = x - f.x, z - f.z
				local d = sqrt(dx * dx + dz * dz)
				local wob = f.R * (1 + 0.18 * noise(dx / 90, dz / 90, f.ph))
				if d < wob and clearOf(x, z, 14, 28) then
					local slope, h = slopeAt(x, z)
					if slope < 1.1 and h < 230 then
						local pos = V(x, h - 0.6, z)
						local edge = d > wob - spacing * 1.2
						local p = if edge then pal else lod
						if f.giant then
							N.giant(folders.props, pos, rng, rng:float(0.55, 0.85), pal)
						elseif h > 120 or rng:chance(0.25) then
							N.pine(folders.props, pos, rng, rng:float(1.4, 2.3), p, h > 190)
						elseif rng:chance(0.3) then
							N.birch(folders.props, pos, rng, rng:float(1.4, 2.0), pal)
						else
							N.oak(folders.props, pos, rng, rng:float(1.5, 2.4), p)
						end
						if rng:chance(0.12) then
							N.bush(folders.props, V(x + rng:float(-6, 6), h, z + rng:float(-6, 6)), rng, pal, rng:float(2, 4))
						end
						if rng:chance(0.05) then
							N.log(folders.props, V(x + 6, h, z + 3), rng, pal)
						end
					end
				end
				W.yield(counter)
			end
		end
	end
	-- lone trees, rocks, bushes, flowers and reeds across the ring
	for _ = 1, 2100 do
		local a = rng:angle()
		local r = rng:float(Land.MOAT_R + 60, Land.MOUNT_R + 350)
		local x, z = polar(a, r)
		local roll = rng:float()
		if roll < 0.2 then
			if clearOf(x, z, 12, 24) then
				local slope, h = slopeAt(x, z)
				if slope < 0.9 and h < 220 then
					if h > 110 then
						N.pine(folders.props, V(x, h - 0.6, z), rng, rng:float(1.3, 2.1), pal)
					else
						N.oak(folders.props, V(x, h - 0.6, z), rng, rng:float(1.4, 2.3), pal)
					end
				end
			end
		elseif roll < 0.42 then
			if clearOf(x, z, 10, 8) then
				local slope, h = slopeAt(x, z)
				N.rocks(folders.props, V(x, h - 0.4, z), rng:float(2.5, 7) * (1 + math.min(slope, 1)), pal.rock, rng, h < 150)
			end
		elseif roll < 0.62 then
			if clearOf(x, z, 8, 12) then
				local _, h = slopeAt(x, z)
				if h < 200 then
					N.bush(folders.props, V(x, h - 0.3, z), rng, pal)
				end
			end
		elseif roll < 0.78 then
			if clearOf(x, z, 5, 12) then
				local slope, h = slopeAt(x, z)
				if slope < 0.5 and h < 160 then
					Land.flowers(folders.props, V(x, h - 0.1, z), rng, pal.flowers)
				end
			end
		end
		W.yield(counter)
	end
	-- reeds along the rivers and lakes
	for _, riv in P.rivers do
		for i = 1, #riv.pts - 1, 1 do
			local a, b = riv.pts[i], riv.pts[i + 1]
			for _, side in { -1, 1 } do
				if rng:chance(0.7) then
					local dx, dz = b[1] - a[1], b[2] - a[2]
					local len = sqrt(dx * dx + dz * dz)
					local nx, nz = -dz / len, dx / len
					local t = rng:float(0, 1)
					local w = riv.segs[i].w + 4
					local x, z = a[1] + dx * t + nx * w * side, a[2] + dz * t + nz * w * side
					Land.reeds(folders.props, V(x, ground(x, z), z), rng)
				end
			end
		end
	end
	for _, l in P.lakes do
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2 + rng:float(-0.1, 0.1)
			local R = l.R * (1 + 0.16 * math.sin(a * 3 + l.ph) + 0.08 * math.sin(a * 7 + l.ph * 2)) + 4
			local x, z = l.x + math.sin(a) * R, l.z + math.cos(a) * R
			Land.reeds(folders.props, V(x, ground(x, z), z), rng)
		end
		local a = rng:angle()
		local R = l.R + 8
		local p = V(l.x + math.sin(a) * R, Land.WL + 1.6, l.z + math.cos(a) * R)
		B.dock(folders.props, CFrame.lookAt(p, V(l.x, p.Y, l.z)), 26)
	end
	-- bridges where roads cross rivers (and over the moat at the four gates)
	for _, road in P.roads do
		for _, riv in P.rivers do
			for _, s in riv.segs do
				-- segment intersection
				local x1, z1, x2, z2 = road[1], road[2], road[3], road[4]
				local x3, z3, x4, z4 = s[1], s[2], s[3], s[4]
				local den = (x1 - x2) * (z3 - z4) - (z1 - z2) * (x3 - x4)
				if abs(den) > 1e-6 then
					local t = ((x1 - x3) * (z3 - z4) - (z1 - z3) * (x3 - x4)) / den
					local u = -((x1 - x2) * (z1 - z3) - (z1 - z2) * (x1 - x3)) / den
					if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
						local ix, iz = x1 + t * (x2 - x1), z1 + t * (z2 - z1)
						local dir = V(x2 - x1, 0, z2 - z1).Unit
						local half = s.w + 16
						local a = V(ix, 0, iz) - dir * half
						local b = V(ix, 0, iz) + dir * half
						B.bridge(folders.city, V(a.X, ground(a.X, a.Z), a.Z), V(b.X, ground(b.X, b.Z), b.Z), road.w * 2 + 2)
					end
				end
			end
		end
	end
	-- landmarks
	for _, lm in P.landmarks do
		local h = ground(lm.x, lm.z)
		landmark(folders.props, lm.kind, V(lm.x, h, lm.z), rng)
		W.yield(counter)
	end
	-- the invisible edge of the world (behind the mountains)
	local edge = Kit.folder("WorldEdge", folders.city)
	local segs = 240
	for i = 0, segs - 1 do
		local a0, a1 = i / segs * math.pi * 2, (i + 1) / segs * math.pi * 2
		local x0, z0 = polar(a0, Land.BARRIER_R)
		local x1, z1 = polar(a1, Land.BARRIER_R)
		local mid = V((x0 + x1) / 2, 500, (z0 + z1) / 2)
		Kit.part(edge, V(4, 1400, V(x1 - x0, 0, z1 - z0).Magnitude + 2), CFrame.lookAt(mid, V(x1, 500, z1)), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CanQuery = false, CastShadow = false })
	end
	-- refs for the chapters
	refs.wilds = {}
	for _, w in P.wilds do
		table.insert(refs.wilds, V(w.x, ground(w.x, w.z), w.z))
	end
	refs.northPass = V(0, ground(0, -Land.PASS_R) + 3, -Land.PASS_R)
	refs.lakes = {}
	for _, l in P.lakes do
		table.insert(refs.lakes, V(l.x, Land.WL, l.z))
	end
end

return Land
