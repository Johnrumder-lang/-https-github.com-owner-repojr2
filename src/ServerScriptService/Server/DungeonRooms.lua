--!nonstrict
-- Room and corridor builders for the underground. Every room gets a masonry
-- shell (flagstones, walls with plinth / courses / pilasters, stepped vault)
-- and a kind-specific interior: catacomb halls with galleries, crypts, bone
-- cathedrals, flooded cisterns, caverns, mines, chasms with broken bridges,
-- forges, the spawn shaft, the exit gate and round boss arenas.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Palette = require(Shared.Palette)
local Kit = require(Shared.Kit)
local K = require(script.Parent.DungeonKit)
local P = require(script.Parent.DungeonProps)
local L = require(script.Parent.DungeonLayout)
local S = require(script.Parent.S)

local R = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material
local UP = V(0, 1, 0)

-- ------------------------------------------------------------------ helpers
local function spot(ctx, room, r, margin, area)
	return L.spot(ctx.rng, room, r, margin, true, area)
end

local function addSpot(room, p: Vector3, y: number?)
	table.insert(room.spots, V(p.X, (y or room.y) + 3, p.Z))
end

local function longX(room)
	return room.sx >= room.sz
end

-- world point from (along long axis offset a from x0/z0, across offset b)
local function at(room, a, b, y)
	if longX(room) then
		return V(room.x0 + a, y or room.y, room.z0 + b)
	end
	return V(room.x0 + b, y or room.y, room.z0 + a)
end

local function dims(room)
	if longX(room) then
		return room.sx, room.sz
	end
	return room.sz, room.sx
end

-- keep the way from every door to the room centre clear of props
local function reservePaths(room)
	for side, list in room.doors do
		for _, d in list do
			local hw = d.w / 2 + 2
			if side == "xn" then
				L.block(room, room.x0, room.z0 + d.c - hw, room.cx, room.z0 + d.c + hw)
			elseif side == "xp" then
				L.block(room, room.cx, room.z0 + d.c - hw, room.x1, room.z0 + d.c + hw)
			elseif side == "zn" then
				L.block(room, room.x0 + d.c - hw, room.z0, room.x0 + d.c + hw, room.cz)
			else
				L.block(room, room.x0 + d.c - hw, room.cz, room.x0 + d.c + hw, room.z1)
			end
		end
	end
	L.block(room, room.cx - 7, room.cz - 7, room.cx + 7, room.cz + 7)
end

local function doorAt(room, side, s0, s1, maxTop)
	for _, d in room.doors[side] do
		if d.c + d.w / 2 + 3 > s0 and d.c - d.w / 2 - 3 < s1 and (maxTop == nil or d.h > maxTop) then
			return true
		end
	end
	return false
end

-- soft fill lights so big rooms read in the dark (Roblox caps Range at 60)
local function fill(ctx, room, yOff)
	local th = ctx.theme
	local La = math.max(room.sx, room.sz)
	local n = if La > 110 then 2 else 1
	local col = K.WARM:Lerp(th.glow, 0.25)
	for i = 1, n do
		local f = if n == 1 then 0.5 else (i - 0.5) / n
		local p = if room.sx >= room.sz then V(room.x0 + room.sx * f, room.y + yOff, room.cz) else V(room.cx, room.y + yOff, room.z0 + room.sz * f)
		local core = K.deco(ctx, V(1, 1, 1), CF(p), col, M.Neon, { Transparency = 1 })
		K.light(ctx, core, col, 60, if room.h > 75 then 0.8 else 0.6)
	end
end
R.fill = fill

-- ------------------------------------------------------------------ shell
-- o: {style, hs, pilasters, torchEvery, noVault, steps, ribs, hole, floor, lowTop,
--     galleries = {side = gh}, noTorches}
function R.shell(ctx, room, o)
	local th = ctx.theme
	local rng = ctx.rng
	local y, H = room.y, room.h
	local hs = o.hs or math.floor(H * 0.6)
	room.hs = hs
	room.frames = {}
	room.slots = {}
	if not o.noFloor then
		K.floor(ctx, room.x0, room.z0, room.x1, room.z1, y, o.floor)
	end
	local sp = o.pilasters or 14
	local torchEvery = o.torchEvery or 2
	if not o.noFill then
		fill(ctx, room, math.min(hs * 0.55, 24))
	end
	for _, side in L.SIDES do
		local a, u, n, len = L.side(room, side)
		local fr = K.frame(a, u, n, y)
		room.frames[side] = fr
		local doors = room.doors[side]
		local gh = o.galleries and o.galleries[side]
		local count = 0
		local pil = K.wall(ctx, fr, len, {
			height = H,
			spring = hs,
			doors = doors,
			style = o.style,
			lowTop = o.lowTop,
			pilasters = if o.style == "rough" then nil else sp,
			cornice = true,
			onPilaster = function(s, i)
				count += 1
				if not o.noTorches and count % torchEvery == 1 then
					P.torch(ctx, K.fpos(fr, s, 9, 1.45), n)
					if gh then
						P.torch(ctx, K.fpos(fr, s, gh + 9, 1.45), n)
					end
				end
			end,
		})
		-- slots between pilasters (for banners, niches, shelves)
		local prev = 3
		for _, s in pil do
			if s - prev > 8 then
				local mid = (prev + s) / 2
				if not doorAt(room, side, mid - 4, mid + 4) then
					table.insert(room.slots, { fr = fr, s = mid, w = s - prev - 4.6, side = side, n = n, len = len })
				end
			end
			prev = s
		end
		if len - 3 - prev > 8 then
			local mid = (prev + len - 3) / 2
			if not doorAt(room, side, mid - 4, mid + 4) then
				table.insert(room.slots, { fr = fr, s = mid, w = len - 3 - prev - 4.6, side = side, n = n, len = len })
			end
		end
		-- torches beside doors (rough caves get them on the rock)
		for _, d in doors do
			for _, sg in { -1, 1 } do
				local s = d.c + sg * (d.w / 2 + 4.6)
				if s > 5 and s < len - 5 and not d.gate then
					P.torch(ctx, K.fpos(fr, s, 10, if o.style == "rough" then 2.7 else 0.36), n)
				end
			end
		end
		-- rough walls: torches at intervals
		if o.style == "rough" and not o.noTorches then
			local nT = math.floor(len / 28)
			for i = 1, nT do
				local s = i * len / (nT + 1)
				if not doorAt(room, side, s - 3, s + 3) then
					P.torch(ctx, K.fpos(fr, s, 9, 2.7), n)
				end
			end
		end
	end
	-- corner piers
	if o.style ~= "rough" then
		local pal = th.trim or th.wall
		for _, cx in { room.x0, room.x1 } do
			for _, cz in { room.z0, room.z1 } do
				local ix = if cx == room.x0 then 1 else -1
				local iz = if cz == room.z0 then 1 else -1
				K.box(ctx, V(cx, y - 0.2, cz), V(cx + ix * 3.6, y + hs, cz + iz * 3.6), K.pj(ctx, pal, 0.05), th.trimMat or th.mat)
				K.box(ctx, V(cx, y - 0.2, cz), V(cx + ix * 4.4, y + 3.2, cz + iz * 4.4), K.pj(ctx, pal, 0.05), th.trimMat or th.mat)
			end
		end
	end
	-- vault
	if o.noVault then
		K.box(ctx, V(room.x0 - 4, y + H, room.z0 - 4), V(room.x1 + 4, y + H + 4, room.z1 + 4), Palette.shade(K.pj(ctx, th.wall, 0.05), 0.8), th.wallMat or th.mat, true)
	else
		local ribs = {}
		local La = math.max(room.sx, room.sz)
		local nr = math.max(1, math.floor(La / sp))
		local step = La / nr
		local base = if longX(room) then room.x0 else room.z0
		for i = 1, nr - 1, (o.ribEvery or 1) do
			table.insert(ribs, base + i * step)
		end
		room.ribs = ribs
		room.insets = K.vault(ctx, room.x0, room.z0, room.x1, room.z1, y + hs, y + H, { ribs = if o.ribs == false then nil else ribs, hole = o.hole, steps = o.steps, depth = o.vaultDepth })
	end
end

-- ------------------------------------------------------------------ wall dressing
local function niche(ctx, fr, s, y0, w, h, content)
	local th = ctx.theme
	local dark = Palette.shade(K.pj(ctx, th.wall, 0.05), 0.35)
	local tc = K.pj(ctx, th.trim or th.wall, 0.05)
	K.fbox(ctx, fr, s - w / 2, s + w / 2, y0, y0 + h, -0.2, 0.38, dark, M.Slate)
	K.fbox(ctx, fr, s - w / 2 - 0.5, s + w / 2 + 0.5, y0 - 0.5, y0, -0.2, 1.1, tc, th.trimMat or th.mat)
	K.fbox(ctx, fr, s - w / 2 - 0.5, s + w / 2 + 0.5, y0 + h, y0 + h + 0.5, -0.2, 0.9, tc, th.trimMat or th.mat)
	K.fbox(ctx, fr, s - w / 2 - 0.5, s - w / 2, y0, y0 + h, -0.2, 0.9, tc, th.trimMat or th.mat)
	K.fbox(ctx, fr, s + w / 2, s + w / 2 + 0.5, y0, y0 + h, -0.2, 0.9, tc, th.trimMat or th.mat)
	local base = K.fpos(fr, s, y0, 0.55)
	local look = CFrame.lookAt(base, base + fr.n)
	if content == "skull" then
		P.skull(ctx, look * CF(ctx.rng:float(-0.6, 0.6), 0, 0), 0.9, true)
		P.bone(ctx, look * CF(0, 0, 0.2) * ANG(0, math.pi / 2, 0), math.min(2.2, w - 0.6))
	elseif content == "skulls" then
		for i = -1, 1 do
			P.skull(ctx, look * CF(i * w * 0.3, 0, 0) * ANG(0, ctx.rng:float(-0.3, 0.3), 0), 0.8, true)
		end
	elseif content == "candle" then
		P.candles(ctx, base, 3, 0.4, ctx.rng:chance(0.4), 12)
	end
end
R.niche = niche

-- banners, niches, shelves and props against the walls
function R.dressWalls(ctx, room, o)
	local th = ctx.theme
	local rng = ctx.rng
	local fl = th.flavor
	for _, sl in room.slots do
		local roll = rng:float()
		local fr = sl.fr
		if sl.w > 5 and roll < (o.banner or 0.3) then
			local top = K.fpos(fr, sl.s, math.min(room.hs - 5, (o.bannerTop or room.hs - 5)), 0.2)
			local bw = math.min(sl.w - 1, rng:float(4.5, 7))
			P.banner(ctx, CFrame.lookAt(top, top + sl.n), bw, math.min(room.hs - 8, rng:float(14, 24)), th.banner or th.accent, th.emblem)
		elseif sl.w > 6 and roll < (o.banner or 0.3) + (o.niche or 0.2) then
			local nw = math.min(3.4, (sl.w - 2) / 2)
			for row = 0, (o.nicheRows or 2) - 1 do
				for col = -1, 1, 2 do
					niche(ctx, fr, sl.s + col * (nw / 2 + 0.7), 4.2 + row * 3.6, nw, 2.4, if rng:chance(0.7) then "skull" else (if fl == "bone" then "skulls" else "candle"))
				end
			end
		elseif roll < 0.72 then
			-- floor prop against the wall
			local p = K.fpos(fr, sl.s, 0, 3.2)
			if L.free(room, p.X, p.Z, 2.4) then
				L.block(room, p.X - 3, p.Z - 3, p.X + 3, p.Z + 3)
				local cf = CFrame.lookAt(p, p + sl.n)
				local pick = rng:float()
				if fl == "mine" or fl == "forge" then
					if pick < 0.5 then
						P.crates(ctx, cf)
					else
						P.weaponRack(ctx, cf * CF(0, 0, 0.6))
					end
				elseif pick < 0.28 then
					P.bookshelf(ctx, cf * CF(0, 0, 1.4), 6, rng:float(8, 11))
				elseif pick < 0.45 then
					P.weaponRack(ctx, cf * CF(0, 0, 0.6))
				elseif pick < 0.62 then
					P.coffin(ctx, cf * ANG(0, math.pi / 2, 0) * CF(0, 0, 0), rng:chance(0.4))
				elseif pick < 0.8 then
					P.crates(ctx, cf)
				else
					P.skeleton(ctx, cf * CF(0, 0, 1.2), "sit", { rags = if rng:chance(0.5) then Palette.shade(th.accent, 0.6) else nil })
				end
			end
		end
		-- roots / moss / cobwebs
		if (fl == "cistern" or fl == "mine" or fl == "crypt") and rng:chance(o.roots or 0.15) then
			P.roots(ctx, K.fpos(fr, sl.s + rng:float(-3, 3), room.hs - 1, 0.3), sl.n, rng:float(10, room.hs - 4))
		end
	end
	-- cobwebs in the upper corners and pilaster heads
	for i = 1, (o.webs or 4) do
		local cx = if rng:chance(0.5) then room.x0 + 3.7 else room.x1 - 3.7
		local cz = if rng:chance(0.5) then room.z0 + 3.7 else room.z1 - 3.7
		local ax = if cx < room.cx then 1 else -1
		local az = if cz < room.cz then 1 else -1
		local y = room.y + rng:float(4, room.hs - 1)
		P.cobweb(ctx, V(cx, y, cz), V(ax, 0, 0), V(0, 0, az), rng:float(2, 4))
	end
end

-- scattered floor props
function R.dressFloor(ctx, room, n)
	local th = ctx.theme
	local rng = ctx.rng
	local fl = th.flavor
	for i = 1, n do
		local p = spot(ctx, room, 3, 6)
		if not p then
			break
		end
		local r = rng:float()
		if r < 0.25 then
			P.bonePile(ctx, p, 2, rng:int(4, 9))
		elseif r < 0.37 then
			P.rubble(ctx, p, 3, rng:int(4, 8))
		elseif r < 0.47 then
			P.candelabra(ctx, p, rng:float(5, 7))
		elseif r < 0.55 then
			K.grate(ctx, p, 6, 6, th.grateGlow or th.glow, rng:chance(0.5))
		elseif r < 0.64 then
			P.skeleton(ctx, CF(p) * ANG(0, rng:angle(), 0), "lie")
		elseif r < 0.72 then
			P.puddle(ctx, p, rng:float(1.5, 3))
		elseif r < 0.8 then
			if fl == "cistern" or fl == "mine" then
				P.shrooms(ctx, p, 2, rng:int(4, 8), th.glow, true)
			elseif fl == "forge" then
				P.cauldron(ctx, p, th.glow)
			else
				P.candles(ctx, p, rng:int(5, 9), 1.2, rng:chance(0.5))
			end
		elseif r < 0.88 then
			P.brokenColumn(ctx, p, rng:float(3.5, 5.5), rng:float(3, 10))
		else
			P.cage(ctx, p, nil, rng:chance(0.6))
		end
	end
	-- hanging cages & chains
	for i = 1, rng:int(1, 3) do
		local p = spot(ctx, room, 2.5, 10)
		if p then
			if rng:chance(0.55) then
				P.cage(ctx, p + V(0, rng:float(8, math.min(16, room.hs - 8)), 0), room.y + room.h - 2, rng:chance(0.5))
			else
				P.chain(ctx, p + V(0, room.h - 2, 0), p + V(0, rng:float(6, 14), 0), 1.6)
			end
		end
	end
end

-- spawn spots on the open floor
function R.spots(ctx, room, n)
	for i = 1, n do
		local p = L.spot(ctx.rng, room, 3, 7, false)
		if p then
			addSpot(room, p)
			L.block(room, p.X - 1, p.Z - 1, p.X + 1, p.Z + 1)
		end
	end
end

-- ------------------------------------------------------------------ galleries
-- gallery walkway along a long wall. returns true if built
function R.gallery(ctx, room, side, depth: number, gh: number)
	local th = ctx.theme
	local rng = ctx.rng
	local fr = room.frames[side]
	local _, _, n, len = L.side(room, side)
	local run = math.ceil(gh * 1.6)
	-- doors in this wall must fit under the gallery
	if doorAt(room, side, 0, len, gh - 2) then
		return false
	end
	-- stair end must be free of doors (this wall and the end wall)
	local endWalls
	if side == "xn" or side == "xp" then
		endWalls = { "zn", "zp" }
	else
		endWalls = { "xn", "xp" }
	end
	local _, _, _, endLen = L.side(room, endWalls[1])
	local nearLo, nearHi
	if side == "xn" or side == "zn" then
		nearLo, nearHi = 0, depth + 3
	else
		nearLo, nearHi = endLen - depth - 3, endLen
	end
	local choice = nil
	for _, e in { 1, 2 } do
		local s0 = if e == 1 then 4 else len - 4 - run
		if not doorAt(room, side, s0 - 2, s0 + run + 2) and not doorAt(room, endWalls[e], nearLo, nearHi) then
			choice = e
			break
		end
	end
	if not choice then
		return false
	end
	local sStair0 = if choice == 1 then 4 else len - 4 - run
	local sG0 = if choice == 1 then 4 + run else 0
	local sG1 = if choice == 1 then len else len - 4 - run
	-- slab + joists
	local slab = K.fbox(ctx, fr, sG0, sG1, gh - 1.6, gh, -0.2, depth, K.pj(ctx, th.floor, 0.04), th.floorMat or th.mat, true)
	if slab then
		slab.Name = "Gallery"
	end
	local j = sG0 + 4
	while j < sG1 - 2 do
		K.fbox(ctx, fr, j - 0.6, j + 0.6, gh - 2.6, gh - 1.6, 0, depth - 0.4, K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat)
		j += 6
	end
	-- tiles on top
	local a = K.fpos(fr, sG0, gh, 0)
	local b = K.fpos(fr, sG1, gh, depth - 1.4)
	K.floor(ctx, math.min(a.X, b.X), math.min(a.Z, b.Z), math.max(a.X, b.X), math.max(a.Z, b.Z), gh + room.y, { noSlab = true, tile = 4.5, cover = 0.7 })
	-- parapet
	K.fbox(ctx, fr, sG0, sG1, gh, gh + 3, depth - 1.2, depth, K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat, true)
	K.fbox(ctx, fr, sG0, sG1, gh + 3, gh + 3.5, depth - 1.5, depth + 0.3, K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat)
	K.fbox(ctx, fr, sG0, sG1, gh - 1.6, gh - 0.8, depth - 0.2, depth + 0.4, K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat)
	-- supports: pillars at the gallery edge with arches between
	local nP = math.max(2, math.floor((sG1 - sG0) / 16))
	local prevTop = nil
	for i = 0, nP do
		local s = sG0 + 2 + i * (sG1 - sG0 - 4) / nP
		local base = K.fpos(fr, s, 0, depth - 2)
		K.pillar(ctx, base, 4, room.hs - 1, { noFlutes = true, bands = 10 })
		L.block(room, base.X - 3.5, base.Z - 3.5, base.X + 3.5, base.Z + 3.5)
		local top = K.fpos(fr, s, gh - 6.5, depth - 2)
		if prevTop then
			K.arch(ctx, prevTop + (top - prevTop).Unit * 2, top - (top - prevTop).Unit * 2, 3.6, 3, { band = 1.4 })
		end
		prevTop = top
		if i % 2 == 1 then
			-- torch on the pillar facing the nave
			P.torch(ctx, K.fpos(fr, s, 10, depth + 0.05), fr.n)
		end
	end
	-- stair along the wall
	local dirS = if choice == 1 then fr.u else -fr.u
	local baseS = if choice == 1 then K.fpos(fr, sStair0, 0, 4.6) else K.fpos(fr, sStair0 + run, 0, 4.6)
	K.stairs(ctx, baseS, dirS, 7, gh, run)
	local e1 = K.fpos(fr, sStair0 - 1, 0, 0)
	local e2 = K.fpos(fr, sStair0 + run + 1, 0, 9)
	L.block(room, math.min(e1.X, e2.X), math.min(e1.Z, e2.Z), math.max(e1.X, e2.X), math.max(e1.Z, e2.Z))
	-- block the aisle under the gallery for large props, keep spots up top
	local ga = K.fpos(fr, sG0, 0, 0)
	local gb = K.fpos(fr, sG1, 0, depth)
	L.block(room, math.min(ga.X, gb.X), math.min(ga.Z, gb.Z), math.max(ga.X, gb.X), math.max(ga.Z, gb.Z))
	for i = 1, 2 do
		local s = rng:float(sG0 + 4, sG1 - 4)
		addSpot(room, K.fpos(fr, s, 0, depth * 0.45), room.y + gh)
	end
	-- props on the gallery
	for i = 1, rng:int(1, 3) do
		local s = rng:float(sG0 + 4, sG1 - 4)
		local p = K.fpos(fr, s, gh, 2.5)
		if rng:chance(0.5) then
			P.crates(ctx, CFrame.lookAt(p, p + fr.n))
		else
			P.bonePile(ctx, p, 1.5, 5)
		end
	end
	return true
end

-- ------------------------------------------------------------------ corridors
function R.corridor(ctx, c)
	local th = ctx.theme
	local rng = ctx.rng
	local fl = th.flavor
	local ax = if c.axis == "x" then V(1, 0, 0) else V(0, 0, 1)
	local across = if c.axis == "x" then V(0, 0, 1) else V(1, 0, 0)
	local s0, s1 = c.s0, c.s1
	if c.a.round then
		s0 -= 2
	end
	if c.b.round then
		s1 += 2
	end
	local len = s1 - s0
	local function P3(s, y, o)
		local p = if c.axis == "x" then V(s, y, c.c + o) else V(c.c + o, y, s)
		return p
	end
	local ya, yb = c.ya, c.yb
	local ylo, yhi = math.min(ya, yb), math.max(ya, yb)
	local dy = yhi - ylo
	local w, ch = c.w, c.ch
	local run = math.ceil(dy * 1.6)
	local mid = (s0 + s1) / 2
	local sa, sb = mid - run / 2, mid + run / 2
	-- floors
	local lowFirst = ya <= yb
	local function floorRun(f0, f1, y)
		if f1 - f0 < 0.5 then
			return
		end
		local a = P3(f0, y, -w / 2)
		local b = P3(f1, y, w / 2)
		K.floor(ctx, math.min(a.X, b.X), math.min(a.Z, b.Z), math.max(a.X, b.X), math.max(a.Z, b.Z), y, { tile = 5 })
	end
	if dy < 0.5 then
		floorRun(s0, s1, ylo)
	elseif lowFirst then
		floorRun(s0, sb, ylo)
		floorRun(sb, s1, yhi)
		K.stairs(ctx, P3(sa, ylo, 0), ax, w - 2.6, dy, run, { sides = false })
	else
		floorRun(s0, sa, yhi)
		floorRun(sa, s1, ylo)
		K.stairs(ctx, P3(sb, ylo, 0), -ax, w - 2.6, dy, run, { sides = false })
	end
	-- walls: low section (full height) + high section
	local sections = {}
	if dy < 0.5 then
		table.insert(sections, { s0, s1, ylo, ch })
	elseif lowFirst then
		table.insert(sections, { s0, sb, ylo, dy + ch })
		table.insert(sections, { sb, s1, yhi, ch })
	else
		table.insert(sections, { s0, sa, yhi, ch })
		table.insert(sections, { sa, s1, ylo, dy + ch })
	end
	for _, sec in sections do
		local f0, f1, y, h = sec[1], sec[2], sec[3], sec[4]
		for _, sg in { -1, 1 } do
			local a = P3(f0, y, sg * w / 2)
			local fr = K.frame(a, ax, across * -sg, y)
			K.wall(ctx, fr, f1 - f0, { height = h, spring = h, lowTop = math.min(h - 3, 9), trim = 0, coarse = true, style = if fl == "mine" then "rough" else th.wallStyle })
		end
		-- ceiling
		local a = P3(f0, y + h, -w / 2 - 4)
		local b = P3(f1, y + h + 4, w / 2 + 4)
		K.box(ctx, a, b, Palette.shade(K.pj(ctx, th.wall, 0.05), 0.8), th.wallMat or th.mat, true)
	end
	-- ribs: stone arches (timber frames in the mines) + torches
	local nR = math.max(1, math.floor(len / 12))
	local tcount = 0
	for i = 1, nR - 1 do
		local s = s0 + i * len / nR
		local y
		if dy < 0.5 then
			y = ylo
		elseif lowFirst then
			y = if s < sa then ylo elseif s > sb then yhi else ylo + dy * (s - sa) / run
		else
			y = if s > sb then ylo elseif s < sa then yhi else yhi - dy * (s - sa) / run
		end
		local ceilY = yhi + ch
		local onStair = dy > 0.5 and s > sa - 1 and s < sb + 1
		if fl == "mine" then
			P.timberFrame(ctx, P3(s, y, 0), w - 2, ceilY - y - 1.4, c.axis == "x")
		elseif not onStair then
			for _, sg in { -1, 1 } do
				local base = P3(s, y, sg * (w / 2 - 0.6))
				local size = if c.axis == "x" then V(2.2, ceilY - y, 1.6) else V(1.6, ceilY - y, 2.2)
				K.deco(ctx, size, CF(base + V(0, (ceilY - y) / 2 - 0.2, 0)), K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat)
			end
			local sp = ceilY - 6
			K.arch(ctx, P3(s, sp, -w / 2 + 1.4), P3(s, sp, w / 2 - 1.4), 5.5, 2.2, { band = 1.2, steps = 4 })
			tcount += 1
			if tcount % 3 == 1 then
				local sg = if (tcount // 3) % 2 == 0 then -1 else 1
				P.torch(ctx, P3(s, y + 8.5, sg * (w / 2 - 1.4)), across * -sg)
			end
		end
	end
	-- a few props along the walls
	local flat = {}
	for i = 1, 3 do
		local s = rng:float(s0 + 6, s1 - 6)
		if dy < 0.5 or s < sa - 3 or s > sb + 3 then
			table.insert(flat, s)
		end
	end
	for i, s in flat do
		local y
		if dy < 0.5 then
			y = ylo
		elseif lowFirst then
			y = if s < sa then ylo else yhi
		else
			y = if s < sa then yhi else ylo
		end
		local sg = rng:sign()
		local p = P3(s, y, sg * (w / 2 - 2.8))
		local r = rng:float()
		if r < 0.3 then
			P.bonePile(ctx, p, 1.2, 5)
		elseif r < 0.5 and w >= 18 then
			P.crates(ctx, CFrame.lookAt(p, p - across * sg))
		elseif r < 0.65 then
			P.skeleton(ctx, CFrame.lookAt(p, p - across * sg) * CF(0, 0, 0.8), "sit")
		elseif r < 0.8 then
			P.puddle(ctx, P3(s, y, 0), rng:float(1.2, 2.2))
		else
			P.rubble(ctx, p, 1.5, 4)
		end
		if i == 1 then
			c.spot = P3(s, y + 3, 0)
		end
	end
	if fl == "forge" and dy < 0.5 then
		local gx = if c.axis == "x" then len * 0.5 else 4
		local gz = if c.axis == "x" then 4 else len * 0.5
		K.grate(ctx, P3((s0 + s1) / 2, ylo, 0), gx, gz, th.grateGlow or th.glow, true)
	end
	-- cobwebs in the corners
	if rng:chance(0.6) then
		local s = rng:float(s0 + 3, s1 - 3)
		local y = if s > sa and s < sb then yhi else (if lowFirst then (if s < sa then ylo else yhi) else (if s < sa then yhi else ylo))
		local sg = rng:sign()
		P.cobweb(ctx, P3(s, y + ch - 0.5, sg * (w / 2 - 0.4)), -across * sg, V(0, -1, 0), rng:float(1.5, 3))
	end
end

-- ------------------------------------------------------------------ gate (exit)
-- Monumental exit: grand stair up to a landing, a sealed archway with the
-- portal behind it. Must be called BEFORE the shell (it adds the opening).
function R.gatePlan(room, side)
	local _, _, _, len = L.side(room, side)
	room.gate = { side = side, c = len / 2, w = 22, rise = 8, depth = 18 }
	table.insert(room.doors[side], { c = len / 2, w = 22, h = 8 + 30, gate = true })
end

function R.gate(ctx, room, refs)
	local th = ctx.theme
	local rng = ctx.rng
	local g = room.gate
	local fr = room.frames[g.side]
	local W = S.World
	local rise, depth = g.rise, g.depth
	local c = g.c
	local stone = th.trim or th.wall
	-- fill the opening below the landing, landing block, grand stair
	K.fbox(ctx, fr, c - g.w / 2 - 0.1, c + g.w / 2 + 0.1, -3, rise, -18, 0, K.pj(ctx, stone, 0.04), th.trimMat or th.mat, true)
	local land = K.fbox(ctx, fr, c - 20, c + 20, -0.2, rise, 0, depth, K.pj(ctx, stone, 0.04), th.trimMat or th.mat, true)
	if land then
		land.Name = "GateLanding"
	end
	K.fbox(ctx, fr, c - 20.6, c + 20.6, rise - 0.6, rise + 0.3, depth - 0.4, depth + 0.5, K.pj(ctx, stone, 0.04), th.trimMat or th.mat)
	local la = K.fpos(fr, c - 19, 0, 0.4)
	local lb = K.fpos(fr, c + 19, 0, depth - 0.6)
	K.floor(ctx, math.min(la.X, lb.X), math.min(la.Z, lb.Z), math.max(la.X, lb.X), math.max(la.Z, lb.Z), room.y + rise, { noSlab = true, tile = 5, cover = 0.9, pal = th.trim or th.floor })
	local run = math.ceil(rise * 1.7)
	K.stairs(ctx, K.fpos(fr, c, 0, depth + run), -fr.n, 28, rise, run)
	local ba = K.fpos(fr, c - 22, 0, 0)
	local bb = K.fpos(fr, c + 22, 0, depth + run + 3)
	L.block(room, math.min(ba.X, bb.X), math.min(ba.Z, bb.Z), math.max(ba.X, bb.X), math.max(ba.Z, bb.Z))
	-- alcove behind the arch: floor, side walls, roof, stairs climbing into the dark
	local T = 16
	K.fbox(ctx, fr, c - g.w / 2 - 1, c + g.w / 2 + 1, rise + 30, rise + 34, -T - 4, 0, K.pj(ctx, th.wall, 0.04), th.wallMat or th.mat, true)
	for _, sg in { -1, 1 } do
		local e = c + sg * (g.w / 2)
		K.fbox(ctx, fr, math.min(e, e + sg * 4), math.max(e, e + sg * 4), -3, rise + 34, -T - 4, -3.9, K.pj(ctx, th.wall, 0.04), th.wallMat or th.mat, true)
	end
	K.fbox(ctx, fr, c - g.w / 2 - 1, c + g.w / 2 + 1, -3, rise + 34, -T - 6, -T, Palette.shade(K.pj(ctx, th.wall, 0.04), 0.7), th.wallMat or th.mat, true)
	for i = 1, 7 do
		K.fbox(ctx, fr, c - g.w / 2 + 1, c + g.w / 2 - 1, rise, rise + i * 1.6, -T + (7 - i) * 1.3, -T + (8 - i) * 1.3, K.pj(ctx, stone, 0.06), th.trimMat or th.mat)
	end
	-- archway ring: stepped pointed arch around the opening
	local archBase = rise + 18
	K.arch(ctx, K.fpos(fr, c - g.w / 2 - 1.2, archBase, 0.9), K.fpos(fr, c + g.w / 2 + 1.2, archBase, 0.9), 12, 2.4, { band = 2.4, steps = 6 })
	K.arch(ctx, K.fpos(fr, c - g.w / 2 - 3.4, archBase, 1.9), K.fpos(fr, c + g.w / 2 + 3.4, archBase, 1.9), 14, 1.6, { band = 1.6, steps = 6 })
	for _, sg in { -1, 1 } do
		local e = c + sg * (g.w / 2 + 2.2)
		K.fbox(ctx, fr, e - 2.2, e + 2.2, rise, archBase + 1, -0.2, 2.6, K.pj(ctx, stone, 0.04), th.trimMat or th.mat)
		K.fbox(ctx, fr, e - 3, e + 3, rise, rise + 3, -0.2, 3.4, K.pj(ctx, stone, 0.04), th.trimMat or th.mat)
		K.fbox(ctx, fr, e - 3, e + 3, archBase - 1, archBase + 1, -0.2, 3.4, K.pj(ctx, stone, 0.04), th.trimMat or th.mat)
		-- glowing rune strips on the jambs
		K.fbox(ctx, fr, e - 0.4, e + 0.4, rise + 5, archBase - 3, 2.6, 2.75, th.glow, M.Neon)
	end
	-- lintel with the room's inner arch fill (blind tympanum)
	K.fbox(ctx, fr, c - g.w / 2, c + g.w / 2, rise + 30, rise + 31.2, -0.2, 0.6, K.pj(ctx, stone, 0.04), th.trimMat or th.mat)
	-- portal inside the arch, facing the room
	local pp = K.fpos(fr, c, rise, -3)
	local portal, film = W.portal(ctx.geo, CFrame.lookAt(pp, pp + fr.n), th.glow, "ASCEND")
	refs.portal = portal
	refs.portalFilm = film
	-- the seal
	local sealC = K.fpos(fr, c, rise + 15, -0.9)
	local size = if fr.alongX then V(g.w, 30, 1.4) else V(1.4, 30, g.w)
	local seal = K.solid(ctx, size, CF(sealC), th.accent, M.ForceField, { Transparency = 0.2, CastShadow = false })
	seal.Name = "Seal"
	refs.barrier = seal
	K.light(ctx, seal, th.glow, 34, 1.6)
	-- guardians, braziers, obelisks
	for _, sg in { -1, 1 } do
		local sp = if room.round then K.fpos(fr, c + sg * 22, 0, 12) else K.fpos(fr, c + sg * 27, 0, 7)
		P.knight(ctx, CFrame.lookAt(sp, sp + fr.n), 2.1, { plinth = 2.4 })
		L.block(room, sp.X - 6, sp.Z - 6, sp.X + 6, sp.Z + 6)
		local bp = K.fpos(fr, c + sg * 16.5, rise, depth - 3)
		P.brazier(ctx, bp, 1, true)
		if not room.round then
			P.banner(ctx, CFrame.lookAt(K.fpos(fr, c + sg * 36, room.hs - 4, 0.3), K.fpos(fr, c + sg * 36, room.hs - 4, 5)), 7, 26, th.banner or th.accent, th.emblem)
		end
	end
	local center = K.fpos(fr, c, rise, depth / 2)
	refs.exitCenter = center
	room.exitCenter = center
	for _, sg in { -1, 1 } do
		P.bonePile(ctx, K.fpos(fr, c + sg * 10, rise, 3), 1.5, 5)
	end
end

-- ------------------------------------------------------------------ spawn
function R.spawn(ctx, room, refs, opts)
	local th = ctx.theme
	local rng = ctx.rng
	local y = room.y
	local cx, cz = room.cx, room.cz
	reservePaths(room)
	R.shell(ctx, room, { hs = math.floor(room.h * 0.58), pilasters = 13, torchEvery = 3, hole = { x = cx, z = cz, r = 7 }, vaultDepth = 0.68, noFill = true })
	-- the shaft above the hole
	local top = y + room.h
	local sh = 64
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local off = V(d[1], 0, d[2]) * 9
		local size = if d[1] ~= 0 then V(4, sh, 22) else V(22, sh, 4)
		K.solid(ctx, size, CF(V(cx, top + sh / 2, cz) + off), K.pj(ctx, th.rock or th.wall, 0.08), th.roughMat or M.Rock)
		-- ragged rock lips
		for i = 1, 4 do
			local p = V(cx, top + rng:float(2, sh - 4), cz) + off * 0.78 + V(d[2], 0, d[1]) * rng:float(-5, 5)
			K.deco(ctx, V(rng:float(2, 4), rng:float(3, 7), rng:float(2, 4)), CF(p) * ANG(rng:float(-0.3, 0.3), rng:angle(), rng:float(-0.3, 0.3)), K.pj(ctx, th.rock or th.wall, 0.1), th.roughMat or M.Rock)
		end
	end
	K.solid(ctx, V(22, 4, 22), CF(cx, top + sh + 2, cz), K.pj(ctx, th.rock or th.wall, 0.05), M.Rock)
	-- pale sky light at the top of the shaft
	local pale = rgb(170, 186, 230)
	local sky = K.deco(ctx, V(14, 0.4, 14), CF(cx, top + sh - 0.3, cz), rgb(200, 210, 240), M.Neon, { Transparency = 0.2 })
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 55
	spot.Range = 60
	spot.Brightness = 4
	spot.Color = pale
	spot.Shadows = true
	spot.Parent = sky
	ctx.lights += 1
	ctx.shadows += 1
	-- the light column + a soft fill light at the bottom
	local col = K.deco(ctx, V(11, room.h + sh - 2, 11), CF(cx, y + (room.h + sh) / 2 - 1, cz), pale, M.Neon, { Transparency = 0.94, CastShadow = false })
	K.deco(ctx, V(5, room.h + sh - 2, 5), CF(cx, y + (room.h + sh) / 2 - 1, cz) * ANG(0, 0.6, 0), pale, M.Neon, { Transparency = 0.93, CastShadow = false })
	local fill = K.deco(ctx, V(1, 1, 1), CF(cx, y + 14, cz), pale, M.Neon, { Transparency = 1 })
	K.light(ctx, fill, pale, 44, 1.6, true)
	local dust = Kit.emitter(col, {
		Texture = Kit.SQUARE,
		Color = ColorSequence.new(rgb(220, 225, 255)),
		LightEmission = 0.6,
		Rate = 8,
		Lifetime = NumberRange.new(6, 10),
		Speed = NumberRange.new(0.2, 0.8),
		Size = NumberSequence.new(0.15, 0),
		Transparency = NumberSequence.new(0.3, 1),
		SpreadAngle = Vector2.new(180, 180),
	})
	local _ = dust
	-- look direction: toward the open floor away from the nearest wall
	local dir = V(1, 0, 0)
	local best = -1
	for _, d in { V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) } do
		local p = V(cx, y, cz) + d * 12
		local sc = if L.free(room, p.X, p.Z, 3) then 1 else 0
		sc += rng:float(0, 0.5)
		if sc > best then
			best = sc
			dir = d
		end
	end
	-- debris where you landed: broken beams, rubble ring, dirt
	local function awayFromSword(a)
		local v = V(math.cos(a), 0, math.sin(a))
		return v:Dot(dir) < 0.35
	end
	for i = 1, 14 do
		local a = rng:angle()
		local r = rng:float(5, 11)
		local p = V(cx + math.cos(a) * r, y, cz + math.sin(a) * r)
		if not awayFromSword(a) then
			continue
		end
		local s = rng:float(0.8, 2.4)
		K.deco(ctx, V(s * 1.3, s * 0.7, s), CF(p + V(0, s * 0.25, 0)) * ANG(rng:float(-0.4, 0.4), rng:angle(), rng:float(-0.4, 0.4)), K.pj(ctx, th.rock or th.wall, 0.1), M.Rock)
	end
	for i = 1, 3 do
		local a = rng:angle()
		if not awayFromSword(a) then
			a += math.pi
		end
		local p = V(cx + math.cos(a) * 7, y + 0.6, cz + math.sin(a) * 7)
		K.deco(ctx, V(0.9, 0.9, rng:float(6, 10)), CF(p) * ANG(rng:float(-0.25, 0.25), a + rng:float(-0.5, 0.5), rng:float(-0.2, 0.2)), K.j(ctx, rgb(70, 50, 34), 0.1), M.Wood)
	end
	K.deco(ctx, V(9, 0.3, 9), CF(cx, y + 0.2, cz) * ANG(0, 0.4, 0), K.j(ctx, rgb(64, 54, 46), 0.05), M.Ground)
	K.deco(ctx, V(6, 0.5, 6), CF(cx + 1, y + 0.3, cz - 1) * ANG(0, 1.1, 0), K.j(ctx, rgb(58, 50, 42), 0.05), M.Ground)
	local sc = V(cx, y, cz)
	refs.spawnCenter = sc
	refs.spawnCF = CFrame.lookAt(sc + V(0, 3, 0), sc + dir * 10 + V(0, 3, 0))
	-- the old sword and its previous owner: in the light, a few steps ahead
	local side = V(-dir.Z, 0, dir.X)
	local sword = sc + dir * 7 + side * 2.2
	refs.swordPos = sword
	L.block(room, sword.X - 5, sword.Z - 5, sword.X + 5, sword.Z + 5)
	if opts.tutorial then
		refs.skeleton = true
		-- a broken grave slab he leans against, candles, his shield
		local back = sword + dir * 3.2 + side * 1.2
		local bcf = CFrame.lookAt(back, back - dir)
		K.solid(ctx, V(4.4, 3.2, 1.6), bcf * CF(0, 1.6, 1.4) * ANG(-0.12, 0, 0.05), K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat)
		K.deco(ctx, V(3.2, 0.6, 0.3), bcf * CF(0, 2.3, 0.55) * ANG(-0.12, 0, 0.05), Palette.shade(K.pj(ctx, th.trim or th.wall, 0.05), 0.6), th.trimMat or th.mat)
		K.deco(ctx, V(4.6, 1.2, 1.8), bcf * CF(1.6, 0.5, 2.6) * ANG(0.2, 0.4, 0.1), K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat)
		P.skeleton(ctx, bcf * CF(0, 0, 0.3), "sit", { reach = sword, rags = rgb(70, 52, 44) })
		-- dented shield and a helmet
		K.deco(ctx, V(2.4, 2.8, 0.3), bcf * CF(-1.9, 0.9, -0.2) * ANG(-1.25, 0.3, 0), rgb(88, 70, 50), M.WoodPlanks)
		K.deco(ctx, V(0.5, 0.5, 0.35), bcf * CF(-1.9, 1.05, -0.4) * ANG(-1.25, 0.3, 0), P.IRON, M.Metal)
		K.deco(ctx, V(1.1, 1, 1.2), bcf * CF(1.6, 0.5, -0.9) * ANG(0.4, 0.8, 1.2), rgb(96, 96, 100), M.CorrodedMetal)
		P.candles(ctx, (bcf * CF(2.4, 0, 0.4)).Position, 4, 0.5, true, 14)
		P.candles(ctx, (bcf * CF(-2.8, 0, 0.8)).Position, 3, 0.4, false)
		P.bonePile(ctx, sword + side * 3 + dir * 1, 1, 3, 0)
		-- a faint cold glow on the blade spot
		local g = K.deco(ctx, V(2.6, 0.08, 1.2), CF(sword + V(0, 0.06, 0)) * ANG(0, 0.5, 0), rgb(150, 160, 210), M.Neon, { Transparency = 0.7 })
		K.light(ctx, g, rgb(170, 180, 255), 10, 0.8)
	end
	R.dressWalls(ctx, room, { banner = 0.2, niche = 0.35 })
	R.dressFloor(ctx, room, 4)
end

-- ------------------------------------------------------------------ kinds
local function nave(ctx, room)
	-- central dais or a line of sarcophagi down the middle
	local rng = ctx.rng
	local th = ctx.theme
	local La, Wb = dims(room)
	if rng:chance(0.55) then
		local c = at(room, La / 2, Wb / 2)
		local cf = if longX(room) then CF(c) else CF(c) * ANG(0, math.pi / 2, 0)
		local dl, dw = 26, 14
		K.solid(ctx, V(dl, 3, dw), cf * CF(0, 1.5, 0), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
		K.deco(ctx, V(dl + 1, 0.6, dw + 1), cf * CF(0, 0.3, 0), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
		K.floor(ctx, c.X - (if longX(room) then dl else dw) / 2 + 0.5, c.Z - (if longX(room) then dw else dl) / 2 + 0.5, c.X + (if longX(room) then dl else dw) / 2 - 0.5, c.Z + (if longX(room) then dw else dl) / 2 - 0.5, room.y + 3, { noSlab = true, tile = 3.5, pal = th.trim or th.floor })
		for _, sg in { -1, 1 } do
			local st = cf * CF(sg * (dl / 2 + 4.8), 0, 0)
			K.stairs(ctx, st.Position, cf.RightVector * -sg, 8, 3, 4.8, { sides = false })
		end
		if rng:chance(0.5) then
			P.altar(ctx, cf * CF(0, 3, 0) * ANG(0, math.pi / 2, 0))
		else
			P.knight(ctx, cf * CF(0, 3, 0) * ANG(0, rng:pick({ 0, math.pi }), 0), 1.6, { plinth = 1.2, candles = true })
		end
		for _, sg in { -1, 1 } do
			P.brazier(ctx, (cf * CF(sg * 9, 3, 4.5)).Position, 0.8, false)
		end
		L.block(room, c.X - 18, c.Z - 18, c.X + 18, c.Z + 18)
		addSpot(room, (cf * CF(-6, 0, -3)).Position, room.y + 3)
	else
		for i = 1, 3 do
			local p = at(room, La * (0.25 + i * 0.125), Wb / 2 + rng:float(-6, 6))
			if L.free(room, p.X, p.Z, 5) then
				P.sarcophagus(ctx, (if longX(room) then CF(p) else CF(p) * ANG(0, math.pi / 2, 0)))
				L.block(room, p.X - 5, p.Z - 5, p.X + 5, p.Z + 5)
			end
		end
	end
end

local function chandeliers(ctx, room, n)
	local La, Wb = dims(room)
	for i = 1, n do
		local p = at(room, La * i / (n + 1), Wb / 2, room.y + room.h - (room.insets and 0 or 2))
		P.chandelier(ctx, p, math.min(room.h * 0.55, room.h - 14), 4.5)
	end
end

function R.hall(ctx, room)
	local th = ctx.theme
	local rng = ctx.rng
	reservePaths(room)
	local hs = math.floor(room.h * 0.62)
	local gh = math.clamp(27, 20, hs - 12)
	local sides = if longX(room) then { "zn", "zp" } else { "xn", "xp" }
	local gal = {}
	for _, sd in sides do
		if rng:chance(0.8) and not doorAt(room, sd, 0, 1000, gh - 2) then
			gal[sd] = gh
		end
	end
	R.shell(ctx, room, { hs = hs, pilasters = 13, torchEvery = 2, galleries = gal })
	for sd, g in gal do
		if not R.gallery(ctx, room, sd, 14, g) then
			gal[sd] = nil
		end
	end
	-- freestanding arcade where there is no gallery
	local La, Wb = dims(room)
	for i, sd in sides do
		if not gal[sd] then
			local b = if i == 1 then 16 else Wb - 16
			local prev = nil
			for k = 1, math.floor(La / 26) do
				local a = k * La / (math.floor(La / 26) + 1)
				local p = at(room, a, b)
				if L.free(room, p.X, p.Z, 4) then
					K.pillar(ctx, p, 6, hs, { bands = 12 })
					L.block(room, p.X - 5, p.Z - 5, p.X + 5, p.Z + 5)
					if prev then
						local u = (p - prev).Unit
						K.arch(ctx, prev + u * 3.5 + V(0, hs - 3, 0), p - u * 3.5 + V(0, hs - 3, 0), 6, 3, { band = 2 })
					end
					prev = p
				else
					prev = nil
				end
			end
		end
	end
	nave(ctx, room)
	chandeliers(ctx, room, rng:int(2, 3))
	R.dressWalls(ctx, room, { banner = 0.35, niche = if th.flavor == "crypt" or th.flavor == "bone" then 0.35 else 0.1 })
	R.dressFloor(ctx, room, rng:int(6, 9))
	R.spots(ctx, room, 7)
end

function R.crypt(ctx, room)
	local th = ctx.theme
	local rng = ctx.rng
	reservePaths(room)
	local hs = math.floor(room.h * 0.68)
	R.shell(ctx, room, { hs = hs, pilasters = 12, torchEvery = 2, steps = 3, lowTop = 11 })
	-- pillar grid with beams
	local sp = 22
	local nx = math.max(1, math.floor((room.sx - 28) / sp))
	local nz = math.max(1, math.floor((room.sz - 28) / sp))
	local ox = room.cx - (nx * sp) / 2
	local oz = room.cz - (nz * sp) / 2
	local grid = {}
	for i = 0, nx do
		for k = 0, nz do
			local p = V(ox + i * sp, room.y, oz + k * sp)
			if math.abs(p.X - room.cx) < 3 and math.abs(p.Z - room.cz) < 3 then
				continue
			end
			if L.free(room, p.X, p.Z, 3) then
				K.pillar(ctx, p, 4.5, hs, { noFlutes = true, bands = 8 })
				L.block(room, p.X - 3.5, p.Z - 3.5, p.X + 3.5, p.Z + 3.5)
				grid[i * 100 + k] = p
			end
		end
	end
	for key, p in grid do
		local i, k = key // 100, key % 100
		for _, nb in { (i + 1) * 100 + k, i * 100 + k + 1 } do
			local q = grid[nb]
			if q then
				local u = (q - p).Unit
				K.arch(ctx, p + u * 3 + V(0, hs - 7, 0), q - u * 3 + V(0, hs - 7, 0), 5, 3, { band = 1.8, steps = 4 })
			end
		end
	end
	-- central tomb on a dais
	local c = V(room.cx, room.y, room.cz)
	K.solid(ctx, V(14, 1, 14), CF(c + V(0, 0.5, 0)), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
	K.solid(ctx, V(10, 1, 10), CF(c + V(0, 1.5, 0)), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
	P.sarcophagus(ctx, CF(c + V(0, 2, 0)) * ANG(0, rng:pick({ 0, math.pi / 2 }), 0), { open = rng:chance(0.3) })
	for _, o in { V(6, 0, 6), V(-6, 0, 6), V(6, 0, -6), V(-6, 0, -6) } do
		P.candles(ctx, c + o + V(0, 1, 0), 4, 0.6, o.X > 0 and o.Z > 0, 16)
	end
	-- rows of sarcophagi / coffins / grave slabs between the pillars
	for i = 1, rng:int(5, 9) do
		local p = spot(ctx, room, 4.5, 8)
		if p then
			local r = rng:float()
			local cf = CF(p) * ANG(0, rng:pick({ 0, math.pi / 2 }), 0)
			if r < 0.5 then
				P.sarcophagus(ctx, cf)
			elseif r < 0.75 then
				P.coffin(ctx, cf, rng:chance(0.5))
			else
				K.deco(ctx, V(3.6, 0.3, 6.6), cf * CF(0, 0.12, 0), K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat)
				K.deco(ctx, V(0.5, 0.1, 3.4), cf * CF(0, 0.3, -0.6), Palette.shade(K.pj(ctx, th.trim or th.wall, 0.05), 0.7), th.trimMat or th.mat)
				K.deco(ctx, V(2.0, 0.1, 0.5), cf * CF(0, 0.3, -1.4), Palette.shade(K.pj(ctx, th.trim or th.wall, 0.05), 0.7), th.trimMat or th.mat)
			end
		end
	end
	R.dressWalls(ctx, room, { banner = 0.15, niche = 0.6, nicheRows = 2 })
	R.dressFloor(ctx, room, rng:int(4, 7))
	R.spots(ctx, room, 6)
end

function R.cathedral(ctx, room)
	local th = ctx.theme
	local rng = ctx.rng
	reservePaths(room)
	local hs = math.floor(room.h * 0.56)
	local gh = 28
	local sides = if longX(room) then { "zn", "zp" } else { "xn", "xp" }
	local gal = {}
	for _, sd in sides do
		if not doorAt(room, sd, 0, 1000, gh - 2) then
			gal[sd] = gh
		end
	end
	-- apse at an end wall (prefer one without doors)
	local ends = if longX(room) then { "xn", "xp" } else { "zn", "zp" }
	local apse = ends[rng:int(1, 2)]
	for _, e in ends do
		if #room.doors[e] == 0 then
			apse = e
		end
	end
	R.shell(ctx, room, { hs = hs, pilasters = 16, torchEvery = 2, galleries = gal, steps = 8 })
	for sd, g in gal do
		if not R.gallery(ctx, room, sd, 18, g) then
			gal[sd] = nil
		end
	end
	local La, Wb = dims(room)
	-- nave pillars (massive) where no gallery supports exist
	for i, sd in sides do
		if not gal[sd] then
			local b = if i == 1 then 20 else Wb - 20
			for k = 1, math.floor(La / 24) do
				local p = at(room, k * La / (math.floor(La / 24) + 1), b)
				if L.free(room, p.X, p.Z, 5) then
					K.pillar(ctx, p, 9, hs, { bands = 16 })
					L.block(room, p.X - 7, p.Z - 7, p.X + 7, p.Z + 7)
				end
			end
		end
	end
	-- apse platform with a colossal statue and altar
	local fr = room.frames[apse]
	local _, _, n, len = L.side(room, apse)
	local plat = 5
	local pd = 20
	if not doorAt(room, apse, len / 2 - 22, len / 2 + 22) then
		K.fbox(ctx, fr, len / 2 - 22, len / 2 + 22, -0.2, plat, 0, pd, K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat, true)
		K.fbox(ctx, fr, len / 2 - 22.5, len / 2 + 22.5, plat - 0.6, plat + 0.2, pd - 0.3, pd + 0.4, K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
		K.stairs(ctx, K.fpos(fr, len / 2, 0, pd + 9), -n, 20, plat, 9)
		local sp = K.fpos(fr, len / 2, plat, 6)
		P.knight(ctx, CFrame.lookAt(sp, sp + n), 2.8, { plinth = 2, color = K.pj(ctx, th.statue or th.trim, 0.03) })
		local ap = K.fpos(fr, len / 2, plat, 15)
		P.altar(ctx, CFrame.lookAt(ap, ap + n))
		for _, sg in { -1, 1 } do
			P.brazier(ctx, K.fpos(fr, len / 2 + sg * 17, plat, 14), 1.1, true)
			P.candelabra(ctx, K.fpos(fr, len / 2 + sg * 9, plat, 17), 6)
		end
		local a0 = K.fpos(fr, len / 2 - 23, 0, 0)
		local a1 = K.fpos(fr, len / 2 + 23, 0, pd + 10)
		L.block(room, math.min(a0.X, a1.X), math.min(a0.Z, a1.Z), math.max(a0.X, a1.X), math.max(a0.Z, a1.Z))
		addSpot(room, K.fpos(fr, len / 2 + 12, 0, 8), room.y + plat)
		-- rose window high above
		local wc = K.fpos(fr, len / 2, hs + 4 - 18, 0.5)
		local rr = math.min(11, (room.h - hs) * 0.35 + 6)
		wc = K.fpos(fr, len / 2, hs - rr - 3, 0.5)
		local seg = 16
		for i = 0, seg - 1 do
			local a0g = i / seg * math.pi * 2
			local p0 = wc + fr.u * (math.cos(a0g) * rr) + V(0, math.sin(a0g) * rr, 0)
			local a1g = (i + 1) / seg * math.pi * 2
			local p1 = wc + fr.u * (math.cos(a1g) * rr) + V(0, math.sin(a1g) * rr, 0)
			P.limb(ctx, p0 + n * 0.3, p1 + n * 0.3, 1.4, K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
			if i % 2 == 0 then
				P.limb(ctx, wc + n * 0.25, p0 + n * 0.25, 0.7, K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
			end
		end
		local wcf = CFrame.fromMatrix(wc + n * 0.1, fr.u, UP)
		local glass = K.deco(ctx, V(rr * 1.42, rr * 1.42, 0.2), wcf * ANG(0, 0, math.pi / 4), th.glow, M.Neon, { Transparency = 0.35 })
		K.deco(ctx, V(rr * 1.42, rr * 1.42, 0.18), wcf, Palette.shade(th.glow, 0.8), M.Neon, { Transparency = 0.3 })
		K.light(ctx, glass, th.glow, 50, 1.5)
	end
	-- pews
	local nb = if gal[sides[1]] then 20 else 26
	for row = 1, 6 do
		local a = La * 0.2 + row * 7.5
		if apse == ends[1] then
			a = La - a
		end
		for _, sg in { -1, 1 } do
			local p = at(room, a, Wb / 2 + sg * 11)
			if L.free(room, p.X, p.Z, 3) and rng:chance(0.8) then
				local cf = if longX(room) then CF(p) * ANG(0, math.pi / 2 + (if apse == ends[1] then math.pi else 0), 0) else CF(p) * ANG(0, if apse == ends[1] then math.pi else 0, 0)
				P.pew(ctx, cf, 12, rng:chance(0.3))
			end
		end
	end
	local _ = nb
	chandeliers(ctx, room, 3)
	R.dressWalls(ctx, room, { banner = 0.5, niche = 0.25 })
	R.dressFloor(ctx, room, rng:int(5, 8))
	R.spots(ctx, room, 8)
end

function R.cistern(ctx, room)
	local th = ctx.theme
	local rng = ctx.rng
	local y = room.y
	local depth = 4.5
	local hs = math.floor(room.h * 0.64)
	R.shell(ctx, room, { hs = hs, pilasters = 16, torchEvery = 2, noFloor = true })
	-- pool bottom, margins, causeways
	K.floor(ctx, room.x0, room.z0, room.x1, room.z1, y - depth, { cover = 0.4, pal = th.rock or th.floor, mat = M.Slate })
	local m = 10
	local function walk(x0, z0, x1, z1)
		K.box(ctx, V(x0, y - depth, z0), V(x1, y - 0.25, z1), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat, true)
		K.floor(ctx, x0, z0, x1, z1, y, { thick = 0.3, tile = 4.2, cover = 0.9 })
		L.block(room, x0 - 1, z0 - 1, x1 + 1, z1 + 1)
	end
	walk(room.x0, room.z0, room.x1, room.z0 + m)
	walk(room.x0, room.z1 - m, room.x1, room.z1)
	walk(room.x0, room.z0 + m, room.x0 + m, room.z1 - m)
	walk(room.x1 - m, room.z0 + m, room.x1, room.z1 - m)
	walk(room.cx - 9, room.cz - 9, room.cx + 9, room.cz + 9)
	for side, list in room.doors do
		for _, d in list do
			local hw = d.w / 2 + 1
			if side == "xn" or side == "xp" then
				local z = room.z0 + d.c
				local x0 = if side == "xn" then room.x0 + m else room.cx + 9
				local x1 = if side == "xn" then room.cx - 9 else room.x1 - m
				walk(x0, z - hw, x1, z + hw)
			else
				local x = room.x0 + d.c
				local z0 = if side == "zn" then room.z0 + m else room.cz + 9
				local z1 = if side == "zn" then room.cz - 9 else room.z1 - m
				walk(x - hw, z0, x + hw, z1)
			end
		end
	end
	-- steps out of the water in the corners of the pool
	for _, cxz in { { room.x0 + m, room.z0 + m, 1, 1 }, { room.x1 - m, room.z1 - m, -1, -1 } } do
		K.stairs(ctx, V(cxz[1] + cxz[3] * 7, y - depth, cxz[2] + cxz[4] * 2.5), V(-cxz[3], 0, 0), 4, depth, 6, { sides = false })
	end
	-- water
	local water = K.deco(ctx, V(room.sx - 2, 0.4, room.sz - 2), CF(room.cx, y - 1.3, room.cz), th.water or rgb(34, 58, 58), M.Glass, { Transparency = 0.35, CastShadow = false })
	water.Name = "Water"
	-- columns rising from the water with arches between
	local sp = 20
	local nx = math.floor((room.sx - 2 * m - 6) / sp)
	local nz = math.floor((room.sz - 2 * m - 6) / sp)
	local ox = room.cx - nx * sp / 2
	local oz = room.cz - nz * sp / 2
	local grid = {}
	for i = 0, nx do
		for k = 0, nz do
			local p = V(ox + i * sp, y - depth, oz + k * sp)
			if L.free(room, p.X, p.Z, 3) then
				K.pillar(ctx, p, 4, hs + depth, { noFlutes = true, bands = 9 })
				grid[i * 100 + k] = p
				-- moss ring at the waterline
				K.deco(ctx, V(5.2, 1.2, 5.2), CF(p + V(0, depth - 0.8, 0)), K.j(ctx, P.MOSS, 0.1), M.LeafyGrass)
				if rng:chance(0.25) then
					P.shrooms(ctx, p + V(2.8, depth - 1.2, 0), 0.6, 3, th.glow, rng:chance(0.5))
				end
			end
		end
	end
	for key, p in grid do
		local i, k = key // 100, key % 100
		for _, nb in { (i + 1) * 100 + k, i * 100 + k + 1 } do
			local q = grid[nb]
			if q then
				local u = (q - p).Unit
				K.arch(ctx, p + u * 2.6 + V(0, depth + hs - 8, 0), q - u * 2.6 + V(0, depth + hs - 8, 0), 6, 2.4, { band = 1.6, steps = 4 })
			end
		end
	end
	-- drips and floating debris
	for i = 1, 6 do
		local x = rng:float(room.x0 + 6, room.x1 - 6)
		local z = rng:float(room.z0 + 6, room.z1 - 6)
		P.drip(ctx, V(x, y + room.h - 3, z), y - 1.1)
	end
	for i = 1, 3 do
		local p = V(rng:float(room.x0 + m + 4, room.x1 - m - 4), y - 1.3, rng:float(room.z0 + m + 4, room.z1 - m - 4))
		K.deco(ctx, V(4, 0.5, 1.2), CF(p) * ANG(0, rng:angle(), 0), K.j(ctx, P.WOOD, 0.1), M.Wood)
	end
	-- moss and props on the margins
	for i = 1, 8 do
		local side = rng:int(1, 4)
		local p
		if side == 1 then
			p = V(rng:float(room.x0 + 4, room.x1 - 4), y, room.z0 + rng:float(2, m - 2))
		elseif side == 2 then
			p = V(rng:float(room.x0 + 4, room.x1 - 4), y, room.z1 - rng:float(2, m - 2))
		elseif side == 3 then
			p = V(room.x0 + rng:float(2, m - 2), y, rng:float(room.z0 + 4, room.z1 - 4))
		else
			p = V(room.x1 - rng:float(2, m - 2), y, rng:float(room.z0 + 4, room.z1 - 4))
		end
		P.moss(ctx, p + V(0, 0.2, 0), 4, 4, 2)
		if i % 2 == 0 then
			P.shrooms(ctx, p, 1.2, 4, th.glow, i % 4 == 0)
		end
	end
	-- the centre island: a well-shrine with candles
	local c = V(room.cx, y, room.cz)
	P.obelisk(ctx, c, 9, th.glow)
	P.candles(ctx, c + V(4, 0.2, 4), 5, 0.8, true, 16)
	P.candles(ctx, c + V(-4, 0.2, -4), 4, 0.7, false)
	R.dressWalls(ctx, room, { banner = 0.2, niche = 0.1, roots = 0.5 })
	-- spots on walkways
	for i = 1, 6 do
		local p = V(rng:float(room.x0 + 4, room.x1 - 4), y, room.z0 + 5)
		if i % 2 == 0 then
			p = V(room.x0 + 5, y, rng:float(room.z0 + 4, room.z1 - 4))
		end
		if i == 5 then
			p = c + V(6, 0, 0)
		end
		addSpot(room, p)
	end
end

local function rockMass(ctx, room, p: Vector3, sz: number, hMax: number)
	local rng = ctx.rng
	local th = ctx.theme
	local h = rng:float(sz * 0.6, math.min(hMax, sz * 2))
	K.solid(ctx, V(sz, h, sz * rng:float(0.7, 1.3)), CF(p + V(0, h / 2 - 0.5, 0)) * ANG(rng:float(-0.08, 0.08), rng:angle(), rng:float(-0.08, 0.08)), K.pj(ctx, th.rock or th.wall, 0.1), th.roughMat or M.Rock)
	K.deco(ctx, V(sz * 0.7, h * 0.5, sz * 0.7), CF(p + V(rng:float(-1, 1), h * 0.9, rng:float(-1, 1))) * ANG(rng:float(-0.3, 0.3), rng:angle(), rng:float(-0.3, 0.3)), K.pj(ctx, th.rock or th.wall, 0.1), th.roughMat or M.Rock)
end

function R.cavern(ctx, room, mine: boolean?)
	local th = ctx.theme
	local rng = ctx.rng
	local y = room.y
	reservePaths(room)
	R.shell(ctx, room, { style = "rough", noVault = true, floor = { pal = th.rock or th.floor, mat = M.Slate, slabMat = M.Rock, cover = 0.35, tile = 7 } })
	room.hs = room.h - 6
	-- ceiling: hanging rock masses and stalactites
	for i = 1, 14 do
		local p = V(rng:float(room.x0 + 6, room.x1 - 6), y + room.h, rng:float(room.z0 + 6, room.z1 - 6))
		local s = rng:float(8, 22)
		K.deco(ctx, V(s, rng:float(4, 14), s * rng:float(0.6, 1.2)), CF(p) * ANG(rng:float(-0.1, 0.1), rng:angle(), rng:float(-0.1, 0.1)), K.pj(ctx, th.rock or th.wall, 0.1), M.Rock)
	end
	for i = 1, 12 do
		local p = V(rng:float(room.x0 + 6, room.x1 - 6), y + room.h - 3, rng:float(room.z0 + 6, room.z1 - 6))
		P.stalagmite(ctx, p, rng:float(6, 16), rng:float(2, 4.5), true)
	end
	-- rock masses along the walls (leaving doors free)
	for i = 1, 16 do
		local side = rng:int(1, 4)
		local p
		if side == 1 then
			p = V(rng:float(room.x0 + 4, room.x1 - 4), y, room.z0 + rng:float(3, 7))
		elseif side == 2 then
			p = V(rng:float(room.x0 + 4, room.x1 - 4), y, room.z1 - rng:float(3, 7))
		elseif side == 3 then
			p = V(room.x0 + rng:float(3, 7), y, rng:float(room.z0 + 4, room.z1 - 4))
		else
			p = V(room.x1 - rng:float(3, 7), y, rng:float(room.z0 + 4, room.z1 - 4))
		end
		if L.free(room, p.X, p.Z, 3) then
			rockMass(ctx, room, p, rng:float(5, 10), room.h * 0.5)
			L.block(room, p.X - 6, p.Z - 6, p.X + 6, p.Z + 6)
		end
	end
	-- a climbable shelf: three rock steps up to a ledge
	local La, Wb = dims(room)
	local shelfSide = rng:int(1, 2)
	local b = if shelfSide == 1 then 8 else Wb - 8
	local a0 = La * rng:float(0.25, 0.55)
	local ok = true
	for i = 0, 3 do
		local p = at(room, a0 + i * 9, b)
		if not L.free(room, p.X, p.Z, 5) then
			ok = false
		end
	end
	if ok then
		for i = 0, 3 do
			local p = at(room, a0 + i * 9, b)
			local h = 4 * (i + 1)
			local size = if longX(room) then V(9.5, h, 12) else V(12, h, 9.5)
			K.solid(ctx, size, CF(p + V(0, h / 2, 0)), K.pj(ctx, th.rock or th.wall, 0.08), M.Rock)
			P.moss(ctx, p + V(0, h, 0), 4, 4, 1)
			L.block(room, p.X - 7, p.Z - 7, p.X + 7, p.Z + 7)
		end
		local top = at(room, a0 + 27, b, y + 16)
		room.chest = CFrame.lookAt(top, at(room, a0, b, y + 16))
		addSpot(room, at(room, a0 + 18, b), y + 12)
		if mine then
			P.lanternPost(ctx, at(room, a0 + 27, b + (if shelfSide == 1 then -3 else 3), y + 16))
		else
			P.crystal(ctx, at(room, a0 + 27, b + (if shelfSide == 1 then -3.5 else 3.5), y + 16), 1.2, th.glow, true)
		end
	end
	-- stalagmites, crystals / fungus, bones
	for i = 1, 10 do
		local p = spot(ctx, room, 2.5, 8)
		if p then
			P.stalagmite(ctx, p, rng:float(3, 10), rng:float(2, 4))
		end
	end
	for i = 1, (if mine then 4 else 7) do
		local p = spot(ctx, room, 3, 8)
		if p then
			if th.flavor == "cistern" then
				if rng:chance(0.5) then
					P.mushroom(ctx, p, rng:float(0.8, 1.6), th.glow, true)
				else
					P.shrooms(ctx, p, 2.5, rng:int(5, 9), th.glow, true)
				end
			else
				P.crystal(ctx, p, rng:float(0.8, 1.5), th.glow, rng:chance(0.7))
			end
		end
	end
	if mine then
		-- rails down the long axis, carts, support frames, scaffold
		local r0 = at(room, 6, Wb / 2 + 8, y)
		local r1 = at(room, La - 6, Wb / 2 + 8, y)
		P.rails(ctx, r0, r1)
		for i = 1, 2 do
			local p = r0:Lerp(r1, rng:float(0.2, 0.8))
			P.minecart(ctx, CFrame.lookAt(p, r1) * CF(0, 0.4, 0), if rng:chance(0.6) then th.glow else nil)
		end
		for k = 1, math.floor(La / 18) do
			local p = at(room, k * 18, Wb / 2, y)
			for _, sg in { -1, 1 } do
				local q = at(room, k * 18, Wb / 2 + sg * (Wb / 2 - 10), y)
				if L.free(room, q.X, q.Z, 2) then
					P.timberFrame(ctx, q, 6, math.min(room.h - 10, 22), not longX(room))
				end
			end
			local _ = p
		end
		for i = 1, 3 do
			local p = spot(ctx, room, 2, 8)
			if p then
				P.lanternPost(ctx, p)
			end
		end
		-- scaffold platform with a ramp
		local sp = spot(ctx, room, 8, 12)
		if sp and not L.free(room, sp.X, sp.Z + 16, 6) then
			sp = nil
		end
		if sp then
			local h = 12
			for _, o in { V(-4.5, 0, -4.5), V(4.5, 0, -4.5), V(-4.5, 0, 4.5), V(4.5, 0, 4.5) } do
				K.solid(ctx, V(1.2, h, 1.2), CF(sp + o + V(0, h / 2, 0)), K.j(ctx, P.WOOD, 0.1), M.Wood)
			end
			K.solid(ctx, V(11, 1, 11), CF(sp + V(0, h - 0.5, 0)), K.j(ctx, P.WOOD, 0.1), M.WoodPlanks)
			local ramp = K.wedge(ctx, V(5, h, 20), CFrame.lookAt(sp + V(0, h / 2, 15.5), sp + V(0, h / 2, 15.5) + V(0, 0, 1)), K.j(ctx, P.WOOD, 0.1), M.WoodPlanks, nil, true)
			local _ = ramp
			P.crates(ctx, CF(sp + V(2, h, 2)))
			addSpot(room, sp, y + h)
			L.block(room, sp.X - 4, sp.Z - 4, sp.X + 4, sp.Z + 30)
		end
		P.rubble(ctx, at(room, La * 0.7, 10, y), 7, 14)
	end
	R.dressFloor(ctx, room, rng:int(4, 7))
	for i = 1, 4 do
		local p = V(rng:float(room.x0 + 8, room.x1 - 8), y + room.h - 4, rng:float(room.z0 + 8, room.z1 - 8))
		P.drip(ctx, p, y)
	end
	R.spots(ctx, room, 7)
end

function R.mine(ctx, room)
	R.cavern(ctx, room, true)
end

function R.chasm(ctx, room)
	local th = ctx.theme
	local rng = ctx.rng
	local y = room.y
	local La, Wb = dims(room)
	local long = longX(room)
	local sidesLong = if long then { "zn", "zp" } else { "xn", "xp" }
	local cw = rng:int(22, 28)
	local dep = rng:int(26, 32)
	-- trench position along the long axis, away from doors on the long walls
	local t0 = nil
	for _ = 1, 12 do
		local c0 = rng:float(La * 0.35, La * 0.65) - cw / 2
		if not doorAt(room, sidesLong[1], c0 - 3, c0 + cw + 3) and not doorAt(room, sidesLong[2], c0 - 3, c0 + cw + 3) then
			t0 = c0
			break
		end
	end
	if not t0 then
		return R.hall(ctx, room)
	end
	local t1 = t0 + cw
	reservePaths(room)
	R.shell(ctx, room, { hs = math.floor(room.h * 0.6), pilasters = 16, torchEvery = 2, noFloor = true })
	-- floor halves (thick solid blocks) + trench bottom
	local function half(a0, a1)
		local p0, p1 = at(room, a0, 0, y - dep - 1), at(room, a1, Wb, y)
		K.box(ctx, V(math.min(p0.X, p1.X), y - dep - 1, math.min(p0.Z, p1.Z)), V(math.max(p0.X, p1.X), y - 0.3, math.max(p0.Z, p1.Z)), K.pj(ctx, th.wall, 0.04), th.wallMat or th.mat, true)
		K.floor(ctx, math.min(p0.X, p1.X), math.min(p0.Z, p1.Z), math.max(p0.X, p1.X), math.max(p0.Z, p1.Z), y, { thick = 0.4 })
	end
	half(0, t0)
	half(t1, La)
	local b0, b1 = at(room, t0, 0, y), at(room, t1, Wb, y)
	local tx0, tz0 = math.min(b0.X, b1.X), math.min(b0.Z, b1.Z)
	local tx1, tz1 = math.max(b0.X, b1.X), math.max(b0.Z, b1.Z)
	L.block(room, tx0 - 3, tz0, tx1 + 3, tz1)
	local by = y - dep
	K.floor(ctx, tx0, tz0, tx1, tz1, by, { pal = th.rock or th.floor, cover = 0.5 })
	-- trench walls: masonry faces + deeper side walls
	local faceA = K.frame(at(room, t0, 0, by), if long then V(0, 0, 1) else V(1, 0, 0), if long then V(1, 0, 0) else V(0, 0, 1), by)
	local faceB = K.frame(at(room, t1, 0, by), if long then V(0, 0, 1) else V(1, 0, 0), if long then V(-1, 0, 0) else V(0, 0, -1), by)
	K.wall(ctx, faceA, Wb, { height = dep, spring = dep, noBack = true, trim = 0, lowTop = 10 })
	K.wall(ctx, faceB, Wb, { height = dep, spring = dep, noBack = true, trim = 0, lowTop = 10 })
	for _, sd in sidesLong do
		local fr = room.frames[sd]
		K.fbox(ctx, fr, t0 - 1, t1 + 1, -dep - 3, 0, -4, 0, K.pj(ctx, th.wall, 0.04), th.wallMat or th.mat, true)
		K.fbox(ctx, fr, t0, t1, -dep, -0.2, -0.2, 0.3, K.pj(ctx, th.wall, 0.06), th.wallMat or th.mat)
	end
	-- edge kerbs
	for _, a in { t0, t1 } do
		local k0, k1 = at(room, a - 0.6, 0, y), at(room, a + 0.6, Wb, y)
		K.box(ctx, V(math.min(k0.X, k1.X), y - 0.8, math.min(k0.Z, k1.Z) + 1), V(math.max(k0.X, k1.X), y + 0.4, math.max(k0.Z, k1.Z) - 1), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
	end
	-- stairs down into the trench, one on each face
	local run = math.ceil(dep * 1.6)
	local across = if long then V(0, 0, 1) else V(1, 0, 0)
	local along = if long then V(1, 0, 0) else V(0, 0, 1)
	local sA = at(room, t0 + 3.5, Wb - 5 - run, by)
	K.stairs(ctx, sA, across, 6, dep, run, { sides = false })
	local sB = at(room, t1 - 3.5, 5 + run, by)
	K.stairs(ctx, sB, -across, 6, dep, run, { sides = false })
	-- landings at the top of each stair
	K.box(ctx, at(room, t0, Wb - 5, y - 1) + along * 0 - V(0, 0, 0), at(room, t0 + 6.5, Wb - 2, y) , K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat, true)
	K.box(ctx, at(room, t1 - 6.5, 2, y - 1), at(room, t1, 5, y), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat, true)
	-- the broken bridge across the middle
	local bw = 10
	local gap = 6
	local bc = Wb / 2 + rng:float(-8, 8)
	local mid = (t0 + t1) / 2
	for _, sg in { -1, 1 } do
		local a0 = if sg < 0 then t0 - 1 else mid + gap / 2
		local a1 = if sg < 0 then mid - gap / 2 else t1 + 1
		local p0, p1 = at(room, a0, bc - bw / 2, y - 2.5), at(room, a1, bc + bw / 2, y)
		K.box(ctx, V(math.min(p0.X, p1.X), y - 2.5, math.min(p0.Z, p1.Z)), V(math.max(p0.X, p1.X), y, math.max(p0.Z, p1.Z)), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat, true)
		-- parapets
		for _, e in { -1, 1 } do
			local q0, q1 = at(room, a0, bc + e * (bw / 2 - 0.5) - 0.5, y), at(room, a1 - (if sg < 0 then 2 else 0), bc + e * (bw / 2 - 0.5) + 0.5, y + 2.4)
			K.box(ctx, V(math.min(q0.X, q1.X), y, math.min(q0.Z, q1.Z)), V(math.max(q0.X, q1.X), y + 2.4, math.max(q0.Z, q1.Z)), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat, true)
		end
		-- broken end: jagged blocks + falling rubble below
		local e0 = at(room, if sg < 0 then mid - gap / 2 else mid + gap / 2, bc, y - 1)
		for i = 1, 3 do
			K.deco(ctx, V(rng:float(1, 2.5), rng:float(1, 2), rng:float(2, 4)), CF(e0 + V(rng:float(-1, 1), rng:float(-1.5, 0.5), rng:float(-3, 3))) * ANG(rng:float(-0.5, 0.5), rng:angle(), rng:float(-0.5, 0.5)), K.pj(ctx, th.trim or th.wall, 0.08), th.trimMat or th.mat)
		end
		-- supporting pier from the bottom
		local pp = at(room, if sg < 0 then t0 + 5 else t1 - 5, bc, by)
		K.pillar(ctx, pp, 5, dep - 2.5, { noCap = true, noFlutes = true, bands = 7 })
	end
	P.rubble(ctx, at(room, mid, bc, by), 6, 10)
	-- stepping pillars at several heights inside the chasm
	for i = 1, 3 do
		local p = at(room, mid + rng:float(-5, 5), rng:float(12, Wb - 12), by)
		if math.abs((p - at(room, mid, bc, by)).Magnitude) > 10 then
			K.pillar(ctx, p, 4.5, dep - rng:float(4, 14), { broken = dep - rng:float(4, 12), noFlutes = true })
		end
	end
	-- the bottom: bones, spikes, glow
	local bArea = { tx0 + 3, tz0 + 3, tx1 - 3, tz1 - 3 }
	for i = 1, 6 do
		local x, z = rng:float(bArea[1], bArea[3]), rng:float(bArea[2], bArea[4])
		local p = V(x, by, z)
		local r = rng:float()
		if r < 0.3 then
			P.bonePile(ctx, p, 2, 7)
		elseif r < 0.55 then
			P.spikes(ctx, p, 1.5, 5)
		elseif r < 0.8 then
			if th.flavor == "cistern" then
				P.shrooms(ctx, p, 2, 6, th.glow, true)
			else
				P.crystal(ctx, p, 1.2, th.glow, true)
			end
		else
			P.skeleton(ctx, CF(p) * ANG(0, rng:angle(), 0), "lie")
		end
	end
	K.grate(ctx, at(room, mid, Wb * 0.3, by), 6, 6, th.grateGlow or th.glow, true)
	K.grate(ctx, at(room, mid, Wb * 0.7, by), 6, 6, th.grateGlow or th.glow, true)
	room.pit = { tx0, tz0, tx1, tz1, by }
	addSpot(room, at(room, mid, Wb * 0.25, by), by)
	-- hanging chains over the gap
	for i = 1, 3 do
		local p = at(room, mid + rng:float(-6, 6), rng:float(10, Wb - 10), y + room.h - 3)
		P.chain(ctx, p, p - V(0, rng:float(16, 30), 0), 1.8)
	end
	R.dressWalls(ctx, room, { banner = 0.35, niche = 0.2 })
	R.dressFloor(ctx, room, rng:int(4, 6))
	R.spots(ctx, room, 7)
end

function R.forge(ctx, room)
	local th = ctx.theme
	local rng = ctx.rng
	local y = room.y
	reservePaths(room)
	R.shell(ctx, room, { hs = math.floor(room.h * 0.6), pilasters = 14, torchEvery = 3, style = "brick" })
	local La, Wb = dims(room)
	-- lava channels with kerbs and grates
	for _, b in { Wb * 0.28, Wb * 0.72 } do
		local a0, a1 = 12, La - 12
		local p0, p1 = at(room, a0, b - 2, y), at(room, a1, b + 2, y)
		local x0, z0, x1, z1 = math.min(p0.X, p1.X), math.min(p0.Z, p1.Z), math.max(p0.X, p1.X), math.max(p0.Z, p1.Z)
		local lava = K.box(ctx, V(x0, y + 0.05, z0), V(x1, y + 0.35, z1), th.glow, M.Neon)
		lava.Name = "Lava"
		for _, e in { -1, 1 } do
			local q0, q1 = at(room, a0, b + e * 2.6 - 0.6, y), at(room, a1, b + e * 2.6 + 0.6, y + 1.2)
			K.box(ctx, V(math.min(q0.X, q1.X), y - 0.2, math.min(q0.Z, q1.Z)), V(math.max(q0.X, q1.X), y + 1.2, math.max(q0.Z, q1.Z)), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat, true)
		end
		for k = 0, 1 do
			local lp = at(room, a0 + (k + 0.5) * (a1 - a0) / 2, b, y + 1)
			local core = K.deco(ctx, V(1, 1, 1), CF(lp), th.glow, M.Neon, { Transparency = 1 })
			K.light(ctx, core, rgb(255, 110, 40), 32, 1.6)
		end
		-- walkable grate crossings
		for _, f in { 0.33, 0.66 } do
			local gp = at(room, a0 + f * (a1 - a0), b, y + 1.25)
			K.solid(ctx, if longX(room) then V(6, 0.4, 7) else V(7, 0.4, 6), CF(gp), P.IRON, M.DiamondPlate)
		end
		L.block(room, x0 - 1, z0 - 1.5, x1 + 1, z1 + 1.5)
	end
	-- forges along a long wall, anvils, racks, cauldrons, chains
	local fs = if longX(room) then (if rng:chance(0.5) then "zn" else "zp") else (if rng:chance(0.5) then "xn" else "xp")
	local fr = room.frames[fs]
	local _, _, n, len = L.side(room, fs)
	for k = 1, 3 do
		local s = k * len / 4
		if not doorAt(room, fs, s - 6, s + 6) then
			local p = K.fpos(fr, s, 0, 3)
			P.forge(ctx, CFrame.lookAt(p, p + n), th.glow)
			L.block(room, p.X - 7, p.Z - 7, p.X + 7, p.Z + 7)
		end
	end
	for i = 1, 3 do
		local p = spot(ctx, room, 3, 8)
		if p then
			if i == 1 then
				P.cauldron(ctx, p, th.glow)
			else
				P.anvil(ctx, CF(p) * ANG(0, rng:angle(), 0))
			end
		end
	end
	for i = 1, 5 do
		local p = V(rng:float(room.x0 + 10, room.x1 - 10), y + room.h - 2, rng:float(room.z0 + 10, room.z1 - 10))
		P.chain(ctx, p, p - V(0, rng:float(14, 30), 0), 1.8)
	end
	-- raised foundry platform at one end
	local e = if longX(room) then "xn" else "zn"
	if #room.doors[e] > 0 then
		e = L.OPP[e]
	end
	if #room.doors[e] == 0 then
		local efr = room.frames[e]
		local _, _, en, elen = L.side(room, e)
		K.fbox(ctx, efr, elen / 2 - 16, elen / 2 + 16, -0.2, 6, 0, 14, K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat, true)
		K.stairs(ctx, K.fpos(efr, elen / 2, 0, 14 + 10), -en, 12, 6, 10)
		local cp = K.fpos(efr, elen / 2 - 8, 6, 7)
		P.cauldron(ctx, cp, th.glow)
		P.brazier(ctx, K.fpos(efr, elen / 2 + 9, 6, 7), 1, true)
		addSpot(room, K.fpos(efr, elen / 2 + 3, 0, 9), y + 6)
		local a0 = K.fpos(efr, elen / 2 - 17, 0, 0)
		local a1 = K.fpos(efr, elen / 2 + 17, 0, 25)
		L.block(room, math.min(a0.X, a1.X), math.min(a0.Z, a1.Z), math.max(a0.X, a1.X), math.max(a0.Z, a1.Z))
	end
	R.dressWalls(ctx, room, { banner = 0.3, niche = 0 })
	R.dressFloor(ctx, room, rng:int(4, 6))
	R.spots(ctx, room, 7)
end

function R.exit(ctx, room, refs)
	local th = ctx.theme
	local rng = ctx.rng
	reservePaths(room)
	R.shell(ctx, room, { hs = math.floor(room.h * 0.62), pilasters = 14, torchEvery = 2 })
	R.gate(ctx, room, refs)
	-- two rows of pillars leading to the gate
	local g = room.gate
	local fr = room.frames[g.side]
	local _, _, n, len = L.side(room, g.side)
	local roomDepth = if g.side == "xn" or g.side == "xp" then room.sx else room.sz
	for k = 1, 3 do
		local dd = 30 + k * 18
		if dd < roomDepth - 12 then
			for _, sg in { -1, 1 } do
				local p = K.fpos(fr, g.c + sg * 22, 0, dd)
				if L.free(room, p.X, p.Z, 4) then
					K.pillar(ctx, p, 6, room.hs, { bands = 12 })
					L.block(room, p.X - 5, p.Z - 5, p.X + 5, p.Z + 5)
					if k == 2 then
						P.brazier(ctx, K.fpos(fr, g.c + sg * 15, 0, dd), 0.9, false)
					end
				end
			end
		end
	end
	chandeliers(ctx, room, 1)
	R.dressWalls(ctx, room, { banner = 0.4, niche = 0.2 })
	R.dressFloor(ctx, room, rng:int(4, 6))
	R.spots(ctx, room, 6)
end

-- ------------------------------------------------------------------ round arenas
function R.arena(ctx, room, refs, throne: boolean?)
	local th = ctx.theme
	local rng = ctx.rng
	local y = room.y
	local c = V(room.cx, y, room.cz)
	local Rr = room.sx / 2 - 2
	local H = room.h
	local hs = math.floor(H * 0.55)
	room.hs = hs
	room.round = true
	room.frames = {}
	room.slots = {}
	K.floor(ctx, room.x0, room.z0, room.x1, room.z1, y, { maxTiles = 420 })
	for i = 0, 3 do
		local am = i / 4 * math.pi * 2 + math.pi / 4
		local col = K.WARM:Lerp(th.glow, 0.3)
		local core = K.deco(ctx, V(1, 1, 1), CF(c + V(math.cos(am) * Rr * 0.5, 26, math.sin(am) * Rr * 0.5)), col, M.Neon, { Transparency = 1 })
		K.light(ctx, core, col, 60, 0.5)
	end
	-- openings: corridors at cardinal points + the gate side
	local open = {}
	for side, list in room.doors do
		for _, d in list do
			local ang = if side == "xp" then 0 elseif side == "zp" then math.pi / 2 elseif side == "xn" then math.pi else -math.pi / 2
			table.insert(open, { ang = ang, side = side, d = d })
		end
	end
	-- straight wall pieces at each opening (axis aligned)
	local piece = {}
	for _, o in open do
		local hw = o.d.w / 2 + 9
		piece[o.side] = hw
		local fr
		local a
		if o.side == "xp" then
			a = V(c.X + Rr, y, c.Z - hw)
			fr = K.frame(a, V(0, 0, 1), V(-1, 0, 0), y)
		elseif o.side == "xn" then
			a = V(c.X - Rr, y, c.Z - hw)
			fr = K.frame(a, V(0, 0, 1), V(1, 0, 0), y)
		elseif o.side == "zp" then
			a = V(c.X - hw, y, c.Z + Rr)
			fr = K.frame(a, V(1, 0, 0), V(0, 0, -1), y)
		else
			a = V(c.X - hw, y, c.Z - Rr)
			fr = K.frame(a, V(1, 0, 0), V(0, 0, 1), y)
		end
		o.fr = fr
		local dd = { c = hw, w = o.d.w, h = o.d.h }
		K.wall(ctx, fr, hw * 2, { height = H, spring = hs, doors = { dd }, trim = 0.5, thick = 6 })
		if not o.d.gate then
			for _, sg in { -1, 1 } do
				P.torch(ctx, K.fpos(fr, hw + sg * (o.d.w / 2 + 4.6), 10, 0.36), fr.n)
			end
		end
	end
	-- ring wall: arcs between the openings, closing onto the straight pieces
	table.sort(open, function(p, q)
		return p.ang < q.ang
	end)
	local verts = {}
	for i, o in open do
		local hw = piece[o.side]
		local beta = math.atan2(hw, Rr)
		local nxt = open[(i % #open) + 1]
		local a0 = o.ang + beta
		local a1 = nxt.ang - math.atan2(piece[nxt.side], Rr)
		if a1 <= a0 then
			a1 += math.pi * 2
		end
		local m = math.max(1, math.ceil((a1 - a0) / (math.pi * 2 / 30)))
		local arc = {}
		local rEnd = math.sqrt(Rr * Rr + hw * hw)
		table.insert(arc, c + V(math.cos(a0) * rEnd, 0, math.sin(a0) * rEnd))
		for k = 1, m - 1 do
			local a = a0 + (a1 - a0) * k / m
			table.insert(arc, c + V(math.cos(a) * Rr, 0, math.sin(a) * Rr))
		end
		local rEnd2 = math.sqrt(Rr * Rr + piece[nxt.side] ^ 2)
		table.insert(arc, c + V(math.cos(a1) * rEnd2, 0, math.sin(a1) * rEnd2))
		table.insert(verts, arc)
	end
	local count = 0
	for _, arc in verts do
		for k = 1, #arc - 1 do
			local p0, p1 = arc[k], arc[k + 1]
			local u = (p1 - p0).Unit
			local n = (c - (p0 + p1) / 2)
			n = V(n.X, 0, n.Z).Unit
			local fr = K.frame(p0, u, n, y)
			count += 1
			local L0 = (p1 - p0).Magnitude
			K.wall(ctx, fr, L0, { height = H + 2, spring = hs, trim = 0, thick = 6, lowTop = 12 })
			if count % 2 == 0 then
				K.fbox(ctx, fr, L0 / 2 - 1.8, L0 / 2 + 1.8, -0.2, hs - 1, -0.2, 1.6, K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat)
				K.fbox(ctx, fr, L0 / 2 - 2.4, L0 / 2 + 2.4, -0.2, 3.4, -0.2, 2.2, K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat)
				if count % 4 == 0 then
					P.torch(ctx, K.fpos(fr, L0 / 2, 10, 1.65), n)
				end
				if throne and count % 4 == 2 then
					P.banner(ctx, CFrame.lookAt(K.fpos(fr, L0 / 2, hs - 3, 1.7), K.fpos(fr, L0 / 2, hs - 3, 5)), 6, 24, th.banner or th.accent, th.emblem)
				end
			end
		end
	end
	-- stepped dome
	local k = 7
	local rise = H - hs
	for s = 1, k do
		local f = s / k
		local t = 1.6 - math.sqrt(2.56 - 2.2 * f * f)
		local inset = Rr * t * 0.8 + 1 + s * 0.4
		local yA = y + hs + (s - 1) * rise / k
		local yB = y + hs + s * rise / k
		local r1 = Rr + 3
		local r0 = Rr - inset
		local seg = 24
		for i = 0, seg - 1 do
			local am = (i + 0.5) / seg * math.pi * 2
			local chord = 2 * r1 * math.sin(math.pi / seg) + 1.5
			local mid = c + V(math.cos(am) * (r0 + r1) / 2, (yA + yB) / 2 - y, math.sin(am) * (r0 + r1) / 2)
			local cfm = CFrame.lookAt(mid, V(c.X, mid.Y, c.Z))
			K.deco(ctx, V(chord, yB - yA, r1 - r0), cfm, K.pj(ctx, th.vault or th.wall, 0.06), th.wallMat or th.mat)
		end
	end
	local topR = Rr * 0.2 + 4
	K.box(ctx, V(c.X - Rr - 6, y + H, c.Z - Rr - 6), V(c.X + Rr + 6, y + H + 4, c.Z + Rr + 6), Palette.shade(K.pj(ctx, th.wall, 0.05), 0.8), th.wallMat or th.mat, true)
	-- radial ribs
	for i = 0, 7 do
		local am = i / 8 * math.pi * 2 + math.pi / 8
		local dir = V(math.cos(am), 0, math.sin(am))
		for s = 1, k do
			local f = s / k
			local t = 1.6 - math.sqrt(2.56 - 2.2 * f * f)
			local inset = Rr * t * 0.8 + 1 + s * 0.4 + 1
			local yA = y + hs + (s - 1) * rise / k - 0.8
			local yB = y + hs + s * rise / k
			local mid = c + dir * (Rr - inset / 2) + V(0, (yA + yB) / 2 - y, 0)
			K.deco(ctx, V(2.6, yB - yA, inset), CFrame.lookAt(mid, V(c.X, mid.Y, c.Z)), K.pj(ctx, th.trim or th.wall, 0.05), th.trimMat or th.mat)
		end
	end
	local _ = topR
	-- ring of pillars with arches
	local pr = Rr - 16
	local np = if throne then 16 else 12
	local prevP = nil
	local firstP = nil
	for i = 0, np - 1 do
		local am = (i + 0.5) / np * math.pi * 2
		local p = c + V(math.cos(am) * pr, 0, math.sin(am) * pr)
		local blocked = false
		for _, o in open do
			local dA = math.abs(((am - o.ang + math.pi) % (math.pi * 2)) - math.pi)
			if dA < (if o.d.gate then 0.42 else 0.3) then
				blocked = true
			end
		end
		if not blocked then
			K.pillar(ctx, p, 7, hs, { bands = 14 })
			L.block(room, p.X - 6, p.Z - 6, p.X + 6, p.Z + 6)
			if prevP and (p - prevP).Magnitude < pr * 0.7 then
				local u = (p - prevP).Unit
				K.arch(ctx, prevP + u * 4 + V(0, hs - 2, 0), p - u * 4 + V(0, hs - 2, 0), 7, 3.4, { band = 2.4 })
			end
			if i % 2 == 0 then
				P.torch(ctx, p + (c - p).Unit * 4.55 + V(0, 10, 0), (c - p).Unit)
			end
			prevP = p
			firstP = firstP or p
		else
			prevP = nil
		end
	end
	-- the dais in the middle: three stepped rings (rotated squares)
	local dr = if throne then 22 else 18
	for s = 0, 2 do
		local w = (dr - s * 3) * 2
		for _, rot in { 0, math.pi / 4 } do
			K.solid(ctx, V(w * 0.83, 1, w * 0.83), CF(c + V(0, s + 0.5, 0)) * ANG(0, rot + s * 0.2, 0), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
		end
	end
	-- magic circle on top
	local cr = dr - 9
	local nseg = 28
	for i = 0, nseg - 1 do
		local am = i / nseg * math.pi * 2
		K.deco(ctx, V(0.7, 0.12, 1.6), CF(c + V(math.cos(am) * cr, 3.06, math.sin(am) * cr)) * ANG(0, -am, 0), th.glow, M.Neon)
	end
	for i = 0, 5 do
		local a1 = i / 6 * math.pi * 2
		local a2 = (i + 2) / 6 * math.pi * 2
		local p1 = c + V(math.cos(a1) * cr * 0.92, 3.07, math.sin(a1) * cr * 0.92)
		local p2 = c + V(math.cos(a2) * cr * 0.92, 3.07, math.sin(a2) * cr * 0.92)
		K.deco(ctx, V(0.35, 0.12, (p2 - p1).Magnitude), CFrame.lookAt((p1 + p2) / 2, p2), th.glow, M.Neon)
	end
	local cc = K.deco(ctx, V(1, 0.1, 1), CF(c + V(0, 3.2, 0)), th.glow, M.Neon, { Transparency = 1 })
	K.light(ctx, cc, th.glow, 40, 1.4)
	L.block(room, c.X - dr, c.Z - dr, c.X + dr, c.Z + dr)
	refs.bossCenter = c + V(0, 6, 0)
	refs.bossSize = math.floor(Rr - 6)
	-- braziers around the dais (a few with shadows)
	for i = 0, 3 do
		local am = i / 4 * math.pi * 2 + math.pi / 4
		P.brazier(ctx, c + V(math.cos(am) * (dr + 5), 0, math.sin(am) * (dr + 5)), 1.2, i < 2)
	end
	-- chandeliers
	for i = 0, 3 do
		local am = i / 4 * math.pi * 2
		local p = c + V(math.cos(am) * Rr * 0.45, H - 8, math.sin(am) * Rr * 0.45)
		P.chandelier(ctx, p, H * 0.45, 5)
	end
	-- floor ring of grates between pillars and wall
	for i = 0, 7 do
		local am = i / 8 * math.pi * 2 + math.pi / 8
		local p = c + V(math.cos(am) * (Rr - 8), y - y, math.sin(am) * (Rr - 8))
		p = V(p.X, y, p.Z)
		if L.free(room, p.X, p.Z, 3) then
			K.grate(ctx, p, 5, 5, th.grateGlow or th.glow, i % 2 == 0)
		end
	end
	-- the gate (exit) on its straight piece
	for _, o in open do
		if o.d.gate then
			room.frames[o.side] = o.fr
			room.gate.c = piece[o.side]
			R.gate(ctx, room, refs)
		end
	end
	if throne then
		-- the Warden's throne in front of the gate, statues in chains, lava ring
		local g = room.gate
		local fr = room.frames[g.side]
		local gdir = (K.fpos(fr, g.c, 0, 0) - c)
		gdir = V(gdir.X, 0, gdir.Z).Unit
		local tp = c + gdir * 10 + V(0, 3, 0)
		local look = CFrame.lookAt(tp, tp - gdir)
		P.throne(ctx, look, 2.5, th.glow)
		for _, sg in { -1, 1 } do
			P.brazier(ctx, (look * CF(sg * 13, 0, 2)).Position, 1.2, true)
		end
		-- lava ring around the dais (kerbed channel)
		local lr = dr + 7
		for i = 0, 23 do
			local am = i / 24 * math.pi * 2
			local p = c + V(math.cos(am) * lr, 0, math.sin(am) * lr)
			local chord = 2 * lr * math.sin(math.pi / 24) + 0.4
			local cfm = CFrame.lookAt(p, V(c.X, p.Y, c.Z))
			local skip = false
			for _, o in open do
				local dA = math.abs(((am - o.ang + math.pi) % (math.pi * 2)) - math.pi)
				if dA < 0.35 then
					skip = true
				end
			end
			if skip then
				K.deco(ctx, V(chord, 0.3, 4.4), cfm * CF(0, 0.2, 0), P.IRON, M.DiamondPlate)
			else
				K.deco(ctx, V(chord, 0.3, 3.2), cfm * CF(0, 0.12, 0), th.glow, M.Neon)
				K.solid(ctx, V(chord, 1, 0.8), cfm * CF(0, 0.5, 2), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
				K.solid(ctx, V(chord, 1, 0.8), cfm * CF(0, 0.5, -2), K.pj(ctx, th.trim or th.wall, 0.04), th.trimMat or th.mat)
			end
			if i % 6 == 0 then
				local core = K.deco(ctx, V(1, 1, 1), cfm * CF(0, 1.5, 0), th.glow, M.Neon, { Transparency = 1 })
				K.light(ctx, core, rgb(255, 110, 40), 26, 1.6)
			end
		end
		-- chained colossi between the pillars
		for i = 0, 3 do
			local am = i / 4 * math.pi * 2 + math.pi / 4
			local p = c + V(math.cos(am) * (Rr - 10), 0, math.sin(am) * (Rr - 10))
			if L.free(room, p.X, p.Z, 4) then
				P.knight(ctx, CFrame.lookAt(p, V(c.X, y, c.Z)), 2.6, { plinth = 1.4 })
				L.block(room, p.X - 7, p.Z - 7, p.X + 7, p.Z + 7)
				P.chain(ctx, p + V(-2, 14, 0), p + V(-3, H * 0.5, 0), 1.6)
			end
		end
	end
	-- props
	for i = 1, 8 do
		local p = spot(ctx, room, 3, 8)
		if p then
			local r = rng:float()
			if r < 0.4 then
				P.bonePile(ctx, p, 2.2, rng:int(6, 10))
			elseif r < 0.6 then
				P.rubble(ctx, p, 3, 6)
			elseif r < 0.8 then
				P.spikes(ctx, p, 1.2, 4)
			else
				P.skeleton(ctx, CF(p) * ANG(0, rng:angle(), 0), "lie")
			end
		end
	end
	for i = 1, 3 do
		local p = spot(ctx, room, 2.5, 10)
		if p then
			P.cage(ctx, p + V(0, rng:float(10, 18), 0), y + H - 10, true)
		end
	end
	for i = 1, 8 do
		local p = L.spot(rng, room, 3, 8, false)
		if p then
			addSpot(room, p)
		end
	end
end

return R
