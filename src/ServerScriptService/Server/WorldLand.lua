--!nonstrict
-- LANDS 2-6: seeded open-world regions built like the old sagas. Rolling hills
-- and cubic cliffs, a winding river (or a fjord cutting in from the sea), a walled
-- town or a palisaded Norse village ringed by farmland, lonely farmsteads, roads
-- with bridges and watchtowers, ruins and old battlefields, forests (and in some
-- lands trees the size of towers), monster camps, a dungeon, a monster tower and
-- the land lord's fortress. Every land is walled in by mountains with a pass in
-- the south (the way in) and one in the north (the sealed gate onward).
-- Land 6 (the Evil Lands) ends at the base of the Endless Tower.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)
local Util = require(Shared.Util)
local S = require(script.Parent.S)

local Land = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material
local TAU = math.pi * 2

local CELL = 20 -- walkable terrain resolution
local OUTER_CELL = 48 -- the mountain ring
local BORDER = 300 -- width of the mountain ring
local HASH = 64 -- road lookup buckets
local ROAD_SLOPE = 0.13 -- max rise per stud along a road

-- town: walled (AoT-style district wall), timber (palisade + half-timber), norse
-- (palisade + longhouses), stilt, desert (mud-brick), stone, dark
local BIOME_SHAPE = {
	Meadow = { amp = 12, macro = 26, freq = 240, water = 1, rough = 0.3, town = "walled", river = true, lakes = 1, forest = 0.36, giants = 0, farms = 4, tree = "oak", mix = { "birch", "pine" } },
	Autumn = { amp = 16, macro = 30, freq = 220, water = 1, rough = 0.4, town = "timber", river = true, lakes = 1, forest = 0.44, giants = 6, farms = 4, tree = "oak", mix = { "birch" } },
	Desert = { amp = 8, macro = 22, freq = 300, water = -6, rough = 0.1, town = "desert", river = false, lakes = 2, forest = 0.05, giants = 0, farms = 1, tree = "cactus", mix = {} },
	Frost = { base = 16, amp = 18, macro = 44, freq = 220, water = 1, rough = 0.6, town = "norse", river = true, lakes = 1, forest = 0.4, giants = 0, farms = 3, tree = "pine", mix = { "dead" }, terrace = 12, snow = true, snowLine = 58 },
	Swamp = { amp = 5, macro = 8, freq = 150, water = 3, rough = 0.2, town = "stilt", river = false, lakes = 3, forest = 0.46, giants = 0, farms = 2, tree = "willow", mix = { "dead" }, wet = true },
	Volcanic = { amp = 18, macro = 34, freq = 200, water = 2, rough = 0.8, lava = true, town = "dark", river = true, lakes = 1, forest = 0.2, giants = 0, farms = 0, tree = "dead", mix = {}, terrace = 10 },
	Crystal = { amp = 18, macro = 30, freq = 210, water = 1, rough = 0.5, town = "stone", river = true, lakes = 1, forest = 0.3, giants = 0, farms = 2, tree = "crystal", mix = { "pine" } },
	Mushroom = { amp = 10, macro = 18, freq = 180, water = 2, rough = 0.3, town = "timber", river = true, lakes = 2, forest = 0.42, giants = 0, farms = 3, tree = "mushroom", mix = { "willow" } },
	Evil = { amp = 18, macro = 34, freq = 200, water = 2, rough = 0.7, lava = true, town = "dark", river = true, lakes = 1, forest = 0.2, giants = 0, farms = 0, tree = "dead", mix = {}, terrace = 10 },
	Fjord = { base = 22, amp = 16, macro = 50, freq = 240, water = 1, rough = 0.6, town = "norse", sea = true, river = true, fjord = true, lakes = 0, forest = 0.38, giants = 0, farms = 4, tree = "pine", mix = { "birch" }, terrace = 14, snowLine = 96 },
	Giantwood = { amp = 10, macro = 22, freq = 260, water = 1, rough = 0.3, town = "walled", river = true, lakes = 1, forest = 0.5, giants = 46, farms = 3, tree = "oak", mix = { "pine", "birch" } },
}
Land.BIOME_SHAPE = BIOME_SHAPE

local ROAD_LOOK = {
	Desert = { rgb(214, 186, 136), M.Sand },
	Frost = { rgb(196, 198, 206), M.Snow },
	Volcanic = { rgb(64, 54, 54), M.Basalt },
	Evil = { rgb(56, 40, 44), M.Basalt },
	Crystal = { rgb(150, 146, 176), M.Ground },
	Swamp = { rgb(96, 82, 60), M.Ground },
	Fjord = { rgb(128, 112, 92), M.Ground },
}

-- ------------------------------------------------------------------ geometry
local function segDist(px: number, pz: number, ax: number, az: number, bx: number, bz: number): (number, number)
	local abx, abz = bx - ax, bz - az
	local l2 = abx * abx + abz * abz
	local t = if l2 > 0 then math.clamp(((px - ax) * abx + (pz - az) * abz) / l2, 0, 1) else 0
	local dx, dz = px - (ax + abx * t), pz - (az + abz * t)
	return math.sqrt(dx * dx + dz * dz), t
end

local function polyNearest(pts, x: number, z: number): number
	local best = math.huge
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local d = segDist(x, z, a.X, a.Z, b.X, b.Z)
		if d < best then
			best = d
		end
	end
	return best
end

local function flat(v: Vector3): Vector3
	return V(v.X, 0, v.Z)
end

-- ------------------------------------------------------------------ terrain
local function natural(plan, x: number, z: number): number
	local shape = plan.shape
	local sd = plan.seed
	local f = shape.freq
	local macro = (shape.base or 12) + Util.fbm(x / (f * 3.4), z / (f * 3.4), 3, sd + 11) * shape.macro
	local h
	if plan.biome == "Desert" then
		local dune = math.abs(math.sin(x / 95 + Util.noise(x / 320, z / 320, sd) * 3.2))
		h = macro + dune * 12 + Util.fbm(x / f, z / f, 3, sd + 5) * shape.amp
	else
		h = macro + Util.fbm(x / f, z / f, 3, sd + 31) * shape.amp + (Util.ridge(x / (f * 0.6), z / (f * 0.6), 2, sd + 7) - 0.5) * shape.amp * shape.rough
	end
	-- shallow lows: a few ponds, not a drowned land (the swamp is allowed to drown)
	local lowLine = shape.water + 5
	if not shape.wet and h < lowLine then
		h = lowLine - (lowLine - h) * 0.35
	end
	if shape.terrace and h > 14 then
		-- plateaus joined by steep steps: cubic cliffs
		local t = shape.terrace
		local b = math.floor(h / t) * t
		local fr = (h - b) / t
		h = b + t * Util.smooth(math.clamp((fr - 0.5) / 0.5, 0, 1))
	end
	return h
end
Land.natural = natural

local function borderRise(plan, x: number, z: number): number
	local inner = plan.inner
	local ex = math.abs(x) - inner
	if plan.coastX and x < 0 then
		ex = -1e9 -- the west is open sea
	end
	local ez = math.abs(z) - inner
	local e = math.max(ex, ez)
	if e < -60 then
		return 0
	end
	local k = math.clamp((e + 60) / 260, 0, 1)
	local amt = 170 + Util.ridge(x / 170, z / 170, 3, plan.seed + 3) * 170
	if ez >= ex then
		-- the passes: valleys through the mountains, south (in) and north (out)
		local p = Util.smooth(math.clamp((math.abs(x) - 60) / 200, 0, 1))
		amt *= 0.18 + 0.82 * p
	end
	return k * k * amt
end

local function seaCut(plan, x: number, z: number, h: number): number
	local cx = plan.coastX(z)
	if x > cx + 70 then
		return h
	end
	local k = Util.smooth(math.clamp((x - (cx - 20)) / 90, 0, 1))
	local floor = plan.water - 6 - math.clamp((cx - x) / 60, 0, 1) * 12
	return math.min(h, Util.lerp(floor, h, k))
end

local function roadNear(plan, x: number, z: number): (number?, number, number)
	local bucket = plan.roadHash[math.floor(x / HASH) * 65536 + math.floor(z / HASH)]
	if not bucket then
		return nil, 0, 0
	end
	local best, bh, bw = math.huge, 0, 0
	for _, s in bucket do
		local d, t = segDist(x, z, s.ax, s.az, s.bx, s.bz)
		local e = d - s.w
		if e < best then
			best = e
			bh = s.ha + (s.hb - s.ha) * t
			bw = s.w
		end
	end
	return best, bh, bw
end
Land.roadNear = roadNear

-- final walkable terrain height at (x, z) and what covers it ("road", "shoulder", "pad")
function Land.terrainAt(plan, x: number, z: number): (number, string?)
	local h = natural(plan, x, z)
	if plan.coastX then
		h = seaCut(plan, x, z, h)
	end
	h += borderRise(plan, x, z)
	local inPad = false
	for _, p in plan.pads do
		local dx, dz = x - p.pos.X, z - p.pos.Z
		local reach = p.r + p.blend
		if math.abs(dx) < reach and math.abs(dz) < reach then
			local d = math.sqrt(dx * dx + dz * dz)
			if d < reach then
				local k = Util.smooth(1 - math.clamp((d - p.r) / p.blend, 0, 1))
				h = Util.lerp(h, p.h, k)
				if d < p.r - 4 then
					inPad = true
				end
			end
		end
	end
	for _, l in plan.lakes do
		local dx, dz = x - l.pos.X, z - l.pos.Z
		if math.abs(dx) < l.r + 60 and math.abs(dz) < l.r + 60 then
			local d = math.sqrt(dx * dx + dz * dz) + Util.noise(x / 40, z / 40, plan.seed) * 14
			if d < l.r then
				h = math.min(h, l.level - 3 - (1 - d / l.r) * 4)
			elseif d < l.r + 50 then
				h = math.min(h, Util.lerp(l.level + 0.5, h, Util.smooth((d - l.r) / 50)))
			end
		end
	end
	local chan = false
	for _, r in plan.rivers do
		if x > r.x0 - 80 and x < r.x1 + 80 and z > r.z0 - 80 and z < r.z1 + 80 then
			local d = polyNearest(r.pts, x, z)
			if d < r.w then
				h = math.min(h, plan.water - r.depth * (1 - (d / r.w) ^ 2 * 0.6))
				chan = true
			elseif d < r.w + 36 then
				h = math.min(h, Util.lerp(plan.water + 0.5, h, Util.smooth((d - r.w) / 36)))
				if d < r.w + 3 then
					chan = true
				end
			end
		end
	end
	if chan then
		return h, "water"
	end
	if inPad then
		return h, "pad"
	end
	local e, rh = roadNear(plan, x, z)
	if e then
		if e < 9 then
			return rh - 1.6, "road"
		elseif e < 50 then
			return Util.lerp(h, rh - 1.6, Util.smooth(1 - (e - 9) / 41)), "shoulder"
		end
	end
	return h, nil
end

function Land.forestAt(plan, x: number, z: number): number
	return (Util.fbm(x / 520, z / 520, 3, plan.seed + 55) + 1) / 2
end

-- ------------------------------------------------------------------ plan
-- Lays out POIs, rivers, lakes and the road network before any terrain exists.
function Land.plan(index: number, bible, seed: number)
	local rng = RNG.new(seed):fork("land", index)
	local info = bible.lands[index]
	local biome = info.biome
	local shape = BIOME_SHAPE[biome] or BIOME_SHAPE.Meadow
	local size = 2200 + index * 200
	local half = size / 2
	local inner = half - BORDER
	local plan = {
		index = index,
		info = info,
		biome = biome,
		shape = shape,
		size = size,
		half = half,
		inner = inner,
		pois = {},
		pads = {},
		roads = {},
		rivers = {},
		lakes = {},
		farms = {},
		wilds = {},
		roadHash = {},
		rng = rng,
		seed = (seed + index * 7919) % 100000,
		water = shape.water,
		lakeLevel = if shape.water > 0 then shape.water else 3,
	}
	if shape.sea then
		local sd = plan.seed
		plan.coastX = function(z: number): number
			return -inner + 430 + Util.fbm(z / 420, 0.37, 3, sd + 91) * 150
		end
	end
	-- rivers first: everything else keeps clear of the water
	if shape.river then
		local zr = rng:float(-inner * 0.22, inner * 0.06)
		local phase = rng:angle()
		local x0, x1 = -half - 60, half + 60
		local w, depth = rng:float(11, 15), 5
		if shape.fjord then
			x0 = plan.coastX(zr) - 260
			x1 = rng:float(inner * 0.1, inner * 0.4)
			w, depth = 30, 14
		end
		local pts = {}
		local n = math.ceil((x1 - x0) / 80)
		for i = 0, n do
			local x = x0 + (x1 - x0) * i / n
			local z = zr + math.sin(x / 360 + phase) * 85 + Util.noise(x / 240, 0.61, plan.seed + 13) * 70
			table.insert(pts, V(x, 0, z))
		end
		local r = { pts = pts, w = w, depth = depth, x0 = math.huge, x1 = -math.huge, z0 = math.huge, z1 = -math.huge }
		for _, p in pts do
			r.x0, r.x1 = math.min(r.x0, p.X), math.max(r.x1, p.X)
			r.z0, r.z1 = math.min(r.z0, p.Z), math.max(r.z1, p.Z)
		end
		table.insert(plan.rivers, r)
	end
	local function riverDist(p: Vector3): number
		local best = math.huge
		for _, r in plan.rivers do
			best = math.min(best, polyNearest(r.pts, p.X, p.Z) - r.w)
		end
		return best
	end
	plan.riverDist = riverDist
	local function add(kind: string, pos: Vector3, r: number)
		local p = { kind = kind, pos = pos, r = r, id = kind .. "_" .. index .. "_" .. (#plan.pois + 1) }
		table.insert(plan.pois, p)
		return p
	end
	local function free(pos: Vector3, r: number, gap: number): boolean
		local lim = inner - r - 70
		if math.abs(pos.X) > lim or math.abs(pos.Z) > lim then
			return false
		end
		for _, q in plan.pois do
			if Util.flatDist(pos, q.pos) < r + q.r + gap then
				return false
			end
		end
		for _, l in plan.lakes do
			if Util.flatDist(pos, l.pos) < r + l.r + 50 then
				return false
			end
		end
		if riverDist(pos) < r + 50 then
			return false
		end
		if plan.coastX and pos.X - r < plan.coastX(pos.Z) + 60 then
			return false
		end
		return true
	end
	local function place(kind: string, r: number, zone, gap: number?)
		for tries = 1, 500 do
			local g = if tries > 300 then 0 else (gap or 40)
			local p = V(rng:float(-inner + r + 80, inner - r - 80), 0, rng:float(zone[1], zone[2]))
			if free(p, r, g) then
				return add(kind, p, r)
			end
		end
		return add(kind, V(rng:float(-inner * 0.5, inner * 0.5), 0, rng:float(zone[1], zone[2])), r)
	end
	-- the fixed skeleton: pass in, town, fortress (or the tower), pass out
	plan.entry = V(0, 0, inner - 40)
	plan.exit = V(0, 0, -inner + 50)
	local entryPoi = add("entry", plan.entry, 55)
	local exitPoi = add("exit", plan.exit, 70)
	local style = shape.town
	local wallR = if style == "norse" or style == "stilt" then 128 elseif style == "desert" then 120 else 150
	local townR = if style == "walled" or style == "timber" or style == "stone" then wallR + 110 else wallR + 62
	local tz = inner - 470
	local tx = rng:float(-inner * 0.28, inner * 0.28)
	if plan.coastX then
		-- a harbour town: the west edge of the town reaches into the sea
		tx = plan.coastX(tz) + townR - 70
	end
	local T = add("town", V(tx, 0, tz), townR)
	T.wallR = wallR
	T.style = style
	plan.town = T
	local goal
	if index == 6 then
		plan.tower = add("endless", V(0, 0, -inner + 400), 160)
		goal = plan.tower
	else
		local cx = rng:float(-inner * 0.4, inner * 0.4)
		if plan.coastX then
			cx = math.max(cx, plan.coastX(-inner + 430) + 280)
		end
		plan.castle = add("castle", V(cx, 0, -inner + 430), 150)
		goal = plan.castle
	end
	-- farmsteads around the town
	local nf = if index == 6 then 0 else shape.farms or 2
	for _ = 1, nf do
		for _ = 1, 150 do
			local a = rng:angle()
			local d = rng:float(T.r + 140, T.r + 400)
			local p = T.pos + V(math.sin(a) * d, 0, math.cos(a) * d)
			if free(p, 95, 30) then
				table.insert(plan.farms, add("farm", p, 95))
				break
			end
		end
	end
	plan.dungeon = place("dungeon", 50, { -inner + 500, inner - 620 })
	plan.monsterTower = place("mtower", 50, { -inner + 500, inner - 620 })
	plan.camps = {}
	for _ = 1, (if index == 6 then 5 else 4) do
		table.insert(plan.camps, place("camp", 60, { -inner + 420, inner - 560 }))
	end
	plan.shrines = {}
	for _ = 1, 3 do
		table.insert(plan.shrines, place("shrine", 30, { -inner + 260, inner - 260 }))
	end
	plan.ruins = {}
	for _ = 1, 2 do
		table.insert(plan.ruins, place("ruin", 60, { -inner + 300, inner - 300 }))
	end
	if index == 6 or rng:chance(0.75) then
		plan.battlefield = place("battle", 80, { -inner + 420, inner - 560 })
	end
	if (shape.giants or 0) > 0 and biome ~= "Giantwood" then
		plan.grove = place("grove", 170, { -inner + 400, inner - 500 }, 10)
		plan.grove.nopad = true
	end
	-- lakes (desert: oases with their own water)
	for _ = 1, shape.lakes or 0 do
		for _ = 1, 200 do
			local r = rng:float(80, 130)
			local p = V(rng:float(-inner + 300, inner - 300), 0, rng:float(-inner + 300, inner - 300))
			if free(p, r, 30) then
				table.insert(plan.lakes, { pos = p, r = r, level = plan.lakeLevel, oasis = shape.water <= 0 })
				break
			end
		end
	end
	-- pads: every POI sits on flat ground at the average natural height around it
	local minH = math.max(plan.water, 0) + 5
	for _, p in plan.pois do
		if not p.nopad then
			local s = 0
			for k = 0, 8 do
				local a = k / 8 * TAU
				local rr = if k == 0 then 0 else p.r * 0.6
				s += natural(plan, p.pos.X + math.sin(a) * rr, p.pos.Z + math.cos(a) * rr)
			end
			local h = math.clamp(s / 9, minH, 64)
			if p == T and plan.coastX then
				h = math.min(h, plan.water + 9)
			end
			h = math.floor(h / 2 + 0.5) * 2
			p.h = h
			p.pos = V(p.pos.X, h, p.pos.Z)
			p.ground = p.pos
			local big = p.kind == "town" or p.kind == "castle" or p.kind == "endless"
			table.insert(plan.pads, { pos = p.pos, r = p.r, h = h, blend = if big then 60 else 40, poi = p })
		end
	end
	plan.entry = entryPoi.pos
	plan.exit = exitPoi.pos

	-- ------------------------------------------------------------ roads
	local function densify(ctrl, wiggle: number)
		local cps = { ctrl[1] }
		for i = 1, #ctrl - 1 do
			local a, b = flat(ctrl[i]), flat(ctrl[i + 1])
			local d = b - a
			local len = d.Magnitude
			local n = math.max(1, math.floor(len / 170))
			local perp = if len > 0 then V(-d.Z, 0, d.X) / len else V()
			for k = 1, n - 1 do
				table.insert(cps, a + d * (k / n) + perp * rng:float(-wiggle, wiggle))
			end
			table.insert(cps, b)
		end
		local pts = { flat(cps[1]) }
		for i = 1, #cps - 1 do
			local a, b = flat(cps[i]), flat(cps[i + 1])
			local n = math.max(1, math.floor((b - a).Magnitude / 16 + 0.5))
			for k = 1, n do
				table.insert(pts, a:Lerp(b, k / n))
			end
		end
		return pts
	end
	local function avoidList(except)
		local list = {}
		for _, p in plan.pois do
			if not except[p] and not p.nopad then
				table.insert(list, { pos = p.pos, r = p.r + 26 })
			end
		end
		for _, l in plan.lakes do
			table.insert(list, { pos = l.pos, r = l.r + 34 })
		end
		return list
	end
	local function relax(pts, avoid)
		for _ = 1, 4 do
			for i = 2, #pts - 1 do
				local q = (pts[i - 1] + pts[i] * 2 + pts[i + 1]) / 4
				for _, o in avoid do
					local dx, dz = q.X - o.pos.X, q.Z - o.pos.Z
					local d = math.sqrt(dx * dx + dz * dz)
					if d < o.r and d > 0.01 then
						q = V(o.pos.X + dx / d * o.r, 0, o.pos.Z + dz / d * o.r)
					end
				end
				pts[i] = q
			end
		end
	end
	local minRoad = plan.lakeLevel + 3
	local function road(ctrl, w: number, kind: string, wiggle: number, except, startH: number?)
		local pts = densify(ctrl, wiggle)
		relax(pts, avoidList(except))
		local n = #pts
		local hs = {}
		for i, p in pts do
			hs[i] = math.max(natural(plan, p.X, p.Z) + borderRise(plan, p.X, p.Z), minRoad)
		end
		for _ = 1, 3 do
			local o = table.clone(hs)
			for i = 1, n do
				local s = 0
				for k = -4, 4 do
					s += o[math.clamp(i + k, 1, n)]
				end
				hs[i] = s / 9
			end
		end
		local fixed = {}
		-- flat inside pads
		for i, p in pts do
			for _, pad in plan.pads do
				if Util.flatDist(p, pad.pos) < pad.r - 4 then
					fixed[i] = pad.h
					break
				end
			end
		end
		if startH then
			fixed[1] = startH
		end
		-- bridges: level runs over the water at the higher bank + clearance
		local bridges = {}
		local i = 1
		while i <= n do
			if riverDist(pts[i]) < 6 then
				local i0 = i
				while i <= n and riverDist(pts[i]) < 6 do
					i += 1
				end
				local i1 = i - 1
				local a, b = math.max(1, i0 - 1), math.min(n, i1 + 1)
				local deck = math.max(plan.water + 6, hs[a], hs[b])
				for k = math.max(1, i0 - 3), math.min(n, i1 + 3) do
					fixed[k] = deck
				end
				table.insert(bridges, { i0 = i0, i1 = i1, a = a, b = b })
			else
				i += 1
			end
		end
		for k, v in fixed do
			hs[k] = v
		end
		local m = 16 * ROAD_SLOPE
		for _ = 1, 2 do
			for k = 2, n do
				if not fixed[k] then
					hs[k] = math.clamp(hs[k], hs[k - 1] - m, hs[k - 1] + m)
				end
			end
			for k = n - 1, 1, -1 do
				if not fixed[k] then
					hs[k] = math.clamp(hs[k], hs[k + 1] - m, hs[k + 1] + m)
				end
			end
		end
		local r = { pts = pts, hs = hs, w = w, kind = kind, bridges = bridges }
		table.insert(plan.roads, r)
		-- spatial hash of the segments (with the reach of the shoulder blend)
		for k = 1, n - 1 do
			local a, b = pts[k], pts[k + 1]
			local s = { ax = a.X, az = a.Z, bx = b.X, bz = b.Z, ha = hs[k], hb = hs[k + 1], w = w }
			local pad = w + 52
			local gx0, gx1 = math.floor((math.min(a.X, b.X) - pad) / HASH), math.floor((math.max(a.X, b.X) + pad) / HASH)
			local gz0, gz1 = math.floor((math.min(a.Z, b.Z) - pad) / HASH), math.floor((math.max(a.Z, b.Z) + pad) / HASH)
			for gx = gx0, gx1 do
				for gz = gz0, gz1 do
					local key = gx * 65536 + gz
					local bucket = plan.roadHash[key]
					if not bucket then
						bucket = {}
						plan.roadHash[key] = bucket
					end
					table.insert(bucket, s)
				end
			end
		end
		return r
	end
	local function clampX(x: number, z: number): number
		local lo = -inner + 200
		if plan.coastX then
			lo = math.max(lo, plan.coastX(z) + 160)
		end
		return math.clamp(x, lo, inner - 200)
	end
	local gateS = T.pos + V(0, 0, wallR + 6)
	local gateN = T.pos - V(0, 0, wallR + 6)
	road({ plan.entry, gateS }, 7, "main", 60, { [entryPoi] = true, [T] = true })
	local front = goal.pos + V(0, 0, if plan.castle then 104 else 124)
	local function between(t: number): Vector3
		local z = Util.lerp(gateN.Z, front.Z, t)
		return V(clampX(Util.lerp(gateN.X, front.X, t) + rng:float(-inner * 0.25, inner * 0.25), z), 0, z)
	end
	plan.mainRoad = road({ gateN, between(0.33), between(0.68), front }, 7, "main", 80, { [T] = true, [goal] = true })
	-- the way out: leaves the main road before the fortress and swings around it
	local junction = goal.pos + V(0, 0, goal.r + 80)
	local jBest, jIdx = math.huge, #plan.mainRoad.pts
	for k, p in plan.mainRoad.pts do
		local d = Util.flatDist(p, junction)
		if d < jBest then
			jBest, jIdx = d, k
		end
	end
	local side = if goal.pos.X > 0 then -1 else 1
	if plan.coastX and goal.pos.X - goal.r - 120 < plan.coastX(goal.pos.Z) then
		side = 1
	end
	local jp = plan.mainRoad.pts[jIdx]
	road({ jp, V(goal.pos.X + side * (goal.r + 100), 0, goal.pos.Z), plan.exit }, 6, "main", 20, { [goal] = true, [exitPoi] = true }, plan.mainRoad.hs[jIdx])
	plan.junctions = { { pos = jp, h = plan.mainRoad.hs[jIdx] } }
	-- branches to everything people would walk to
	local function nearestMain(p: Vector3)
		local best, bp, bh = math.huge, nil, 0
		for _, r in plan.roads do
			if r.kind == "main" then
				for k = 1, #r.pts, 2 do
					local d = Util.flatDist(r.pts[k], p)
					if d < best then
						best, bp, bh = d, r.pts[k], r.hs[k]
					end
				end
			end
		end
		return bp, best, bh
	end
	local targets = { plan.dungeon, plan.monsterTower }
	for _, f in plan.farms do
		table.insert(targets, f)
	end
	for _, rr in plan.ruins do
		table.insert(targets, rr)
	end
	if plan.battlefield then
		table.insert(targets, plan.battlefield)
	end
	for _, target in targets do
		local from, d, fh = nearestMain(target.pos)
		if from and d > target.r + 40 then
			local except = { [target] = true }
			for _, p in plan.pois do
				if Util.flatDist(from, p.pos) < p.r + 40 then
					except[p] = true
				end
			end
			local dir = flat(from - target.pos).Unit
			local stop = flat(target.pos) + dir * target.r * 0.45
			local w = if target.kind == "farm" then 4 else 5
			local br = road({ from, stop }, w, "branch", 40, except, fh)
			target.road = br
			target.roadDir = dir
			table.insert(plan.junctions, { pos = from, h = fh, to = target })
		end
	end
	return plan
end

-- ------------------------------------------------------------------ small builders
local function fenceLine(parent, a: Vector3, b: Vector3, groundY, col: Color3)
	local d = flat(b - a)
	local len = d.Magnitude
	local n = math.max(1, math.floor(len / 10))
	for i = 0, n do
		local p = a + d * (i / n)
		Kit.part(parent, V(0.6, 3.4, 0.6), CF(p.X, groundY(p.X, p.Z) + 1.7, p.Z), col, M.WoodPlanks)
	end
	local ya, yb = groundY(a.X, a.Z), groundY(b.X, b.Z)
	for _, yy in { 1.3, 2.7 } do
		local pa, pb = V(a.X, ya + yy, a.Z), V(b.X, yb + yy, b.Z)
		Kit.deco(parent, V(0.3, 0.35, (pb - pa).Magnitude), CFrame.lookAt((pa + pb) / 2, pb), col, M.WoodPlanks, { CastShadow = false })
	end
end

local function palm(parent, pos: Vector3, rng)
	local m = Kit.model("Palm", parent)
	local h = rng:float(12, 18)
	local c = CF(pos) * ANG(0, rng:angle(), 0) * ANG(rng:float(-0.25, 0.25), 0, 0)
	for i = 0, 3 do
		Kit.part(m, V(1.2 - i * 0.1, h / 4 + 0.3, 1.2 - i * 0.1), c * CF(0, h / 8 + i * h / 4, 0), Palette.shade(rgb(140, 110, 72), 1 + (i % 2) * 0.08), M.WoodPlanks)
	end
	local top = c * CF(0, h, 0)
	for i = 1, 6 do
		Kit.deco(m, V(1.6, 0.3, 7), top * ANG(0, i / 6 * TAU, 0) * ANG(-0.35, 0, 0) * CF(0, 0, -3.2), Palette.shade(rgb(80, 150, 70), rng:float(0.9, 1.1)), M.Grass)
	end
	return m
end

-- flat-roofed mud-brick house (desert towns)
local function adobe(parent, cf: CFrame, w: number, d: number, rng, o)
	local B = S.Build
	local m = Kit.model(o.name or "Adobe", parent)
	local wall = rng:pick({ rgb(222, 196, 150), rgb(210, 184, 140), rgb(230, 206, 164) })
	local h = rng:pick({ 9, 10, 14 })
	local doorW, doorH, t = 3.6, 6.5, 1
	local side = (w - doorW) / 2
	B.solid(m, V(side, h, t), cf * CF(-(doorW / 2 + side / 2), h / 2, -d / 2 + t / 2), wall, M.Sandstone)
	B.solid(m, V(side, h, t), cf * CF(doorW / 2 + side / 2, h / 2, -d / 2 + t / 2), wall, M.Sandstone)
	B.solid(m, V(doorW, h - doorH, t), cf * CF(0, doorH + (h - doorH) / 2, -d / 2 + t / 2), wall, M.Sandstone)
	B.solid(m, V(w, h, t), cf * CF(0, h / 2, d / 2 - t / 2), wall, M.Sandstone)
	for _, sx in { -1, 1 } do
		B.solid(m, V(t, h, d - 2 * t), cf * CF(sx * (w / 2 - t / 2), h / 2, 0), wall, M.Sandstone)
	end
	B.solid(m, V(w, 0.8, d), cf * CF(0, h + 0.4, 0), Palette.shade(wall, 0.95), M.Sandstone)
	for _, sx in { -1, 1 } do
		B.deco(m, V(0.8, 1.4, d), cf * CF(sx * (w / 2 - 0.4), h + 1.5, 0), wall, M.Sandstone)
		B.deco(m, V(w, 1.4, 0.8), cf * CF(0, h + 1.5, sx * (d / 2 - 0.4)), wall, M.Sandstone)
		B.deco(m, V(1.6, 1.6, 0.2), cf * CF(sx * (w / 4 + 1), h * 0.6, -d / 2 - 0.05), rgb(40, 30, 26))
	end
	for i = 1, 4 do
		B.deco(m, V(0.5, 0.5, 1.6), cf * CF(-w / 2 + i * w / 5, h - 1, -d / 2 - 0.6), rgb(110, 80, 52), M.WoodPlanks)
	end
	if rng:chance(0.6) then
		B.deco(m, V(doorW + 3, 0.2, 3), cf * CF(0, doorH + 0.8, -d / 2 - 1.4) * ANG(0.25, 0, 0), rng:pick({ rgb(190, 60, 50), rgb(60, 120, 170), rgb(220, 180, 70) }), M.Fabric)
	end
	return m, (cf * CF(0, 0, -d / 2 - 3)).Position
end

-- swamp house: a thatched longhouse on stilts with a ramp to the door
local function stiltHouse(parent, cf: CFrame, w: number, d: number, rng, o)
	local B = S.Build
	local lift = 5
	local L = d + 8
	local m = B.longhouse(parent, cf * CF(0, lift, 0), { len = L, w = w - 2, turf = false, rng = rng, name = o.name })
	for _, sx in { -1, 1 } do
		for k = -1, 1 do
			B.solid(m, V(1, lift + 1, 1), cf * CF(sx * (w / 2 - 1.5), (lift + 1) / 2 - 0.5, k * L / 3), rgb(70, 54, 40), M.WoodPlanks)
		end
	end
	local bottom = (cf * CF(0, 0.3, -L / 2 - 9)).Position
	local top = (cf * CF(0, lift + 0.8, -L / 2 - 0.5)).Position
	B.solid(m, V(3.6, 0.6, (top - bottom).Magnitude), CFrame.lookAt((bottom + top) / 2, top), rgb(96, 72, 50), M.WoodPlanks)
	return m, (cf * CF(0, 0, -L / 2 - 11)).Position
end

-- ------------------------------------------------------------------ town
local ROOFS = {
	Meadow = { rgb(150, 70, 50), rgb(136, 60, 40), rgb(170, 90, 60), rgb(120, 56, 44), rgb(90, 84, 90) },
	Autumn = { rgb(170, 80, 36), rgb(150, 64, 34), rgb(120, 70, 44), rgb(180, 110, 50) },
	Mushroom = { rgb(200, 60, 60), rgb(230, 220, 200), rgb(180, 50, 60) },
	Giantwood = { rgb(90, 84, 90), rgb(110, 76, 56), rgb(80, 110, 60), rgb(136, 60, 40) },
	Crystal = { rgb(120, 90, 200), rgb(80, 110, 190), rgb(150, 110, 210) },
	Volcanic = { rgb(110, 30, 30), rgb(60, 40, 44), rgb(90, 24, 26) },
	Evil = { rgb(110, 30, 30), rgb(40, 30, 34), rgb(90, 24, 26) },
}

local function buildTown(ctx, p)
	local W, B, N = S.World, S.Build, S.Nature
	local rng, city, props, biome = ctx.rng, ctx.city, ctx.props, ctx.biome
	local g = p.pos
	local R = p.wallR
	local style = p.style
	local refs = { spots = {}, houses = {} }
	local norse = style == "norse" or style == "stilt"
	local plazaC = if style == "desert" then rgb(214, 190, 150) elseif style == "dark" then rgb(70, 60, 62) elseif norse then rgb(118, 98, 74) else rgb(158, 150, 138)
	local plazaM = if norse then M.Ground elseif style == "desert" then M.Sandstone else M.Cobblestone
	local roofs = ROOFS[biome] or ROOFS.Meadow
	local stoneWall = if style == "dark" then rgb(70, 60, 62) elseif style == "desert" then rgb(214, 190, 146) elseif style == "stone" then rgb(222, 222, 232) else rgb(186, 178, 164)
	-- plaza + streets
	W.solid(city, V(66, 0.4, 66), CF(g + V(0, 0.2, 0)), plazaC, plazaM)
	W.solid(city, V(66, 0.4, 66), CF(g + V(0, 0.21, 0)) * ANG(0, math.pi / 4, 0), Palette.shade(plazaC, 0.96), plazaM)
	local streetW = 12
	for k = 0, 3 do
		local a = k * math.pi / 2
		local dir = V(math.sin(a), 0, math.cos(a))
		local len = R - 26 + 14
		local mid = g + dir * (30 + len / 2) + V(0, 0.15, 0)
		W.solid(city, V(streetW, 0.3, len), CFrame.lookAt(mid, mid + dir), plazaC, plazaM)
	end
	local ringR = math.floor(R * 0.62)
	for k = 0, 23 do
		local a0, a1 = k / 24 * TAU, (k + 1) / 24 * TAU
		local p0 = g + V(math.sin(a0) * ringR, 0.14, math.cos(a0) * ringR)
		local p1 = g + V(math.sin(a1) * ringR, 0.14, math.cos(a1) * ringR)
		W.solid(city, V(9, 0.28, (p1 - p0).Magnitude + 1), CFrame.lookAt((p0 + p1) / 2, p1), Palette.shade(plazaC, 0.94), plazaM)
	end
	local function nearStreet(a: number, halfW: number, rr: number): boolean
		for k = 0, 3 do
			local diff = math.abs(((a - k * math.pi / 2 + math.pi) % TAU) - math.pi)
			if diff * rr < streetW / 2 + halfW + 2 then
				return true
			end
		end
		return false
	end
	local function house(cf: CFrame, w: number, d: number, o)
		if style == "timber" or style == "walled" then
			return B.halfTimber(city, cf, { w = w, d = d, floors = o.floors or rng:int(2, 3), rng = rng, sign = o.sign, roof = rng:pick(roofs), name = o.name })
		elseif style == "norse" then
			return B.longhouse(city, cf, { len = d + 12, w = w - 2, turf = biome ~= "Frost" or rng:chance(0.35), rng = rng, name = o.name })
		elseif style == "stilt" then
			return stiltHouse(city, cf, w, d, rng, o)
		elseif style == "desert" then
			return adobe(city, cf, w, d, rng, o)
		end
		local wall = if style == "dark" then Palette.jitter(rgb(74, 64, 66), 0.1, rng:float()) else Palette.jitter(rgb(214, 214, 226), 0.05, rng:float())
		return B.stoneHouse(city, cf, { w = w, d = d, floors = o.floors or rng:int(2, 3), wall = wall, roof = rng:pick(roofs), rng = rng, name = o.name })
	end
	local function garden(pos: Vector3, facing: CFrame)
		local roll = rng:float()
		if norse then
			if roll < 0.4 then
				B.woodpile(props, facing * CF(0, 0, 2))
			elseif roll < 0.7 then
				-- fish-drying rack
				for _, sx in { -3, 3 } do
					Kit.part(props, V(0.5, 5, 0.5), facing * CF(sx, 2.5, 0), rgb(90, 66, 44), M.WoodPlanks)
				end
				Kit.deco(props, V(7, 0.3, 0.3), facing * CF(0, 4.8, 0), rgb(90, 66, 44), M.WoodPlanks)
				for i = -2, 2 do
					Kit.deco(props, V(0.5, 1.6, 0.3), facing * CF(i * 1.2, 3.8, 0), rgb(180, 170, 150), M.SmoothPlastic)
				end
			else
				B.hayBale(props, facing * CF(0, 0, 0))
				W.barrel(props, facing * CF(3, 0, 1))
			end
		elseif style == "desert" then
			if roll < 0.5 then
				palm(props, pos, rng)
			else
				W.barrel(props, facing)
				W.crate(props, facing * CF(2.6, 0, 0.6))
			end
		else
			if roll < 0.35 then
				N.oak(props, pos, rng, rng:float(0.7, 0.95), ctx.pal)
			elseif roll < 0.55 then
				B.laundry(props, (facing * CF(-4, 0, 0)).Position, (facing * CF(4, 0, 0)).Position)
			elseif roll < 0.75 then
				B.woodpile(props, facing)
			else
				B.cart(props, facing)
			end
		end
	end
	-- two rings of houses: inner ring faces the plaza, outer ring faces the ring street
	-- inner block (plaza -> ring street) gets two rows back to back when it is deep
	-- enough, the outer block one row facing the ring street
	local innerDepth = ringR - 5 - 34
	local rings = {}
	if innerDepth >= 40 and not norse then
		table.insert(rings, { rr = 34 + 8, depth = 14, fill = 0.8, id = 1 })
		table.insert(rings, { rr = ringR - 5 - 8, depth = 14, fill = 0.8, id = 1, out = true })
	else
		table.insert(rings, { rr = math.floor((34 + ringR - 5) / 2), depth = innerDepth - 6, fill = 0.75, id = 1 })
	end
	table.insert(rings, { rr = math.floor((ringR + 5 + R - 14) / 2), depth = R - 14 - ringR - 5 - 6, fill = 0.85, id = 2 })
	local innAngle = math.atan2(-16, -6) % TAU -- towards the innkeeper
	local placedInn, placedHall = false, false
	for _, ring in rings do
		local ri = ring.id
		local rr = ring.rr
		local a = rng:float(0, 0.3)
		while a < TAU - 0.05 do
			local w = if norse then rng:int(11, 13) else rng:int(12, 16)
			local d = math.min(if norse then ring.depth - 12 else rng:int(10, 13), ring.depth)
			local o = {}
			local special = nil
			if ri == 1 and not placedInn and math.abs(((a - innAngle + math.pi) % TAU) - math.pi) < 0.35 then
				special = "inn"
				w, o.sign, o.floors, o.name = 18, true, 3, "Inn"
				placedInn = true
			elseif ri == 2 and not placedHall and math.abs(((a - math.pi * 1.25 + math.pi) % TAU) - math.pi) < 0.2 then
				special = "hall"
				w = if norse then 18 else 22
				placedHall = true
			end
			local step = (w + 5) / rr
			local am = a + step / 2
			if not nearStreet(am, w / 2, rr) then
				local dir = V(math.sin(am), 0, math.cos(am))
				local pos = g + dir * rr
				local cf = if ring.out then CFrame.lookAt(pos, pos + dir) else CFrame.lookAt(pos, V(g.X, pos.Y, g.Z))
				if special == "hall" then
					if norse then
						B.longhouse(city, cf * CF(0, 0, 4), { len = math.max(ring.depth + 4, 30), w = 17, wallH = 7, turf = biome ~= "Frost", rng = rng, name = "MeadHall" })
					elseif style == "timber" or style == "walled" then
						B.church(city, cf * CF(0, 0, 2), { rng = rng })
					else
						local mh = house(cf, 20, math.min(18, ring.depth), { floors = 3, name = "Hall" })
						table.insert(refs.houses, mh)
					end
				elseif special or rng:chance(ring.fill) then
					local m, door = house(cf, w, d, o)
					table.insert(refs.houses, m)
					table.insert(refs.spots, door)
				else
					garden(pos, cf)
				end
			end
			a += step
			W.yield(ctx.count)
		end
	end
	-- the plaza: fountain / fire / well, stalls, lanterns, waystone
	if norse then
		W.campfire(city, g + V(0, 0.4, 0))
		for i = 1, 6 do
			local a = i / 6 * TAU
			Kit.part(city, V(4, 1.2, 1.4), CF(g + V(math.sin(a) * 7, 0.9, math.cos(a) * 7)) * ANG(0, a, 0), rgb(100, 74, 50), M.WoodPlanks)
		end
		-- carved pillar with shields
		Kit.part(city, V(1.6, 12, 1.6), CF(g + V(9, 6.4, -9)), rgb(90, 64, 42), M.WoodPlanks)
		Kit.deco(city, V(2.2, 2.2, 2.2), CF(g + V(9, 12.6, -9)) * ANG(0, 0.785, 0), rgb(70, 50, 34), M.WoodPlanks)
	elseif style == "desert" then
		W.well(city, g + V(0, 0.4, 0))
	elseif style == "dark" then
		Kit.part(city, V(5, 3, 5), CF(g + V(0, 1.9, 0)), rgb(40, 34, 36), M.Basalt)
		local fire = Kit.deco(city, V(3, 1, 3), CF(g + V(0, 3.9, 0)), rgb(255, 90, 30), M.Neon)
		Kit.fire(fire, rgb(255, 90, 30), 1.4)
		Kit.pointLight(fire, rgb(255, 110, 50), 40, 2)
	else
		B.fountain(city, g + V(0, 0.4, 0), { color = if style == "stone" then rgb(230, 228, 240) else nil })
	end
	for i = 1, 4 do
		local a = i / 4 * TAU + 0.4
		B.stall(city, CF(g + V(math.cos(a) * 20, 0.4, math.sin(a) * 20)) * ANG(0, -a, 0), rng:pick({ rgb(200, 60, 60), rgb(60, 120, 200), rgb(220, 180, 60), rgb(90, 160, 90) }), rng)
	end
	for k = 0, 3 do
		local a = k * math.pi / 2
		local dir = V(math.sin(a), 0, math.cos(a))
		local perp = V(dir.Z, 0, -dir.X)
		for _, rr in { 52, R - 24 } do
			for _, sx in { -1, 1 } do
				local lp = g + dir * rr + perp * sx * (streetW / 2 + 1.2)
				if norse then
					W.torch(city, CF(lp))
				else
					W.lantern(city, lp)
				end
			end
		end
	end
	-- the wall
	local gates = { 0, math.pi / 2, math.pi, math.pi * 1.5 }
	if style == "walled" or style == "stone" or style == "dark" or style == "desert" then
		local h = if style == "walled" then 46 elseif style == "desert" then 20 elseif style == "dark" then 34 else 30
		local thick = if style == "walled" then 12 elseif style == "desert" then 6 else 9
		local banner = if style == "dark" then rgb(110, 14, 20) elseif style == "stone" then rgb(90, 70, 170) else rgb(40, 70, 130)
		B.greatWall(city, g, R, h, thick, {
			gates = gates,
			gateWidth = streetW + 4,
			gateHeight = math.min(h * 0.62, 22),
			segment = 30,
			cannons = style == "walled",
			name = "TownWall",
			color = stoneWall,
			banner = banner,
			emblem = if style == "walled" then rgb(236, 232, 220) else Palette.metal.gold,
		})
	else
		local pts = {}
		local segs = 44
		for k = 0, segs do
			local a = k / segs * TAU
			table.insert(pts, g + V(math.sin(a) * R, 0, math.cos(a) * R))
		end
		local gaps = {}
		for k = 1, segs do
			local am = (k - 0.5) / segs * TAU
			for _, ga in gates do
				if math.abs(((am - ga + math.pi) % TAU) - math.pi) * R < streetW / 2 + 5 then
					gaps[k] = true
				end
			end
		end
		B.palisade(city, pts, 11, { gaps = gaps, groundY = ctx.groundY, rail = true, step = 3 })
		for _, ga in gates do
			for _, sx in { -1, 1 } do
				local a = ga + sx * (streetW / 2 + 9) / R
				B.watchtower(city, g + V(math.sin(a) * (R - 5), 0, math.cos(a) * (R - 5)), { height = 17 })
			end
		end
	end
	-- farmland ring outside the wall (walled / timber / stone towns)
	local fieldIn, fieldOut = R + 22, p.r - 16
	if fieldOut - fieldIn > 40 then
		local rr = (fieldIn + fieldOut) / 2
		local depth = fieldOut - fieldIn
		local a = rng:float(0, 0.2)
		local mills = 0
		while a < TAU do
			local fw = rng:float(30, 42)
			local step = (fw + 5) / rr
			local am = a + step / 2
			local dir = V(math.sin(am), 0, math.cos(am))
			local pos = g + dir * rr
			local e = roadNear(ctx.plan, pos.X, pos.Z)
			if not nearStreet(am, fw / 2 + 4, rr) and not (e and e < depth / 2 + 4) then
				local cf = CFrame.lookAt(pos, V(g.X, pos.Y, g.Z))
				if mills < 2 and rng:chance(0.12) then
					mills += 1
					B.windmill(props, pos, math.atan2(dir.X, dir.Z), { speed = rng:float(0.3, 0.6) })
				else
					N.field(props, cf, fw, depth, rng:pick({ "wheat", "wheat", "green", "flax" }), rng)
				end
			end
			a += step
		end
	end
	-- harbour: docks and longships on the sea side of the town
	if ctx.plan.coastX then
		for _, dz in { -46, 12, 60 } do
			local base = g + V(-(p.r - 4), 0, dz)
			local dcf = CFrame.lookAt(base, base + V(-1, 0, 0))
			B.dock(city, dcf, 56, 8)
			if dz ~= 12 then
				B.longship(city, CFrame.lookAt(V(base.X - 30, ctx.plan.water + 0.3, base.Z + 10), V(base.X - 60, ctx.plan.water + 0.3, base.Z + 10)), { rng = rng, len = rng:int(34, 42) })
			end
		end
	end
	-- NPC spots (the World chapter populates them)
	refs.center = g
	refs.merchant = CFrame.lookAt(g + V(18, 3, 4), g + V(0, 3, 0))
	refs.innkeeper = CFrame.lookAt(g + V(-16, 3, -6), g + V(0, 3, 0))
	refs.questGiver = CFrame.lookAt(g + V(4, 3, -18), g + V(0, 3, 0))
	refs.elder = CFrame.lookAt(g + V(-6, 3, 16), g + V(0, 3, 0))
	refs.waystone = g + V(0, 0, 26)
	local ws = W.solid(city, V(3, 9, 3), CF(g + V(0, 4.5, 26)) * ANG(0, 0.4, 0), rgb(90, 100, 140), M.Slate)
	local rune = W.deco(city, V(3.2, 1.2, 3.2), CF(g + V(0, 6, 26)) * ANG(0, 0.4, 0), rgb(120, 220, 255), M.Neon)
	Kit.pointLight(rune, rgb(120, 220, 255), 16, 1.2)
	refs.waystonePart = ws
	return refs
end

-- ------------------------------------------------------------------ farmsteads
local function farmstead(ctx, p)
	local W, B, N = S.World, S.Build, S.Nature
	local rng, city, props = ctx.rng, ctx.city, ctx.props
	local g = p.pos
	local toRoad = p.roadDir or flat(ctx.plan.town.pos - g).Unit
	local cf = CFrame.lookAt(g, g + toRoad)
	local norse = ctx.shape.town == "norse" or ctx.shape.town == "stilt"
	-- farmhouse + barn face the road (-Z)
	if norse then
		B.longhouse(city, cf * CF(-16, 0, -4), { len = rng:int(30, 38), w = 13, turf = ctx.biome ~= "Frost", rng = rng, name = "Farmhouse" })
	elseif ctx.shape.town == "desert" then
		adobe(city, cf * CF(-16, 0, -4), 16, 12, rng, { name = "Farmhouse" })
	else
		B.halfTimber(city, cf * CF(-16, 0, -4), { w = 15, d = 12, floors = rng:int(1, 2), rng = rng, name = "Farmhouse" })
	end
	B.longhouse(city, cf * CF(18, 0, 4), { len = 22, w = 13, wallH = 6.5, turf = false, rng = rng, name = "Barn" })
	-- yard
	B.haystack(props, (cf * CF(2, 0, 14)).Position, rng:float(0.8, 1.1))
	B.haystack(props, (cf * CF(-4, 0, 20)).Position, rng:float(0.7, 1))
	B.hayBale(props, cf * CF(8, 0, -14) * ANG(0, 0.3, 0))
	B.hayBale(props, cf * CF(10, 0, -10) * ANG(0, -0.2, 0))
	B.cart(props, cf * CF(4, 0, -8) * ANG(0, 1.2, 0))
	B.woodpile(props, cf * CF(-26, 0, 8) * ANG(0, math.pi / 2, 0))
	W.well(props, (cf * CF(0, 0, -2)).Position)
	-- fields behind the buildings, fenced
	local crop = if ctx.biome == "Desert" then "green" else rng:pick({ "wheat", "wheat", "green", "flax" })
	for _, f in { { -34, 52 }, { 0, 52 }, { 34, 52 } } do
		N.field(props, cf * CF(f[1], 0, f[2]) * ANG(0, math.pi, 0), 30, 42, if rng:chance(0.7) then crop else "green", rng)
	end
	local fc = rgb(120, 92, 62)
	local corners = { cf * CF(-50, 0, 30), cf * CF(50, 0, 30), cf * CF(50, 0, 74), cf * CF(-50, 0, 74) }
	for i = 1, 4 do
		if i ~= 1 then
			fenceLine(props, corners[i].Position, corners[i % 4 + 1].Position, ctx.groundY, fc)
		end
	end
	-- scarecrow
	local sc = cf * CF(rng:float(-30, 30), 0, 52)
	Kit.part(props, V(0.4, 6, 0.4), sc * CF(0, 3, 0), rgb(110, 80, 52), M.WoodPlanks)
	Kit.deco(props, V(5, 0.4, 0.4), sc * CF(0, 4.6, 0), rgb(110, 80, 52), M.WoodPlanks)
	Kit.deco(props, V(1.8, 2.2, 1), sc * CF(0, 4.2, 0), rgb(150, 90, 60), M.Fabric)
	Kit.deco(props, V(1.2, 1.2, 1.2), sc * CF(0, 6, 0), rgb(214, 184, 96), M.Grass)
	Kit.deco(props, V(2.4, 0.3, 2.4), sc * CF(0, 6.7, 0), rgb(190, 160, 90), M.Grass)
	p.yard = (cf * CF(0, 3, -10)).Position
end

-- ------------------------------------------------------------------ POI builders
local function campBuild(ctx, p)
	local W, B = S.World, S.Build
	local rng, props = ctx.rng, ctx.props
	local g = p.pos
	local toRoad = flat(ctx.plan.town.pos - g).Unit
	local gapA = math.atan2(toRoad.X, toRoad.Z)
	local pts, gaps = {}, {}
	local segs = 18
	for k = 0, segs do
		local a = k / segs * TAU
		table.insert(pts, g + V(math.sin(a) * 27, 0, math.cos(a) * 27))
		if k >= 1 and math.abs((((k - 0.5) / segs * TAU - gapA + math.pi) % TAU) - math.pi) < 0.3 then
			gaps[k] = true
		end
	end
	B.palisade(props, pts, 7, { gaps = gaps, groundY = ctx.groundY, step = 3, wood = rgb(84, 62, 44) })
	local tentCol = rng:pick({ rgb(120, 70, 50), rgb(90, 90, 70), rgb(70, 50, 80), rgb(110, 30, 30) })
	for i = 1, rng:int(3, 5) do
		local a = gapA + math.pi + rng:float(-1.8, 1.8)
		local r = rng:float(11, 19)
		W.tent(props, CF(g + V(math.sin(a) * r, 0, math.cos(a) * r)) * ANG(0, -a, 0), tentCol)
	end
	W.campfire(props, g)
	for _ = 1, 4 do
		W.crate(props, CF(g + V(rng:float(-16, 16), 0, rng:float(-16, 16))) * ANG(0, rng:angle(), 0))
	end
	W.banner(props, CF(g + V(4, 0, 4)), rgb(120, 20, 20), rgb(20, 20, 20))
	-- skull totems and spikes outside
	for i = 1, 2 do
		local q = g + V(math.sin(gapA + (i - 1.5) * 0.5) * 32, 0, math.cos(gapA + (i - 1.5) * 0.5) * 32)
		Kit.part(props, V(1, 9, 1), CF(q + V(0, 4.5, 0)), rgb(70, 50, 36), M.WoodPlanks)
		Kit.deco(props, V(1.5, 1.3, 1.5), CF(q + V(0, 9.6, 0)), rgb(230, 225, 210), M.SmoothPlastic)
	end
	for i = 1, 8 do
		local a = i / 8 * TAU + 0.2
		local q = g + V(math.sin(a) * 33, 1, math.cos(a) * 33)
		Kit.wedge(props, V(0.8, 3, 1.6), CFrame.lookAt(q, q + V(math.sin(a), 0.6, math.cos(a))) * ANG(-math.pi / 2, 0, 0), rgb(90, 66, 44), M.WoodPlanks, { CanCollide = false })
	end
	-- a cage
	local cc = CF(g + V(-12, 0, -8))
	for _, x in { -2, 2 } do
		for _, z in { -2, 2 } do
			Kit.part(props, V(0.4, 5, 0.4), cc * CF(x, 2.5, z), Palette.metal.dark, M.Metal)
		end
	end
	Kit.part(props, V(4.8, 0.4, 4.8), cc * CF(0, 5.2, 0), rgb(70, 50, 36), M.WoodPlanks)
	p.chest = CF(g + V(0, 0, -14))
	p.ground = g
end

local function dungeonEntrance(ctx, p)
	local W = S.World
	local rng, city = ctx.rng, ctx.city
	local g = p.pos
	local rock = ctx.pal.rock
	-- a rocky hill with a cave mouth facing the road
	local face = p.roadDir or V(0, 0, 1)
	local arch = CFrame.lookAt(g, g - face) * ANG(0, math.pi, 0)
	for i = 1, 22 do
		local q = arch * CF(rng:float(-20, 20), rng:float(0, 14), rng:float(4, 22))
		W.solid(city, V(1, 1, 1) * rng:float(7, 14), CF(q.Position) * ANG(rng:angle(), rng:angle(), 0), Palette.jitter(rock, 0.12, rng:float()), M.Slate)
	end
	W.solid(city, V(3, 14, 3), arch * CF(-7, 7, 0), Palette.stone[4], M.Cobblestone)
	W.solid(city, V(3, 14, 3), arch * CF(7, 7, 0), Palette.stone[4], M.Cobblestone)
	W.solid(city, V(17, 3, 3), arch * CF(0, 15, 0), Palette.stone[4], M.Cobblestone)
	local dark = W.deco(city, V(11, 12, 0.5), arch * CF(0, 6.5, 0.5), rgb(5, 5, 8))
	local glow = W.deco(city, V(1, 1, 1), arch * CF(0, 6, -1), rgb(160, 100, 255), M.Neon, { Transparency = 1 })
	Kit.pointLight(glow, rgb(160, 100, 255), 20, 1.5)
	W.torch(city, arch * CF(-9, 0, -2))
	W.torch(city, arch * CF(9, 0, -2))
	p.door = dark
	p.ground = g
end

local function monsterTower(ctx, p, color)
	local W = S.World
	local city = ctx.city
	local g = p.pos
	local floors = 4
	local fh = 14
	local half = 13
	local m = Kit.model("MonsterTower", city)
	local wallC = color or Palette.stone[4]
	local function stairSide(f)
		return if f % 2 == 0 then 1 else -1
	end
	local function slab(y: number, holeSide: number?)
		if not holeSide then
			W.solid(m, V(half * 2, 1, half * 2), CF(g.X, y, g.Z), Palette.stone[3], M.Slate)
			return
		end
		W.solid(m, V(half * 2 - 8, 1, half * 2), CF(g.X - holeSide * 4, y, g.Z), Palette.stone[3], M.Slate)
		W.solid(m, V(8, 1, half), CF(g.X + holeSide * (half - 4), y, g.Z - half / 2), Palette.stone[3], M.Slate)
	end
	for f = 0, floors - 1 do
		local y0 = g.Y + f * fh
		slab(y0 + 0.5, if f == 0 then nil else stairSide(f - 1))
		for _, sgn in { 1, -1 } do
			if not (f == 0 and sgn == 1) then
				W.solid(m, V(half * 2 + 2, fh, 2), CF(g.X, y0 + fh / 2 + 1, g.Z + sgn * half), wallC, M.Cobblestone)
			end
			W.solid(m, V(2, fh, half * 2), CF(g.X + sgn * half, y0 + fh / 2 + 1, g.Z), wallC, M.Cobblestone)
		end
		local sd = stairSide(f)
		for i = 0, 6 do
			W.solid(m, V(6, 2, 2), CF(g.X + sd * (half - 4), y0 + 2 + i * 2, g.Z + 1 + i * 1.7), Palette.stone[2], M.Cobblestone)
		end
		W.torch(m, CF(g.X - half + 1.5, y0 + 6, g.Z))
		-- arrow slits + banners outside
		W.deco(m, V(1.2, 4, 0.3), CF(g.X, y0 + fh * 0.6, g.Z - half - 1.1), rgb(14, 10, 12))
	end
	-- ground floor front with the doorway
	W.solid(m, V(half * 2 - 8, fh, 2), CF(g.X - 7, g.Y + fh / 2 + 1, g.Z + half), wallC, M.Cobblestone)
	W.solid(m, V(4, fh, 2), CF(g.X + half - 2, g.Y + fh / 2 + 1, g.Z + half), wallC, M.Cobblestone)
	-- roof platform (with the last stairwell opening) and crenels
	slab(g.Y + floors * fh + 0.5, stairSide(floors - 1))
	for i = -2, 2 do
		for _, s in { 1, -1 } do
			W.solid(m, V(2, 3, 2), CF(g.X + i * 6, g.Y + floors * fh + 3, g.Z + s * (half + 1)), wallC, M.Cobblestone)
			W.solid(m, V(2, 3, 2), CF(g.X + s * (half + 1), g.Y + floors * fh + 3, g.Z + i * 6), wallC, M.Cobblestone)
		end
	end
	-- buttresses
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			W.solid(m, V(4, floors * fh * 0.7, 4), CF(g.X + sx * (half + 1), g.Y + floors * fh * 0.35, g.Z + sz * (half + 1)), Palette.shade(wallC, 0.9), M.Cobblestone)
		end
	end
	for _, s in { -1, 1 } do
		W.banner(m, CF(g.X + s * (half + 1.3), g.Y + floors * fh - 4, g.Z) * ANG(0, s * math.pi / 2, 0), rgb(110, 16, 20), rgb(20, 20, 20))
	end
	p.ground = g
	p.floors = {}
	for f = 0, floors - 1 do
		table.insert(p.floors, V(g.X - 3, g.Y + f * fh + 3, g.Z - 3))
	end
	p.top = V(g.X, g.Y + floors * fh + 4, g.Z)
end

local function fortress(ctx, p, wallC: Color3, roofC: Color3)
	local W, B = S.World, S.Build
	local rng, city = ctx.rng, ctx.city
	local g = p.pos
	local R = 88
	B.greatWall(city, g, R, 38, 10, { gates = { 0 }, gateWidth = 18, gateHeight = 22, segment = 26, cannons = false, name = "Fortress", color = wallC, banner = rgb(90, 10, 16), emblem = rgb(20, 20, 20) })
	local m = Kit.model("Keep", city)
	local kc = CF(g + V(0, 0, -36))
	W.solid(m, V(46, 40, 34), kc * CF(0, 20, 0), wallC, M.Cobblestone)
	for _, y in { 13, 27 } do
		W.deco(m, V(47, 1.2, 35), kc * CF(0, y, 0), Palette.shade(wallC, 1.15), M.Slate)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			W.tower(m, (kc * CF(sx * 23, 0, sz * 17)).Position, 7, 54, wallC, roofC)
		end
		-- tall windows
		for i = -1, 1 do
			W.deco(m, V(2, 7, 0.3), kc * CF(i * 12 + sx * 2, 30, 17.1), rgb(255, 120, 60), M.Neon, { Transparency = 0.3 })
		end
	end
	B.gableRoof(m, kc, 46, 34, 40, math.rad(38), roofC, M.Slate, { overhang = 1.2 })
	W.deco(m, V(12, 14, 0.6), kc * CF(0, 7, 17.2), rgb(12, 8, 10))
	-- steps to the keep door
	for i = 0, 2 do
		W.solid(m, V(18 - i * 2, 1, 3), kc * CF(0, 0.5 + i, 20.5 - i * 1.5), Palette.shade(wallC, 0.9), M.Slate)
	end
	-- courtyard: fires, banners, tents, spiked barricades, racks
	for i = 1, 6 do
		local q = g + V(rng:float(-55, 55), 0, rng:float(0, 60))
		W.banner(city, CF(q), rgb(90, 10, 16), rgb(20, 20, 20))
	end
	for _, q in { V(-40, 0, 20), V(40, 0, 20), V(0, 0, 50) } do
		W.campfire(city, g + q)
	end
	for i = 1, 4 do
		local a = rng:float(-1, 1)
		W.tent(city, CF(g + V(if i % 2 == 0 then -58 else 58, 0, -10 + i * 14)) * ANG(0, a, 0), rgb(80, 30, 30))
	end
	for i = -3, 3 do
		local q = g + V(i * 8, 0, 72)
		Kit.part(city, V(6, 1, 1), CF(q + V(0, 1.5, 0)) * ANG(0, 0, 0.5), rgb(80, 60, 40), M.WoodPlanks)
		Kit.part(city, V(6, 1, 1), CF(q + V(0, 1.5, 0)) * ANG(0, 0, -0.5), rgb(80, 60, 40), M.WoodPlanks)
	end
	p.ground = g
	p.courtyard = g + V(0, 3, 22)
	p.gate = g + V(0, 3, R + 8)
end

local function shrineBuild(ctx, p)
	local rng, props = ctx.rng, ctx.props
	local g = p.pos
	local runeC = if ctx.biome == "Evil" or ctx.biome == "Volcanic" then rgb(255, 70, 40) else rgb(120, 220, 255)
	for i = 1, 8 do
		local a = i / 8 * TAU
		local h = rng:float(7, 13)
		local cf = CF(g + V(math.cos(a) * 11, h / 2, math.sin(a) * 11)) * ANG(rng:float(-0.08, 0.08), -a, rng:float(-0.08, 0.08))
		Kit.part(props, V(2.8, h, 1.8), cf, Palette.stone[rng:int(1, 4)], M.Slate)
		if i % 2 == 0 then
			Kit.deco(props, V(0.4, h * 0.6, 1.9), cf * CF(0, 0, 0), runeC, M.Neon, { Transparency = 0.2 })
		end
	end
	Kit.part(props, V(7, 2, 7), CF(g + V(0, 1, 0)), Palette.stone[2], M.Marble)
	Kit.deco(props, V(7.2, 0.2, 7.2), CF(g + V(0, 2.05, 0)), Palette.shade(Palette.stone[2], 1.1), M.Marble)
	p.chest = CF(g + V(0, 2, 0))
	p.ground = g
end

local function ruinBuild(ctx, p)
	local W, N = S.World, S.Nature
	local rng, props = ctx.rng, ctx.props
	local g = p.pos
	local stone = Palette.shade(ctx.pal.rock, 1.15)
	-- broken tower
	local tp = g + V(rng:float(-10, 10), 0, rng:float(-10, 10))
	for i = 0, 5 do
		local k = 1 - i * 0.08
		for _, side in { 0, 1, 2, 3 } do
			if not (i > 2 and (side + i) % 3 == 0) then
				local a = side * math.pi / 2
				local dir = V(math.sin(a), 0, math.cos(a))
				local cf = CFrame.lookAt(tp + dir * 7 * k + V(0, 2 + i * 4, 0), tp + dir * 20 + V(0, 2 + i * 4, 0))
				W.solid(props, V(14 * k, 4, 2.4), cf, Palette.shade(stone, 0.92 + ((i + side) % 2) * 0.06), M.Cobblestone)
			end
		end
	end
	-- wall stubs and rubble
	for i = 1, 5 do
		local a = rng:angle()
		local q = g + V(math.sin(a) * rng:float(22, 45), 0, math.cos(a) * rng:float(22, 45))
		local h = rng:float(3, 10)
		W.solid(props, V(rng:float(8, 16), h, 2.4), CF(q + V(0, h / 2, 0)) * ANG(0, rng:angle(), 0), stone, M.Cobblestone)
	end
	for _ = 1, 10 do
		W.solid(props, V(1, 1, 1) * rng:float(1.5, 3.5), CF(g + V(rng:float(-30, 30), 0.8, rng:float(-30, 30))) * ANG(rng:angle(), rng:angle(), 0), Palette.shade(stone, rng:float(0.85, 1.05)), M.Cobblestone)
	end
	N.dead(props, g + V(rng:float(-25, 25), 0, rng:float(-25, 25)), rng, nil, ctx.pal)
	W.banner(props, CF(tp + V(9, 0, 0)), rgb(70, 60, 50), nil)
	p.ground = g
end

-- an old battle: swords and spears in the earth, shields, broken carts, banners
local function battlefieldBuild(ctx, p)
	local W, B = S.World, S.Build
	local rng, props = ctx.rng, ctx.props
	local g = p.pos
	local metal = rgb(150, 150, 156)
	local shieldCols = { rgb(170, 30, 36), rgb(236, 232, 220), rgb(40, 70, 140), rgb(220, 190, 70), rgb(70, 90, 60) }
	for _ = 1, 40 do
		local q = g + V(rng:float(-65, 65), 0, rng:float(-65, 65))
		local roll = rng:float()
		local tilt = ANG(rng:float(-0.35, 0.35), rng:angle(), rng:float(-0.35, 0.35))
		if roll < 0.35 then
			Kit.deco(props, V(0.25, 4.4, 0.7), CF(q + V(0, 1.8, 0)) * tilt, metal, M.Metal)
			Kit.deco(props, V(1.8, 0.3, 0.4), CF(q + V(0, 1.8, 0)) * tilt * CF(0, 1.6, 0), rgb(80, 60, 40), M.WoodPlanks)
		elseif roll < 0.6 then
			Kit.deco(props, V(0.3, 9, 0.3), CF(q + V(0, 3.6, 0)) * tilt, rgb(110, 80, 52), M.WoodPlanks)
		elseif roll < 0.85 then
			Kit.cyl(props, 0.35, 3, CF(q + V(0, 0.3, 0)) * ANG(0, rng:angle(), math.pi / 2 + rng:float(-0.3, 0.3)), rng:pick(shieldCols), M.WoodPlanks, { CanCollide = false })
		else
			Kit.deco(props, V(1, 0.9, 1.1), CF(q + V(0, 0.45, 0)) * ANG(0, rng:angle(), 0), rgb(230, 225, 210), M.SmoothPlastic)
		end
	end
	for _ = 1, 3 do
		local q = g + V(rng:float(-50, 50), 0, rng:float(-50, 50))
		W.banner(props, CF(q) * ANG(rng:float(-0.2, 0.2), rng:angle(), rng:float(-0.25, 0.25)), rng:pick({ rgb(120, 30, 30), rgb(40, 60, 120) }), nil)
	end
	for _ = 1, 2 do
		local c = B.cart(props, CF(g + V(rng:float(-40, 40), 0, rng:float(-40, 40))) * ANG(0, rng:angle(), rng:float(0.2, 0.5)))
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Palette.shade(d.Color, 0.45)
			end
		end
	end
	-- a burial cairn
	for i = 0, 3 do
		Kit.part(props, V(6 - i * 1.3, 1.4, 6 - i * 1.3), CF(g + V(0, 0.7 + i * 1.4, 0)) * ANG(0, i * 0.5, 0), Palette.stone[rng:int(1, 4)], M.Slate)
	end
	p.ground = g
end

local function exitGate(ctx, p, index: number)
	local W = S.World
	local city = ctx.city
	local ex = p.pos
	local col = if index == 6 then rgb(255, 40, 60) else rgb(120, 220, 255)
	local gate, film = W.portal(city, CFrame.lookAt(ex, ex + V(0, 0, 1)), col, if index == 6 then "" else "TO THE NEXT LAND")
	-- a border wall across the pass with towers at both ends
	local stone = Palette.shade(ctx.pal.rock, 1.2)
	for _, sx in { -1, 1 } do
		W.wall(city, ex + V(sx * 9, 0, -4), ex + V(sx * 60, 0, -4), 24, 7, stone)
		W.tower(city, ex + V(sx * 64, 0, -4), 9, 38, stone, rgb(60, 50, 70))
		W.tower(city, ex + V(sx * 13, 0, -4), 5, 30, stone, rgb(60, 50, 70))
	end
	local seal = W.solid(city, V(14, 18, 4), CF(ex + V(0, 9, 0)), rgb(255, 60, 60), M.ForceField, { Transparency = 0.1 })
	return gate, film, seal
end

-- ------------------------------------------------------------------ build
function Land.build(index: number, bible, seed: number)
	local W, B, N = S.World, S.Build, S.Nature
	local plan = Land.plan(index, bible, seed)
	local rng = plan.rng
	local biome = plan.biome
	local shape = plan.shape
	local pal = table.clone(Palette.biomes[biome] or Palette.biomes.Meadow)
	pal.snow = shape.snow
	local lodPal = table.clone(pal)
	lodPal.lod = true
	local map = W.sub("Map")
	local props = W.sub("Props")
	local city = W.sub("City")
	local count = { n = 0 }

	-- 1. fine height grid (walkable area)
	local ext = plan.inner + 60
	local n = math.ceil(ext * 2 / CELL)
	local origin = V(-n * CELL / 2, 0, -n * CELL / 2)
	local Hg, Kg, Kind = {}, {}, {}
	local water = plan.water
	for ix = 1, n do
		local col, kcol = {}, {}
		Hg[ix] = col
		Kind[ix] = kcol
		local x = origin.X + (ix - 0.5) * CELL
		for iz = 1, n do
			local z = origin.Z + (iz - 0.5) * CELL
			local h, kind = Land.terrainAt(plan, x, z)
			local q
			if kind == "road" then
				q = math.floor(h)
			elseif water > 0 and h < water - 1.5 then
				q = math.max(math.floor(h / 3) * 3, water - 18)
			else
				local edge = math.max(math.abs(x), math.abs(z)) - plan.inner
				local step = if edge > 30 then 4 elseif kind == "shoulder" then 1 else 2
				q = math.floor(h / step + 0.5) * step
			end
			col[iz] = q
			kcol[iz] = kind
		end
		if ix % 12 == 0 then
			task.wait()
		end
	end
	local function cellOf(x: number, z: number): (number, number)
		return math.clamp(math.floor((x - origin.X) / CELL) + 1, 1, n), math.clamp(math.floor((z - origin.Z) / CELL) + 1, 1, n)
	end
	local function groundY(x: number, z: number): number
		local ix, iz = cellOf(x, z)
		return Hg[ix][iz]
	end
	local function kindAt(x: number, z: number): string?
		local ix, iz = cellOf(x, z)
		return Kind[ix][iz]
	end
	plan.groundY = groundY

	-- 2. colours: roads, water beds, shores, cliffs, snow, forest floor, meadows
	local snowLine = shape.snowLine or 150
	local noSnow = biome == "Desert" or biome == "Volcanic" or biome == "Evil"
	local function oasisNear(x: number, z: number): boolean
		for _, l in plan.lakes do
			if l.oasis and Util.flatDist(V(x, 0, z), l.pos) < l.r + 40 then
				return true
			end
		end
		return false
	end
	for ix = 1, n do
		local kcol = {}
		Kg[ix] = kcol
		local x = origin.X + (ix - 0.5) * CELL
		for iz = 1, n do
			local z = origin.Z + (iz - 0.5) * CELL
			local h = Hg[ix][iz]
			local kind = Kind[ix][iz]
			local c
			local edge = math.max(math.abs(x), math.abs(z)) - plan.inner
			if kind == "road" then
				c = 4
			elseif (water > 0 or oasisNear(x, z)) and h < plan.lakeLevel - 0.5 then
				c = 8
			else
				local sl, low = 0, h
				for _, o in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 } } do
					local jx, jz = math.clamp(ix + o[1], 1, n), math.clamp(iz + o[2], 1, n)
					local hn = Hg[jx][jz]
					if math.abs(o[1]) + math.abs(o[2]) == 1 then
						sl = math.max(sl, math.abs(h - hn))
					end
					low = math.min(low, hn)
				end
				if (water > 0 or oasisNear(x, z)) and h <= plan.lakeLevel + 3 and low < plan.lakeLevel then
					-- beaches and river banks: only right next to the water
					c = if shape.lava then 5 else 6
				elseif h > snowLine and not noSnow then
					c = 10
				elseif sl >= 8 or edge > 40 then
					c = if Util.noise(x / 60, z / 60, plan.seed + 4) > 0.2 then 7 else 5
				elseif kind == "pad" then
					if Util.flatDist(V(x, 0, z), plan.town.pos) < plan.town.wallR - 4 then
						c = 11 -- trodden town ground
					else
						c = if Util.noise(x / 90, z / 90, plan.seed) > 0.1 then 1 else 2
					end
				elseif Land.forestAt(plan, x, z) > 1 - shape.forest then
					c = 9
				else
					local gn = Util.noise(x / 260, z / 260, plan.seed + index)
					c = if gn > 0.25 then 3 elseif gn > -0.08 then 1 else 2
				end
			end
			kcol[iz] = c
		end
	end
	local grassMat = if biome == "Desert" then M.Sand elseif biome == "Frost" then M.Snow elseif biome == "Volcanic" or biome == "Evil" then M.Ground else M.Grass
	local rockMat = if biome == "Volcanic" or biome == "Evil" then M.Basalt else M.Slate
	local palette = {
		pal.grass[1],
		pal.grass[2],
		pal.grass[3],
		Palette.shade(pal.dirt, 1.1),
		pal.rock,
		pal.sand,
		Palette.shade(pal.rock, 1.22),
		Palette.shade(pal.sand, 0.72),
		Palette.shade(pal.grass[4], 0.86),
		rgb(240, 244, 250),
		if shape.town == "norse" or shape.town == "stilt" then Palette.shade(pal.dirt, 1.05) elseif biome == "Desert" then rgb(214, 190, 150) else rgb(142, 132, 116),
		}
		local mats = { grassMat, grassMat, grassMat, M.Ground, rockMat, M.Sand, rockMat, if biome == "Swamp" then M.Mud else M.Sand, grassMat, M.Snow, if shape.town == "norse" or shape.town == "stilt" or biome == "Desert" then M.Ground else M.Cobblestone }
	plan.stats = {}
	plan.stats.fine = W.heightfield({
		parent = map,
		origin = origin,
		nx = n,
		nz = n,
		cell = CELL,
		step = 1,
		base = -30,
		height = function(ix, iz)
			return Hg[ix][iz]
		end,
		color = function(ix, iz)
			return Kg[ix][iz]
		end,
		palette = palette,
		material = function(k)
			return mats[k] or grassMat
		end,
	})
	-- 3. the mountain ring (coarse)
	local no = math.ceil(plan.size / OUTER_CELL)
	local oo = V(-no * OUTER_CELL / 2, 0, -no * OUTER_CELL / 2)
	local snowPeak = if shape.snowLine then shape.snowLine + 40 else 200
	plan.stats.coarse = W.heightfield({
		parent = map,
		origin = oo,
		nx = no,
		nz = no,
		cell = OUTER_CELL,
		step = 1,
		base = -30,
		skip = function(ix, iz)
			local x, z = oo.X + (ix - 0.5) * OUTER_CELL, oo.Z + (iz - 0.5) * OUTER_CELL
			return math.max(math.abs(x), math.abs(z)) < ext - OUTER_CELL / 2
		end,
		height = function(ix, iz)
			local x, z = oo.X + (ix - 0.5) * OUTER_CELL, oo.Z + (iz - 0.5) * OUTER_CELL
			local h = natural(plan, x, z)
			if plan.coastX then
				h = seaCut(plan, x, z, h)
			end
			h += borderRise(plan, x, z)
			if water > 0 and h < water - 1 then
				return math.max(math.floor(h / 6) * 6, water - 18)
			end
			return math.floor(h / 16 + 0.5) * 16
		end,
		color = function(ix, iz, h)
			if water > 0 and h < water then
				return 8
			elseif h > snowPeak and not noSnow then
				return 10
			elseif h > 48 then
				return if (ix + iz) % 3 == 0 then 7 else 5
			end
			return 2
		end,
		palette = palette,
		material = function(k)
			return mats[k] or grassMat
		end,
	})
	-- skyline peaks beyond the edge of the world
	local half = plan.half
	for i = 1, 22 do
		local a = i / 22 * TAU + rng:float(-0.1, 0.1)
		local pos = V(math.sin(a) * (half + rng:float(120, 420)), 0, math.cos(a) * (half + rng:float(120, 420)))
		if not (plan.coastX and pos.X < -half * 0.3) then
			N.mountain(map, pos + V(0, -20, 0), rng:float(220, 340), rng:float(320, 560), rng, pal, if noSnow then nil else 300)
		end
	end
	-- water: tiled sheets (parts stop at 2048 studs), oases get their own
	if water > 0 then
		local tile = 2000
		local k = math.ceil(plan.size * 2 / tile)
		for tx = 0, k - 1 do
			for tz = 0, k - 1 do
				local cx = -plan.size + (tx + 0.5) * (plan.size * 2 / k)
				local cz = -plan.size + (tz + 0.5) * (plan.size * 2 / k)
				W.water(map, CF(cx, water - 0.4, cz), V(plan.size * 2 / k + 1, 1, plan.size * 2 / k + 1), pal.water, shape.lava)
			end
		end
	end
	for _, l in plan.lakes do
		if l.oasis then
			W.water(map, CF(l.pos.X, l.level - 0.4, l.pos.Z), V(l.r * 2 + 24, 1, l.r * 2 + 24), pal.water)
			for i = 1, 9 do
				local a = i / 9 * TAU + rng:float(-0.2, 0.2)
				local q = l.pos + V(math.sin(a) * (l.r + rng:float(8, 26)), 0, math.cos(a) * (l.r + rng:float(8, 26)))
				palm(props, V(q.X, groundY(q.X, q.Z), q.Z), rng)
			end
		end
	end
	-- invisible walls at the edge of the playable land
	local lim = plan.inner + 150
	for _, s in { { V(0, 300, lim), V(lim * 2, 800, 4) }, { V(0, 300, -lim), V(lim * 2, 800, 4) }, { V(lim, 300, 0), V(4, 800, lim * 2) }, { V(-lim, 300, 0), V(4, 800, lim * 2) } } do
		local wall = Kit.part(map, s[2], CF(s[1]), rgb(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false })
		wall.CanQuery = false
		wall.Name = "EdgeOfTheLand"
	end

	-- 4. roads and bridges
	local look = ROAD_LOOK[biome] or { rgb(146, 118, 84), M.Ground }
	local roadsM = Kit.model("Roads", map)
	local T = plan.town
	for _, r in plan.roads do
		local skip = {}
		for _, bd in r.bridges do
			for k = bd.i0, bd.i1 do
				skip[k] = true
			end
			local a, b = r.pts[bd.a], r.pts[bd.b]
			B.bridge(city, V(a.X, r.hs[bd.a], a.Z), V(b.X, r.hs[bd.b], b.Z), r.w * 2 + 2, { color = if shape.town == "norse" or shape.town == "stilt" then rgb(120, 94, 66) else nil })
		end
		local k = 1
		while k < #r.pts do
			local j = math.min(k + 2, #r.pts)
			local pa, pb = r.pts[k], r.pts[j]
			if not (skip[k] or skip[j]) and Util.flatDist(pa, T.pos) > T.wallR - 2 then
				local a = V(pa.X, r.hs[k], pa.Z)
				local b = V(pb.X, r.hs[j], pb.Z)
				local len = (b - a).Magnitude
				if len > 0.5 then
					W.solid(roadsM, V(r.w * 2, 2.4, len + 1.6), CFrame.lookAt((a + b) / 2, b) * CF(0, -1, 0), Palette.shade(look[1], 0.95 + (math.floor(k / 2) % 3) * 0.035), look[2])
				end
			end
			k = j
			W.yield(count)
		end
	end
	-- signposts at the junctions, watchtowers along the main road
	for _, jn in plan.junctions do
		local to = if jn.to then flat(jn.to.pos - jn.pos) else V(0, 0, -1)
		local sp = jn.pos + V(10, 0, 0)
		B.signpost(props, V(sp.X, groundY(sp.X, sp.Z), sp.Z), math.atan2(-to.Z, to.X))
	end
	local mr = plan.mainRoad
	for _, t in { 0.22, 0.5, 0.8 } do
		local k = math.clamp(math.floor(#mr.pts * t), 2, #mr.pts - 1)
		local a, b = mr.pts[k - 1], mr.pts[k + 1]
		local dir = flat(b - a).Unit
		local side = V(dir.Z, 0, -dir.X) * (if rng:chance(0.5) then 1 else -1)
		local q = mr.pts[k] + side * (mr.w + 12)
		if plan.riverDist(q) > 30 then
			B.watchtower(city, V(q.X, groundY(q.X, q.Z), q.Z), { height = 20 })
		end
	end

	-- 5. places
	local ctx = { rng = rng, city = city, props = props, map = map, pal = pal, biome = biome, shape = shape, plan = plan, groundY = groundY, count = count }
	local refs = { plan = plan, pois = plan.pois, index = index, biome = biome }
	local wallC = if biome == "Evil" or biome == "Volcanic" then rgb(50, 40, 44) elseif biome == "Desert" then rgb(200, 170, 120) elseif biome == "Crystal" then rgb(200, 200, 216) else Palette.stone[4]
	local roofC = if biome == "Evil" then rgb(120, 10, 20) else rgb(60, 50, 70)
	refs.town = buildTown(ctx, T)
	for _, f in plan.farms do
		farmstead(ctx, f)
	end
	for _, c in plan.camps do
		campBuild(ctx, c)
	end
	dungeonEntrance(ctx, plan.dungeon)
	monsterTower(ctx, plan.monsterTower, wallC)
	for _, sh in plan.shrines do
		shrineBuild(ctx, sh)
	end
	for _, ru in plan.ruins do
		ruinBuild(ctx, ru)
	end
	if plan.battlefield then
		battlefieldBuild(ctx, plan.battlefield)
	end
	if plan.castle then
		fortress(ctx, plan.castle, wallC, roofC)
	end
	local exitPoi
	for _, p in plan.pois do
		if p.kind == "exit" then
			exitPoi = p
		end
	end
	local gate, film, seal = exitGate(ctx, exitPoi, index)
	refs.exitGate = gate
	refs.exitFilm = film
	refs.exitPos = exitPoi.pos
	refs.exitSeal = seal
	local ep = plan.entry
	refs.entry = CFrame.lookAt(ep + V(0, 4, 0), V(T.pos.X, ep.Y + 4, T.pos.Z))
	-- a timber arch where the southern pass opens into the land
	for _, sx in { -1, 1 } do
		Kit.part(city, V(1.6, 14, 1.6), CF(ep + V(sx * 9, 7, 16)), rgb(90, 64, 42), M.WoodPlanks)
	end
	Kit.part(city, V(22, 1.6, 1.6), CF(ep + V(0, 13.6, 16)), rgb(90, 64, 42), M.WoodPlanks)
	Kit.deco(city, V(8, 3, 0.4), CF(ep + V(0, 11, 16)), rgb(150, 110, 60), M.WoodPlanks)

	-- 6. nature: forests, groves of giant trees, bushes, rocks, flowers
	local function blocked(x: number, z: number, margin: number): boolean
		local kind = kindAt(x, z)
		if kind == "road" or kind == "shoulder" or kind == "pad" or kind == "water" then
			return true
		end
		for _, p in plan.pois do
			if not p.nopad and math.abs(x - p.pos.X) < p.r + margin and math.abs(z - p.pos.Z) < p.r + margin and Util.flatDist(V(x, 0, z), p.pos) < p.r + margin then
				return true
			end
		end
		return false
	end
	local trees, bushes, rocks, flowers = {}, {}, {}, {}
	local spacing = 22
	local lim2 = plan.inner - 20
	for gx = -lim2, lim2, spacing do
		for gz = -lim2, lim2, spacing do
			local x = gx + rng:float(-8, 8)
			local z = gz + rng:float(-8, 8)
			local h = groundY(x, z)
			if h > plan.lakeLevel + 1.5 and h < 110 and not blocked(x, z, 6) then
				local ix, iz = cellOf(x, z)
				local c = Kg[ix][iz]
				local p = V(x, h, z)
				if c == 5 or c == 7 then
					if rng:chance(0.08) then
						table.insert(rocks, p)
					end
				elseif c == 9 then
					local roll = rng:float()
					if roll < 0.55 then
						table.insert(trees, p)
					elseif roll < 0.63 then
						table.insert(bushes, p)
					elseif roll < 0.65 then
						table.insert(rocks, p)
					end
				else
					local roll = rng:float()
					if roll < 0.03 then
						table.insert(trees, p)
					elseif roll < 0.06 then
						table.insert(bushes, p)
					elseif roll < 0.075 then
						table.insert(rocks, p)
					elseif roll < 0.1 then
						table.insert(flowers, p)
					end
				end
			end
		end
		if gx % (spacing * 20) < spacing then
			task.wait()
		end
	end
	local function cap(list, maxN: number)
		if #list <= maxN then
			return list
		end
		rng:shuffle(list)
		local out = table.move(list, 1, maxN, 1, {})
		return out
	end
	-- giant trees: the whole Giantwood, or one grove elsewhere
	local giants = {}
	if biome == "Giantwood" then
		local pool = table.clone(trees)
		rng:shuffle(pool)
		for _, p in pool do
			if #giants >= shape.giants then
				break
			end
			local ok = not blocked(p.X, p.Z, 30)
			if ok then
				for _, q in giants do
					if Util.flatDist(p, q) < 120 then
						ok = false
						break
					end
				end
			end
			if ok then
				local e = roadNear(plan, p.X, p.Z)
				if e and e < 30 then
					ok = false
				end
			end
			if ok then
				table.insert(giants, p)
			end
		end
	elseif plan.grove then
		local gp = plan.grove.pos
		for _ = 1, shape.giants * 6 do
			if #giants >= shape.giants then
				break
			end
			local a, d = rng:angle(), rng:float(0, plan.grove.r)
			local x, z = gp.X + math.sin(a) * d, gp.Z + math.cos(a) * d
			local ok = not blocked(x, z, 30)
			for _, q in giants do
				if Util.flatDist(V(x, 0, z), q) < 90 then
					ok = false
				end
			end
			if ok then
				table.insert(giants, V(x, groundY(x, z), z))
			end
		end
	end
	for _, p in giants do
		N.giant(props, p, rng, rng:float(0.85, 1.25), pal)
		W.yield(count)
	end
	plan.giants = giants
	local main = shape.tree
	local mix = shape.mix or {}
	for i, p in cap(trees, if main == "oak" or main == "pine" then 900 else 650) do
		local near = false
		for _, q in giants do
			if math.abs(p.X - q.X) < 24 and math.abs(p.Z - q.Z) < 24 then
				near = true
				break
			end
		end
		if not near then
			local kind = if #mix > 0 and rng:chance(0.3) then rng:pick(mix) else main
			local ix, iz = cellOf(p.X, p.Z)
			local interior = Kg[ix][iz] == 9 and i % 4 ~= 0
			if kind == "oak" or kind == "pine" or kind == "birch" or kind == "willow" or kind == "dead" then
				N.tree(props, p, kind, rng, nil, if interior then lodPal else pal)
			else
				W.tree(props, p, kind, rng, nil, pal)
			end
		end
		W.yield(count)
	end
	for _, p in cap(bushes, 240) do
		N.bush(props, p, rng, pal)
	end
	for _, p in cap(rocks, 200) do
		N.rocks(props, p, rng:float(3, 9), pal.rock, rng, biome ~= "Desert" and biome ~= "Volcanic" and biome ~= "Evil")
	end
	for _, p in cap(flowers, 100) do
		if rng:chance(0.5) then
			W.flowers(props, p, rng, pal)
		else
			W.grass(props, p, rng, pal.grass[1])
		end
	end
	-- reeds along the rivers
	if not shape.lava then
		for _, r in plan.rivers do
			for k = 2, #r.pts - 1 do
				if rng:chance(0.6) then
					local a, b = r.pts[k - 1], r.pts[k + 1]
					local dir = flat(b - a).Unit
					local side = V(dir.Z, 0, -dir.X) * (if rng:chance(0.5) then 1 else -1)
					local q = r.pts[k] + side * (r.w + rng:float(2, 6))
					local h = groundY(q.X, q.Z)
					if h > water - 1 and h < water + 4 then
						N.reeds(props, V(q.X, h, q.Z), rng)
					end
				end
			end
		end
	end
	-- the fjord: longships out on the water
	if plan.coastX then
		for i = 1, 3 do
			local z = rng:float(-plan.inner * 0.6, plan.inner * 0.6)
			local x = plan.coastX(z) - rng:float(120, 260)
			B.longship(city, CFrame.lookAt(V(x, water + 0.3, z), V(x + rng:float(-1, 1), water + 0.3, z + 1) + V(0, 0, rng:sign() * 40)), { rng = rng, len = rng:int(36, 44) })
		end
	end

	-- 7. open ground for roaming monsters
	for _ = 1, 400 do
		if #plan.wilds >= 16 then
			break
		end
		local x = rng:float(-plan.inner + 200, plan.inner - 200)
		local z = rng:float(-plan.inner + 250, plan.inner - 400)
		local h = groundY(x, z)
		if h > plan.lakeLevel + 2 and h < 80 and not blocked(x, z, 50) then
			table.insert(plan.wilds, V(x, h, z))
		end
	end
	return refs
end

return Land
