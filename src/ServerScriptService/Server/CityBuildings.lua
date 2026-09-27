--!nonstrict
-- Facade generator for the prologue city. A facade is described in a local frame F
-- placed on the facade plane (the building mass face) at street level, with
-- F.LookVector pointing OUT to the street. Local coordinates: u along the facade
-- (F's X axis), y = world height, d = distance in front of the mass face (d > 0
-- is outside, d < 0 is inside the building). Everything protrudes in layers
-- (reveals, frames, sills, lintels, string courses, cornices) so no two visible
-- faces are coplanar.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local CityKit = require(script.Parent.CityKit)

local Buildings = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local Mt = CityKit.M

local function shade(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end
Buildings.shade = shade

-- local box helper: u0..u1, y0..y1, d0..d1 (d outward)
local function L(B, F, u0, u1, y0, y1, d0, d1, color, mat, solid)
	return B:lbox(F, u0, u1, y0, y1, -d1, -d0, color, mat, solid)
end
Buildings.L = L

local GLASS_DAY = { rgb(62, 78, 92), rgb(70, 86, 98), rgb(56, 66, 78), rgb(80, 92, 100), rgb(66, 74, 84) }
local GLASS_NIGHT = { rgb(255, 208, 140), rgb(255, 196, 120), rgb(240, 226, 190), rgb(200, 214, 255), rgb(255, 180, 110), rgb(150, 170, 255) }

Buildings.STYLES = {
	brick = { wall = { rgb(150, 78, 62), rgb(128, 66, 54), rgb(166, 100, 76), rgb(112, 60, 50), rgb(140, 92, 72) }, mat = Mt.brick, trim = { rgb(206, 198, 180), rgb(188, 182, 170), rgb(214, 206, 190) }, trimMat = Mt.limestone, frame = { rgb(236, 234, 228), rgb(40, 40, 44), rgb(60, 70, 64) } },
	stone = { wall = { rgb(196, 186, 164), rgb(176, 168, 150), rgb(206, 198, 180), rgb(160, 156, 146) }, mat = Mt.limestone, trim = { rgb(226, 220, 204), rgb(150, 146, 136) }, trimMat = Mt.limestone, frame = { rgb(40, 40, 44), rgb(90, 64, 44) } },
	plaster = { wall = { rgb(170, 176, 160), rgb(196, 176, 140), rgb(150, 164, 176), rgb(186, 160, 150), rgb(206, 200, 186), rgb(140, 150, 140) }, mat = Mt.plaster, trim = { rgb(230, 226, 216), rgb(210, 206, 196) }, trimMat = Mt.concrete, frame = { rgb(236, 234, 228), rgb(50, 50, 54) } },
	modern = { wall = { rgb(160, 162, 164), rgb(120, 124, 128), rgb(196, 196, 192), rgb(90, 94, 100) }, mat = Mt.concrete, trim = { rgb(60, 62, 66), rgb(200, 200, 198) }, trimMat = Mt.metal, frame = { rgb(40, 42, 46), rgb(170, 172, 176) } },
	glass = { wall = { rgb(58, 72, 86), rgb(66, 84, 96), rgb(50, 62, 74) }, mat = Mt.glass, trim = { rgb(150, 156, 164), rgb(96, 100, 108) }, trimMat = Mt.metal, frame = { rgb(150, 156, 164) } },
}

-- one window with reveals, frame, mullion, sill and lintel
local function window(B, F, o, uc: number, wb: number, ww: number, wh: number, refs)
	local rng = B.rng
	local trim, frame, wall = o.trimC, o.frameC, o.wallC
	local u0, u1 = uc - ww / 2, uc + ww / 2
	local gc = rng:pick(GLASS_DAY)
	local glass = L(B, F, u0, u1, wb, wb + wh, 0.02, 0.1, gc, Mt.glass, false)
	glass.Reflectance = 0.12
	if rng:chance(o.lit or 0.3) then
		CityKit.nightPart(refs, glass, gc, rng:pick(GLASS_NIGHT), Mt.glass, 0)
		table.insert(refs.windows, glass)
	end
	-- sill + lintel (all styles)
	L(B, F, u0 - 0.35, u1 + 0.35, wb - 0.35, wb + 0.08, 0, 0.72, trim, o.trimMat)
	if o.detail == "simple" then
		L(B, F, u0 - 0.3, u1 + 0.3, wb + wh - 0.05, wb + wh + 0.7, 0, 0.35, trim, o.trimMat)
		return
	end
	if o.style == "brick" or o.style == "stone" then
		L(B, F, u0 - 0.5, u1 + 0.5, wb + wh - 0.08, wb + wh + 0.9, 0, 0.55, trim, o.trimMat)
		L(B, F, u0 - 0.1, u0 + 0.28, wb + 0.08, wb + wh - 0.08, 0, 0.48, shade(wall, 0.92), o.wallMat)
		L(B, F, u1 - 0.28, u1 + 0.1, wb + 0.08, wb + wh - 0.08, 0, 0.48, shade(wall, 0.92), o.wallMat)
		if o.style == "stone" then
			-- keystone
			L(B, F, uc - 0.35, uc + 0.35, wb + wh + 0.2, wb + wh + 1.25, 0, 0.7, shade(trim, 1.04), o.trimMat)
		end
	else
		L(B, F, u0 - 0.2, u1 + 0.2, wb + wh - 0.05, wb + wh + 0.3, 0, 0.4, trim, o.trimMat)
	end
	-- frame
	L(B, F, u0 + 0.28, u0 + 0.5, wb + 0.08, wb + wh - 0.08, 0.1, 0.3, frame, Mt.wood)
	L(B, F, u1 - 0.5, u1 - 0.28, wb + 0.08, wb + wh - 0.08, 0.1, 0.3, frame, Mt.wood)
	L(B, F, u0 + 0.28, u1 - 0.28, wb + wh - 0.3, wb + wh - 0.08, 0.1, 0.3, frame, Mt.wood)
	L(B, F, uc - 0.09, uc + 0.09, wb + 0.08, wb + wh - 0.3, 0.1, 0.26, frame, Mt.wood)
	L(B, F, u0 + 0.5, u1 - 0.5, wb + wh * 0.68, wb + wh * 0.68 + 0.18, 0.1, 0.26, frame, Mt.wood)
	-- AC unit hanging under some windows
	if o.ac and rng:chance(o.ac) then
		local ax = uc + rng:float(-ww * 0.2, ww * 0.2)
		L(B, F, ax - 0.9, ax + 0.9, wb - 1.5, wb - 0.4, 0.2, 1.5, rgb(206, 206, 200), Mt.metal)
		L(B, F, ax - 0.7, ax + 0.7, wb - 1.35, wb - 0.55, 1.5, 1.56, rgb(120, 120, 118), Mt.diamond)
	end
end

-- Juliet balcony railing in front of a window
local function juliet(B, F, uc, wb, ww, color)
	L(B, F, uc - ww / 2 - 0.3, uc + ww / 2 + 0.3, wb - 0.5, wb - 0.2, 0.1, 1.2, shade(color, 1.1), Mt.concrete)
	L(B, F, uc - ww / 2 - 0.2, uc + ww / 2 + 0.2, wb + 2.3, wb + 2.45, 0.9, 1.1, color, Mt.metal)
	local n = math.max(3, math.floor(ww / 0.6))
	for i = 0, n do
		local x = uc - ww / 2 - 0.1 + i * (ww + 0.2) / n
		L(B, F, x - 0.05, x + 0.05, wb - 0.2, wb + 2.3, 0.95, 1.05, color, Mt.metal)
	end
end

-- projecting balcony with railing (plaster/modern)
local function balcony(B, F, u0, u1, yf, o)
	local slab = shade(o.trimC, 1.02)
	L(B, F, u0, u1, yf, yf + 0.55, 0, 3.4, slab, Mt.concrete)
	if o.style == "modern" then
		local gp = L(B, F, u0 + 0.1, u1 - 0.1, yf + 0.55, yf + 3.6, 3.15, 3.3, rgb(170, 200, 210), Mt.glass)
		gp.Transparency = 0.55
		L(B, F, u0, u1, yf + 3.6, yf + 3.8, 3.1, 3.35, rgb(60, 62, 66), Mt.metal)
		for _, s in { u0 + 0.1, u1 - 0.3 } do
			local gs = L(B, F, s, s + 0.2, yf + 0.55, yf + 3.6, 0.3, 3.15, rgb(170, 200, 210), Mt.glass)
			gs.Transparency = 0.55
		end
	else
		local rc = rgb(40, 40, 44)
		L(B, F, u0 + 0.1, u1 - 0.1, yf + 3.4, yf + 3.6, 3.1, 3.3, rc, Mt.metal)
		L(B, F, u0 + 0.1, u1 - 0.1, yf + 0.9, yf + 1.05, 3.12, 3.28, rc, Mt.metal)
		local n = math.floor((u1 - u0) / 0.9)
		for i = 0, n do
			local x = u0 + 0.2 + i * (u1 - u0 - 0.4) / n
			L(B, F, x - 0.05, x + 0.05, yf + 0.55, yf + 3.4, 3.15, 3.25, rc, Mt.metal)
		end
		for _, s in { u0 + 0.1, u1 - 0.3 } do
			L(B, F, s, s + 0.2, yf + 3.4, yf + 3.6, 0.2, 3.1, rc, Mt.metal)
		end
		-- a potted plant / chair on some balconies
		if B.rng:chance(0.5) then
			local x = B.rng:float(u0 + 1, u1 - 1)
			L(B, F, x - 0.4, x + 0.4, yf + 0.55, yf + 1.4, 1.8, 2.6, rgb(160, 90, 60), Mt.concrete)
			L(B, F, x - 0.7, x + 0.7, yf + 1.4, yf + 2.4, 1.6, 2.8, rgb(70, 120, 60), Mt.leafy)
		end
	end
end

-- iron fire escape spanning u0..u1 for floors 1..n
local function fireEscape(B, F, u0, u1, y0, floors, fh)
	local c = rgb(34, 34, 36)
	local dp = 4.2
	for k = 1, floors do
		local yf = y0 + (k - 1) * fh
		L(B, F, u0, u1, yf - 0.2, yf + 0.05, 0.2, dp, rgb(46, 46, 48), Mt.diamond)
		L(B, F, u0, u1, yf + 3.3, yf + 3.45, dp - 0.15, dp, c, Mt.metal)
		L(B, F, u0, u1, yf + 1.6, yf + 1.72, dp - 0.14, dp - 0.02, c, Mt.metal)
		for _, s in { u0, u1 - 0.15 } do
			L(B, F, s, s + 0.15, yf + 3.3, yf + 3.45, 0.2, dp, c, Mt.metal)
		end
		local n = math.floor((u1 - u0) / 1.4)
		for i = 0, n do
			local x = u0 + 0.05 + i * (u1 - u0 - 0.2) / n
			L(B, F, x, x + 0.1, yf + 0.05, yf + 3.3, dp - 0.12, dp - 0.02, c, Mt.metal)
		end
		-- bracket under the platform
		for _, s in { u0 + 0.4, u1 - 0.55 } do
			B:deco(V(0.15, 0.15, 4.4), F * CF(s, yf - 1.3, -2.0) * ANG(math.rad(-28), 0, 0), c, Mt.metal)
		end
		if k < floors then
			-- stair to the next platform
			local sx0, sx1 = u0 + 1.2, u1 - 1.4
			local dx = sx1 - sx0
			local len = math.sqrt(dx * dx + fh * fh)
			local ang = math.atan2(fh, dx)
			local mid = F * CF((sx0 + sx1) / 2, yf + fh / 2, -(dp * 0.5 + 0.6))
			B:deco(V(len, 0.25, 1.8), mid * ANG(0, 0, ang), rgb(52, 52, 54), Mt.diamond)
			for _, off in { -0.95, 0.95 } do
				B:deco(V(len, 0.5, 0.1), mid * CF(0, 0, off) * ANG(0, 0, ang) * CF(0, 0.2, 0), c, Mt.metal)
			end
		else
			-- ladder up to the roof
			for _, s in { u1 - 1.4, u1 - 0.6 } do
				L(B, F, s - 0.06, s + 0.06, yf + 0.05, yf + fh * 0.9, 0.8, 0.92, c, Mt.metal)
			end
		end
	end
	-- drop ladder below the first platform
	for _, s in { u0 + 0.8, u0 + 1.8 } do
		L(B, F, s - 0.06, s + 0.06, y0 - 5, y0 - 0.2, dp - 0.9, dp - 0.78, c, Mt.metal)
	end
	for i = 1, 6 do
		L(B, F, u0 + 0.8, u0 + 1.8, y0 - 5 + i * 0.75, y0 - 5 + i * 0.75 + 0.08, dp - 0.9, dp - 0.78, c, Mt.metal)
	end
end

-- Resolves colours/materials for a style + rng into an options table.
function Buildings.resolve(B, o)
	local st = Buildings.STYLES[o.style or "brick"]
	o.wallC = o.wall or B.rng:pick(st.wall)
	o.wallMat = o.mat or st.mat
	o.trimC = o.trim or B.rng:pick(st.trim)
	o.trimMat = o.trimMat or st.trimMat
	o.frameC = o.frame or B.rng:pick(st.frame)
	return o
end

-- Upper facade: floors of windows, string courses, pilasters, balconies, cornice.
-- o: {y0, floors, floorH, bays, style, detail, lit, balcony, julietChance, ac, fire = {b0,b1}, cornice, top}
function Buildings.facade(B, F, W: number, o, refs)
	local rng = B.rng
	local fh = o.floorH or 12
	local n = o.bays or math.max(1, math.floor(W / 8))
	local bw = W / n
	local y0 = o.y0
	local top = y0 + o.floors * fh
	local style = o.style or "brick"
	if style == "glass" then
		return Buildings.curtainWall(B, F, W, o, refs)
	end
	if style == "modern" then
		return Buildings.ribbon(B, F, W, o, refs)
	end
	local ww = math.min(bw * 0.5, 4.6)
	local wh = fh * 0.56
	local pilW = 1.4
	-- corner pilasters
	for _, s in { -1, 1 } do
		local ua, ub = s * W / 2 - (if s > 0 then pilW else -0.1), s * W / 2 + (if s > 0 then 0.1 else pilW)
		L(B, F, math.min(ua, ub), math.max(ua, ub), y0 - 0.5, top, 0, 0.42, shade(o.wallC, 0.9), o.wallMat)
	end
	for k = 0, o.floors - 1 do
		local yf = y0 + k * fh
		-- string course at the floor line
		if k > 0 or o.baseCourse ~= false then
			L(B, F, -W / 2 + 0.2, W / 2 - 0.2, yf - 0.35, yf + 0.3, 0, 0.36, o.trimC, o.trimMat)
		end
		for b = 0, n - 1 do
			local uc = -W / 2 + (b + 0.5) * bw
			local wb = yf + 2.6
			local isFire = o.fire and b >= o.fire[1] and b <= o.fire[2]
			if not isFire and style == "plaster" and o.balcony and rng:chance(o.balcony) and k > 0 then
				-- french door + balcony
				balcony(B, F, uc - ww / 2 - 1.0, uc + ww / 2 + 1.0, yf, o)
				window(B, F, o, uc, yf + 0.6, ww, wh + 1.9, refs)
			else
				window(B, F, o, uc, wb, ww, wh, refs)
				if not isFire and o.juliet and rng:chance(o.juliet) then
					juliet(B, F, uc, wb, ww, rgb(36, 36, 40))
				end
			end
		end
	end
	if o.fire then
		local u0 = -W / 2 + o.fire[1] * bw + 0.6
		local u1 = -W / 2 + (o.fire[2] + 1) * bw - 0.6
		fireEscape(B, F, u0, u1, y0, o.floors, fh)
	end
	-- cornice
	if o.cornice ~= false then
		local cc = o.trimC
		L(B, F, -W / 2 - 0.1, W / 2 + 0.1, top - 1.4, top - 0.2, 0, 0.5, cc, o.trimMat)
		if o.detail ~= "simple" then
			local nd = math.floor(W / 1.6)
			for i = 0, nd - 1 do
				local x = -W / 2 + 0.8 + i * (W - 1.6) / math.max(1, nd - 1)
				L(B, F, x - 0.3, x + 0.3, top - 0.2, top + 0.35, 0, 0.9, shade(cc, 0.95), o.trimMat)
			end
		end
		L(B, F, -W / 2 - 0.3, W / 2 + 0.3, top + 0.35, top + 1.0, -0.3, 1.5, cc, o.trimMat)
		L(B, F, -W / 2 - 0.2, W / 2 + 0.2, top + 1.0, top + 2.4, -0.8, 0.3, shade(o.wallC, 0.95), o.wallMat)
		L(B, F, -W / 2 - 0.35, W / 2 + 0.35, top + 2.4, top + 2.75, -1.0, 0.5, cc, o.trimMat)
	end
	return top
end

-- Glass curtain wall: mullions, floor bands, spandrels; some panels lit at night.
function Buildings.curtainWall(B, F, W: number, o, refs)
	local rng = B.rng
	local fh = o.floorH or 12
	local y0 = o.y0
	local top = y0 + o.floors * fh
	local mc = o.trimC
	local nm = math.floor(W / 4)
	local step = W / nm
	for i = 0, nm do
		local u = -W / 2 + i * step
		L(B, F, u - 0.2, u + 0.2, y0, top, 0, 0.45, mc, Mt.metal)
	end
	for k = 0, o.floors do
		local yf = y0 + k * fh
		L(B, F, -W / 2, W / 2, yf - 0.9, yf + 0.9, 0.02, 0.2, shade(o.wallC, 0.7), Mt.glass)
		L(B, F, -W / 2 - 0.1, W / 2 + 0.1, yf + 0.9, yf + 1.2, 0, 0.32, mc, Mt.metal)
	end
	for k = 0, o.floors - 1 do
		local yf = y0 + k * fh
		for i = 0, nm - 1 do
			if rng:chance(o.lit or 0.2) then
				local u = -W / 2 + (i + 0.5) * step
				local p = L(B, F, u - step / 2 + 0.2, u + step / 2 - 0.2, yf + 1.2, yf + fh - 0.9, 0.02, 0.06, o.wallC, Mt.glass)
				CityKit.nightPart(refs, p, o.wallC, rng:pick({ rgb(236, 240, 255), rgb(255, 236, 200), rgb(220, 232, 255) }), Mt.glass, 0)
				table.insert(refs.windows, p)
			end
		end
	end
	L(B, F, -W / 2 - 0.3, W / 2 + 0.3, top, top + 1.2, -0.5, 0.6, mc, Mt.metal)
	return top
end

-- Modern concrete: projecting floor plates and ribbon windows with slim mullions.
function Buildings.ribbon(B, F, W: number, o, refs)
	local rng = B.rng
	local fh = o.floorH or 12
	local y0 = o.y0
	local top = y0 + o.floors * fh
	for k = 0, o.floors - 1 do
		local yf = y0 + k * fh
		L(B, F, -W / 2, W / 2, yf - 0.6, yf + 1.6, 0, 0.9, o.wallC, o.wallMat)
		local gb, gt = yf + 1.6, yf + fh - 0.6
		local nm = math.floor(W / 5)
		local step = W / nm
		for i = 0, nm - 1 do
			local u = -W / 2 + (i + 0.5) * step
			local gc = rng:pick(GLASS_DAY)
			local g = L(B, F, u - step / 2 + 0.1, u + step / 2 - 0.1, gb, gt, 0.02, 0.1, gc, Mt.glass)
			g.Reflectance = 0.15
			if rng:chance(o.lit or 0.3) then
				CityKit.nightPart(refs, g, gc, rng:pick(GLASS_NIGHT), Mt.glass, 0)
				table.insert(refs.windows, g)
			end
			L(B, F, u + step / 2 - 0.12, u + step / 2 + 0.12, gb, gt, 0, 0.3, o.frameC, Mt.metal)
		end
		if o.balcony and k > 0 and rng:chance(o.balcony) then
			local u0 = rng:float(-W / 2 + 1, W / 2 - 9)
			balcony(B, F, u0, u0 + 8, yf, o)
		end
	end
	L(B, F, -W / 2, W / 2, top - 0.6, top + 2.2, 0, 0.9, o.wallC, o.wallMat)
	L(B, F, -W / 2 - 0.1, W / 2 + 0.1, top + 2.2, top + 2.5, -0.5, 1.0, o.trimC, Mt.metal)
	return top
end

local SHOPS = {
	{ "CAFE LUNA", rgb(60, 90, 70), rgb(240, 230, 200) },
	{ "PHARMACY", rgb(40, 130, 90), rgb(255, 255, 255) },
	{ "WASH & FOLD", rgb(60, 110, 170), rgb(255, 255, 255) },
	{ "PIZZA NAPOLI", rgb(170, 40, 36), rgb(255, 236, 200) },
	{ "BARBER", rgb(30, 30, 36), rgb(230, 200, 120) },
	{ "24/7 MARKET", rgb(200, 60, 40), rgb(255, 255, 255) },
	{ "BOOKS", rgb(90, 60, 40), rgb(240, 220, 170) },
	{ "NOODLE BAR", rgb(150, 30, 40), rgb(255, 210, 120) },
	{ "PHONE REPAIR", rgb(40, 60, 120), rgb(120, 220, 255) },
	{ "BAKERY", rgb(190, 150, 100), rgb(80, 50, 30) },
	{ "KEBAB HOUSE", rgb(200, 120, 30), rgb(40, 20, 10) },
	{ "FLOWERS", rgb(120, 150, 90), rgb(255, 255, 255) },
	{ "DRY CLEANING", rgb(90, 90, 110), rgb(255, 255, 255) },
	{ "PAWN & GOLD", rgb(40, 40, 40), rgb(230, 190, 80) },
	{ "OPTICIAN", rgb(230, 230, 226), rgb(40, 60, 120) },
	{ "LIQUOR", rgb(80, 20, 30), rgb(255, 220, 120) },
}
Buildings.SHOPS = SHOPS

-- Ground-floor shopfront between u0..u1 (height gh) with a 3-stud-deep shop interior.
function Buildings.shopfront(B, F, u0: number, u1: number, gh: number, o, refs, shopIdx: number?)
	local rng = B.rng
	local shop = SHOPS[shopIdx or rng:int(1, #SHOPS)]
	local base = CityKit.WALK_Y
	local w = u1 - u0
	local depth = 3.2
	local glassTop = gh - 3.4
	-- interior: floor, back wall, side walls
	L(B, F, u0, u1, 0, base + 0.2, -depth, 0, rgb(170, 166, 156), Mt.tiles, true)
	L(B, F, u0, u1, base, glassTop, -depth - 0.4, -depth, shade(shop[2], 0.55), Mt.plaster, true)
	-- shelves with products or a counter
	local interiorLight
	if rng:chance(0.6) then
		for i = 0, 2 do
			local sy = base + 1.4 + i * 1.8
			L(B, F, u0 + 1, u1 - 1, sy, sy + 0.2, -depth, -depth + 1.1, rgb(200, 196, 188), Mt.wood)
			local x = u0 + 1.2
			while x < u1 - 1.6 do
				local pw = rng:float(0.4, 0.9)
				L(B, F, x, x + pw, sy + 0.2, sy + 0.2 + rng:float(0.5, 1.2), -depth + 0.1, -depth + 0.9, rng:pick({ rgb(200, 60, 50), rgb(60, 110, 200), rgb(240, 220, 90), rgb(90, 170, 90), rgb(230, 230, 230), rgb(200, 120, 60) }), Mt.plastic)
				x += pw + rng:float(0.05, 0.3)
			end
		end
	else
		local cx = u0 + w * 0.35
		L(B, F, cx - 3, cx + 3, base + 0.2, base + 3.4, -depth + 0.3, -depth + 1.8, shade(shop[2], 0.8), Mt.wood)
		L(B, F, cx - 3.1, cx + 3.1, base + 3.4, base + 3.6, -depth + 0.2, -depth + 1.9, rgb(60, 50, 44), Mt.granite)
	end
	interiorLight = L(B, F, u0 + 1, u1 - 1, glassTop - 0.35, glassTop - 0.15, -depth + 0.5, -depth + 1.1, rgb(200, 200, 196), Mt.glass)
	CityKit.nightPart(refs, interiorLight, rgb(200, 200, 196), rgb(255, 240, 210), Mt.plastic, 0)
	-- end pilasters (also the shop's side walls)
	for _, s in { u0, u1 } do
		local a = if s == u0 then s else s - 0.9
		L(B, F, a, a + 0.9, 0, gh, -depth - 0.4, 0.6, shade(o.wallC, 0.86), o.wallMat, true)
	end
	-- stall riser + glazing
	L(B, F, u0 + 0.9, u1 - 0.9, 0, base + 1.0, 0, 0.35, rgb(46, 46, 50), Mt.granite, true)
	local doorW = 3.8
	local doorU = if rng:chance(0.5) then u0 + 2.2 else u1 - 2.2 - doorW
	local gl = L(B, F, u0 + 0.9, u1 - 0.9, base + 1.0, glassTop, 0.05, 0.15, rgb(120, 150, 160), Mt.glass, true)
	gl.Transparency = 0.55
	gl.Reflectance = 0.12
	local nm = math.max(2, math.floor((w - 1.8) / 3.2))
	for i = 1, nm - 1 do
		local u = u0 + 0.9 + i * (w - 1.8) / nm
		if math.abs(u - (doorU + doorW / 2)) > doorW / 2 + 0.3 then
			L(B, F, u - 0.1, u + 0.1, base + 1.0, glassTop, 0.15, 0.4, rgb(40, 40, 44), Mt.metal)
		end
	end
	L(B, F, u0 + 0.9, u1 - 0.9, glassTop - 1.6, glassTop - 1.4, 0.15, 0.4, rgb(40, 40, 44), Mt.metal)
	-- door (frame + push bar)
	L(B, F, doorU, doorU + 0.2, base, glassTop - 1.6, 0.15, 0.5, rgb(40, 40, 44), Mt.metal)
	L(B, F, doorU + doorW - 0.2, doorU + doorW, base, glassTop - 1.6, 0.15, 0.5, rgb(40, 40, 44), Mt.metal)
	L(B, F, doorU + 0.3, doorU + doorW - 0.3, base + 3.6, base + 3.8, 0.4, 0.55, rgb(180, 180, 184), Mt.metal)
	-- fascia with the sign
	L(B, F, u0, u1, glassTop, gh, -depth, 0.7, shade(o.wallC, 0.92), o.wallMat)
	local sign = L(B, F, u0 + 1.2, u1 - 1.2, glassTop + 0.5, gh - 0.4, 0.7, 0.95, shop[2], Mt.wood)
	B:label(sign, Enum.NormalId.Front, shop[1], shop[3], Enum.Font.GothamBlack, nil, 16)
	-- neon "OPEN" in the window
	if rng:chance(0.55) then
		local ou = if doorU < u0 + w / 2 then u1 - 3.5 else u0 + 3.5
		local op = L(B, F, ou - 1.1, ou + 1.1, base + 4.2, base + 5.1, -0.1, 0.0, rgb(90, 40, 50), Mt.glass)
		B:label(op, Enum.NormalId.Front, "OPEN", rgb(255, 80, 110), Enum.Font.GothamBlack, nil, 20)
		CityKit.nightPart(refs, op, rgb(90, 40, 50), rgb(255, 60, 100), Mt.glass, 0)
	end
	-- awning
	if rng:chance(o.awning or 0.5) then
		local ac = rng:pick({ rgb(120, 30, 34), rgb(30, 70, 60), rgb(40, 50, 80), rgb(150, 110, 40), rgb(50, 50, 54) })
		local ay = glassTop - 0.1
		local aw = u1 - u0 - 1.6
		B:wedge(V(aw, 1.8, 4.2), F * CF((u0 + u1) / 2, ay - 0.9, -2.1) * ANG(0, math.pi, 0), ac, Mt.fabric)
		L(B, F, u0 + 0.8, u1 - 0.8, ay - 2.6, ay - 1.8, 4.2, 4.35, ac, Mt.fabric)
		L(B, F, u0 + 0.8, u1 - 0.8, ay - 2.1, ay - 1.95, 4.35, 4.4, rgb(230, 226, 214), Mt.fabric)
	end
	return shop
end

-- Simple residential ground floor: plinth, windows, an entrance with steps.
function Buildings.groundResidential(B, F, W: number, gh: number, o, refs)
	local base = CityKit.WALK_Y
	L(B, F, -W / 2, W / 2, 0, base + 1.6, 0, 0.5, shade(o.trimC, 0.8), Mt.granite)
	local n = math.max(2, math.floor(W / 8))
	local bw = W / n
	local doorBay = math.floor(n / 2)
	for b = 0, n - 1 do
		local uc = -W / 2 + (b + 0.5) * bw
		if b == doorBay then
			L(B, F, uc - 2.8, uc + 2.8, gh - 3.6, gh - 2.8, 0, 1.2, o.trimC, o.trimMat)
			L(B, F, uc - 2.2, uc - 1.8, base + 0.4, gh - 3.6, 0, 0.9, o.trimC, o.trimMat)
			L(B, F, uc + 1.8, uc + 2.2, base + 0.4, gh - 3.6, 0, 0.9, o.trimC, o.trimMat)
			L(B, F, uc - 1.8, uc + 1.8, base + 0.4, gh - 3.6, 0.02, 0.2, rgb(50, 36, 30), Mt.wood)
			L(B, F, uc - 0.2, uc + 0.2, base + 3.5, base + 3.7, 0.2, 0.4, rgb(190, 170, 110), Mt.metal)
			L(B, F, uc - 2.4, uc + 2.4, 0, base + 0.4, 0, 1.4, rgb(150, 148, 142), Mt.concrete, true)
		else
			window(B, F, o, uc, base + 3.2, math.min(bw * 0.5, 4.4), gh - 7.5, refs)
		end
	end
end

-- Rooftop clutter on a mass top at height `top` (local frame F, depth D into the building).
function Buildings.roof(B, F, W: number, D: number, top: number, o)
	local rng = B.rng
	L(B, F, -W / 2 + 0.2, W / 2 - 0.2, top, top + 0.1, -D + 0.2, -0.2, rgb(70, 70, 72), Mt.slate)
	if rng:chance(0.45) and W > 20 then
		-- wooden water tank on legs
		local u, dd = rng:float(-W / 2 + 5, W / 2 - 5), -rng:float(8, math.max(9, D - 6))
		local p = F * CF(u, top, -dd)
		for _, a in { -1.6, 1.6 } do
			for _, b in { -1.6, 1.6 } do
				B:deco(V(0.4, 5, 0.4), p * CF(a, 2.5, b), rgb(40, 40, 40), Mt.metal)
			end
		end
		B:deco(V(4.6, 0.3, 4.6), p * CF(0, 5.1, 0), rgb(60, 50, 40), Mt.wood)
		B:post(6, 5.2, (p * CF(0, 5.25, 0)).Position, rgb(120, 90, 62), Mt.planks)
		B:wedge(V(5.2, 1.6, 2.6), p * CF(0, 12.05, -1.3) * ANG(0, 0, 0), rgb(70, 60, 52), Mt.shingles)
		B:wedge(V(5.2, 1.6, 2.6), p * CF(0, 12.05, 1.3) * ANG(0, math.pi, 0), rgb(70, 60, 52), Mt.shingles)
	end
	for _ = 1, rng:int(1, 3) do
		local u, dd = rng:float(-W / 2 + 3, W / 2 - 3), rng:float(4, math.max(5, D - 4))
		local p = F * CF(u, top + 0.1, dd)
		B:deco(V(3, 2.2, 2.4), p * CF(0, 1.1, 0), rgb(186, 186, 182), Mt.metal)
		B:deco(V(1.8, 0.1, 1.8), p * CF(0, 2.25, 0), rgb(60, 60, 60), Mt.diamond)
	end
	if rng:chance(0.5) then
		local u, dd = rng:float(-W / 2 + 4, W / 2 - 4), rng:float(6, math.max(7, D - 6))
		local p = F * CF(u, top, dd)
		B:deco(V(5, 5, 6), p * CF(0, 2.5, 0), shade(o.wallC, 0.85), o.wallMat)
		B:deco(V(5.6, 0.4, 6.6), p * CF(0, 5.2, 0), rgb(60, 60, 62), Mt.metal)
	end
	if rng:chance(0.35) then
		local u = rng:float(-W / 2 + 2, W / 2 - 2)
		B:deco(V(0.2, 8, 0.2), F * CF(u, top + 4, 3), rgb(70, 70, 74), Mt.metal)
		B:deco(V(2.2, 0.1, 0.1), F * CF(u, top + 6.5, 3), rgb(70, 70, 74), Mt.metal)
	end
end

-- Complete generic building. F on the facade plane at street level (LookVector out).
-- o: {W, D, style, floors, floorH, gh (ground floor height), shops (count or 0), detail, lit, side = {F2, W2}}
function Buildings.building(B, F, o, refs)
	local rng = B.rng
	local W, D = o.W, o.D
	o = Buildings.resolve(B, o)
	local gh = o.gh or 14
	local fh = o.floorH or 12
	local top = gh + o.floors * fh
	local shopDepth = if (o.shops or 0) > 0 then 3.6 else 0
	-- mass: ground part set back behind the shop interiors, upper part to the facade plane
	L(B, F, -W / 2, W / 2, 0, gh, -D, -shopDepth, shade(o.wallC, 0.96), o.wallMat, true)
	L(B, F, -W / 2, W / 2, gh, top, -D, 0, o.wallC, o.wallMat, true)
	-- ground floor
	if (o.shops or 0) > 0 then
		local ns = o.shops
		for i = 0, ns - 1 do
			local a = -W / 2 + i * W / ns
			Buildings.shopfront(B, F, a, a + W / ns, gh, o, refs, o.shopIdx and (o.shopIdx + i))
		end
		L(B, F, -W / 2 - 0.1, W / 2 + 0.1, gh - 0.1, gh + 0.7, 0, 0.9, o.trimC, o.trimMat)
	else
		Buildings.groundResidential(B, F, W, gh, o, refs)
		L(B, F, -W / 2 - 0.1, W / 2 + 0.1, gh - 0.4, gh + 0.4, 0, 0.8, o.trimC, o.trimMat)
	end
	-- upper floors
	local fo = table.clone(o)
	fo.y0 = gh
	Buildings.facade(B, F, W, fo, refs)
	-- side facade for corner buildings
	if o.side then
		local so = table.clone(o)
		so.y0 = gh
		so.fire = nil
		so.bays = nil
		Buildings.facade(B, o.side.F, o.side.W, so, refs)
		L(B, o.side.F, -o.side.W / 2, o.side.W / 2, 0, gh, 0, 0.3, shade(o.trimC, 0.8), Mt.granite)
		if o.side.shop then
			Buildings.shopfront(B, o.side.F, o.side.W / 2 - 16, o.side.W / 2 - 1, gh, o, refs)
		end
	end
	if o.detail ~= "simple" then
		Buildings.roof(B, F, W, D, top, o)
	end
	return top
end

return Buildings
