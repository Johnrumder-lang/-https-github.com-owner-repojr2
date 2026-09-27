--!nonstrict
-- PROLOGUE: an ordinary modern city block, in cubes. Apartment, office, streets,
-- the club, and the crosswalk where the truck is waiting.
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

local ASPHALT = rgb(52, 52, 58)
local SIDEWALK = rgb(170, 168, 162)
local CURB = rgb(140, 138, 134)
local LINE = rgb(235, 225, 160)

function Prologue.build(bible, seed: number)
	local rng = RNG.new(seed):fork("prologue")
	local W = S.World
	local map = W.sub("Map")
	local props = W.sub("Props")
	local refs = { windows = {}, streetLights = {} }

	-- ground & roads -------------------------------------------------------
	W.solid(map, V(900, 4, 900), CF(0, -2, 0), SIDEWALK, Enum.Material.Concrete)
	-- main street (east-west) and cross street (north-south at x = 150)
	W.solid(map, V(900, 0.4, 30), CF(0, 0.2, 0), ASPHALT, Enum.Material.Asphalt)
	W.solid(map, V(30, 0.4, 900), CF(150, 0.21, 0), ASPHALT, Enum.Material.Asphalt)
	for x = -440, 440, 18 do
		if math.abs(x - 150) > 22 then
			W.deco(map, V(8, 0.1, 0.6), CF(x, 0.45, 0), LINE)
		end
	end
	for z = -440, 440, 18 do
		if math.abs(z) > 22 then
			W.deco(map, V(0.6, 0.1, 8), CF(150, 0.46, z), LINE)
		end
	end
	-- curbs
	for _, z in { -15.5, 15.5 } do
		W.solid(map, V(900, 0.8, 1), CF(0, 0.4, z), CURB, Enum.Material.Concrete)
	end
	for _, x in { 134.5, 165.5 } do
		W.solid(map, V(1, 0.8, 900), CF(x, 0.41, 0), CURB, Enum.Material.Concrete)
	end
	-- crosswalks
	local function zebra(center: Vector3, alongX: boolean)
		for i = -5, 5 do
			local off = if alongX then V(i * 2.6, 0, 0) else V(0, 0, i * 2.6)
			W.deco(map, if alongX then V(1.4, 0.12, 12) else V(12, 0.12, 1.4), CF(center + off + V(0, 0.46, 0)), rgb(240, 240, 240))
		end
	end
	zebra(V(40, 0, 0), false) -- day crossing to the office (main street)
	refs.dayCrossing = V(40, 0, 0)
	zebra(V(150, 0, 40), true) -- the fateful crossing (cross street)
	refs.crossing = V(150, 0, 40)
	-- traffic lights
	local function trafficLight(p: Vector3, red: boolean)
		W.solid(props, V(0.6, 12, 0.6), CF(p + V(0, 6, 0)), rgb(40, 40, 44), Enum.Material.Metal)
		local box = W.solid(props, V(1.4, 3.6, 1.2), CF(p + V(0, 12.5, 0)), rgb(30, 30, 34))
		W.deco(props, V(0.8, 0.8, 0.2), CF(p + V(0, 13.6, -0.65)), if red then rgb(255, 40, 40) else rgb(60, 20, 20), Enum.Material.Neon)
		W.deco(props, V(0.8, 0.8, 0.2), CF(p + V(0, 11.4, -0.65)), if red then rgb(20, 60, 20) else rgb(60, 255, 90), Enum.Material.Neon)
		return box
	end
	trafficLight(V(33, 0, 18), false)
	trafficLight(V(47, 0, -18), false)
	refs.fatefulLight = trafficLight(V(133, 0, 34), true)
	trafficLight(V(167, 0, 46), true)

	-- building facades ------------------------------------------------------
	local facadeColors = { rgb(170, 150, 130), rgb(130, 120, 110), rgb(190, 180, 160), rgb(110, 110, 120), rgb(150, 90, 80), rgb(90, 100, 110), rgb(200, 196, 186), rgb(120, 130, 100) }
	local function facade(x0: number, x1: number, z0: number, depth: number, height: number, faceSign: number, color: Color3, lit: number)
		local w = x1 - x0
		local cx = (x0 + x1) / 2
		local cz = z0 + depth / 2 * faceSign
		local b = W.solid(props, V(w, height, depth), CF(cx, height / 2, cz), color, Enum.Material.Concrete)
		-- window grid on the street side
		local fz = z0 - 0.05 * faceSign
		for y = 8, height - 4, 7 do
			for x = x0 + 3, x1 - 3, 6 do
				local on = rng:chance(lit)
				local win = W.deco(props, V(3.4, 4, 0.2), CF(x, y, fz), if on then rgb(255, 220, 150) else rgb(60, 80, 100), if on then Enum.Material.Neon else Enum.Material.Glass, { Transparency = if on then 0.2 else 0.1 })
				if on then
					table.insert(refs.windows, win)
				end
			end
		end
		-- rooftop details
		if rng:chance(0.6) then
			W.deco(props, V(math.min(8, w * 0.3), 4, 6), CF(cx + rng:float(-w * 0.3, w * 0.3), height + 2, cz), Palette.shade(color, 0.8))
		end
		W.deco(props, V(w, 1, depth + 0.4), CF(cx, height + 0.5, cz), Palette.shade(color, 0.85))
		return b
	end
	-- fill both sides of both streets, skipping plots used by the story buildings
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
				facade(x, x + w, side * 24, 40, rng:int(30, 110), side, rng:pick(facadeColors), 0.45)
				x += w + 2
			end
		end
	end
	fillStreet(1, { { -92, -30 }, { 128, 172 }, { 190, 262 } })
	fillStreet(-1, { { 4, 76 }, { 128, 172 } })
	-- cross street buildings
	for z = -430, 430, 44 do
		if z < -70 or z > 110 then
			for _, side in { -1, 1 } do
				local x0 = 150 + side * 24
				local h = rng:int(30, 100)
				local b = W.solid(props, V(40, h, 40), CF(x0 + side * 20, h / 2, z), rng:pick(facadeColors), Enum.Material.Concrete)
			end
		end
	end

	-- street furniture -------------------------------------------------------
	for x = -420, 420, 34 do
		for _, side in { -1, 1 } do
			if math.abs(x - 150) > 30 then
				local p = V(x, 0, side * 19)
				W.solid(props, V(0.6, 16, 0.6), CF(p + V(0, 8, 0)), rgb(60, 62, 70), Enum.Material.Metal)
				W.deco(props, V(4, 0.5, 0.8), CF(p + V(0, 16, -side * 1.6)), rgb(60, 62, 70), Enum.Material.Metal)
				local lamp = W.deco(props, V(1.8, 0.4, 1.2), CF(p + V(0, 15.6, -side * 3)), rgb(255, 230, 180), Enum.Material.Neon)
				local l = Kit.spotLight(lamp, rgb(255, 220, 170), 40, 3, 70, Enum.NormalId.Bottom)
				l.Enabled = false
				table.insert(refs.streetLights, l)
			end
		end
	end
	-- parked cars
	local carColors = { rgb(200, 40, 40), rgb(40, 90, 200), rgb(230, 230, 235), rgb(30, 30, 34), rgb(240, 200, 50), rgb(90, 160, 90) }
	local function car(cf: CFrame, color: Color3)
		local m = Kit.model("Car", props)
		W.solid(m, V(5, 2, 10), cf * CF(0, 1.8, 0), color, Enum.Material.SmoothPlastic)
		W.solid(m, V(4.4, 1.8, 5.4), cf * CF(0, 3.6, 0.6), Palette.shade(color, 0.9))
		W.deco(m, V(4.5, 1.4, 0.2), cf * CF(0, 3.6, -2.2), rgb(140, 180, 210), Enum.Material.Glass, { Transparency = 0.3 })
		for _, wx in { -2.4, 2.4 } do
			for _, wz in { -3.2, 3.2 } do
				Kit.cyl(m, 0.9, 2, cf * CF(wx, 1, wz), rgb(20, 20, 20))
			end
		end
		W.deco(m, V(1, 0.5, 0.2), cf * CF(-1.6, 2.1, -5.05), rgb(255, 250, 220), Enum.Material.Neon)
		W.deco(m, V(1, 0.5, 0.2), cf * CF(1.6, 2.1, -5.05), rgb(255, 250, 220), Enum.Material.Neon)
		W.deco(m, V(1, 0.5, 0.2), cf * CF(-1.6, 2.1, 5.05), rgb(200, 20, 20), Enum.Material.Neon)
		W.deco(m, V(1, 0.5, 0.2), cf * CF(1.6, 2.1, 5.05), rgb(200, 20, 20), Enum.Material.Neon)
		return m
	end
	for i = 1, 16 do
		local x = rng:float(-400, 400)
		if math.abs(x - 150) > 40 and math.abs(x - 40) > 20 then
			local side = rng:sign()
			car(CF(x, 0.4, side * 11) * ANG(0, math.pi / 2, 0), rng:pick(carColors))
		end
	end
	-- trees in planters, benches, bins, bus stop
	for x = -400, 400, 55 do
		for _, side in { -1, 1 } do
			if math.abs(x - 150) > 30 and rng:chance(0.7) then
				local p = V(x + 12, 0, side * 20)
				W.solid(props, V(4, 1.4, 4), CF(p + V(0, 0.7, 0)), rgb(120, 116, 110), Enum.Material.Concrete)
				W.tree(props, p + V(0, 1.2, 0), "oak", rng, 0.7, Palette.biomes.Meadow)
			end
		end
	end
	local busStop = V(-120, 0, 19)
	W.solid(props, V(12, 0.4, 4), CF(busStop + V(0, 8, 0)), rgb(60, 60, 70), Enum.Material.Metal)
	W.deco(props, V(12, 7, 0.2), CF(busStop + V(0, 4, 1.8)), rgb(160, 200, 220), Enum.Material.Glass, { Transparency = 0.5 })
	W.solid(props, V(8, 1, 2), CF(busStop + V(0, 1.8, 1)), rgb(80, 60, 50), Enum.Material.WoodPlanks)

	-- APARTMENT (north side, x -90..-32) -------------------------------------
	local ax, az = -61, 24
	local aw, ad, ah = 56, 36, 60
	local apt = Kit.model("Apartment", props)
	local wallC = rgb(196, 170, 140)
	-- exterior shell (hollow ground floor)
	W.solid(apt, V(aw, ah - 16, ad), CF(ax, 16 + (ah - 16) / 2, az + ad / 2), wallC, Enum.Material.Brick)
	W.solid(apt, V(aw, 16, 1), CF(ax, 8, az + ad - 0.5), wallC, Enum.Material.Brick)
	W.solid(apt, V(1, 16, ad), CF(ax - aw / 2 + 0.5, 8, az + ad / 2), wallC, Enum.Material.Brick)
	W.solid(apt, V(1, 16, ad), CF(ax + aw / 2 - 0.5, 8, az + ad / 2), wallC, Enum.Material.Brick)
	-- front wall with door and windows
	W.solid(apt, V(24, 16, 1), CF(ax - 16, 8, az + 0.5), wallC, Enum.Material.Brick)
	W.solid(apt, V(28, 16, 1), CF(ax + 14, 8, az + 0.5), wallC, Enum.Material.Brick)
	W.solid(apt, V(4, 7, 1), CF(ax - 2, 12.5, az + 0.5), wallC, Enum.Material.Brick)
	local aptDoor = W.solid(apt, V(4, 9, 0.5), CF(ax - 2, 4.5, az + 0.5), rgb(90, 50, 40), Enum.Material.WoodPlanks)
	aptDoor.Name = "AptDoor"
	refs.aptDoor = aptDoor
	refs.aptOutside = CF(ax - 2, 3, az - 5)
	for y = 22, ah - 6, 10 do
		for x = ax - aw / 2 + 5, ax + aw / 2 - 5, 8 do
			table.insert(refs.windows, W.deco(apt, V(4, 5, 0.2), CF(x, y, az - 0.05), rgb(255, 220, 150), Enum.Material.Neon, { Transparency = 0.3 }))
		end
	end
	W.solid(apt, V(aw + 2, 1, ad + 2), CF(ax, ah + 0.5, az + ad / 2), Palette.shade(wallC, 0.8))
	-- interior (ground floor apartment)
	local ceil = W.solid(apt, V(aw - 2, 0.6, ad - 2), CF(ax, 15.7, az + ad / 2), rgb(236, 232, 224))
	W.solid(apt, V(aw - 2, 0.3, ad - 2), CF(ax, 0.15, az + ad / 2), rgb(160, 120, 84), Enum.Material.WoodPlanks)
	-- partition walls
	W.solid(apt, V(1, 15, 16), CF(ax - 10, 7.5, az + ad - 9), rgb(230, 225, 215))
	W.solid(apt, V(10, 15, 1), CF(ax - 22, 7.5, az + 16), rgb(230, 225, 215))
	-- bedroom (north-west)
	local bedCF = CF(ax - 20, 0, az + ad - 7)
	W.solid(apt, V(7, 2, 10), bedCF * CF(0, 1.5, 0), rgb(100, 70, 50), Enum.Material.WoodPlanks)
	W.solid(apt, V(6.6, 1, 9.6), bedCF * CF(0, 3, 0), rgb(90, 110, 170), Enum.Material.Fabric)
	W.deco(apt, V(5, 0.8, 2), bedCF * CF(0, 3.8, 3.6), rgb(240, 240, 245), Enum.Material.Fabric)
	W.solid(apt, V(2.5, 3, 2.5), bedCF * CF(5, 1.5, 3.5), rgb(120, 90, 60), Enum.Material.WoodPlanks)
	local lampShade = W.deco(apt, V(1.2, 1.4, 1.2), bedCF * CF(5, 4, 3.5), rgb(255, 220, 160), Enum.Material.Neon)
	Kit.pointLight(lampShade, rgb(255, 210, 150), 14, 1)
	local clock = W.deco(apt, V(1.6, 0.8, 1), bedCF * CF(5, 3.4, 2.6), rgb(20, 20, 24))
	Kit.label(clock, Enum.NormalId.Front, "07:02", rgb(255, 50, 50), Enum.Font.Arcade, nil, 20)
	W.solid(apt, V(6, 12, 3), CF(ax - 26, 6, az + 20), rgb(140, 100, 70), Enum.Material.WoodPlanks)
	refs.bedCF = bedCF * CF(0, 4.2, 0)
	refs.wakeCF = CFrame.lookAt((bedCF * CF(2.5, 3, -6.5)).Position, (bedCF * CF(0, 3, -12)).Position)
	refs.ceilingCam = CFrame.lookAt((bedCF * CF(0, 5, 1)).Position, (bedCF * CF(0, 15, 1.2)).Position)
	-- kitchen (east)
	local kx = ax + 16
	W.solid(apt, V(22, 4, 3), CF(kx, 2, az + ad - 2.5), rgb(230, 230, 232), Enum.Material.Marble)
	W.deco(apt, V(22, 0.3, 3.2), CF(kx, 4.1, az + ad - 2.5), rgb(60, 60, 64), Enum.Material.Granite)
	local fridge = W.solid(apt, V(4, 9, 3.5), CF(kx + 12, 4.5, az + ad - 3), rgb(236, 236, 240), Enum.Material.Metal)
	refs.fridge = fridge
	W.solid(apt, V(4, 4.2, 3), CF(kx - 4, 2.1, az + ad - 2.5), rgb(40, 40, 44), Enum.Material.Metal)
	for i = 0, 1 do
		for j = 0, 1 do
			W.deco(apt, V(1.2, 0.1, 1.2), CF(kx - 4.8 + i * 1.6, 4.3, az + ad - 3.2 + j * 1.4), rgb(20, 20, 20))
		end
	end
	-- dining table with the breakfast plate
	local tp = V(kx - 2, 0, az + 14)
	W.solid(apt, V(8, 0.6, 5), CF(tp + V(0, 3.6, 0)), rgb(150, 110, 70), Enum.Material.WoodPlanks)
	for _, o in { V(-3.5, 0, -2), V(3.5, 0, -2), V(-3.5, 0, 2), V(3.5, 0, 2) } do
		W.solid(apt, V(0.5, 3.3, 0.5), CF(tp + o + V(0, 1.65, 0)), rgb(120, 86, 56))
	end
	W.solid(apt, V(2.6, 2, 2.6), CF(tp + V(0, 1.8, -4)), rgb(120, 86, 56), Enum.Material.WoodPlanks)
	local plate = W.solid(apt, V(1.8, 0.2, 1.8), CF(tp + V(0, 4.0, -1)), rgb(245, 245, 245))
	W.deco(apt, V(1.1, 0.4, 1.1), CF(tp + V(0, 4.3, -1)), rgb(220, 180, 90))
	refs.plate = plate
	refs.dinnerSpot = CF(tp + V(0, 3, -6))
	-- living room: couch + TV
	W.solid(apt, V(12, 2.4, 4), CF(ax - 2, 1.6, az + 8), rgb(70, 90, 110), Enum.Material.Fabric)
	W.solid(apt, V(12, 3, 1.2), CF(ax - 2, 3.2, az + 10), rgb(64, 84, 104), Enum.Material.Fabric)
	W.solid(apt, V(8, 5, 0.6), CF(ax - 2, 5, az + 1.6), rgb(16, 16, 18))
	W.deco(apt, V(10, 0.12, 8), CF(ax - 2, 0.35, az + 6), rgb(170, 60, 60), Enum.Material.Fabric)
	local ceilLamp = W.deco(apt, V(2, 0.4, 2), CF(ax + 10, 15.2, az + 18), rgb(255, 240, 210), Enum.Material.Neon)
	Kit.pointLight(ceilLamp, rgb(255, 230, 200), 40, 1.2, true)
	refs.aptInside = CF(ax - 2, 3, az + 6)
	refs.aptCenter = V(ax, 3, az + 18)

	-- OFFICE (south side, x 6..74) --------------------------------------------
	local ox, oz = 40, -24
	local ow, od, oh = 68, 40, 90
	local off = Kit.model("Office", props)
	local glass = rgb(110, 150, 180)
	W.solid(off, V(ow, oh - 18, od), CF(ox, 18 + (oh - 18) / 2, oz - od / 2), rgb(90, 104, 120), Enum.Material.Glass, { Transparency = 0 })
	for y = 22, oh - 4, 8 do
		W.deco(off, V(ow + 0.4, 0.8, od + 0.4), CF(ox, y, oz - od / 2), rgb(200, 205, 210), Enum.Material.Metal)
	end
	W.solid(off, V(ow, 18, 1), CF(ox, 9, oz - od + 0.5), rgb(200, 205, 210), Enum.Material.Concrete)
	W.solid(off, V(1, 18, od), CF(ox - ow / 2 + 0.5, 9, oz - od / 2), rgb(200, 205, 210), Enum.Material.Concrete)
	W.solid(off, V(1, 18, od), CF(ox + ow / 2 - 0.5, 9, oz - od / 2), rgb(200, 205, 210), Enum.Material.Concrete)
	-- glass front with door gap
	W.solid(off, V(30, 18, 0.6), CF(ox - 19, 9, oz - 0.3), glass, Enum.Material.Glass, { Transparency = 0.45 })
	W.solid(off, V(30, 18, 0.6), CF(ox + 19, 9, oz - 0.3), glass, Enum.Material.Glass, { Transparency = 0.45 })
	W.solid(off, V(8, 8, 0.6), CF(ox, 14, oz - 0.3), glass, Enum.Material.Glass, { Transparency = 0.45 })
	local sign = W.deco(off, V(26, 3, 0.6), CF(ox, 20, oz + 0.2), rgb(30, 30, 40))
	Kit.label(sign, Enum.NormalId.Back, string.upper(bible.company), rgb(120, 200, 255), Enum.Font.Arcade, nil, 14)
	W.solid(off, V(ow - 2, 0.4, od - 2), CF(ox, 0.2, oz - od / 2), rgb(120, 124, 130), Enum.Material.Carpet)
	W.solid(off, V(ow - 2, 0.6, od - 2), CF(ox, 17.7, oz - od / 2), rgb(236, 236, 236))
	for i = 0, 3 do
		local l = W.deco(off, V(10, 0.3, 2), CF(ox - 24 + i * 16, 17.3, oz - od / 2), rgb(240, 250, 255), Enum.Material.Neon)
		Kit.pointLight(l, rgb(230, 245, 255), 30, 0.9)
	end
	-- cubicles: 3 rows x 4 desks
	refs.desks = {}
	refs.coworkerSeats = {}
	for row = 0, 2 do
		for col = 0, 3 do
			local dp = V(ox - 24 + col * 16, 0, oz - 10 - row * 10)
			W.solid(off, V(7, 0.5, 4), CF(dp + V(0, 3.4, 0)), rgb(210, 200, 185), Enum.Material.WoodPlanks)
			W.solid(off, V(0.4, 6, 5), CF(dp + V(-4, 3, 0)), rgb(130, 140, 160), Enum.Material.Fabric)
			W.solid(off, V(8, 6, 0.4), CF(dp + V(0, 3, 2.3)), rgb(130, 140, 160), Enum.Material.Fabric)
			local mon = W.solid(off, V(3, 2.2, 0.3), CF(dp + V(0, 5, 1)), rgb(20, 20, 24))
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
			W.solid(off, V(2.6, 2.2, 2.6), CF(dp + V(0, 1.6, -3)), rgb(40, 40, 50), Enum.Material.Fabric)
			local seat = CFrame.lookAt(dp + V(0, 3, -3), dp + V(0, 3, 2))
			if row == 1 and col == 1 then
				refs.myDesk = mon
				refs.mySeat = seat
				refs.deskCam = CFrame.lookAt(dp + V(0, 5.6, -2.4), dp + V(0, 5, 1))
			else
				table.insert(refs.coworkerSeats, seat)
			end
		end
	end
	-- boss office corner, coffee machine, plants
	W.solid(off, V(1, 17, 14), CF(ox + 20, 8.5, oz - 31), rgb(200, 205, 210), Enum.Material.Glass, { Transparency = 0.5 })
	W.solid(off, V(10, 0.5, 5), CF(ox + 27, 3.4, oz - 32), rgb(90, 60, 40), Enum.Material.WoodPlanks)
	refs.bossSpot = CFrame.lookAt(V(ox + 10, 3, oz - 6), V(ox, 3, oz - 20))
	local coffee = W.solid(off, V(2.4, 4, 2), CF(ox - 30, 2, oz - 4), rgb(40, 40, 44), Enum.Material.Metal)
	refs.coffee = coffee
	for i = 1, 4 do
		local pp = V(ox - 32 + i * 16, 0, oz - 37)
		W.solid(off, V(2, 2, 2), CF(pp + V(0, 1, 0)), rgb(200, 190, 170))
		W.deco(off, V(3, 3, 3), CF(pp + V(0, 3.4, 0)) * ANG(0, i, 0), rgb(60, 140, 70))
	end
	refs.officeDoor = V(ox, 3, oz + 3)
	refs.officeInside = V(ox, 3, oz - 6)

	-- THE CLUB (north side, across the cross street) --------------------------
	local cx, cz = 226, 24
	local club = Kit.model("Club", props)
	W.solid(club, V(70, 40, 44), CF(cx, 20, cz + 22), rgb(24, 22, 30), Enum.Material.Concrete)
	local clubSign = W.deco(club, V(40, 8, 1), CF(cx, 30, cz - 0.6), rgb(20, 10, 30))
	Kit.label(clubSign, Enum.NormalId.Front, bible.club, rgb(255, 60, 200), Enum.Font.Arcade, nil, 12)
	Kit.label(clubSign, Enum.NormalId.Back, bible.club, rgb(255, 60, 200), Enum.Font.Arcade, nil, 12)
	for i, col in { rgb(255, 60, 200), rgb(60, 200, 255), rgb(255, 230, 60) } do
		local strip = W.deco(club, V(70, 0.6, 0.6), CF(cx, 4 + i * 6, cz - 0.4), col, Enum.Material.Neon)
		Kit.pointLight(strip, col, 22, 1.2)
	end
	W.solid(club, V(8, 12, 1), CF(cx, 6, cz - 0.2), rgb(10, 10, 12))
	W.solid(club, V(30, 0.4, 3), CF(cx - 20, 0.6, cz - 4), rgb(150, 20, 30), Enum.Material.Fabric)
	for i = 0, 6 do
		W.solid(club, V(0.3, 3, 0.3), CF(cx - 34 + i * 4, 1.5, cz - 5.5), Palette.metal.gold, Enum.Material.Metal)
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
