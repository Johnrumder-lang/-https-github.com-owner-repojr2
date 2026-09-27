--!nonstrict
-- Title screen (v3): a ruined gothic cathedral nave built client-side behind a
-- blood-red blackletter title, "PRESS ANY KEY", then sharp boxed items on the left
-- (NEW STORY / CONTINUE / SETTINGS / CREDITS) with panels on the right.
-- Also owns the pause menu (M / P): it frees the cursor, sets C.paused and asks the
-- server to pause the world (Net "Menu" "Pause" {on}); the server only pauses solo.
-- Public: Menu.show() Menu.hide() Menu.setInfo(d) Menu.pause(on) Menu.isPaused()
--         Menu.openPanel(name) Menu.reveal()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local C = require(script.Parent.C)
local UI = require(script.Parent.UI)

local Menu: any = {}
local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local V2 = Vector2.new
local V3 = Vector3.new
local COL = UI.COL
local KC = Enum.KeyCode

local gui, root
local pgui, proot
local info = { hasSave = false, started = false }
local state = "splash" -- splash | main
local items = {} -- main menu items {api, fn, name}
local sel = 1
local panels = {}
local openName = nil
local splash, itemsFrame, navHint
local newStory: any = {}
local continueApi
local pause: any = { open = false, items = {}, sel = 1 }
local embers = {}
local diorama: any = nil
local flickers = {}
local menuCC: ColorCorrectionEffect? = nil
local blur: BlurEffect? = nil
local shownOnce = false
local ORIGIN = V3(0, 9000, 0)

-- ================================================================== 3D backdrop
-- A ruined cathedral nave: clustered piers, pointed arcades, clerestory windows,
-- a ribbed vault with a collapsed bay (moon shaft), a rose window over the altar,
-- torn banners, pews, chains, a sword planted in a candle ring and a lone cloaked
-- figure facing the altar. ~1.6k decorative parts, 4 shadowed lights.
local function buildDiorama()
	if diorama then
		diorama:Destroy()
	end
	flickers = {}
	local m = Instance.new("Model")
	m.Name = "MenuDiorama"
	local rng = Random.new(1313)
	local M = Enum.Material
	local function J(c: Color3, a: number?)
		return Palette.jitter(c, a or 0.08, rng:NextNumber())
	end
	local function at(x, y, z)
		return CFrame.new(ORIGIN + V3(x, y, z))
	end
	local function P(size, cf, color, mat, props)
		return Kit.deco(m, size, cf, color, mat or M.Slate, props)
	end
	local STONE = rgb(86, 81, 78)
	local STONE_D = rgb(58, 55, 54)
	local STONE_L = rgb(108, 101, 94)
	local WOOD = rgb(70, 50, 36)
	local IRON = rgb(52, 48, 46)
	local BANNER = rgb(118, 18, 24)
	local GOLD = rgb(170, 140, 80)
	local WAX = rgb(222, 210, 182)
	local FLAME = rgb(255, 176, 90)

	local function candle(x, y, z, h, light)
		h = h or rng:NextNumber(0.8, 2.6)
		P(V3(0.5, h, 0.5), at(x, y + h / 2, z), J(WAX, 0.05), M.Plaster)
		P(V3(0.8, 0.18, 0.8), at(x + rng:NextNumber(-0.1, 0.1), y + 0.09, z), J(WAX, 0.06), M.Plaster)
		local f = P(V3(0.22, 0.5, 0.22), at(x, y + h + 0.3, z), FLAME, M.Neon)
		if light then
			local l = Kit.pointLight(f, rgb(255, 150, 70), light, 1.1, false)
			table.insert(flickers, { l = l, b = 1.1, seed = rng:NextNumber() * 100 })
		end
		return f
	end

	-- floor: dark bed + jittered flagstones (nave) + large slabs (aisles)
	P(V3(140, 1, 280), at(0, -1.5, -50), rgb(28, 26, 26), M.Basalt)
	for ix = -3, 2 do
		for iz = 0, 22 do
			local h = 1 + rng:NextNumber() * 0.2
			local y = rng:NextNumber() * 0.12
			P(V3(7.8, h, 7.8), at(ix * 8 + 4, y - h / 2, 40 - iz * 8 - 4), J(rgb(64, 60, 57), 0.12), M.Slate)
		end
	end
	for _, sx in { -1, 1 } do
		for iz = 0, 14 do
			local h = 1.2
			P(V3(11.7, h, 11.7), at(sx * 32, rng:NextNumber() * 0.1 - h / 2, 40 - iz * 12 - 6), J(rgb(48, 45, 44), 0.12), M.Slate)
		end
	end
	-- torn carpet runner
	local z = 36
	while z > -76 do
		local len = rng:NextNumber(8, 18)
		P(V3(6, 0.2, len), at(0, 0.22, z - len / 2), J(rgb(78, 14, 18), 0.1), M.Fabric)
		P(V3(0.35, 0.22, len), at(-3.2, 0.24, z - len / 2), J(GOLD, 0.1), M.Fabric)
		P(V3(0.35, 0.22, len), at(3.2, 0.24, z - len / 2), J(GOLD, 0.1), M.Fabric)
		z -= len + rng:NextNumber(1, 4)
	end

	-- piers: plinth, base, shaft with four colonnettes, band, capital, abacus
	local PZ = { 22, -2, -26, -50, -74, -98, -122 }
	for _, sx in { -1, 1 } do
		local x = sx * 21
		for i, pz in PZ do
			P(V3(11, 3, 11), at(x, 1.5, pz), J(STONE_D), M.Slate)
			P(V3(9.2, 1.6, 9.2), at(x, 3.8, pz), J(STONE_L), M.Limestone)
			P(V3(7, 62, 7), at(x, 35.6, pz), J(STONE), M.Cobblestone)
			for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
				P(V3(1.8, 62, 1.8), at(x + c[1] * 3.6, 35.6, pz + c[2] * 3.6), J(STONE_L, 0.06), M.Granite)
			end
			P(V3(8.2, 1, 8.2), at(x, 40, pz), J(STONE_L), M.Limestone)
			P(V3(9.6, 2.4, 9.6), at(x, 67.8, pz), J(STONE_L), M.Limestone)
			P(V3(10.8, 1.2, 10.8), at(x, 69.6, pz), J(STONE_D), M.Slate)
			-- candles on the plinth facing the nave
			local cx = x - sx * 4.6
			candle(cx, 3, pz - 1.4, nil, if i % 2 == 1 then 18 else nil)
			candle(cx + sx * 0.2, 3, pz + 0.3)
			candle(cx - sx * 0.3, 3, pz + 1.6, 0.7)
			-- a few broken plinth corners
			if rng:NextNumber() < 0.4 then
				P(V3(2.2, 1.6, 2.2), at(x - sx * 5.8, 0.8, pz + rng:NextNumber(-4, 4)) * CFrame.Angles(0.3, rng:NextNumber() * 3, 0.2), J(STONE_D), M.Slate)
			end
		end
	end

	-- pointed arcades between piers (equilateral arches) + stepped spandrels
	local SPRING = 70.2
	for _, sx in { -1, 1 } do
		local x = sx * 21
		for i = 1, #PZ - 1 do
			local zA, zB = PZ[i] - 3.5, PZ[i + 1] + 3.5 -- zA > zB
			local span = zA - zB
			local segs = 5
			for side = 0, 1 do
				-- left half uses the circle centred on the far springing point
				local cz = if side == 0 then zB else zA
				local a0, a1 = if side == 0 then 0 else math.pi, if side == 0 then math.pi / 3 else math.pi * 2 / 3
				for s = 0, segs - 1 do
					local t0, t1 = a0 + (a1 - a0) * s / segs, a0 + (a1 - a0) * (s + 1) / segs
					local p0 = V3(x, SPRING + math.sin(t0) * span, cz + math.cos(t0) * span)
					local p1 = V3(x, SPRING + math.sin(t1) * span, cz + math.cos(t1) * span)
					local mid = (p0 + p1) / 2
					local len = (p1 - p0).Magnitude + 0.35
					P(V3(2.4, 6, len), CFrame.lookAt(ORIGIN + mid, ORIGIN + p1, V3(1, 0, 0)), J(STONE_L, 0.06), M.Limestone)
					-- spandrel fill up to the triforium
					local top = math.max(p0.Y, p1.Y) + 1.1
					if top < 86 then
						P(V3(5.4, 86 - top, math.abs(p1.Z - p0.Z) + 0.3), at(x, (86 + top) / 2, mid.Z), J(STONE, 0.06), M.Brick)
					end
				end
			end
		end
		-- triforium band with string courses and blind niches, clerestory with windows
		P(V3(5, 10, 172), at(x, 91, -50), J(STONE), M.Brick)
		P(V3(5, 32, 12), at(x, 112.4, -130), J(STONE), M.Cobblestone)
		P(V3(6.2, 0.7, 168), at(x, 86.2, -50), J(STONE_L), M.Limestone)
		P(V3(6.2, 0.7, 168), at(x, 96, -50), J(STONE_L), M.Limestone)
		for nz = 32, -130, -6 do
			P(V3(5.2, 6, 2.2), at(x, 90.6, nz), rgb(30, 28, 30), M.Basalt)
			P(V3(5.3, 1, 3), at(x, 94, nz), J(STONE_L), M.Limestone)
		end
		for i = 1, #PZ do
			local pz = PZ[i]
			P(V3(5, 32, 8), at(x, 112.4, pz), J(STONE), M.Cobblestone)
			if i < #PZ then
				local wz = pz - 12
				P(V3(0.6, 22, 12), at(x, 108.6, wz), rgb(120, 140, 190), M.Neon, { Transparency = 0.45 })
				P(V3(1.4, 22, 0.9), at(x, 108.6, wz), J(STONE_D), M.Slate)
				P(V3(1.4, 0.9, 12), at(x, 104, wz), J(STONE_D), M.Slate)
				for k = 0, 2 do
					local wdt = 12 - k * 4
					P(V3(5, 2, (16 - wdt) / 2 + 0.2), at(x, 120.6 + k * 2, wz + (wdt + (16 - wdt) / 2) / 2), J(STONE), M.Cobblestone)
					P(V3(5, 2, (16 - wdt) / 2 + 0.2), at(x, 120.6 + k * 2, wz - (wdt + (16 - wdt) / 2) / 2), J(STONE), M.Cobblestone)
				end
				P(V3(5, 2, 16), at(x, 126.6, wz), J(STONE), M.Cobblestone)
				P(V3(5, 12, 16), at(x, 101, wz), J(STONE), M.Brick)
			end
		end
		P(V3(6.4, 1, 168), at(x, 128.4, -50), J(STONE_L), M.Limestone)
		-- aisle outer wall (dark) and lean-to aisle roof
		P(V3(4, 70, 170), at(sx * 46, 35, -50), J(rgb(46, 43, 42)), M.Brick)
		P(V3(25, 1.6, 170), at(sx * 34.5, 71.5, -50) * CFrame.Angles(0, 0, sx * 0.12), J(rgb(52, 49, 48)), M.Slate)
		for rz = 22, -122, -24 do
			P(V3(23, 1.4, 1.6), at(sx * 34.5, 69.6, rz) * CFrame.Angles(0, 0, sx * 0.12), J(STONE_L), M.Limestone)
		end
	end

	-- ribbed vault: transverse ribs + webbing, one collapsed bay (moon shaft)
	local RISE, HALF, VBASE = 22, 21, 128.4
	local AZ_VAULT = -134
	local function vy(u)
		return VBASE + RISE * (1 - (math.abs(u) / HALF) ^ 1.45)
	end
	local VS = 8
	for i, pz in PZ do
		for s = 0, VS * 2 - 1 do
			local u0, u1 = -HALF + s * HALF / VS, -HALF + (s + 1) * HALF / VS
			local p0, p1 = V3(u0, vy(u0), pz), V3(u1, vy(u1), pz)
			P(V3(2.2, 2.6, (p1 - p0).Magnitude + 0.3), CFrame.lookAt(ORIGIN + (p0 + p1) / 2, ORIGIN + p1, V3(0, 0, 1)), J(STONE_L, 0.05), M.Limestone)
		end
		if i < #PZ or pz > AZ_VAULT then
			local last = i == #PZ
			local bz = if last then (pz + AZ_VAULT) / 2 else pz - 12
			local blen = if last then pz - AZ_VAULT + 1 else 24
			for s = 0, VS * 2 - 1 do
				local broken = i == 3 and s >= 3 and s <= 6
				if not broken then
					local u0, u1 = -HALF + s * HALF / VS, -HALF + (s + 1) * HALF / VS
					local p0, p1 = V3(u0, vy(u0) + 1.6, bz), V3(u1, vy(u1) + 1.6, bz)
					P(V3(1, blen, (p1 - p0).Magnitude + 0.4), CFrame.lookAt(ORIGIN + (p0 + p1) / 2, ORIGIN + p1, V3(0, 0, 1)), J(rgb(64, 60, 58), 0.1), M.Slate)
				end
			end
		end
	end
	-- ridge rib
	P(V3(2, 2, 150), at(0, VBASE + RISE, -50), J(STONE_L), M.Limestone)
	-- collapsed bay: jagged chunks, moon shaft, cold spotlight, rubble on the floor
	local holeZ = -38
	for _ = 1, 6 do
		P(V3(rng:NextNumber(2, 5), 1, rng:NextNumber(3, 7)), at(rng:NextNumber(-15, -3), 146 + rng:NextNumber(-3, 1), holeZ + rng:NextNumber(-8, 8)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.6, 0.6)), J(rgb(64, 60, 58)), M.Slate)
	end
	local shaftTop = V3(-9, 150, holeZ)
	local shaftBot = V3(-5, 0, holeZ - 10)
	local sh = P(V3(12, (shaftTop - shaftBot).Magnitude, 10), CFrame.lookAt(ORIGIN + (shaftTop + shaftBot) / 2, ORIGIN + shaftBot) * CFrame.Angles(math.pi / 2, 0, 0), rgb(150, 170, 215), M.Neon, { Transparency = 0.93 })
	sh.CastShadow = false
	local sh2 = P(V3(6, (shaftTop - shaftBot).Magnitude, 5), sh.CFrame, rgb(180, 196, 235), M.Neon, { Transparency = 0.9 })
	sh2.CastShadow = false
	local moon = P(V3(1, 1, 1), CFrame.lookAt(ORIGIN + shaftTop, ORIGIN + shaftBot), rgb(0, 0, 0), M.Slate, { Transparency = 1 })
	Kit.spotLight(moon, rgb(150, 170, 215), 170, 2.2, 28, Enum.NormalId.Front)
	for _ = 1, 16 do
		local s = rng:NextNumber(1, 4)
		P(V3(s, s * rng:NextNumber(0.4, 1), s * rng:NextNumber(0.6, 1.4)), at(-5 + rng:NextNumber(-7, 7), s * 0.3, holeZ - 10 + rng:NextNumber(-8, 8)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber() * 3, rng:NextNumber(-0.6, 0.6)), J(rgb(70, 66, 62), 0.12), M.Slate)
	end

	-- apse wall with a rose window
	local AZ = -136
	local RC = V3(0, 86, AZ)
	local R = 20
	P(V3(96, 62, 4), at(0, 31, AZ), J(STONE), M.Brick)
	P(V3(96, 50, 4), at(0, 133, AZ), J(STONE), M.Brick)
	P(V3(26, 46, 4), at(-35, 85, AZ), J(STONE), M.Brick)
	P(V3(26, 46, 4), at(35, 85, AZ), J(STONE), M.Brick)
	-- round the square opening off with stepped corner blocks
	for _, qx in { -1, 1 } do
		for _, qy in { -1, 1 } do
			for k = 0, 5 do
				local a = (k + 0.5) / 6 * math.pi / 2
				local cx, cy = math.cos(a) * R, math.sin(a) * R
				local wx, wy = 22 - cx, 23 - cy
				if wx > 0.3 and wy > 0.3 then
					P(V3(wx + 0.2, math.max(1, wy / 1.5), 4), at(qx * (cx + wx / 2), RC.Y + qy * (cy + wy / 2), AZ), J(STONE), M.Brick)
				end
			end
		end
	end
	local GLASS = { rgb(190, 26, 36), rgb(96, 60, 170), rgb(214, 132, 44), rgb(150, 20, 40) }
	for k = 0, 23 do
		local a0, a1 = k / 24 * math.pi * 2, (k + 1) / 24 * math.pi * 2
		local p0 = RC + V3(math.cos(a0) * R, math.sin(a0) * R, 0)
		local p1 = RC + V3(math.cos(a1) * R, math.sin(a1) * R, 0)
		P(V3(2.6, 5, (p1 - p0).Magnitude + 0.4), CFrame.lookAt(ORIGIN + (p0 + p1) / 2, ORIGIN + p1, V3(0, 0, 1)), J(STONE_L, 0.05), M.Limestone)
	end
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local dir = V3(math.cos(a), math.sin(a), 0)
		P(V3(0.9, 13.5, 1.6), CFrame.lookAt(ORIGIN + RC + dir * 13.5 + V3(0, 0, 0.6), ORIGIN + RC + dir * 13.5 + V3(0, 0, 10), dir), J(STONE_L, 0.05), M.Limestone)
		local mid = (k + 0.5) / 12 * math.pi * 2
		local g = GLASS[k % #GLASS + 1]
		for j, r in { 10.5, 16 } do
			local d = V3(math.cos(mid), math.sin(mid), 0)
			P(V3(if j == 1 then 3.4 else 5.2, if j == 1 then 3.4 else 4.2, 0.4), CFrame.lookAt(ORIGIN + RC + d * r, ORIGIN + RC + d * r + V3(0, 0, 1), d), g, M.Neon, { Transparency = 0.12 })
		end
	end
	P(V3(6, 6, 1.2), at(RC.X, RC.Y, AZ + 0.6) * CFrame.Angles(0, 0, math.pi / 4), J(STONE_L), M.Limestone)
	P(V3(3.6, 3.6, 0.6), at(RC.X, RC.Y, AZ + 1.3) * CFrame.Angles(0, 0, math.pi / 4), rgb(236, 190, 90), M.Neon, { Transparency = 0.1 })
	P(V3(60, 60, 1), at(0, 86, AZ - 3), rgb(60, 10, 20), M.Neon, { Transparency = 0.35 })
	local glowPart = P(V3(1, 1, 1), at(0, 80, AZ + 10), rgb(0, 0, 0), M.Slate, { Transparency = 1 })
	Kit.pointLight(glowPart, rgb(210, 50, 56), 70, 2.4, false)

	-- altar steps, altar, candelabras, statues
	P(V3(44, 1.2, 12), at(0, 0.6, -120), J(STONE_L), M.Marble)
	P(V3(38, 1.2, 10), at(0, 1.8, -123), J(STONE_L), M.Marble)
	P(V3(32, 1.2, 10), at(0, 3, -128), J(STONE_L), M.Marble)
	P(V3(12, 5, 5), at(0, 6.1, -129), J(rgb(120, 112, 104)), M.Marble)
	P(V3(12.4, 0.5, 5.4), at(0, 8.7, -129), J(STONE_L), M.Marble)
	P(V3(3.4, 0.2, 5.8), at(0, 8.95, -129), J(rgb(110, 16, 22)), M.Fabric)
	P(V3(3.4, 4.4, 0.2), at(0, 6.8, -126.25), J(rgb(110, 16, 22)), M.Fabric)
	for k = -2, 2 do
		candle(k * 2.2, 8.95, -130 + math.abs(k) * 0.4, rng:NextNumber(1, 2.8), if k == 0 then 16 else nil)
	end
	for _, sx in { -1, 1 } do
		local x = sx * 11
		P(V3(0.7, 12, 0.7), at(x, 9.6, -125), IRON, M.CorrodedMetal)
		P(V3(3, 0.6, 3), at(x, 3.9, -125), IRON, M.CorrodedMetal)
		P(V3(5.4, 0.45, 0.45), at(x, 15.2, -125), IRON, M.CorrodedMetal)
		for _, o in { -2.4, 0, 2.4 } do
			P(V3(0.9, 0.3, 0.9), at(x + o, 15.6, -125), IRON, M.CorrodedMetal)
			local f = candle(x + o, 15.75, -125, rng:NextNumber(1.2, 2))
			if o == 0 then
				Kit.fire(f, rgb(255, 150, 60), 0.35)
				local l = Kit.pointLight(f, rgb(255, 150, 70), 28, 1.6, true)
				table.insert(flickers, { l = l, b = 1.6, seed = rng:NextNumber() * 100 })
			end
		end
		-- hooded statue with a stone sword
		local sxp = sx * 30
		P(V3(7, 7, 7), at(sxp, 3.5, -131), J(STONE_D), M.Slate)
		P(V3(5, 11, 3.6), at(sxp, 12.5, -131), J(STONE_L, 0.05), M.Limestone)
		P(V3(5.8, 6, 4.2), at(sxp, 10, -131), J(STONE_L, 0.05), M.Limestone)
		P(V3(6, 2, 3.8), at(sxp, 18.4, -131), J(STONE_L, 0.05), M.Limestone)
		P(V3(3, 3, 3), at(sxp, 20.8, -131), J(STONE_L, 0.05), M.Limestone)
		P(V3(3.6, 3.6, 3.4), at(sxp, 21.1, -131.3), J(STONE, 0.05), M.Limestone)
		P(V3(0.6, 11, 0.3), at(sxp, 10.4, -128.9), J(STONE_L), M.Limestone)
		P(V3(3, 0.6, 0.6), at(sxp, 16, -128.9), J(STONE_L), M.Limestone)
		P(V3(1.6, 1.4, 1), at(sxp, 16.8, -128.8), J(STONE_L), M.Limestone)
	end

	-- pews (some toppled / broken)
	for _, sx in { -1, 1 } do
		for row = 0, 9 do
			local pz = 24 - row * 8.5
			local x = sx * 11.5
			local broken = rng:NextNumber()
			local base = at(x, 0, pz)
			if broken < 0.18 then
				base = base * CFrame.new(0, 1, 0) * CFrame.Angles(rng:NextNumber(-1.2, -1.4), rng:NextNumber(-0.3, 0.3), 0)
			elseif broken < 0.3 then
				base = base * CFrame.Angles(0, rng:NextNumber(-0.35, 0.35), 0)
			end
			local lenX = if broken > 0.9 then 5 else 9
			P(V3(lenX, 0.5, 2.2), base * CFrame.new(0, 1.9, 0), J(WOOD, 0.1), M.WoodPlanks)
			P(V3(lenX, 2.6, 0.4), base * CFrame.new(0, 3.2, 1.0), J(WOOD, 0.1), M.WoodPlanks)
			P(V3(lenX + 0.3, 0.3, 0.6), base * CFrame.new(0, 4.6, 1.0), J(rgb(56, 40, 30), 0.1), M.Wood)
			for _, lx in { -lenX / 2 + 0.6, lenX / 2 - 0.6 } do
				P(V3(0.5, 1.7, 2), base * CFrame.new(lx, 0.85, 0), J(WOOD, 0.1), M.Wood)
			end
		end
	end

	-- torn banners on alternate piers
	for _, sx in { -1, 1 } do
		for i = 2, #PZ - 1, 2 do
			local x = sx * (21 - 3.9)
			local pz = PZ[i]
			P(V3(0.4, 0.4, 6.4), at(x - sx * 0.3, 62, pz), IRON, M.CorrodedMetal)
			P(V3(0.25, 20, 5.2), at(x - sx * 0.5, 51.6, pz), J(BANNER, 0.1), M.Fabric)
			P(V3(0.3, 0.8, 5.4), at(x - sx * 0.55, 61.2, pz), J(GOLD, 0.1), M.Fabric)
			P(V3(0.3, 0.5, 5.4), at(x - sx * 0.55, 43.4, pz), J(GOLD, 0.1), M.Fabric)
			P(V3(0.26, 1.6, 1.6), at(x - sx * 0.52, 51.6, pz), J(GOLD, 0.1), M.Fabric)
			for k = -1, 1 do
				local l = rng:NextNumber(2, 7)
				P(V3(0.25, l, 1.6), at(x - sx * 0.5, 41.6 - l / 2, pz + k * 1.8), J(BANNER, 0.12), M.Fabric)
			end
		end
	end

	-- hanging chains with iron cages / braziers
	for _, c in { { -9, -62 }, { 10, -16 } } do
		local top = vy(c[1]) + 1
		local bottom = 48
		local y, k = top, 0
		while y > bottom do
			P(if k % 2 == 0 then V3(0.3, 1.5, 0.9) else V3(0.9, 1.5, 0.3), at(c[1], y, c[2]), IRON, M.Metal)
			y -= 1.25
			k += 1
		end
		P(V3(4, 0.4, 4), at(c[1], bottom - 1, c[2]), IRON, M.CorrodedMetal)
		P(V3(4, 0.4, 4), at(c[1], bottom - 6, c[2]), IRON, M.CorrodedMetal)
		for _, o in { { -1.8, -1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { 1.8, 1.8 }, { 0, -1.8 }, { 0, 1.8 }, { -1.8, 0 }, { 1.8, 0 } } do
			P(V3(0.25, 5, 0.25), at(c[1] + o[1], bottom - 3.5, c[2] + o[2]), IRON, M.Metal)
		end
		local coal = P(V3(2.4, 0.8, 2.4), at(c[1], bottom - 5.4, c[2]), rgb(255, 110, 40), M.Neon)
		Kit.fire(coal, rgb(255, 130, 50), 0.5)
		local l = Kit.pointLight(coal, rgb(255, 130, 60), 30, 1.4, false)
		table.insert(flickers, { l = l, b = 1.4, seed = rng:NextNumber() * 100 })
	end

	-- the sword in the candle ring, on a cracked dais
	local SZ = -86
	P(V3(15, 1, 15), at(0, 0.5, SZ) * CFrame.Angles(0, math.pi / 4, 0), J(STONE_D), M.Slate)
	P(V3(10.5, 0.8, 10.5), at(0, 1.4, SZ), J(STONE_L), M.Granite)
	P(V3(6, 0.5, 6), at(0.4, 2.05, SZ + 0.3) * CFrame.Angles(0, 0.2, 0.03), J(STONE), M.Granite)
	for _ = 1, 5 do
		P(V3(rng:NextNumber(1, 2.4), 0.4, rng:NextNumber(1, 2.4)), at(rng:NextNumber(-6, 6), 0.2, SZ + rng:NextNumber(-7, 7)) * CFrame.Angles(0.2, rng:NextNumber() * 3, 0.15), J(STONE_D), M.Slate)
	end
	local swordCF = at(0.3, 5.1, SZ) * CFrame.Angles(0.06, 0.35, 0.1)
	P(V3(0.95, 10, 0.26), swordCF, rgb(196, 200, 210), M.Metal)
	P(V3(0.22, 8.6, 0.32), swordCF * CFrame.new(0, 0.4, 0), rgb(170, 150, 255), M.Neon, { Transparency = 0.15 })
	P(V3(3.8, 0.5, 0.7), swordCF * CFrame.new(0, 5.2, 0), GOLD, M.Metal)
	P(V3(0.5, 2.3, 0.5), swordCF * CFrame.new(0, 6.6, 0), rgb(46, 30, 24), M.Fabric)
	local pommel = P(V3(0.85, 0.85, 0.85), swordCF * CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, math.pi / 4), GOLD, M.Metal)
	Kit.pointLight(pommel, rgb(170, 150, 255), 24, 1.8, true)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		candle(math.cos(a) * 8.6, 0.1, SZ + math.sin(a) * 8.6, rng:NextNumber(0.7, 2.4), if k % 4 == 0 then 13 else nil)
	end
	local ember = P(V3(8, 1, 8), at(0, 1, SZ), rgb(0, 0, 0), M.Slate, { Transparency = 1 })
	Kit.emitter(ember, {
		Texture = Kit.SQUARE,
		Color = ColorSequence.new(rgb(255, 150, 60), rgb(200, 40, 30)),
		LightEmission = 1,
		Rate = 7,
		Lifetime = NumberRange.new(3, 6),
		Speed = NumberRange.new(1.5, 4),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = V3(0.6, 0.8, 0),
		Size = NumberSequence.new(0.14, 0),
		EmissionDirection = Enum.NormalId.Top,
	})

	-- the lone figure: cloaked, hooded, back to the camera, facing the altar
	local fig = at(0.6, 0, SZ - 11) * CFrame.Angles(0, math.rad(8), 0)
	local CLOAK = rgb(24, 20, 24)
	local function F(size, off, color, mat)
		P(size, fig * CFrame.new(off), color, mat or M.Fabric)
	end
	F(V3(1.1, 1, 1.5), V3(-0.62, 0.5, -0.1), rgb(30, 26, 24), M.Leather)
	F(V3(1.1, 1, 1.5), V3(0.62, 0.5, -0.1), rgb(30, 26, 24), M.Leather)
	F(V3(1.05, 2.4, 1.05), V3(-0.62, 2.2, 0), rgb(34, 32, 36))
	F(V3(1.05, 2.4, 1.05), V3(0.62, 2.2, 0), rgb(34, 32, 36))
	F(V3(3.2, 4.6, 1.9), V3(0, 3.3, 0.25), CLOAK)
	F(V3(3.8, 1.3, 2.3), V3(0, 1.4, 0.3), CLOAK)
	for k = -1, 1 do
		F(V3(0.9, rng:NextNumber(0.6, 1.3), 0.3), V3(k * 1.2, 0.5, 1.35), CLOAK)
	end
	F(V3(2.6, 2.6, 1.3), V3(0, 5.8, 0), rgb(38, 32, 36))
	F(V3(2.95, 3, 1.55), V3(0, 5.8, 0.14), CLOAK)
	F(V3(1.15, 0.8, 1.6), V3(-1.62, 6.9, 0), rgb(70, 64, 60), M.CorrodedMetal)
	F(V3(1.15, 0.8, 1.6), V3(1.62, 6.9, 0), rgb(70, 64, 60), M.CorrodedMetal)
	F(V3(0.95, 2.6, 0.95), V3(-1.78, 5.3, 0), CLOAK)
	F(V3(0.95, 2.6, 0.95), V3(1.78, 5.3, 0), CLOAK)
	F(V3(2.75, 0.4, 1.42), V3(0, 4.55, 0), rgb(112, 18, 26))
	F(V3(0.5, 2.8, 0.2), V3(0.7, 3.3, 0.95), rgb(112, 18, 26))
	F(V3(1.3, 1.3, 1.3), V3(0, 7.9, -0.05), rgb(40, 34, 36))
	F(V3(1.65, 1.75, 1.75), V3(0, 8.0, 0.1), CLOAK)
	F(V3(0.9, 0.5, 0.9), V3(0, 8.95, 0.35), CLOAK)

	-- cobwebs in arch corners
	for k = 1, 8 do
		local sx = if k % 2 == 0 then 1 else -1
		local pz = PZ[(k % (#PZ - 1)) + 1] - 5
		P(V3(0.05, 6, 6), at(sx * 18.4, 64, pz) * CFrame.Angles(math.pi / 4, 0, 0), rgb(170, 170, 176), M.Fabric, { Transparency = 0.72 })
	end

	-- fallen pier section in the right aisle
	P(V3(7, 7, 22), at(31, 3.5, -64) * CFrame.Angles(0.05, 0.5, 0.08), J(STONE), M.Cobblestone)
	P(V3(9, 2.2, 9), at(26, 1, -52) * CFrame.Angles(0.2, 0.3, -0.15), J(STONE_L), M.Limestone)

	-- floor fog + falling ash
	for k = 0, 4 do
		local fp = P(V3(40, 1, 30), at(0, 1.5, 20 - k * 32), rgb(0, 0, 0), M.Slate, { Transparency = 1 })
		Kit.emitter(fp, {
			Texture = Kit.SMOKE,
			Color = ColorSequence.new(rgb(46, 40, 52)),
			LightEmission = 0,
			Rate = 2.5,
			Lifetime = NumberRange.new(9, 14),
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(80, 80),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 20) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(1, 1) }),
			RotSpeed = NumberRange.new(-8, 8),
			Rotation = NumberRange.new(0, 360),
			EmissionDirection = Enum.NormalId.Top,
		})
	end
	local ash = P(V3(60, 1, 180), at(0, 96, -50), rgb(0, 0, 0), M.Slate, { Transparency = 1 })
	Kit.emitter(ash, {
		Texture = Kit.SQUARE,
		Color = ColorSequence.new(rgb(150, 140, 132)),
		LightEmission = 0.1,
		Rate = 30,
		Lifetime = NumberRange.new(14, 20),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = V3(0.4, -0.6, 0.2),
		Size = NumberSequence.new(0.12),
		EmissionDirection = Enum.NormalId.Bottom,
		RotSpeed = NumberRange.new(-60, 60),
	})

	m.Parent = workspace
	diorama = m
	Menu.dioramaParts = #m:GetChildren()
end

-- ================================================================== audio buses
local function applyAudio()
	local master = SoundService:FindFirstChild("Master")
	if not master then
		master = Instance.new("SoundGroup")
		master.Name = "Master"
		master.Volume = 1
		master.Parent = SoundService
	end
	local bus = master:FindFirstChild("MusicBus")
	if not bus then
		bus = Instance.new("SoundGroup")
		bus.Name = "MusicBus"
		bus.Volume = 1
		bus.Parent = master
	end
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx and sfx:IsA("SoundGroup") then
		sfx.Parent = master
	end
	local music = SoundService:FindFirstChild("Music")
	if music and music:IsA("SoundGroup") then
		music.Parent = bus
	end
	master.Volume = math.clamp(tonumber(C.settings.masterVolume) or 1, 0, 1)
	bus.Volume = math.clamp(tonumber(C.settings.musicVolume) or 1, 0, 1)
end

-- ================================================================== settings panel
local SETTINGS = {
	{ "sensitivity", "Mouse sensitivity", 0.2, 3, 0.1, function(v)
		return string.format("%.1f", v)
	end },
	{ "fov", "Field of view", 60, 110, 5, function(v)
		return tostring(math.floor(v + 0.5))
	end },
	{ "shake", "Camera shake", 0, 2, 0.1, function(v)
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end },
	{ "masterVolume", "Master volume", 0, 1, 0.05, function(v)
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end },
	{ "musicVolume", "Music volume", 0, 1, 0.05, function(v)
		return string.format("%d%%", math.floor(v * 100 + 0.5))
	end },
	{ "damageNumbers", "Damage numbers" },
	{ "blood", "Blood" },
	{ "impactFrames", "Impact frames" },
}

local dragging = nil -- {track, set}
local refreshers = {}

local function panelHeader(p, title, sub)
	local _, t = UI.display(p, title, { Name = "Header", Size = UDim2.new(1, -80, 0, 70), Position = UDim2.fromOffset(40, 22), size = 64, from = COL.Bone, to = rgb(170, 158, 138), shadowY = 3 })
	UI.flourish(p, 440, UDim2.fromOffset(40, 98), { side = "left", AnchorPoint = V2(0, 0.5), color = COL.Gold })
	if sub then
		UI.text(p, sub, { Name = "Sub", Size = UDim2.new(1, -80, 0, 44), Position = UDim2.fromOffset(40, 112), font = UI.BODY, size = 16, color = COL.BoneDim, y = Enum.TextYAlignment.Top })
	end
	return t
end

local function buildSettings(parent: Instance, pos: UDim2, anchor: Vector2)
	local p = UI.panel(parent, UDim2.fromOffset(660, 568), pos, { AnchorPoint = anchor, color = COL.Ink, t = 0.12, Name = "Settings", Visible = false })
	panelHeader(p, "SETTINGS")
	local y = 124
	local rows = {}
	for i, def in SETTINGS do
		local key, label = def[1], def[2]
		local row = UI.frame(p, { Name = "Row_" .. key, Size = UDim2.fromOffset(580, 42), Position = UDim2.fromOffset(40, y), color = COL.Ink3, t = if i % 2 == 0 then 0.7 else 1 })
		UI.text(row, string.upper(label), { Name = "Label", Size = UDim2.fromOffset(250, 44), Position = UDim2.fromOffset(12, 0), font = UI.BOLD, size = 15, color = COL.Bone })
		if def[3] then
			local lo, hi, step, fmt = def[3], def[4], def[5], def[6]
			local value = UI.text(row, "", { Name = "Value", Size = UDim2.fromOffset(64, 44), Position = UDim2.fromOffset(570, 0), AnchorPoint = V2(1, 0), font = UI.BLACK, size = 15, color = COL.GoldBright, x = Enum.TextXAlignment.Right })
			local track = UI.frame(row, { Name = "Track", Size = UDim2.fromOffset(180, 4), Position = UDim2.fromOffset(300, 20), color = COL.Ink3, t = 0 })
			UI.stroke(track, COL.Gold, 1, 0.55)
			local fill = UI.frame(track, { Name = "Fill", Size = UDim2.fromScale(0.5, 1), color = COL.Blood, t = 0 })
			local knob = UI.diamond(track, 10, UDim2.fromScale(0.5, 0.5), { color = COL.GoldBright, stroke = COL.Ink, strokeT = 0.2, Name = "Knob" })
			local function refresh()
				local v = tonumber(C.settings[key]) or lo
				local f = math.clamp((v - lo) / (hi - lo), 0, 1)
				fill.Size = UDim2.fromScale(f, 1)
				knob.Position = UDim2.fromScale(f, 0.5)
				value.Text = fmt(v)
			end
			local function set(v)
				v = math.clamp(math.floor(v / step + 0.5) * step, lo, hi)
				C.setSetting(key, v)
				refresh()
			end
			UI.button(row, "<", UDim2.fromOffset(28, 28), UDim2.fromOffset(262, 8), function()
				set((tonumber(C.settings[key]) or lo) - step)
			end, { Name = "Dec_" .. key, textSize = 14 })
			UI.button(row, ">", UDim2.fromOffset(28, 28), UDim2.fromOffset(490, 8), function()
				set((tonumber(C.settings[key]) or lo) + step)
			end, { Name = "Inc_" .. key, textSize = 14 })
			local hit = UI.new("TextButton", { Parent = row, Name = "Hit_" .. key, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(196, 30), Position = UDim2.fromOffset(292, 7), AutoButtonColor = false })
			local function fromMouse(x)
				local ap, as = track.AbsolutePosition, track.AbsoluteSize
				if as.X > 1 then
					set(lo + math.clamp((x - ap.X) / as.X, 0, 1) * (hi - lo))
				end
			end
			hit.MouseButton1Down:Connect(function(x)
				dragging = { fn = fromMouse }
				if type(x) == "number" then
					fromMouse(x)
				end
			end)
			refresh()
			table.insert(refreshers, refresh)
			rows[key] = { set = set, refresh = refresh }
		else
			local pill = UI.frame(row, { Name = "Pill", Size = UDim2.fromOffset(200, 28), Position = UDim2.fromOffset(300, 8), color = COL.Ink, t = 0.2 })
			UI.stroke(pill, COL.Gold, 1, 0.55)
			local offB = UI.new("TextButton", { Parent = pill, Name = "Off_" .. key, Text = "OFF", Size = UDim2.fromScale(0.5, 1), BorderSizePixel = 0, AutoButtonColor = false, Font = UI.BOLD, TextSize = 13, BackgroundColor3 = COL.Ink3, BackgroundTransparency = 1, TextColor3 = COL.Bone })
			local onB = UI.new("TextButton", { Parent = pill, Name = "On_" .. key, Text = "ON", Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), BorderSizePixel = 0, AutoButtonColor = false, Font = UI.BOLD, TextSize = 13, BackgroundColor3 = COL.Blood, BackgroundTransparency = 1, TextColor3 = COL.Bone })
			local function refresh()
				local on = C.settings[key] ~= false
				onB.BackgroundTransparency = if on then 0.1 else 1
				onB.BackgroundColor3 = COL.Blood
				offB.BackgroundTransparency = if on then 1 else 0.1
				offB.BackgroundColor3 = COL.Ink3
				onB.TextColor3 = if on then COL.Bone else COL.BoneFaint
				offB.TextColor3 = if on then COL.BoneFaint else COL.Bone
			end
			onB.MouseButton1Click:Connect(function()
				UI.onClick()
				C.setSetting(key, true)
				refresh()
			end)
			offB.MouseButton1Click:Connect(function()
				UI.onClick()
				C.setSetting(key, false)
				refresh()
			end)
			refresh()
			table.insert(refreshers, refresh)
			rows[key] = { refresh = refresh }
		end
		y += 46
	end
	UI.button(p, "BACK", UDim2.fromOffset(120, 34), UDim2.new(0, 40, 1, -52), function()
		Menu.openPanel(nil)
	end, { kind = "ghost", Name = "SettingsBack", textSize = 15 })
	UI.text(p, "Changes apply instantly.", { Name = "Note", Size = UDim2.fromOffset(300, 34), Position = UDim2.new(1, -40, 1, -52), AnchorPoint = V2(1, 0), font = UI.BODY, size = 13, color = COL.BoneFaint, x = Enum.TextXAlignment.Right })
	return p, rows
end

local function refreshSettings()
	for _, r in refreshers do
		r()
	end
end

-- ================================================================== panels
local function buildNewStory(parent)
	local p = UI.panel(parent, UDim2.fromOffset(660, 540), UDim2.new(1, -110, 0.5, 104), { AnchorPoint = V2(1, 0.5), color = COL.Ink, t = 0.12, Name = "NewStory", Visible = false })
	panelHeader(p, "NEW STORY", "Every seed is a different world: new lands, names, bosses and fate. Leave it empty and let the dice decide.")
	UI.text(p, "SEED", { Name = "SeedLabel", Size = UDim2.fromOffset(200, 16), Position = UDim2.fromOffset(40, 180), font = UI.BOLD, size = 13, color = COL.Gold })
	local box = UI.new("TextBox", {
		Parent = p,
		Name = "Seed",
		Position = UDim2.fromOffset(40, 200),
		Size = UDim2.fromOffset(440, 48),
		BackgroundColor3 = COL.Ink,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		TextColor3 = COL.Bone,
		PlaceholderText = "random",
		PlaceholderColor3 = COL.BoneFaint,
		Font = UI.BODY,
		TextSize = 22,
		Text = "",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UI.pad(box, 16, 16, 0, 0)
	UI.stroke(box, COL.Gold, 1, 0.4)
	newStory.box = box
	UI.button(p, "DICE", UDim2.fromOffset(120, 48), UDim2.fromOffset(496, 200), function()
		box.Text = tostring(math.random(1000, 999999))
	end, { Name = "Dice", textSize = 15 })
	-- skip prologue toggle
	local skip = false
	local row = UI.frame(p, { Name = "SkipRow", Size = UDim2.fromOffset(576, 58), Position = UDim2.fromOffset(40, 268), color = COL.Ink3, t = 0.6 })
	UI.text(row, "SKIP PROLOGUE", { Name = "Label", Size = UDim2.fromOffset(360, 24), Position = UDim2.fromOffset(14, 6), font = UI.BOLD, size = 15, color = COL.Bone })
	UI.text(row, "Start in the other world - skips the modern-day intro.", { Name = "Desc", Size = UDim2.fromOffset(400, 20), Position = UDim2.fromOffset(14, 30), font = UI.BODY, size = 13, color = COL.BoneFaint })
	local skipB, _, skipApi
	skipB, _, skipApi = UI.button(row, "OFF", UDim2.fromOffset(96, 34), UDim2.fromOffset(466, 12), function()
		skip = not skip
		skipB.Text = if skip then "ON" else "OFF"
		skipApi.set(skip)
	end, { Name = "SkipToggle", textSize = 15 })
	newStory.skip = function()
		return skip
	end
	-- begin
	local beginB, _, beginApi = UI.button(p, "BEGIN", UDim2.fromOffset(576, 70), UDim2.fromOffset(40, 356), function()
		Menu.begin()
	end, { kind = "primary", font = UI.GOTHIC, textSize = 46, Name = "BEGIN" })
	newStory.beginApi = beginApi
	newStory.beginB = beginB
	UI.keyRow(p, { { "Enter", "Begin" }, { "Backspace", "Back" } }, { h = 20, size = 11, gap = 18, Name = "Keys", Position = UDim2.fromOffset(40, 446) })
	newStory.status = UI.text(p, "", { Name = "Status", Size = UDim2.fromOffset(576, 40), Position = UDim2.fromOffset(40, 470), font = UI.SERIF, size = 18, color = COL.GoldBright, y = Enum.TextYAlignment.Top })
	UI.button(p, "BACK", UDim2.fromOffset(100, 30), UDim2.new(1, -40, 0, 442), function()
		Menu.openPanel(nil)
	end, { kind = "ghost", AnchorPoint = V2(1, 0), Name = "NewStoryBack", textSize = 15 })
	box.FocusLost:Connect(function(enter)
		if enter and openName == "new" then
			Menu.begin()
		end
	end)
	return p
end

local function buildCredits(parent)
	local p = UI.panel(parent, UDim2.fromOffset(660, 520), UDim2.new(1, -110, 0.5, 104), { AnchorPoint = V2(1, 0.5), color = COL.Ink, t = 0.12, Name = "Credits", Visible = false })
	panelHeader(p, "CREDITS")
	local y = 130
	for _, block in {
		{ "STORY & DIRECTION", "John" },
		{ "BUILT FROM CODE", "Every block, rig, weapon and world is generated by a Python place pipeline and a great deal of Luau." },
		{ "SPECIAL THANKS", "The truck.  The cat who learned to open doors.  You." },
	} do
		UI.text(p, block[1], { Size = UDim2.fromOffset(580, 18), Position = UDim2.fromOffset(40, y), font = UI.BOLD, size = 13, color = COL.Gold })
		UI.text(p, block[2], { Size = UDim2.fromOffset(580, 56), Position = UDim2.fromOffset(40, y + 20), font = UI.SERIF, size = 21, color = COL.Bone, y = Enum.TextYAlignment.Top })
		y += 92
	end
	UI.flourish(p, 380, UDim2.new(0.5, 0, 0, y + 8), { color = COL.Gold, t = 0.3 })
	UI.text(p, "Don't cross the street on a Monday.", { Size = UDim2.fromOffset(580, 26), Position = UDim2.fromOffset(40, y + 24), font = UI.SERIF, size = 19, color = COL.BoneDim, x = Enum.TextXAlignment.Center })
	UI.button(p, "BACK", UDim2.fromOffset(100, 30), UDim2.new(0, 40, 1, -48), function()
		Menu.openPanel(nil)
	end, { kind = "ghost", Name = "CreditsBack", textSize = 15 })
	return p
end

function Menu.openPanel(name: string?)
	openName = name
	for k, it in items do
		if name and it.name == name then
			sel = k
		end
	end
	if name == "settings" then
		refreshSettings()
	end
	for n, p in panels do
		p.Visible = n == name
	end
	for i, it in items do
		it.api.set(i == sel or it.name == name)
	end
end

-- ================================================================== main menu
local function setSel(i: number)
	if #items == 0 then
		return
	end
	sel = ((i - 1) % #items) + 1
	for k, it in items do
		it.api.set(k == sel or it.name == openName)
	end
	UI.onHover()
end

function Menu.reveal()
	if state == "main" then
		return
	end
	state = "main"
	splash.Visible = false
	UI.fadeIn(itemsFrame, 0.35)
	UI.fadeIn(navHint, 0.6)
	for i, it in items do
		local b = it.api.button
		b.Position = UDim2.fromOffset(-40, (i - 1) * 58)
		UI.tween(b, 0.25 + i * 0.06, { Position = UDim2.fromOffset(0, (i - 1) * 58) }, Enum.EasingStyle.Quint)
	end
	setSel(1)
end

function Menu.begin()
	if newStory.pending then
		return
	end
	newStory.pending = true
	newStory.status.Text = "Summoning your story..."
	newStory.beginApi.enable(false)
	Net.send("Menu", "Start", { mode = "new", seed = newStory.box.Text, skipPrologue = newStory.skip() })
	task.delay(8, function()
		if C.menuOpen and newStory.pending then
			newStory.pending = false
			newStory.beginApi.enable(true)
			newStory.status.Text = "No answer yet. If someone else is hosting, they have to begin the story - otherwise press BEGIN again."
		end
	end)
end

local function activate(i: number)
	local it = items[i]
	if it and it.api.enabled then
		UI.onClick()
		it.fn()
	end
end

function Menu.build()
	gui, root = UI.layer("Menu", 50)
	-- embers (pooled, animated per frame while the menu is visible)
	local emberLayer = UI.frame(root, { Name = "Embers" })
	local erng = Random.new(99)
	for i = 1, 34 do
		local s = erng:NextInteger(2, 5)
		local f = UI.frame(emberLayer, { Name = "E", Size = UDim2.fromOffset(s, s), color = if i % 3 == 0 then COL.GoldBright else COL.BloodBright, t = 0.3, Rotation = 45 })
		table.insert(embers, { f = f, x = erng:NextNumber(), y = erng:NextNumber(), v = erng:NextNumber(18, 55), drift = erng:NextNumber(-12, 12), ph = erng:NextNumber() * 6 })
	end
	-- legibility gradients
	local left = UI.frame(root, { Name = "ShadeLeft", Size = UDim2.fromScale(0.62, 1), color = COL.Ink, t = 0.05 })
	UI.gradient(left, nil, { { 0, 0.05 }, { 0.55, 0.45 }, { 1, 1 } }, 0)
	local top = UI.frame(root, { Name = "ShadeTop", Size = UDim2.new(1, 0, 0, 220), color = COL.Ink, t = 0.2 })
	UI.gradient(top, nil, { { 0, 0 }, { 1, 1 } }, 90)
	local bottom = UI.frame(root, { Name = "ShadeBottom", Size = UDim2.new(1, 0, 0, 260), Position = UDim2.fromScale(0, 1), AnchorPoint = V2(0, 1), color = COL.Ink, t = 0.1 })
	UI.gradient(bottom, nil, { { 0, 1 }, { 1, 0 } }, 90)
	local red = UI.frame(root, { Name = "RedGlow", Size = UDim2.new(0.5, 0, 0, 300), Position = UDim2.fromScale(0, 1), AnchorPoint = V2(0, 1), color = COL.Blood, t = 0.7 })
	UI.gradient(red, nil, { { 0, 0.6 }, { 0.6, 0.9 }, { 1, 1 } }, -60)
	-- title block
	local tb = UI.frame(root, { Name = "Title", Size = UDim2.fromOffset(1300, 360), Position = UDim2.fromOffset(104, 92) })
	UI.text(tb, "THE", { Name = "The", Size = UDim2.fromOffset(160, 64), Position = UDim2.fromOffset(10, 0), font = UI.GOTHIC, size = 60, color = COL.BoneDim, strokeT = 0.5, wrap = false })
	UI.hline(tb, { Size = UDim2.fromOffset(430, 1), Position = UDim2.fromOffset(140, 38), color = COL.Gold, fade = "right", t = 0.2 })
	UI.diamond(tb, 6, UDim2.fromOffset(134, 38), { color = COL.GoldBright })
	UI.display(tb, "RANDOM STORY", {
		Name = "Main",
		Size = UDim2.fromOffset(1300, 190),
		Position = UDim2.fromOffset(0, 40),
		size = 176,
		wrap = false,
		from = rgb(246, 84, 72),
		mid = COL.Blood,
		to = rgb(52, 4, 10),
		midAt = 0.5,
		outline = rgb(16, 2, 4),
		outlineSize = 2,
		shadowX = 5,
		shadowY = 8,
		shadowT = 0.25,
	})
	UI.flourish(tb, 820, UDim2.fromOffset(10, 244), { side = "left", AnchorPoint = V2(0, 0.5), color = COL.Gold })
	UI.text(tb, "a reincarnation you didn't deserve", { Name = "Subtitle", Size = UDim2.fromOffset(900, 40), Position = UDim2.fromOffset(12, 262), font = UI.SERIF, size = 30, color = COL.BoneDim, strokeT = 0.6 })

	-- press any key
	splash = UI.frame(root, { Name = "Splash", Size = UDim2.fromOffset(600, 90), Position = UDim2.fromOffset(110, 560) })
	UI.diamond(splash, 8, UDim2.fromOffset(6, 20), { color = COL.BloodBright })
	local pressLabel = UI.text(splash, "PRESS ANY KEY", { Name = "Press", Size = UDim2.fromOffset(500, 40), Position = UDim2.fromOffset(24, 0), font = UI.BLACK, size = 26, color = COL.Bone, strokeT = 0.5 })
	UI.text(splash, "or click - your story is waiting", { Name = "Hint", Size = UDim2.fromOffset(500, 26), Position = UDim2.fromOffset(24, 40), font = UI.SERIF, size = 20, color = COL.BoneFaint })
	Menu.pressLabel = pressLabel

	-- items
	itemsFrame = UI.frame(root, { Name = "Items", Size = UDim2.fromOffset(380, 300), Position = UDim2.fromOffset(110, 540), Visible = false })
	local function item(name, text, fn, hint)
		local idx = #items + 1
		local b, _, api = UI.button(itemsFrame, text, UDim2.fromOffset(380, 48), UDim2.fromOffset(0, (idx - 1) * 58), nil, {
			kind = "menu",
			hint = hint,
			onHover = function()
				sel = idx
				for k, it in items do
					it.api.set(k == sel or it.name == openName)
				end
			end,
		})
		b.MouseButton1Click:Connect(function()
			sel = idx
			if api.enabled then
				fn()
			end
		end)
		table.insert(items, { api = api, fn = fn, name = name })
		return api, b
	end
	item("new", "NEW STORY", function()
		Menu.openPanel("new")
	end, "ENTER")
	continueApi = item("continue", "CONTINUE", function()
		if info.started then
			Menu.hide()
		elseif info.hasSave then
			Net.send("Menu", "Start", { mode = "continue" })
		end
	end)
	item("arena", "PVP ARENA", function()
		if info.started then
			Menu.hide()
			return
		end
		Net.send("Menu", "Arena", {})
	end, "FIGHT")
	item("settings", "SETTINGS", function()
		Menu.openPanel("settings")
	end)
	item("credits", "CREDITS", function()
		Menu.openPanel("credits")
	end)
	navHint = UI.keyRow(root, { { { "W", "S" }, "Select" }, { "Enter", "Confirm" } }, { h = 20, size = 11, gap = 18, Name = "NavHint", Position = UDim2.fromOffset(110, 850) })
	navHint.Visible = false

	-- bottom: controls + version
	UI.hline(root, { Size = UDim2.new(1, -220, 0, 1), Position = UDim2.new(0, 110, 1, -84), color = COL.Gold, fade = "right", t = 0.55 })
	UI.keyRow(root, {
		{ { "W", "A", "S", "D" }, "Move" },
		{ "Space", "Jump" },
		{ "Shift", "Dash" },
		{ "LMB", "Attack" },
		{ "RMB", "Parry" },
		{ "Q", "Stop time" },
		{ "I", "Inventory" },
		{ "M", "Pause" },
		{ "Alt", "Free cursor" },
	}, { h = 20, size = 11, gap = 18, Name = "Controls", Position = UDim2.new(0, 110, 1, -58), color = COL.BoneFaint })
	UI.text(root, string.upper(Config.VERSION or "v3") .. "  ·  EVERY SEED IS A NEW WORLD", { Name = "Version", Size = UDim2.fromOffset(500, 20), Position = UDim2.new(1, -60, 1, -48), AnchorPoint = V2(1, 0.5), font = UI.BOLD, size = 11, color = COL.BoneFaint, x = Enum.TextXAlignment.Right })

	panels.new = buildNewStory(root)
	panels.settings = buildSettings(root, UDim2.new(1, -110, 0.5, 104), V2(1, 0.5))
	panels.credits = buildCredits(root)
	Menu.setInfo(info)

	-- ------------------------------------------------ pause menu
	pgui, proot = UI.layer("Pause", 60)
	pgui.Enabled = false
	local dim = UI.frame(proot, { Name = "Dim", color = COL.Ink, t = 0.3 })
	UI.gradient(dim, nil, { { 0, 0 }, { 0.6, 0.35 }, { 1, 0.6 } }, 0)
	local ptb = UI.frame(proot, { Name = "Title", Size = UDim2.fromOffset(900, 220), Position = UDim2.fromOffset(104, 150) })
	UI.display(ptb, "PAUSED", { Name = "Main", Size = UDim2.fromOffset(900, 140), size = 130, wrap = false, from = COL.Bone, mid = rgb(200, 186, 160), to = rgb(120, 104, 86), shadowY = 6 })
	UI.flourish(ptb, 620, UDim2.fromOffset(10, 150), { side = "left", AnchorPoint = V2(0, 0.5), color = COL.Gold })
	pause.sub = UI.text(ptb, "", { Name = "Sub", Size = UDim2.fromOffset(900, 34), Position = UDim2.fromOffset(12, 168), font = UI.SERIF, size = 26, color = COL.BoneDim })
	local pitems = UI.frame(proot, { Name = "Items", Size = UDim2.fromOffset(380, 200), Position = UDim2.fromOffset(110, 430) })
	local function pitem(name, text, fn)
		local idx = #pause.items + 1
		local b, _, api = UI.button(pitems, text, UDim2.fromOffset(380, 48), UDim2.fromOffset(0, (idx - 1) * 58), nil, {
			kind = "menu",
			Name = "Pause_" .. name,
			onHover = function()
				pause.sel = idx
				for k, it in pause.items do
					it.api.set(k == idx or it.name == pause.panel)
				end
			end,
		})
		b.MouseButton1Click:Connect(fn)
		table.insert(pause.items, { api = api, fn = fn, name = name })
	end
	pitem("resume", "RESUME", function()
		Menu.pause(false)
	end)
	pitem("settings", "SETTINGS", function()
		Menu.pausePanel(if pause.panel == "settings" then nil else "settings")
	end)
	pitem("controls", "CONTROLS", function()
		Menu.pausePanel(if pause.panel == "controls" then nil else "controls")
	end)
	pause.seed = UI.text(proot, "", { Name = "Seed", Size = UDim2.fromOffset(800, 20), Position = UDim2.new(0, 110, 1, -60), font = UI.BOLD, size = 12, color = COL.BoneFaint })
	UI.keyRow(proot, { { { "M", "P" }, "Resume" }, { { "W", "S" }, "Select" }, { "Enter", "Confirm" } }, { h = 20, size = 11, gap = 18, Name = "Keys", Position = UDim2.fromOffset(110, 610) })
	local ps = buildSettings(proot, UDim2.new(1, -110, 0.5, 20), V2(1, 0.5))
	ps.Name = "PauseSettings"
	local back = ps:FindFirstChild("SettingsBack")
	if back then
		back.Name = "PauseSettingsBack"
		back.MouseButton1Click:Connect(function()
			Menu.pausePanel(nil)
		end)
	end
	pause.settings = ps
	-- controls panel
	local pc = UI.panel(proot, UDim2.fromOffset(660, 620), UDim2.new(1, -110, 0.5, 20), { AnchorPoint = V2(1, 0.5), color = COL.Ink, t = 0.18, Name = "PauseControls", Visible = false })
	panelHeader(pc, "CONTROLS")
	local CONTROLS = {
		{ { "W", "A", "S", "D" }, "Move" },
		{ "Space", "Jump  ·  twice to double jump" },
		{ "Shift", "Dash (brief invulnerability)" },
		{ { "Ctrl", "C" }, "Slide" },
		{ "LMB", "Attack  ·  hold for a heavy swing" },
		{ "RMB", "Parry / block" },
		{ "Q", "Stop time" },
		{ "R", "Drink a flask" },
		{ { "F", "G" }, "Aether step  ·  Void slash" },
		{ "E", "Interact / talk" },
		{ { "I", "Tab" }, "Inventory & level-up points" },
		{ { "M", "P" }, "Pause" },
		{ "Alt", "Free / lock the cursor" },
	}
	for i, c in CONTROLS do
		UI.keyRow(pc, { c }, { h = 22, size = 12, gap = 10, Name = "C" .. i, Position = UDim2.fromOffset(44, 118 + (i - 1) * 36), color = COL.Bone })
	end
	pause.controls = pc
end

function Menu.pausePanel(name: string?)
	pause.panel = name
	for k, it in pause.items do
		if name and it.name == name then
			pause.sel = k
		end
	end
	pause.settings.Visible = false
	pause.controls.Visible = false
	if name == "settings" then
		refreshSettings()
		pause.settings.Visible = true
	elseif name == "controls" then
		pause.controls.Visible = true
	end
	for k, it in pause.items do
		it.api.set(k == pause.sel or it.name == name)
	end
end

function Menu.isPaused(): boolean
	return pause.open == true
end

function Menu.pause(on: boolean)
	if C.menuOpen then
		on = false
	end
	if on == pause.open then
		return
	end
	pause.open = on
	C.paused = on
	C.cursor.pause = if on then true else nil
	pgui.Enabled = on
	if on then
		if C.Inventory and type(C.Inventory.toggle) == "function" and C.Inventory.isOpen and C.Inventory.isOpen() then
			C.Inventory.toggle(false)
		end
		local solo = #Players:GetPlayers() <= 1
		pause.sub.Text = if solo then "The world holds its breath." else "Other souls walk this world - time does not stop for them."
		pause.seed.Text = string.format("SEED  %s     ·     %s", tostring(C.seed or "?"), string.upper(Config.VERSION or "v3"))
		pause.sel = 1
		Menu.pausePanel(nil)
		if blur then
			blur.Enabled = true
			blur.Size = 0
			UI.tween(blur, 0.25, { Size = 14 })
		end
	else
		Menu.pausePanel(nil)
		if blur then
			blur.Enabled = false
		end
	end
	Net.send("Menu", "Pause", { on = on })
end

-- ================================================================== show / hide
function Menu.show()
	C.menuOpen = true
	gui.Enabled = true
	UI.setAlpha(root, 1)
	buildDiorama()
	if C.Mood and C.Mood.apply then
		C.Mood.apply("menu", 0.2)
	end
	if menuCC then
		menuCC.Enabled = true
	end
	if C.Audio and C.Audio.music then
		C.Audio.music("Menu")
	end
	if shownOnce then
		state = "splash"
		Menu.reveal()
	else
		shownOnce = true
		state = "splash"
		splash.Visible = true
		itemsFrame.Visible = false
		navHint.Visible = false
	end
	Menu.openPanel(nil)
end

function Menu.hide()
	C.menuOpen = false
	newStory.pending = false
	if newStory.beginApi then
		newStory.beginApi.enable(true)
		newStory.status.Text = ""
	end
	if menuCC then
		menuCC.Enabled = false
	end
	UI.fadeTo(root, 0, 0.6, function()
		if not C.menuOpen then
			gui.Enabled = false
		end
	end)
	if diorama then
		diorama:Destroy()
		diorama = nil
	end
	flickers = {}
	if C.HUD and C.HUD.show then
		C.HUD.show(true)
	end
end

function Menu.setInfo(d)
	d = d or {}
	info.hasSave = d.hasSave == true
	info.started = d.started == true
	if continueApi then
		local b = continueApi.button
		continueApi.text(if info.started then "JOIN STORY" else "CONTINUE")
		continueApi.enable(info.started or info.hasSave)
		local hint = b:FindFirstChild("Hint")
		if not hint then
			hint = UI.text(b, "", { Name = "Hint", Size = UDim2.new(0, 160, 1, 0), Position = UDim2.new(1, -16, 0, 0), AnchorPoint = V2(1, 0), font = UI.BOLD, size = 12, color = COL.BoneFaint, x = Enum.TextXAlignment.Right, ZIndex = 3 })
		end
		hint.Text = if info.started or info.hasSave then "" else "NO SAVE"
	end
end

-- ================================================================== per frame
RunService.RenderStepped:Connect(function(dt)
	if not C.menuOpen or not gui or not gui.Enabled then
		return
	end
	local t = os.clock()
	local cam = workspace.CurrentCamera
	if cam and not C.inCutscene and diorama then
		-- slow push down the nave, ping-pong, with a breathing sway
		local k = (math.sin(t * 0.045 - math.pi / 2) + 1) / 2
		local pos = V3(-7.5, 11.5 - k * 2, 34 - k * 58) + V3(math.sin(t * 0.21) * 0.6, math.sin(t * 0.33) * 0.35, 0)
		local target = V3(-2 + math.sin(t * 0.13) * 1.2, 21 + math.sin(t * 0.17) * 0.8, -150)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(ORIGIN + pos, ORIGIN + target) * CFrame.Angles(0, 0, math.sin(t * 0.11) * 0.012)
		cam.FieldOfView = 60
	end
	for _, f in flickers do
		f.l.Brightness = f.b * (0.82 + math.noise(t * 3.1, f.seed) * 0.35)
	end
	-- embers drift upward across the screen
	local ds = UI.designSize()
	for _, e in embers do
		e.y -= e.v * dt / ds.Y
		if e.y < -0.02 then
			e.y = 1.02
			e.x = math.random()
		end
		local x = e.x * ds.X + math.sin(t * 0.8 + e.ph) * e.drift * 3
		e.f.Position = UDim2.fromOffset(x, e.y * ds.Y)
		e.f.BackgroundTransparency = 0.25 + (1 - e.y) * 0.6
	end
	if state == "splash" and Menu.pressLabel then
		Menu.pressLabel.TextTransparency = 0.15 + (math.sin(t * 3) * 0.5 + 0.5) * 0.55
	end
	if dragging and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		dragging = nil
	end
end)

-- ================================================================== input
local function onKey(input, gp)
	local k = input.KeyCode
	local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	-- title screen
	if C.menuOpen and gui and gui.Enabled then
		if state == "splash" then
			if isMouse or input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.Gamepad1 then
				Menu.reveal()
			end
			return
		end
		if typing or gp then
			return
		end
		if openName then
			if k == KC.Backspace or k == KC.ButtonB then
				Menu.openPanel(nil)
			elseif (k == KC.Return or k == KC.KeypadEnter) and openName == "new" then
				Menu.begin()
			end
			return
		end
		if k == KC.W or k == KC.Up or k == KC.DPadUp then
			setSel(sel - 1)
		elseif k == KC.S or k == KC.Down or k == KC.DPadDown then
			setSel(sel + 1)
		elseif k == KC.Return or k == KC.KeypadEnter or k == KC.Space or k == KC.ButtonA then
			activate(sel)
		end
		return
	end
	if typing then
		return
	end
	-- pause
	if k == KC.M or k == KC.P or k == KC.ButtonStart then
		Menu.pause(not pause.open)
		return
	end
	if pause.open then
		if k == KC.W or k == KC.Up or k == KC.DPadUp then
			pause.sel = ((pause.sel - 2) % #pause.items) + 1
			Menu.pausePanel(pause.panel)
			UI.onHover()
		elseif k == KC.S or k == KC.Down or k == KC.DPadDown then
			pause.sel = (pause.sel % #pause.items) + 1
			Menu.pausePanel(pause.panel)
			UI.onHover()
		elseif k == KC.Return or k == KC.KeypadEnter or k == KC.ButtonA then
			local it = pause.items[pause.sel]
			if it then
				UI.onClick()
				it.fn()
			end
		elseif k == KC.Backspace or k == KC.ButtonB then
			if pause.panel then
				Menu.pausePanel(nil)
			else
				Menu.pause(false)
			end
		end
	end
end

function Menu.init()
	-- grading only while the title screen is up
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "MenuCC"
	cc.Contrast = 0.14
	cc.Saturation = -0.12
	cc.TintColor = rgb(255, 236, 228)
	cc.Enabled = false
	cc.Parent = Lighting
	menuCC = cc
	local bl = Instance.new("BlurEffect")
	bl.Name = "PauseBlur"
	bl.Size = 0
	bl.Enabled = false
	bl.Parent = Lighting
	blur = bl
	applyAudio()
	C.onSetting(function(key)
		if key == "masterVolume" or key == "musicVolume" then
			applyAudio()
		end
	end)
	Menu.build()
	Menu.show()
	Net.on("Scene", function(name, d)
		if name == "menu" then
			Menu.setInfo(d)
		elseif name == "started" then
			C.seed = d and d.seed or C.seed
			if C.menuOpen then
				Menu.hide()
			end
		end
	end)
	UserInputService.InputBegan:Connect(onKey)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			dragging.fn(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = nil
		end
	end)
end

return Menu
