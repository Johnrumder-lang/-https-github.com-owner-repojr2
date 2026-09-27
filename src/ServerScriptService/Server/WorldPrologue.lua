--!nonstrict
-- PROLOGUE: an ordinary modern city block, in cubes. The apartment (real rooms: a
-- hall, living room with the TV on its own wall, bedroom, bathroom, kitchen), the
-- open-plan office (desks, office chairs that people actually sit on, the boss's
-- glass office), shopfront streets, the club, and the crossing where the truck waits.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)

local Prologue = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material

local ASPHALT = rgb(50, 50, 56)
local SIDEWALK = rgb(168, 166, 160)
local CURB = rgb(138, 136, 132)
local LINE = rgb(235, 225, 160)

-- seated rigs: hips on a seat whose top is at `seatTop` (Type / Sit poses drop the
-- torso by 1 stud, thighs sit 2.5 below the root)
Prologue.SEAT_ROOT = 2.5

function Prologue.build(bible, seed: number)
	local rng = RNG.new(seed):fork("prologue")
	local W = S.World
	local map = W.sub("Map")
	local props = W.sub("Props")
	local refs = { windows = {}, streetLights = {} }
	local solid, deco = W.solid, W.deco

	-- ------------------------------------------------------------ furniture kit
	local function officeChair(parent, cf: CFrame, color: Color3?)
		-- 5-star base, gas lift, seat, backrest, armrests; returns the seat's top height
		local c = color or rgb(34, 36, 44)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			deco(parent, V(0.25, 0.2, 1.3), cf * ANG(0, a, 0) * CF(0, 0.3, 0.65), rgb(30, 30, 32), M.Metal)
			deco(parent, V(0.3, 0.3, 0.3), cf * ANG(0, a, 0) * CF(0, 0.15, 1.25), rgb(20, 20, 22))
		end
		deco(parent, V(0.3, 1.3, 0.3), cf * CF(0, 1.0, 0), rgb(120, 122, 128), M.Metal)
		solid(parent, V(2.3, 0.45, 2.2), cf * CF(0, 1.85, 0), c, M.Fabric)
		solid(parent, V(2.2, 2.4, 0.4), cf * CF(0, 3.3, 1.05) * ANG(-0.08, 0, 0), c, M.Fabric)
		for _, x in { -1.15, 1.15 } do
			deco(parent, V(0.25, 0.9, 0.25), cf * CF(x, 2.4, 0.3), rgb(30, 30, 32), M.Metal)
			deco(parent, V(0.35, 0.2, 1.4), cf * CF(x, 2.9, 0.1), rgb(26, 26, 28))
		end
		return cf.Position.Y + 2.07
	end
	local function woodChair(parent, cf: CFrame, color: Color3)
		for _, o in { V(-0.8, 0, -0.8), V(0.8, 0, -0.8), V(-0.8, 0, 0.8), V(0.8, 0, 0.8) } do
			solid(parent, V(0.3, 2.0, 0.3), cf * CF(o + V(0, 1.0, 0)), Palette.shade(color, 0.85), M.Wood)
		end
		solid(parent, V(2.0, 0.3, 2.0), cf * CF(0, 2.15, 0), color, M.WoodPlanks)
		solid(parent, V(2.0, 2.2, 0.3), cf * CF(0, 3.4, 0.85), color, M.WoodPlanks)
		return cf.Position.Y + 2.3
	end
	local function table_(parent, cf: CFrame, size: Vector3, color: Color3, mat)
		solid(parent, V(size.X, 0.3, size.Z), cf * CF(0, size.Y - 0.15, 0), color, mat or M.WoodPlanks)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				solid(parent, V(0.35, size.Y - 0.3, 0.35), cf * CF(sx * (size.X / 2 - 0.4), (size.Y - 0.3) / 2, sz * (size.Z / 2 - 0.4)), Palette.shade(color, 0.8), M.Wood)
			end
		end
	end
	local function lamp(parent, pos: Vector3, color: Color3?, range: number?)
		local l = deco(parent, V(1.4, 0.3, 1.4), CF(pos), color or rgb(255, 238, 205), M.Neon)
		Kit.pointLight(l, color or rgb(255, 225, 190), range or 22, 1.1, true)
		return l
	end
	local function plant(parent, pos: Vector3, s: number?)
		local k = s or 1
		solid(parent, V(1.6, 1.6, 1.6) * k, CF(pos + V(0, 0.8 * k, 0)), rgb(196, 110, 70), M.Brick)
		for i = 1, 5 do
			deco(parent, V(0.9, 1.6, 0.9) * k, CF(pos + V(0, 2.2 * k, 0)) * ANG(0.35, i * 1.25, 0) * CF(0, 0.5 * k, 0), rgb(56, 124 + i * 6, 58))
		end
	end
	local function windowPane(parent, cf: CFrame, w: number, h: number, lit: boolean?)
		-- frame, mullion, sill and glass (cf faces out of the wall)
		local frame = rgb(236, 234, 228)
		deco(parent, V(w, h, 0.2), cf, if lit then rgb(255, 220, 150) else rgb(80, 100, 120), if lit then M.Neon else M.Glass, { Transparency = if lit then 0.25 else 0.35 })
		deco(parent, V(w + 0.6, 0.3, 0.4), cf * CF(0, h / 2 + 0.15, 0), frame)
		deco(parent, V(w + 0.8, 0.35, 0.8), cf * CF(0, -h / 2 - 0.15, -0.2), frame)
		deco(parent, V(0.3, h, 0.4), cf * CF(-w / 2 - 0.15, 0, 0), frame)
		deco(parent, V(0.3, h, 0.4), cf * CF(w / 2 + 0.15, 0, 0), frame)
		deco(parent, V(0.18, h, 0.3), cf, frame)
		deco(parent, V(w, 0.18, 0.3), cf * CF(0, h * 0.15, 0), frame)
	end

	-- ------------------------------------------------------------ ground & roads
	W.solid(map, V(900, 4, 900), CF(0, -2, 0), SIDEWALK, M.Concrete)
	W.solid(map, V(900, 0.4, 30), CF(0, 0.2, 0), ASPHALT, M.Asphalt)
	W.solid(map, V(30, 0.4, 900), CF(150, 0.21, 0), ASPHALT, M.Asphalt)
	-- sidewalk paving slabs (a lighter strip with joints)
	for x = -440, 440, 12 do
		for _, z in { -19, 19 } do
			deco(map, V(0.2, 0.06, 7), CF(x, 0.02, z), Palette.shade(SIDEWALK, 0.88))
		end
	end
	for x = -440, 440, 18 do
		if math.abs(x - 150) > 22 then
			deco(map, V(8, 0.1, 0.6), CF(x, 0.45, 0), LINE)
		end
	end
	for z = -440, 440, 18 do
		if math.abs(z) > 22 then
			deco(map, V(0.6, 0.1, 8), CF(150, 0.46, z), LINE)
		end
	end
	for _, z in { -14.6, 14.6 } do
		deco(map, V(900, 0.08, 0.4), CF(0, 0.45, z), rgb(236, 236, 236))
	end
	for _, z in { -15.5, 15.5 } do
		W.solid(map, V(900, 0.8, 1), CF(0, 0.4, z), CURB, M.Concrete)
	end
	for _, x in { 134.5, 165.5 } do
		W.solid(map, V(1, 0.8, 900), CF(x, 0.41, 0), CURB, M.Concrete)
	end
	-- manholes and drains
	for i = 1, 12 do
		local x = rng:float(-400, 400)
		if math.abs(x - 150) > 30 then
			Kit.cyl(map, 0.1, 3, CF(x, 0.42, rng:float(-8, 8)) * ANG(0, 0, math.pi / 2), rgb(40, 40, 44), M.DiamondPlate)
		end
	end
	local function zebra(center: Vector3, alongX: boolean)
		for i = -5, 5 do
			local off = if alongX then V(i * 2.6, 0, 0) else V(0, 0, i * 2.6)
			deco(map, if alongX then V(1.4, 0.12, 12) else V(12, 0.12, 1.4), CF(center + off + V(0, 0.46, 0)), rgb(240, 240, 240))
		end
	end
	zebra(V(40, 0, 0), false)
	refs.dayCrossing = V(40, 0, 0)
	zebra(V(150, 0, 40), true)
	refs.crossing = V(150, 0, 40)
	local function trafficLight(p: Vector3, red: boolean)
		solid(props, V(0.6, 12, 0.6), CF(p + V(0, 6, 0)), rgb(40, 40, 44), M.Metal)
		local box = solid(props, V(1.4, 3.6, 1.2), CF(p + V(0, 12.5, 0)), rgb(30, 30, 34))
		deco(props, V(0.8, 0.8, 0.2), CF(p + V(0, 13.6, -0.65)), if red then rgb(255, 40, 40) else rgb(60, 20, 20), M.Neon)
		deco(props, V(0.8, 0.8, 0.2), CF(p + V(0, 12.5, -0.65)), rgb(60, 50, 10), M.Neon)
		deco(props, V(0.8, 0.8, 0.2), CF(p + V(0, 11.4, -0.65)), if red then rgb(20, 60, 20) else rgb(60, 255, 90), M.Neon)
		solid(props, V(0.9, 1.4, 0.6), CF(p + V(0, 4.5, 0.5)), rgb(40, 40, 44))
		return box
	end
	trafficLight(V(33, 0, 18), false)
	trafficLight(V(47, 0, -18), false)
	refs.fatefulLight = trafficLight(V(133, 0, 34), true)
	trafficLight(V(167, 0, 46), true)

	-- ------------------------------------------------------------ facades
	local facadeColors = { rgb(170, 150, 130), rgb(130, 120, 110), rgb(190, 180, 160), rgb(110, 110, 120), rgb(150, 90, 80), rgb(90, 100, 110), rgb(200, 196, 186), rgb(120, 130, 100), rgb(160, 110, 90) }
	local shopNames = { "BAKERY", "PHARMACY", "NOODLES", "BOOKS", "LAUNDRY", "PHONE REPAIR", "FLORIST", "CAFE", "KEBAB", "DENTIST", "PAWN", "24/7" }
	local awningColors = { rgb(170, 40, 40), rgb(40, 90, 150), rgb(40, 120, 70), rgb(200, 150, 40), rgb(90, 50, 110) }
	-- a building on the street: storefront, framed windows per floor, cornices,
	-- a parapet and rooftop clutter. faceSign: -1 = front faces -Z (north side of
	-- the street faces the road at -Z), +1 = front faces +Z.
	local function building(x0: number, x1: number, z0: number, depth: number, height: number, faceSign: number, color: Color3, shop: boolean)
		local w = x1 - x0
		local cx = (x0 + x1) / 2
		local cz = z0 + depth / 2 * faceSign
		local mat = rng:pick({ M.Brick, M.Brick, M.Concrete, M.Plaster })
		local b = Kit.model("Building", props)
		solid(b, V(w, height, depth), CF(cx, height / 2, cz), color, mat)
		local faceCF = CFrame.lookAt(V(cx, 0, z0), V(cx, 0, z0 - faceSign))
		local fz = function(y: number, x: number)
			return faceCF * CF(x - cx, y, -0.15)
		end
		-- ground floor: shop window + door + awning + sign, or a lobby door
		if shop then
			local sw = math.min(w - 8, 22)
			deco(b, V(sw, 7, 0.3), fz(4.5, cx - 2), rgb(90, 120, 140), M.Glass, { Transparency = 0.3 })
			deco(b, V(sw + 1, 0.5, 0.5), fz(8.2, cx - 2), rgb(40, 40, 44), M.Metal)
			deco(b, V(sw + 1, 1.2, 0.6), fz(0.6, cx - 2), Palette.shade(color, 0.7), mat)
			solid(b, V(3.4, 7.5, 0.4), fz(3.75, cx + sw / 2 + 1.5), rgb(60, 50, 44), M.Wood)
			local aw = rng:pick(awningColors)
			for i = 0, 2 do
				deco(b, V(sw + 2, 0.25, 1.6), faceCF * CF(cx - 2 - cx, 9.4 - i * 0.35, -0.9 - i * 1.5) * ANG(-0.25, 0, 0), if i % 2 == 0 then aw else rgb(236, 232, 224), M.Fabric)
			end
			local sign = deco(b, V(sw * 0.7, 2, 0.3), fz(11, cx - 2), rgb(30, 30, 36))
			Kit.label(sign, Enum.NormalId.Front, rng:pick(shopNames), rgb(255, 240, 200), Enum.Font.GothamBold, nil, 14)
			-- a shelf behind the glass
			deco(b, V(sw - 2, 0.3, 1.4), faceCF * CF(cx - 2 - cx, 3, 1.2), rgb(120, 90, 60))
			for i = 1, 6 do
				deco(b, V(0.8, 0.9, 0.8), faceCF * CF(cx - 2 - cx - sw / 2 + i * sw / 7, 3.6, 1.2), rng:pick(awningColors))
			end
		else
			solid(b, V(4.4, 8, 0.4), fz(4, cx), rgb(50, 44, 40), M.Wood)
			deco(b, V(6, 0.5, 2), faceCF * CF(0, 8.6, -1), Palette.shade(color, 0.7))
			local l = deco(b, V(0.6, 0.6, 0.3), fz(7, cx + 3.2), rgb(255, 230, 180), M.Neon)
			Kit.pointLight(l, rgb(255, 220, 170), 12, 0.8)
		end
		-- upper floors
		local lit = 0.4
		for y = 14, height - 5, 7 do
			deco(b, V(w + 0.4, 0.5, 0.6), fz(y - 3.4, cx), Palette.shade(color, 0.8), mat)
			for x = x0 + 4, x1 - 4, 6.5 do
				windowPane(b, fz(y, x), 3.2, 4, rng:chance(lit))
			end
		end
		-- a fire escape on some buildings
		if height > 30 and rng:chance(0.35) then
			local fx = cx + rng:float(-w * 0.25, w * 0.25)
			for y = 13, height - 8, 7 do
				deco(b, V(6, 0.25, 2.4), faceCF * CF(fx - cx, y - 3, -1.4), rgb(40, 40, 44), M.DiamondPlate)
				deco(b, V(6, 1.2, 0.12), faceCF * CF(fx - cx, y - 2.2, -2.6), rgb(40, 40, 44), M.Metal)
				deco(b, V(0.3, 7.6, 0.3), faceCF * CF(fx - cx + 2.6, y + 0.5, -2.4) * ANG(0, 0, 0.6), rgb(40, 40, 44), M.Metal)
			end
		end
		-- parapet, rooftop units, water tank
		deco(b, V(w + 0.6, 1.4, depth + 0.6), CF(cx, height + 0.7, cz), Palette.shade(color, 0.85), mat)
		deco(b, V(w - 1, 0.3, depth - 1), CF(cx, height + 0.2, cz), rgb(70, 70, 74))
		for _ = 1, rng:int(1, 3) do
			local p = V(cx + rng:float(-w * 0.35, w * 0.35), height + 1.2, cz + rng:float(-depth * 0.3, depth * 0.3))
			deco(b, V(3, 2, 3), CF(p), rgb(170, 172, 176), M.Metal)
			deco(b, V(2.2, 0.2, 2.2), CF(p + V(0, 1.1, 0)), rgb(60, 60, 64), M.DiamondPlate)
		end
		if rng:chance(0.3) and w > 20 then
			local p = V(cx + rng:float(-w * 0.2, w * 0.2), height + 1, cz)
			for _, o in { V(-1.5, 0, -1.5), V(1.5, 0, -1.5), V(-1.5, 0, 1.5), V(1.5, 0, 1.5) } do
				deco(b, V(0.4, 4, 0.4), CF(p + o + V(0, 2, 0)), rgb(80, 60, 44), M.Wood)
			end
			Kit.cyl(b, 5, 5, CF(p + V(0, 6.5, 0)) * ANG(0, 0, math.pi / 2), rgb(110, 80, 56), M.WoodPlanks)
		end
		return b
	end
	local function fillStreet(side: number, skipRanges)
		local x = -430
		while x < 430 do
			local w = rng:int(24, 46)
			local skip = false
			for _, r in skipRanges do
				if x + w > r[1] and x < r[2] then
					skip = true
					x = r[2] + 2
					break
				end
			end
			if not skip then
				building(x, x + w, side * 24, 40, rng:int(30, 110), side, rng:pick(facadeColors), rng:chance(0.7))
				x += w + 2
			end
		end
	end
	fillStreet(1, { { -94, -28 }, { 128, 172 }, { 188, 264 } })
	fillStreet(-1, { { 2, 78 }, { 128, 172 } })
	for z = -430, 430, 44 do
		if z < -70 or z > 110 then
			for _, side in { -1, 1 } do
				local x0 = 150 + side * 24
				local h = rng:int(30, 100)
				solid(props, V(40, h, 40), CF(x0 + side * 20, h / 2, z), rng:pick(facadeColors), M.Concrete)
				for y = 10, h - 5, 7 do
					for dz = -15, 15, 7.5 do
						windowPane(props, CFrame.lookAt(V(x0 - side * 0.2, y, z + dz), V(x0 - side * 2, y, z + dz)), 3.2, 4, rng:chance(0.35))
					end
				end
			end
		end
	end

	-- ------------------------------------------------------------ street furniture
	for x = -420, 420, 34 do
		for _, side in { -1, 1 } do
			if math.abs(x - 150) > 30 then
				local p = V(x, 0, side * 19)
				solid(props, V(0.6, 16, 0.6), CF(p + V(0, 8, 0)), rgb(60, 62, 70), M.Metal)
				deco(props, V(4, 0.5, 0.8), CF(p + V(0, 16, -side * 1.6)), rgb(60, 62, 70), M.Metal)
				local lampPart = deco(props, V(1.8, 0.4, 1.2), CF(p + V(0, 15.6, -side * 3)), rgb(255, 230, 180), M.Neon)
				local l = Kit.spotLight(lampPart, rgb(255, 220, 170), 40, 3, 70, Enum.NormalId.Bottom)
				l.Enabled = false
				table.insert(refs.streetLights, l)
			end
		end
	end
	local carColors = { rgb(200, 40, 40), rgb(40, 90, 200), rgb(230, 230, 235), rgb(30, 30, 34), rgb(240, 200, 50), rgb(90, 160, 90), rgb(120, 120, 128) }
	local function car(cf: CFrame, color: Color3)
		local m = Kit.model("Car", props)
		solid(m, V(5, 1.6, 10), cf * CF(0, 1.6, 0), color, M.SmoothPlastic)
		solid(m, V(4.6, 1.7, 5.2), cf * CF(0, 3.2, 0.5), Palette.shade(color, 0.95))
		deco(m, V(4.4, 1.4, 0.15), cf * CF(0, 3.2, -2.15) * ANG(-0.35, 0, 0), rgb(120, 160, 190), M.Glass, { Transparency = 0.3 })
		deco(m, V(4.4, 1.3, 0.15), cf * CF(0, 3.2, 3.15) * ANG(0.35, 0, 0), rgb(120, 160, 190), M.Glass, { Transparency = 0.3 })
		for _, sx in { -2.33, 2.33 } do
			deco(m, V(0.12, 1.2, 4.4), cf * CF(sx, 3.25, 0.5), rgb(120, 160, 190), M.Glass, { Transparency = 0.35 })
		end
		deco(m, V(5.1, 0.5, 10.1), cf * CF(0, 0.95, 0), rgb(26, 26, 28))
		for _, wx in { -2.4, 2.4 } do
			for _, wz in { -3.2, 3.2 } do
				Kit.cyl(m, 0.9, 2.1, cf * CF(wx, 1.05, wz), rgb(20, 20, 20))
				Kit.cyl(m, 0.95, 1.1, cf * CF(wx, 1.05, wz), rgb(170, 170, 176), M.Metal)
			end
		end
		deco(m, V(1.1, 0.45, 0.2), cf * CF(-1.7, 1.9, -5.05), rgb(255, 250, 220), M.Neon)
		deco(m, V(1.1, 0.45, 0.2), cf * CF(1.7, 1.9, -5.05), rgb(255, 250, 220), M.Neon)
		deco(m, V(1.1, 0.45, 0.2), cf * CF(-1.7, 1.9, 5.05), rgb(200, 20, 20), M.Neon)
		deco(m, V(1.1, 0.45, 0.2), cf * CF(1.7, 1.9, 5.05), rgb(200, 20, 20), M.Neon)
		deco(m, V(2.2, 0.3, 0.2), cf * CF(0, 1.4, -5.1), rgb(40, 40, 44))
		return m
	end
	for _ = 1, 18 do
		local x = rng:float(-400, 400)
		if math.abs(x - 150) > 40 and math.abs(x - 40) > 20 and math.abs(x + 61) > 20 then
			local side = rng:sign()
			car(CF(x, 0.4, side * 11) * ANG(0, math.pi / 2, 0), rng:pick(carColors))
		end
	end
	-- planters with trees, benches, bins, hydrants, a bus stop
	for x = -400, 400, 55 do
		for _, side in { -1, 1 } do
			if math.abs(x - 150) > 30 and math.abs(x + 61) > 16 and rng:chance(0.75) then
				local p = V(x + 12, 0, side * 20)
				solid(props, V(4, 1.4, 4), CF(p + V(0, 0.7, 0)), rgb(120, 116, 110), M.Concrete)
				W.tree(props, p + V(0, 1.2, 0), "oak", rng, 0.75, Palette.biomes.Meadow)
			end
			if rng:chance(0.4) and math.abs(x - 150) > 30 then
				local bp = V(x - 8, 0, side * 20.5)
				solid(props, V(5, 0.4, 1.4), CF(bp + V(0, 1.7, 0)), rgb(110, 80, 56), M.WoodPlanks)
				solid(props, V(5, 1.4, 0.3), CF(bp + V(0, 2.6, side * 0.6)), rgb(110, 80, 56), M.WoodPlanks)
				for _, dx in { -2, 2 } do
					solid(props, V(0.3, 1.5, 1.2), CF(bp + V(dx, 0.75, 0)), rgb(40, 40, 44), M.Metal)
				end
			end
			if rng:chance(0.25) and math.abs(x - 150) > 30 then
				local hp = V(x + 3, 0, side * 17.5)
				solid(props, V(0.9, 2, 0.9), CF(hp + V(0, 1, 0)), rgb(200, 30, 30), M.Metal)
				solid(props, V(1.4, 0.4, 0.6), CF(hp + V(0, 1.4, 0)), rgb(200, 30, 30), M.Metal)
			end
		end
	end
	local busStop = V(-120, 0, 19)
	solid(props, V(12, 0.4, 4), CF(busStop + V(0, 8, 0)), rgb(60, 60, 70), M.Metal)
	deco(props, V(12, 7, 0.2), CF(busStop + V(0, 4, 1.8)), rgb(160, 200, 220), M.Glass, { Transparency = 0.5 })
	solid(props, V(8, 1, 2), CF(busStop + V(0, 1.8, 1)), rgb(80, 60, 50), M.WoodPlanks)
	solid(props, V(0.4, 8, 0.4), CF(busStop + V(-5.8, 4, -1.8)), rgb(60, 60, 70), M.Metal)
	local bsign = deco(props, V(2.4, 2.4, 0.2), CF(busStop + V(-5.8, 8.8, -1.8)), rgb(30, 90, 170))
	Kit.label(bsign, Enum.NormalId.Front, "BUS", rgb(255, 255, 255), Enum.Font.GothamBold, nil, 20)

	-- ------------------------------------------------------------ APARTMENT
	-- ground floor flat of a 6-storey block on the north side (x -89..-33, z 24..60).
	-- The front door is on the street wall, the TV has its own wall facing the couch.
	local ax, az = -61, 24
	local aw, ad, ah = 56, 36, 62
	local apt = Kit.model("Apartment", props)
	local wallC = rgb(190, 164, 136)
	local inner = rgb(232, 226, 214)
	local floorY = 0.4
	-- shell: upper floors solid, ground floor hollow with windows
	solid(apt, V(aw, ah - 16, ad), CF(ax, 16 + (ah - 16) / 2, az + ad / 2), wallC, M.Brick)
	solid(apt, V(aw, 16, 1), CF(ax, 8, az + ad - 0.5), wallC, M.Brick)
	solid(apt, V(1, 16, ad), CF(ax - aw / 2 + 0.5, 8, az + ad / 2), wallC, M.Brick)
	solid(apt, V(1, 16, ad), CF(ax + aw / 2 - 0.5, 8, az + ad / 2), wallC, M.Brick)
	-- front wall (street side, z = az): door at x = ax - 6, two living-room windows
	local doorX = ax - 6
	local front = { { ax - aw / 2, doorX - 2.5 }, { doorX + 2.5, ax + 4 }, { ax + 12, ax + 16 }, { ax + 24, ax + aw / 2 } }
	for _, seg in front do
		solid(apt, V(seg[2] - seg[1], 16, 1), CF((seg[1] + seg[2]) / 2, 8, az + 0.5), wallC, M.Brick)
	end
	solid(apt, V(5, 6.5, 1), CF(doorX, 12.75, az + 0.5), wallC, M.Brick)
	for _, wx in { { ax + 4, ax + 12 }, { ax + 16, ax + 24 } } do
		local c = (wx[1] + wx[2]) / 2
		solid(apt, V(8, 4, 1), CF(c, 2, az + 0.5), wallC, M.Brick)
		solid(apt, V(8, 4, 1), CF(c, 14, az + 0.5), wallC, M.Brick)
		windowPane(apt, CFrame.lookAt(V(c, 8, az + 0.3), V(c, 8, az - 5)), 7.4, 7.6, false)
	end
	local aptDoor = solid(apt, V(5, 9.5, 0.5), CF(doorX, 4.75, az + 0.5), rgb(88, 50, 38), M.WoodPlanks)
	aptDoor.Name = "AptDoor"
	deco(apt, V(0.4, 0.4, 0.8), CF(doorX + 1.8, 4.6, az + 0.2), Palette.metal.gold, M.Metal)
	deco(apt, V(6.4, 0.6, 2.4), CF(doorX, 10, az - 0.8), rgb(60, 56, 54))
	refs.aptDoor = aptDoor
	refs.aptOutside = CF(doorX, 3, az - 5)
	-- upper windows
	for y = 22, ah - 6, 9 do
		for x = ax - aw / 2 + 5, ax + aw / 2 - 5, 8 do
			windowPane(apt, CFrame.lookAt(V(x, y, az - 0.1), V(x, y, az - 5)), 4, 5, rng:chance(0.5))
		end
	end
	solid(apt, V(aw + 2, 1.4, ad + 2), CF(ax, ah + 0.7, az + ad / 2), Palette.shade(wallC, 0.8))
	-- floor & ceiling
	solid(apt, V(aw - 2, 0.3, ad - 2), CF(ax, 0.15, az + ad / 2), rgb(150, 112, 80), M.WoodPlanks)
	solid(apt, V(aw - 2, 0.6, ad - 2), CF(ax, 15.7, az + ad / 2), rgb(236, 232, 224))
	-- partitions (with doorways): bathroom (south-west), bedroom (north-west), kitchen (north-east)
	local function partition(a: Vector3, b: Vector3, gapAt: number?, gap: number?)
		local d = b - a
		local len = d.Magnitude
		local dir = d.Unit
		if not gapAt then
			solid(apt, V(0.6, 15.4, len), CFrame.lookAt((a + b) / 2 + V(0, 7.7, 0), b + V(0, 7.7, 0)), inner)
			return
		end
		local g0, g1 = gapAt - (gap or 4.5) / 2, gapAt + (gap or 4.5) / 2
		if g0 > 0 then
			solid(apt, V(0.6, 15.4, g0), CFrame.lookAt(a + dir * g0 / 2 + V(0, 7.7, 0), b + V(0, 7.7, 0)), inner)
		end
		if g1 < len then
			solid(apt, V(0.6, 15.4, len - g1), CFrame.lookAt(a + dir * (g1 + len) / 2 + V(0, 7.7, 0), b + V(0, 7.7, 0)), inner)
		end
		solid(apt, V(0.6, 6, g1 - g0), CFrame.lookAt(a + dir * (g0 + g1) / 2 + V(0, 12.4, 0), b + V(0, 12.4, 0)), inner)
	end
	local wx = ax - 10 -- west rooms end here
	local mz = az + 18 -- south / north split
	partition(V(wx, 0, az + 1), V(wx, 0, mz), 12, 4.5) -- bathroom east wall (door into the hall)
	partition(V(ax - aw / 2 + 1, 0, mz), V(wx, 0, mz)) -- bathroom / bedroom
	partition(V(wx, 0, mz), V(wx, 0, az + ad - 1), 4, 4.5) -- bedroom door
	partition(V(wx, 0, mz), V(ax + 6, 0, mz), 7, 7) -- kitchen arch (east part stays open)
	-- living room -------------------------------------------------------------
	-- TV on the east wall, couch facing it, rug, coffee table, lamp, shelf, plant
	local tvWallX = ax + aw / 2 - 1
	local tvZ = az + 9
	solid(apt, V(3, 2.4, 10), CF(tvWallX - 1.8, 1.2, tvZ), rgb(60, 44, 34), M.WoodPlanks)
	local tv = solid(apt, V(0.6, 5.4, 9.4), CF(tvWallX - 2.2, 5.6, tvZ), rgb(14, 14, 16))
	deco(apt, V(0.1, 4.8, 8.8), CF(tvWallX - 2.55, 5.6, tvZ), rgb(26, 34, 52), M.Glass)
	refs.tv = tv
	local couchX = ax + 8
	solid(apt, V(4, 2.2, 12), CF(couchX, 1.4, tvZ), rgb(70, 90, 112), M.Fabric)
	solid(apt, V(1.4, 3.4, 12), CF(couchX - 2.4, 2.8, tvZ), rgb(64, 84, 104), M.Fabric)
	for _, s in { -1, 1 } do
		solid(apt, V(4, 3, 1.2), CF(couchX, 2.0, tvZ + s * 6.4), rgb(62, 82, 102), M.Fabric)
	end
	for i = -1, 1 do
		deco(apt, V(3.4, 0.6, 3.6), CF(couchX + 0.2, 2.8, tvZ + i * 3.8), rgb(80, 102, 124), M.Fabric)
	end
	deco(apt, V(10, 0.12, 12), CF(couchX + 7, 0.4, tvZ), rgb(160, 56, 56), M.Fabric)
	table_(apt, CF(couchX + 6, 0.3, tvZ), V(4, 1.8, 6), rgb(120, 86, 56))
	deco(apt, V(0.8, 0.7, 0.8), CF(couchX + 6, 2.4, tvZ - 1), rgb(236, 236, 236))
	solid(apt, V(1, 11, 7), CF(ax + 4.5, 5.5, az + 16), rgb(110, 80, 56), M.WoodPlanks)
	for s = 0, 3 do
		for k = 0, 5 do
			deco(apt, V(0.8, 1.6, 0.6), CF(ax + 4, 2 + s * 2.6, az + 13.4 + k * 1), rng:pick({ rgb(160, 40, 40), rgb(40, 70, 140), rgb(220, 200, 140), rgb(60, 110, 60) }))
		end
	end
	plant(apt, V(tvWallX - 2, 0.3, az + 2.5))
	solid(apt, V(0.4, 6, 0.4), CF(couchX - 1, 3, tvZ - 7.5), rgb(40, 40, 44), M.Metal)
	lamp(apt, V(couchX - 1, 6.3, tvZ - 7.5), rgb(255, 214, 160), 18)
	-- hall: coat rack + shoe rack by the door
	solid(apt, V(3, 1.4, 1.2), CF(doorX - 3, 0.7, az + 2), rgb(90, 64, 44), M.WoodPlanks)
	solid(apt, V(0.3, 6, 0.3), CF(doorX + 3.8, 3, az + 2), rgb(90, 64, 44), M.Wood)
	deco(apt, V(1.4, 2.2, 0.8), CF(doorX + 3.8, 4.8, az + 2.3), rgb(60, 70, 90), M.Fabric)
	-- bathroom (south-west) -----------------------------------------------------
	local bx = ax - aw / 2 + 1
	solid(apt, V(3, 2.2, 2.4), CF(bx + 2, 1.1, az + 4), rgb(240, 240, 242), M.Marble)
	solid(apt, V(1, 2.6, 2.4), CF(bx + 0.9, 3.2, az + 4), rgb(240, 240, 242), M.Marble)
	solid(apt, V(3.4, 3, 2), CF(bx + 2, 1.5, az + 10), rgb(236, 236, 240), M.Marble)
	deco(apt, V(0.2, 3, 2.8), CF(bx + 0.3, 6, az + 10), rgb(190, 210, 225), M.Glass, { Transparency = 0.1 })
	solid(apt, V(7, 0.4, 6), CF(bx + 4, 0.35, az + 14), rgb(220, 226, 230), M.Marble)
	deco(apt, V(0.2, 7, 6), CF(bx + 7.5, 3.8, az + 14), rgb(190, 220, 240), M.Glass, { Transparency = 0.5 })
	for x = bx + 1, wx - 1, 2 do
		deco(apt, V(1.9, 0.05, 1.9), CF(x, 0.33, az + 3), rgb(210, 220, 226))
	end
	lamp(apt, V((bx + wx) / 2, 15.2, az + 9), rgb(240, 248, 255), 16)
	-- bedroom (north-west) ------------------------------------------------------
	local bedCF = CF(ax - 20, 0, az + ad - 7)
	solid(apt, V(7, 1.6, 10), bedCF * CF(0, 1.1, 0), rgb(100, 70, 50), M.WoodPlanks)
	solid(apt, V(6.6, 1, 9.6), bedCF * CF(0, 2.4, 0), rgb(240, 240, 245), M.Fabric)
	solid(apt, V(7.2, 4, 0.6), bedCF * CF(0, 2.4, 5), rgb(100, 70, 50), M.WoodPlanks)
	deco(apt, V(6.8, 0.5, 6.4), bedCF * CF(0, 3.05, -1.2), rgb(90, 110, 170), M.Fabric)
	deco(apt, V(2.6, 0.7, 1.6), bedCF * CF(-1.6, 3.2, 3.6), rgb(250, 250, 252), M.Fabric)
	deco(apt, V(2.6, 0.7, 1.6), bedCF * CF(1.6, 3.2, 3.6), rgb(250, 250, 252), M.Fabric)
	solid(apt, V(2.5, 2.6, 2.5), bedCF * CF(5, 1.3, 3.5), rgb(120, 90, 60), M.WoodPlanks)
	local lampShade = deco(apt, V(1.2, 1.4, 1.2), bedCF * CF(5, 3.7, 3.5), rgb(255, 220, 160), M.Neon)
	Kit.pointLight(lampShade, rgb(255, 210, 150), 14, 1)
	local clock = deco(apt, V(1.6, 0.8, 1), bedCF * CF(5, 3.0, 2.6), rgb(20, 20, 24))
	Kit.label(clock, Enum.NormalId.Front, "07:02", rgb(255, 50, 50), Enum.Font.Arcade, nil, 20)
	solid(apt, V(6, 12, 3), CF(ax - 26, 6, az + 21), rgb(140, 100, 70), M.WoodPlanks)
	-- a desk with the gaming PC under the bedroom window
	table_(apt, CF(ax - 14.5, 0.3, az + ad - 3), V(6, 3.4, 2.6), rgb(60, 60, 64), M.Metal)
	deco(apt, V(3, 2, 0.3), CF(ax - 14.5, 5, az + ad - 2.4), rgb(20, 20, 24))
	solid(apt, V(1.4, 3, 2.4), CF(ax - 16.6, 1.8, az + ad - 3), rgb(30, 30, 34))
	deco(apt, V(0.2, 2.6, 0.1), CF(ax - 15.9, 1.8, az + ad - 4.25), rgb(80, 255, 200), M.Neon)
	windowPane(apt, CFrame.lookAt(V(ax - aw / 2 + 0.6, 8, az + 27), V(ax - aw / 2 - 5, 8, az + 27)), 7, 6, false)
	refs.bedCF = bedCF * CF(0, 4.2, 0)
	refs.wakeCF = CFrame.lookAt((bedCF * CF(3.5, 3, -6.5)).Position, (bedCF * CF(10, 3, -12)).Position)
	refs.ceilingCam = CFrame.lookAt((bedCF * CF(0, 5, 1)).Position, (bedCF * CF(0, 15, 1.2)).Position)
	-- kitchen + dining (north-east) ---------------------------------------------
	local kz = az + ad - 2.5
	local kx0, kx1 = ax - 8, ax + aw / 2 - 1
	solid(apt, V(kx1 - kx0 - 6, 3.6, 3), CF((kx0 + kx1) / 2 - 3, 1.8, kz), rgb(236, 236, 238), M.Marble)
	deco(apt, V(kx1 - kx0 - 6, 0.3, 3.2), CF((kx0 + kx1) / 2 - 3, 3.75, kz), rgb(60, 60, 64), M.Granite)
	for x = kx0 + 2, kx1 - 8, 3 do
		deco(apt, V(2.6, 2.6, 0.1), CF(x, 1.8, kz - 1.55), rgb(200, 200, 204))
		deco(apt, V(0.8, 0.15, 0.2), CF(x, 2.8, kz - 1.65), rgb(140, 140, 146), M.Metal)
		solid(apt, V(2.8, 3, 1.6), CF(x, 10, kz + 0.6), rgb(226, 226, 230))
	end
	local fridge = solid(apt, V(4, 9, 3.5), CF(kx1 - 2.5, 4.5, kz - 0.5), rgb(236, 236, 240), M.Metal)
	deco(apt, V(0.2, 3, 0.2), CF(kx1 - 4, 5.5, kz - 2.3), rgb(150, 150, 156), M.Metal)
	refs.fridge = fridge
	local stoveX = kx0 + 10
	deco(apt, V(3.2, 0.1, 2.6), CF(stoveX, 3.95, kz), rgb(20, 20, 20))
	for i = 0, 1 do
		for j = 0, 1 do
			deco(apt, V(0.9, 0.12, 0.9), CF(stoveX - 0.8 + i * 1.6, 4.0, kz - 0.6 + j * 1.2), rgb(60, 20, 20))
		end
	end
	solid(apt, V(3.4, 1.4, 2.6), CF(stoveX, 11.5, kz + 0.2), rgb(150, 150, 156), M.Metal)
	deco(apt, V(2.4, 0.3, 1.6), CF(kx0 + 16, 3.85, kz), rgb(170, 170, 176), M.Metal)
	-- dining table with the breakfast plate and two chairs
	local tp = V(ax + 12, 0, az + 25)
	table_(apt, CF(tp + V(0, 0.3, 0)), V(8, 3.6, 5), rgb(150, 110, 70))
	woodChair(apt, CF(tp + V(0, 0.3, -4)), rgb(120, 86, 56))
	woodChair(apt, CF(tp + V(0, 0.3, 4)) * ANG(0, math.pi, 0), rgb(120, 86, 56))
	local plate = solid(apt, V(1.8, 0.2, 1.8), CF(tp + V(0, 4.1, -1)), rgb(245, 245, 245))
	deco(apt, V(1.1, 0.4, 1.1), CF(tp + V(0, 4.35, -1)), rgb(220, 180, 90))
	deco(apt, V(0.6, 0.9, 0.6), CF(tp + V(1.6, 4.5, -1)), rgb(250, 250, 250))
	deco(apt, V(0.45, 0.15, 0.45), CF(tp + V(1.6, 4.98, -1)), rgb(90, 50, 30))
	refs.plate = plate
	refs.dinnerSpot = CFrame.lookAt(tp + V(0, 3, -6), tp + V(0, 3, 0))
	windowPane(apt, CFrame.lookAt(V(ax + 20, 8, az + ad - 0.6), V(ax + 20, 8, az + ad + 5)), 7, 6, false)
	-- ceiling lights per room
	lamp(apt, V(ax + 10, 15.2, az + 9), nil, 34)
	lamp(apt, V(ax + 10, 15.2, az + 27), nil, 30)
	lamp(apt, V(ax - 20, 15.2, az + 27), rgb(255, 225, 190), 24)
	refs.aptInside = CF(ax + 2, 3, az + 6)
	refs.aptCenter = V(ax + 6, 3, az + 12)

	-- ------------------------------------------------------------ OFFICE
	-- south side (x 6..74, z -24..-64): glass lobby, reception, open-plan desks with
	-- office chairs, the boss's glass corner office, coffee corner, printer.
	local ox, oz = 40, -24
	local ow, od, oh = 68, 40, 90
	local off = Kit.model("Office", props)
	local glass = rgb(110, 150, 180)
	solid(off, V(ow, oh - 18, od), CF(ox, 18 + (oh - 18) / 2, oz - od / 2), rgb(90, 104, 120), M.Glass, { Transparency = 0 })
	for y = 22, oh - 4, 8 do
		deco(off, V(ow + 0.4, 0.8, od + 0.4), CF(ox, y, oz - od / 2), rgb(200, 205, 210), M.Metal)
	end
	for x = ox - ow / 2 + 4, ox + ow / 2 - 4, 8 do
		deco(off, V(0.6, oh - 18, 0.6), CF(x, 18 + (oh - 18) / 2, oz + 0.3), rgb(200, 205, 210), M.Metal)
	end
	solid(off, V(ow, 18, 1), CF(ox, 9, oz - od + 0.5), rgb(200, 205, 210), M.Concrete)
	solid(off, V(1, 18, od), CF(ox - ow / 2 + 0.5, 9, oz - od / 2), rgb(200, 205, 210), M.Concrete)
	solid(off, V(1, 18, od), CF(ox + ow / 2 - 0.5, 9, oz - od / 2), rgb(200, 205, 210), M.Concrete)
	solid(off, V(30, 18, 0.6), CF(ox - 19, 9, oz - 0.3), glass, M.Glass, { Transparency = 0.45 })
	solid(off, V(30, 18, 0.6), CF(ox + 19, 9, oz - 0.3), glass, M.Glass, { Transparency = 0.45 })
	solid(off, V(8, 8, 0.6), CF(ox, 14, oz - 0.3), glass, M.Glass, { Transparency = 0.45 })
	for _, x in { -4, 4 } do
		deco(off, V(0.5, 10, 0.8), CF(ox + x, 5, oz - 0.3), rgb(200, 205, 210), M.Metal)
	end
	local sign = deco(off, V(26, 3, 0.6), CF(ox, 20, oz + 0.2), rgb(30, 30, 40))
	Kit.label(sign, Enum.NormalId.Back, string.upper(bible.company), rgb(120, 200, 255), Enum.Font.GothamBold, nil, 14)
	solid(off, V(ow - 2, 0.4, od - 2), CF(ox, 0.2, oz - od / 2), rgb(112, 118, 126), M.Carpet)
	solid(off, V(ow - 2, 0.6, od - 2), CF(ox, 17.7, oz - od / 2), rgb(236, 236, 236))
	for i = 0, 3 do
		for j = 0, 2 do
			local l = deco(off, V(6, 0.3, 3), CF(ox - 24 + i * 16, 17.3, oz - 10 - j * 10), rgb(240, 250, 255), M.Neon)
			if j == 1 then
				Kit.pointLight(l, rgb(230, 245, 255), 30, 0.9)
			end
		end
	end
	-- reception
	solid(off, V(10, 3.8, 2.6), CF(ox - 18, 1.9, oz - 5), rgb(236, 236, 238), M.Marble)
	deco(off, V(10.2, 0.3, 2.8), CF(ox - 18, 3.9, oz - 5), rgb(40, 40, 44), M.Granite)
	-- desks: 3 rows x 4, a monitor, keyboard, lamp, mug and an office chair each
	refs.desks = {}
	refs.coworkerSeats = {}
	for row = 0, 2 do
		for col = 0, 3 do
			local dp = V(ox - 24 + col * 16, 0.4, oz - 10 - row * 10)
			local deskTop = 3.6
			solid(off, V(7, 0.25, 3.6), CF(dp + V(0, deskTop - 0.4, 0.2)), rgb(214, 204, 188), M.WoodPlanks)
			for _, sx in { -3.2, 3.2 } do
				solid(off, V(0.3, deskTop - 0.5, 3.2), CF(dp + V(sx, (deskTop - 0.5) / 2, 0.2)), rgb(170, 172, 178), M.Metal)
			end
			-- cubicle screens
			solid(off, V(0.3, 5.6, 5.2), CF(dp + V(-3.9, 2.8, 0.2)), rgb(120, 132, 150), M.Fabric)
			solid(off, V(8, 5.6, 0.3), CF(dp + V(0, 2.8, 2.2)), rgb(120, 132, 150), M.Fabric)
			local mon = solid(off, V(3, 2.1, 0.25), CF(dp + V(0, deskTop + 1.4, 1.2)), rgb(20, 20, 24))
			deco(off, V(0.3, 0.9, 0.3), CF(dp + V(0, deskTop - 0.05, 1.35)), rgb(30, 30, 34), M.Metal)
			deco(off, V(2.2, 0.12, 0.8), CF(dp + V(0, deskTop - 0.2, -0.3)), rgb(40, 40, 44))
			deco(off, V(0.4, 0.12, 0.6), CF(dp + V(1.7, deskTop - 0.2, -0.3)), rgb(40, 40, 44))
			if rng:chance(0.6) then
				deco(off, V(0.5, 0.6, 0.5), CF(dp + V(-2.4, deskTop, 0.2)), rng:pick({ rgb(240, 240, 240), rgb(200, 60, 60), rgb(60, 90, 160) }))
			end
			if rng:chance(0.5) then
				deco(off, V(1.8, 0.4, 2.2), CF(dp + V(2.2, deskTop - 0.1, 0.6)) * ANG(0, rng:float(-0.3, 0.3), 0), rgb(245, 245, 240))
			end
			local sg = Instance.new("SurfaceGui")
			sg.Face = Enum.NormalId.Front
			sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			sg.CanvasSize = Vector2.new(120, 88)
			sg.LightInfluence = 0
			local bg = Instance.new("Frame")
			bg.Size = UDim2.fromScale(1, 1)
			bg.BackgroundColor3 = rgb(230, 240, 235)
			bg.BorderSizePixel = 0
			bg.Parent = sg
			for r = 0, 6 do
				for c = 0, 3 do
					local cell = Instance.new("Frame")
					cell.Size = UDim2.fromOffset(28, 10)
					cell.Position = UDim2.fromOffset(2 + c * 29, 4 + r * 12)
					cell.BackgroundColor3 = if r == 0 then rgb(60, 140, 90) else rgb(255, 255, 255)
					cell.BorderSizePixel = 0
					cell.Parent = bg
				end
			end
			sg.Parent = mon
			-- the chair faces the desk (+Z); a seated worker's root sits SEAT_ROOT above the seat
			local chairCF = CFrame.lookAt(dp + V(0, 0, -2.6), dp + V(0, 0, 5))
			local seatTop = officeChair(off, chairCF, rng:pick({ rgb(34, 36, 44), rgb(40, 50, 80), rgb(70, 30, 34) }))
			local seat = CFrame.lookAt(V(dp.X, seatTop + Prologue.SEAT_ROOT, dp.Z - 2.4), V(dp.X, seatTop + Prologue.SEAT_ROOT, dp.Z + 5))
			if row == 1 and col == 1 then
				refs.myDesk = mon
				refs.mySeat = seat
				refs.deskCam = CFrame.lookAt(dp + V(0.2, seatTop + 3.2, -2.2), dp + V(0, deskTop + 1.3, 1.2))
			else
				table.insert(refs.coworkerSeats, seat)
			end
		end
	end
	-- boss office corner (glass walls, big desk, leather chair, shelf, plant)
	local bo = V(ox + 24, 0.4, oz - 30)
	solid(off, V(1, 17, 18), CF(bo.X - 8, 8.9, bo.Z), rgb(200, 205, 210), M.Glass, { Transparency = 0.55 })
	solid(off, V(16, 17, 1), CF(bo.X, 8.9, bo.Z + 9), rgb(200, 205, 210), M.Glass, { Transparency = 0.55 })
	table_(off, CF(bo + V(0, 0, -2)), V(10, 3.6, 5), rgb(84, 56, 38))
	officeChair(off, CFrame.lookAt(bo + V(0, 0, -6.5), bo + V(0, 0, 4)), rgb(30, 20, 18))
	solid(off, V(10, 11, 2), CF(bo + V(0, 5.5, -8.5)), rgb(90, 64, 44), M.WoodPlanks)
	plant(off, bo + V(-6, 0, -7), 1.2)
	refs.bossSpot = CFrame.lookAt(V(ox + 10, 3.4, oz - 6), V(ox, 3.4, oz - 20))
	-- coffee corner, water cooler, printer, whiteboard, plants
	local coffee = solid(off, V(2.4, 4, 2), CF(ox - 30, 2.4, oz - 4), rgb(40, 40, 44), M.Metal)
	refs.coffee = coffee
	solid(off, V(4, 3.4, 2.6), CF(ox - 30, 1.7, oz - 8), rgb(236, 236, 238))
	Kit.cyl(off, 2.2, 1.6, CF(ox - 30, 5.8, oz - 12) * ANG(0, 0, math.pi / 2), rgb(170, 210, 240), M.Glass, { Transparency = 0.3 })
	solid(off, V(1.8, 3.6, 1.8), CF(ox - 30, 2.2, oz - 12), rgb(230, 230, 232))
	solid(off, V(4, 3.6, 3), CF(ox - 30, 2.2, oz - 18), rgb(210, 212, 216))
	local wb = deco(off, V(12, 5, 0.3), CF(ox - 8, 8, oz - od + 1.2), rgb(248, 248, 250))
	deco(off, V(8, 0.2, 0.1), CF(ox - 10, 9, oz - od + 1.4), rgb(40, 90, 200))
	deco(off, V(5, 0.2, 0.1), CF(ox - 6, 7.5, oz - od + 1.4), rgb(200, 40, 40))
	local _ = wb
	for i = 1, 4 do
		plant(off, V(ox - 32 + i * 16, 0.4, oz - 37))
	end
	refs.officeDoor = V(ox, 3, oz + 3)
	refs.officeInside = V(ox, 3, oz - 6)

	-- ------------------------------------------------------------ THE CLUB
	local cx, cz = 226, 24
	local club = Kit.model("Club", props)
	solid(club, V(70, 40, 44), CF(cx, 20, cz + 22), rgb(24, 22, 30), M.Concrete)
	for x = cx - 30, cx + 30, 10 do
		deco(club, V(1, 38, 0.6), CF(x, 20, cz - 0.3), rgb(40, 36, 50), M.Metal)
	end
	local clubSign = deco(club, V(40, 8, 1), CF(cx, 30, cz - 0.6), rgb(20, 10, 30))
	Kit.label(clubSign, Enum.NormalId.Front, bible.club, rgb(255, 60, 200), Enum.Font.GothamBlack, nil, 12)
	Kit.label(clubSign, Enum.NormalId.Back, bible.club, rgb(255, 60, 200), Enum.Font.GothamBlack, nil, 12)
	for i, col in { rgb(255, 60, 200), rgb(60, 200, 255), rgb(255, 230, 60) } do
		local strip = deco(club, V(70, 0.6, 0.6), CF(cx, 4 + i * 6, cz - 0.4), col, M.Neon)
		Kit.pointLight(strip, col, 22, 1.2)
	end
	solid(club, V(8, 12, 1), CF(cx, 6, cz - 0.2), rgb(10, 10, 12))
	solid(club, V(30, 0.4, 3), CF(cx - 20, 0.6, cz - 4), rgb(150, 20, 30), M.Fabric)
	for i = 0, 6 do
		solid(club, V(0.3, 3, 0.3), CF(cx - 34 + i * 4, 1.5, cz - 5.5), Palette.metal.gold, M.Metal)
	end
	for i = 0, 5 do
		deco(club, V(4, 0.25, 0.25), CF(cx - 32 + i * 4, 2.8, cz - 5.5), rgb(150, 20, 30), M.Fabric)
	end
	refs.clubDoor = V(cx, 3, cz - 4)
	refs.clubQueue = {}
	for i = 1, 6 do
		table.insert(refs.clubQueue, CFrame.lookAt(V(cx - 8 - i * 3.6, 3, cz - 4), V(cx, 3, cz - 4)))
	end
	refs.bouncer = CFrame.lookAt(V(cx + 6, 3, cz - 4), V(cx + 6, 3, cz - 20))

	-- truck route (cross street, coming from the south, heading north)
	refs.truckFrom = CFrame.lookAt(V(150, 0.4, -330), V(150, 0.4, 0))
	refs.truckTo = CFrame.lookAt(V(150, 0.4, 150), V(150, 0.4, 400))
	refs.walkPath = { V(-20, 3, 20), V(60, 3, 20), V(120, 3, 20), V(130, 3, 40) }
	return refs
end

-- Day/evening/night: lights on, windows lit
function Prologue.setNight(refs, on: boolean)
	for _, l in refs.streetLights do
		l.Enabled = on
	end
end

return Prologue
