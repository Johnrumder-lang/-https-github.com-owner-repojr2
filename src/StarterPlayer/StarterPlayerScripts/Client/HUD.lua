--!nonstrict
-- In-game HUD (v3, gothic souls x Ultrakill):
--   bottom-left  VITALS  winged level emblem, souls health bar with damage trail,
--                        dash charges, flask pips, XP line, weapon, speed readout
--   bottom-right POWERS  time-stop clock gauge (Q), F / G ability slots with cooldowns
--   top          compass strip (marker bearing + distance), objective, waypoint marker
--   right        toasts, STYLE METER (rank word, decay bar, "+ BONUS" list)
--   centre       crosshair, tutorial hints, first-time controls card, zone title cards,
--                boss bar, level-up banner, death screen, hurt / time-stop vignettes,
--                free-cursor notice (Left Alt), custom ProximityPrompt billboards.
-- Public API (used by Controller / CombatClient / TimeStopFX / Mood / FX):
--   HUD.show(on)  HUD.setProfile(p)  HUD.hurt(dmg, blocked)  HUD.flash(color, t)
--   HUD.flashTimeStop()  HUD.timeStop(on, mine, duration)  HUD.frozenNotice()
--   HUD.objective(text, sub)  HUD.marker(pos, label)  HUD.tutorial(text, key, dur)
--   HUD.toast(d)  HUD.levelUp(text, sub)  HUD.death()  HUD.zone(title, sub)  HUD.boss(d)
--   HUD.addStyle(label, points)  HUD.resetStyle()  HUD.getStyle()  HUD.speed(sps)
--   HUD.controls(on)  HUD.setCursorFree(on)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Palette = require(Shared.Palette)
local Util = require(Shared.Util)
local C = require(script.Parent.C)
local UI = require(script.Parent.UI)

local HUD: any = {}
local player = Players.LocalPlayer
local COL = UI.COL
local rgb = Color3.fromRGB
local V2 = Vector2.new
local UCFG = Config.UI or {}

local built = false
local gui, root, over
local visibleHud = false
local w: any = {} -- widgets

local DEATH_LINES = {
	"The truck was faster.",
	"Time didn't stop for that one.",
	"The king would be proud.",
	"Power level confirmed: low.",
	"Try parrying. With your hands.",
	"Even the chicken would've dodged.",
	"Respawning... reluctantly.",
	"Two seconds weren't enough.",
	"The abyss sends its regards.",
	"Weak. As appraised.",
	"The god is laughing somewhere.",
	"Skill issue, isekai edition.",
}

local RANKS = UCFG.styleRanks or { "DULL", "CRUEL", "BRUTAL", "SAVAGE", "SADISTIC", "MERCILESS", "TIME-BREAKER" }
local THRESH = UCFG.styleThresholds or { 0, 90, 220, 400, 640, 940, 1300 }
local STYLE_MAX = UCFG.styleMax or 1700
local RANK_COL = {
	rgb(150, 144, 134), -- DULL
	COL.Bone, -- CRUEL
	COL.GoldBright, -- BRUTAL
	rgb(236, 142, 70), -- SAVAGE
	COL.BloodBright, -- SADISTIC
	rgb(255, 64, 92), -- MERCILESS
	COL.Violet, -- TIME-BREAKER
}

local function hex(c: Color3): string
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function safeCombat()
	local cc = C.CombatClient
	return if type(cc) == "table" then cc else {}
end

local function toDesign(x: number, y: number): (number, number)
	local s = UI.scale
	return x / s, y / s
end

-- ------------------------------------------------------------------ build: vitals
local function buildVitals()
	local v = UI.frame(root, { Name = "Vitals", Size = UDim2.fromOffset(620, 150), Position = UDim2.new(0, 34, 1, -26), AnchorPoint = V2(0, 1) })
	w.vitals = v
	-- soft dark backing so the cluster reads over bright scenes
	local back = UI.frame(v, { Name = "Backing", Size = UDim2.new(1, 60, 1, 30), Position = UDim2.fromOffset(-40, -10), color = COL.Ink, t = 0.45 })
	UI.gradient(back, nil, { { 0, 0.2 }, { 0.6, 0.55 }, { 1, 1 } }, 0)
	-- wings + emblem
	local ec = V2(64, 80)
	UI.wing(v, ec, -1, { angle = -14, spread = 17, n = 4, len = 56, gap = 34, color = COL.Gold, t = 0.1 })
	UI.wing(v, ec, -1, { angle = 16, spread = -17, n = 3, len = 40, gap = 34, color = COL.Gold, t = 0.35 })
	UI.diamond(v, 62, UDim2.fromOffset(ec.X, ec.Y), { color = COL.Ink, t = 0.05, stroke = COL.Gold, thick = 1.5, strokeT = 0.05, Name = "EmblemOuter" })
	UI.diamond(v, 52, UDim2.fromOffset(ec.X, ec.Y), { t = 1, stroke = COL.Gold, strokeT = 0.6, Name = "EmblemRing" })
	UI.diamond(v, 40, UDim2.fromOffset(ec.X, ec.Y), { color = COL.BloodDeep, t = 0.05, stroke = COL.Blood, strokeT = 0.2, Name = "EmblemCore" })
	UI.diamond(v, 6, UDim2.fromOffset(ec.X, ec.Y - 44), { color = COL.GoldBright })
	UI.diamond(v, 6, UDim2.fromOffset(ec.X, ec.Y + 44), { color = COL.GoldBright })
	UI.text(v, "LV", { Name = "LvTag", Size = UDim2.fromOffset(40, 12), Position = UDim2.fromOffset(ec.X, ec.Y - 18), AnchorPoint = V2(0.5, 0.5), font = UI.BOLD, size = 10, color = COL.Gold, x = Enum.TextXAlignment.Center })
	w.level = UI.text(v, "1", { Name = "Level", Size = UDim2.fromOffset(60, 36), Position = UDim2.fromOffset(ec.X, ec.Y + 3), AnchorPoint = V2(0.5, 0.5), font = UI.GOTHIC, size = 34, color = COL.Bone, x = Enum.TextXAlignment.Center, strokeT = 0.4 })
	-- weapon + speed
	w.weaponDot = UI.diamond(v, 6, UDim2.fromOffset(124, 30), { color = COL.Gold })
	w.weapon = UI.text(v, "", { Name = "Weapon", Size = UDim2.fromOffset(300, 18), Position = UDim2.fromOffset(134, 30), AnchorPoint = V2(0, 0.5), font = UI.BOLD, size = 13, color = COL.BoneDim, strokeT = 0.7, wrap = false })
	w.speedText = UI.text(v, "", { Name = "Speed", Size = UDim2.fromOffset(180, 18), Position = UDim2.fromOffset(538, 30), AnchorPoint = V2(1, 0.5), font = UI.BOLD, size = 13, color = COL.BoneDim, x = Enum.TextXAlignment.Right, strokeT = 0.7, rich = true, Visible = false })
	-- health
	w.hp = UI.soulsBar(v, { Name = "Health", Size = UDim2.fromOffset(420, 20), Position = UDim2.fromOffset(118, 44), capSize = 9 })
	w.hpText = UI.text(w.hp.holder, "100 / 100", { Name = "HpText", Size = UDim2.new(1, -14, 1, 0), Position = UDim2.fromOffset(0, 0), font = UI.BOLD, size = 13, color = COL.Bone, x = Enum.TextXAlignment.Right, strokeT = 0.35 })
	UI.pad(w.hpText, 0, 12, 0, 0)
	-- dash charges
	w.dashRow = UI.frame(v, { Name = "Dash", Size = UDim2.fromOffset(240, 7), Position = UDim2.fromOffset(118, 76) })
	w.dashSegs = {}
	-- flasks
	w.flaskRow = UI.frame(v, { Name = "Flasks", Size = UDim2.fromOffset(200, 22), Position = UDim2.fromOffset(380, 68) })
	w.flaskPips = {}
	w.flaskKey = UI.keycap(v, "R", UDim2.fromOffset(380, 68), { h = 20, Name = "FlaskKey" })
	-- xp + status
	local xpBack = UI.frame(v, { Name = "XP", Size = UDim2.fromOffset(420, 3), Position = UDim2.fromOffset(118, 100), color = rgb(30, 26, 20), t = 0.1 })
	w.xpFill = UI.frame(xpBack, { Name = "Fill", Size = UDim2.fromScale(0, 1), color = COL.Gold, t = 0 })
	UI.gradient(w.xpFill, { COL.GoldDeep, COL.GoldBright }, nil, 0)
	w.status = UI.text(v, "", { Name = "Status", Size = UDim2.fromOffset(460, 20), Position = UDim2.fromOffset(118, 108), font = UI.BOLD, size = 13, color = COL.BoneDim, rich = true, strokeT = 0.7, wrap = false })
end

local function rebuildDash(max: number)
	for _, s in w.dashSegs do
		s.back:Destroy()
	end
	w.dashSegs = {}
	local gap = 5
	local segW = (240 - gap * (max - 1)) / math.max(max, 1)
	for i = 1, max do
		local back = UI.frame(w.dashRow, { Name = "Seg" .. i, Size = UDim2.fromOffset(segW, 7), Position = UDim2.fromOffset((i - 1) * (segW + gap), 0), color = rgb(34, 30, 30), t = 0.2 })
		UI.stroke(back, COL.Bone, 1, 0.8)
		local fill = UI.frame(back, { Name = "Fill", Size = UDim2.fromScale(1, 1), color = COL.Bone, t = 0.05 })
		table.insert(w.dashSegs, { back = back, fill = fill })
	end
	w.dashMax = max
end

local lastFlasks = nil
local function rebuildFlasks(n: number, max: number)
	local sig = n .. "/" .. max
	if lastFlasks == sig then
		return
	end
	lastFlasks = sig
	for _, p in w.flaskPips do
		p:Destroy()
	end
	w.flaskPips = {}
	for i = 1, max do
		local full = i <= n
		local d = UI.diamond(w.flaskRow, 11, UDim2.fromOffset(8 + (i - 1) * 20, 11), {
			color = if full then COL.BloodBright else COL.Ink,
			t = if full then 0 else 0.2,
			stroke = if full then COL.GoldBright else COL.BoneFaint,
			strokeT = if full then 0.2 else 0.3,
			inner = if full then rgb(255, 160, 150) else nil,
			innerScale = 0.35,
			Name = "Flask" .. i,
		})
		table.insert(w.flaskPips, d)
	end
	w.flaskKey.Position = UDim2.fromOffset(380 + max * 20 + 4, 69)
end

-- ------------------------------------------------------------------ build: powers
local CLOCK_C = V2(356, 78)
local function buildPowers()
	local p = UI.frame(root, { Name = "Powers", Size = UDim2.fromOffset(440, 170), Position = UDim2.new(1, -34, 1, -26), AnchorPoint = V2(1, 1) })
	w.powers = p
	local back = UI.frame(p, { Name = "Backing", Size = UDim2.new(1, 60, 1, 30), Position = UDim2.fromOffset(-20, -10), color = COL.Ink, t = 0.45 })
	UI.gradient(back, nil, { { 0, 1 }, { 0.4, 0.55 }, { 1, 0.2 } }, 0)
	-- time stop clock
	local clock = UI.frame(p, { Name = "Clock", Size = UDim2.fromOffset(132, 132), Position = UDim2.fromOffset(CLOCK_C.X, CLOCK_C.Y), AnchorPoint = V2(0.5, 0.5) })
	w.clock = clock
	UI.wing(clock, V2(66, 66), 1, { angle = -18, spread = 16, n = 3, len = 30, gap = 62, color = COL.Gold, t = 0.3 })
	UI.wing(clock, V2(66, 66), 1, { angle = 18, spread = -16, n = 2, len = 24, gap = 62, color = COL.Gold, t = 0.5 })
	local face = UI.frame(clock, { Name = "Face", Size = UDim2.fromOffset(116, 116), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5), color = COL.Ink, t = 0.12 })
	UI.corner(face, 0, 0.5)
	UI.stroke(face, COL.Gold, 1.5, 0.15)
	UI.gradient(face, { rgb(70, 60, 110), rgb(255, 255, 255) }, nil, 90)
	local ring = UI.frame(clock, { Name = "Ring", Size = UDim2.fromOffset(98, 98), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5) })
	UI.corner(ring, 0, 0.5)
	w.clockRing = UI.stroke(ring, COL.Violet, 1, 0.6)
	w.ticks = {}
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local major = i % 3 == 0
		local r = 44
		local t = UI.frame(clock, {
			Name = "Tick" .. i,
			Size = UDim2.fromOffset(if major then 4 else 3, if major then 13 else 9),
			Position = UDim2.fromOffset(66 + math.sin(a) * r, 66 - math.cos(a) * r),
			AnchorPoint = V2(0.5, 0.5),
			Rotation = math.deg(a),
			color = COL.Violet,
			t = 0,
		})
		table.insert(w.ticks, t)
	end
	-- hands: rotating holders (children rotate with their parent)
	local function hand(name, len, thick, col, tr)
		local h = UI.frame(clock, { Name = name, Size = UDim2.fromOffset(len * 2, len * 2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5) })
		UI.frame(h, { Name = "Blade", Size = UDim2.fromOffset(thick, len), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 1), color = col, t = tr or 0 })
		return h
	end
	w.handSlow = hand("HandH", 24, 4, COL.GoldBright, 0.1)
	w.handFast = hand("HandM", 36, 2, COL.Bone, 0)
	UI.diamond(clock, 9, UDim2.fromScale(0.5, 0.5), { color = COL.Ink, stroke = COL.GoldBright, strokeT = 0, inner = COL.Violet })
	w.clockText = UI.text(clock, "READY", { Name = "State", Size = UDim2.fromOffset(100, 18), Position = UDim2.new(0.5, 0, 0.5, 26), AnchorPoint = V2(0.5, 0.5), font = UI.BLACK, size = 13, color = COL.GoldBright, x = Enum.TextXAlignment.Center, strokeT = 0.3 })
	local lab = UI.keyRow(p, { { "Q", "Stop time" } }, { h = 18, size = 11, gap = 6, Name = "ClockLabel", Position = UDim2.fromOffset(CLOCK_C.X, 158), AnchorPoint = V2(0.5, 0.5), color = COL.Violet })
	w.clockLabel = lab
	-- ability slots (F / G)
	w.abilitySlots = {}
	local function slot(id, key, name, col, x, y)
		local s = UI.panel(p, UDim2.fromOffset(60, 60), UDim2.fromOffset(x, y or 78), { AnchorPoint = V2(0.5, 0.5), color = COL.Ink, t = 0.18, edge = col, edgeT = 0.35, bracketColor = col, bracketLen = 8, Name = "Ability_" .. id })
		UI.diamond(s, 22, UDim2.fromScale(0.5, 0.46), { color = Palette.shade(col, 0.35), t = 0.1, stroke = col, strokeT = 0.1, inner = col, innerScale = 0.4 })
		local cd = UI.frame(s, { Name = "Cooldown", Size = UDim2.fromScale(1, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = V2(0, 1), color = Color3.new(0, 0, 0), t = 0.3 })
		local cdText = UI.text(s, "", { Name = "CdText", font = UI.BLACK, size = 18, x = Enum.TextXAlignment.Center, color = COL.Bone, strokeT = 0.3 })
		UI.keycap(s, key, UDim2.fromOffset(-10, -10), { h = 20 })
		UI.text(s, name, { Name = "Name", Size = UDim2.new(1, 20, 0, 14), Position = UDim2.new(0.5, 0, 1, 12), AnchorPoint = V2(0.5, 0.5), font = UI.BOLD, size = 10, color = COL.BoneDim, x = Enum.TextXAlignment.Center })
		s.Visible = false
		w.abilitySlots[id] = { frame = s, cd = cd, text = cdText }
	end
	slot("step", "F", "AETHER STEP", rgb(150, 220, 240), 150)
	slot("slash", "G", "VOID SLASH", COL.Violet, 234)
	slot("rune", "Z", "FLAME RUNE", rgb(230, 70, 50), 150, -12)
	slot("storm", "X", "STORM WEB", rgb(120, 200, 255), 234, -12)
end

-- ------------------------------------------------------------------ build: top (objective, compass, marker)
local COMPASS_W = 640
local PX_PER_DEG = COMPASS_W / 180
local LETTERS = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }
local function buildTop()
	-- objective
	local o = UI.frame(root, { Name = "Objective", Size = UDim2.fromOffset(540, 0), Position = UDim2.fromOffset(40, 92), auto = Enum.AutomaticSize.Y, Visible = false })
	w.obj = o
	UI.list(o, 4)
	local head = UI.frame(o, { Name = "Head", Size = UDim2.fromOffset(400, 18), LayoutOrder = 1 })
	UI.diamond(head, 7, UDim2.fromOffset(5, 9), { color = COL.BloodBright })
	w.objLabel = UI.text(head, "OBJECTIVE", { Name = "Label", Size = UDim2.fromOffset(300, 18), Position = UDim2.fromOffset(18, 0), font = UI.BOLD, size = 13, color = COL.Gold, strokeT = 0.7 })
	UI.hline(o, { Size = UDim2.fromOffset(360, 1), color = COL.Gold, fade = "right", t = 0.25, LayoutOrder = 2 })
	w.objText = UI.text(o, "", { Name = "Text", Size = UDim2.fromOffset(540, 0), auto = Enum.AutomaticSize.Y, font = UI.BODY, size = 22, color = COL.Bone, strokeT = 0.55, LayoutOrder = 3 })
	w.objSub = UI.text(o, "", { Name = "Sub", Size = UDim2.fromOffset(540, 0), auto = Enum.AutomaticSize.Y, font = UI.SERIF, size = 18, color = COL.BoneDim, strokeT = 0.7, LayoutOrder = 4 })
	local dist = UI.frame(o, { Name = "Dist", Size = UDim2.fromOffset(400, 20), LayoutOrder = 5, Visible = false })
	UI.diamond(dist, 8, UDim2.fromOffset(5, 10), { color = COL.Ink, stroke = COL.GoldBright, inner = COL.GoldBright })
	w.objDistText = UI.text(dist, "", { Size = UDim2.fromOffset(380, 20), Position = UDim2.fromOffset(18, 0), font = UI.BOLD, size = 13, color = COL.GoldBright, strokeT = 0.6, wrap = false })
	w.objDist = dist

	-- compass
	local ch = UI.frame(root, { Name = "Compass", Size = UDim2.fromOffset(COMPASS_W, 64), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = V2(0.5, 0) })
	w.compass = ch
	local strip = UI.frame(ch, { Name = "Strip", Size = UDim2.fromOffset(COMPASS_W, 30), color = COL.Ink, t = 0.3, clip = true })
	UI.gradient(strip, nil, UI.FADE_BOTH, 0)
	UI.hline(ch, { Size = UDim2.fromOffset(COMPASS_W, 1), Position = UDim2.fromOffset(0, 0), color = COL.Gold, t = 0.35 })
	UI.hline(ch, { Size = UDim2.fromOffset(COMPASS_W, 1), Position = UDim2.fromOffset(0, 30), color = COL.Gold, t = 0.35 })
	w.compassTicks = {}
	for a = 0, 345, 15 do
		local letter = LETTERS[a]
		local item
		if letter then
			item = UI.text(strip, letter, { Name = "L" .. a, Size = UDim2.fromOffset(34, 30), AnchorPoint = V2(0.5, 0), font = if a == 0 then UI.BLACK else UI.BOLD, size = if #letter == 1 then 16 else 12, color = if a == 0 then COL.BloodBright else COL.Bone, x = Enum.TextXAlignment.Center })
		else
			item = UI.frame(strip, { Name = "T" .. a, Size = UDim2.fromOffset(1, 8), AnchorPoint = V2(0.5, 0.5), color = COL.BoneDim, t = 0.2 })
		end
		table.insert(w.compassTicks, { a = a, o = item, letter = letter ~= nil })
	end
	w.compassPip = UI.diamond(strip, 10, UDim2.fromOffset(COMPASS_W / 2, 15), { color = COL.GoldBright, stroke = COL.Ink, strokeT = 0.2, inner = COL.Ink, innerScale = 0.3, Name = "Pip" })
	w.compassPip.Visible = false
	UI.diamond(ch, 7, UDim2.fromOffset(COMPASS_W / 2, 33), { color = COL.GoldBright, Name = "Notch" })
	w.compassDist = UI.text(ch, "", { Name = "Dist", Size = UDim2.fromOffset(120, 16), Position = UDim2.fromOffset(COMPASS_W / 2, 46), AnchorPoint = V2(0.5, 0.5), font = UI.BOLD, size = 12, color = COL.GoldBright, x = Enum.TextXAlignment.Center, strokeT = 0.5, Visible = false })

	-- free cursor notice
	w.cursorNote = UI.keyRow(root, { { "ALT", "Cursor free - press again to lock" } }, { h = 20, size = 12, gap = 8, Name = "CursorNote", Position = UDim2.new(0.5, 0, 0, 100), AnchorPoint = V2(0.5, 0.5), color = COL.Bone })
	w.cursorNote.Visible = false

	-- world marker
	local m = UI.frame(root, { Name = "Marker", Size = UDim2.fromOffset(200, 80), AnchorPoint = V2(0.5, 0.5), Visible = false })
	w.marker = m
	UI.diamond(m, 26, UDim2.fromScale(0.5, 0.5), { t = 1, stroke = COL.GoldBright, strokeT = 0.45, Name = "Ring" })
	UI.diamond(m, 15, UDim2.fromScale(0.5, 0.5), { color = COL.GoldBright, t = 0.05, stroke = COL.Ink, strokeT = 0.3, inner = COL.Ink, innerScale = 0.35, Name = "Core" })
	w.markerLabel = UI.text(m, "", { Name = "Label", Size = UDim2.fromOffset(200, 16), Position = UDim2.new(0.5, 0, 0.5, -30), AnchorPoint = V2(0.5, 0.5), font = UI.BOLD, size = 13, color = COL.Bone, x = Enum.TextXAlignment.Center, strokeT = 0.4, wrap = false })
	w.markerDist = UI.text(m, "", { Name = "Dist", Size = UDim2.fromOffset(200, 16), Position = UDim2.new(0.5, 0, 0.5, 28), AnchorPoint = V2(0.5, 0.5), font = UI.BOLD, size = 13, color = COL.GoldBright, x = Enum.TextXAlignment.Center, strokeT = 0.4, wrap = false })
	local arrow = UI.frame(m, { Name = "Arrow", Size = UDim2.fromOffset(60, 60), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5), Visible = false })
	UI.diamond(arrow, 8, UDim2.new(0.5, 0, 0, 0), { color = COL.GoldBright })
	UI.diamond(arrow, 5, UDim2.new(0.5, 0, 0, 9), { color = COL.GoldBright, t = 0.4 })
	w.markerArrow = arrow

	-- crosshair
	local cr = UI.frame(root, { Name = "Crosshair", Size = UDim2.fromOffset(32, 32), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5) })
	w.crosshair = cr
	local dot = UI.frame(cr, { Size = UDim2.fromOffset(4, 4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5), color = COL.Bone, t = 0 })
	UI.stroke(dot, Color3.new(0, 0, 0), 1, 0.4)
	for _, o in { { 0, -11, 2, 7 }, { 0, 11, 2, 7 }, { -11, 0, 7, 2 }, { 11, 0, 7, 2 } } do
		local f = UI.frame(cr, { Name = "Tick", Size = UDim2.fromOffset(o[3], o[4]), Position = UDim2.new(0.5, o[1], 0.5, o[2]), AnchorPoint = V2(0.5, 0.5), color = COL.Bone, t = 0.15 })
		UI.stroke(f, Color3.new(0, 0, 0), 1, 0.6)
	end
	w.tsLabel = UI.text(root, "", { Name = "TimeStopTimer", Size = UDim2.fromOffset(300, 20), Position = UDim2.new(0.5, 0, 0.5, 44), AnchorPoint = V2(0.5, 0.5), font = UI.BLACK, size = 15, color = COL.Violet, x = Enum.TextXAlignment.Center, strokeT = 0.3, Visible = false })
end

-- ------------------------------------------------------------------ build: right side (toasts, style)
local STYLE_ROWS = 6
local function buildRight()
	local tl = UI.frame(over, { Name = "Toasts", Size = UDim2.fromOffset(400, 380), Position = UDim2.new(1, -34, 0, 96), AnchorPoint = V2(1, 0) })
	UI.list(tl, 8, false, Enum.HorizontalAlignment.Right)
	w.toasts = tl

	local s = UI.frame(root, { Name = "Style", Size = UDim2.fromOffset(340, 262), Position = UDim2.new(1, -34, 0, 486), AnchorPoint = V2(1, 0), Visible = false })
	w.style = s
	local back = UI.panel(s, UDim2.fromScale(1, 1), UDim2.new(), { color = COL.Ink, t = 0.32, edgeT = 0.7, bracketT = 0.2, Name = "Back" })
	UI.gradient(back, { rgb(255, 255, 255), rgb(120, 110, 110) }, { { 0, 0.4 }, { 1, 0 } }, 0)
	UI.frame(s, { Name = "Rail", Size = UDim2.new(0, 2, 1, -16), Position = UDim2.fromOffset(0, 8), color = COL.Blood, t = 0.1 })
	UI.text(s, "STYLE", { Name = "Head", Size = UDim2.fromOffset(200, 16), Position = UDim2.fromOffset(18, 12), font = UI.BOLD, size = 12, color = COL.Gold })
	UI.hline(s, { Size = UDim2.fromOffset(250, 1), Position = UDim2.fromOffset(64, 20), color = COL.Gold, fade = "right", t = 0.4 })
	w.styleRank = UI.text(s, "", { Name = "Rank", Size = UDim2.fromOffset(316, 80), Position = UDim2.fromOffset(16, 26), font = UI.GOTHIC, size = 42, color = COL.Bone, rich = true, y = Enum.TextYAlignment.Bottom, strokeT = 0.35, wrap = false })
	UI.new("UIScale", { Parent = w.styleRank, Name = "Slam", Scale = 1 })
	local barBack = UI.frame(s, { Name = "Meter", Size = UDim2.fromOffset(308, 6), Position = UDim2.fromOffset(18, 112), color = rgb(30, 24, 26), t = 0.1 })
	UI.stroke(barBack, COL.Gold, 1, 0.6)
	w.styleFill = UI.frame(barBack, { Name = "Fill", Size = UDim2.fromScale(0.5, 1), color = COL.Bone, t = 0 })
	w.styleRows = {}
	local list = UI.frame(s, { Name = "Bonuses", Size = UDim2.fromOffset(308, 132), Position = UDim2.fromOffset(18, 126) })
	for i = 1, STYLE_ROWS do
		local l = UI.text(list, "", { Name = "Row" .. i, Size = UDim2.fromOffset(308, 21), Position = UDim2.fromOffset(0, (i - 1) * 21), font = UI.BOLD, size = 15, color = COL.Bone, rich = true, strokeT = 0.5, wrap = false })
		table.insert(w.styleRows, l)
	end
end

-- ------------------------------------------------------------------ build: centre (hints, titles, boss, banners)
local CONTROLS_1 = { { { "W", "A", "S", "D" }, "Move" }, { "Space", "Jump / wall jump" }, { "Shift", "Dash" }, { "Ctrl", "Slide / slam" }, { "LMB", "Attack (hold: launch)" }, { "RMB", "Parry" } }
local CONTROLS_2 = { { "Q", "Stop time" }, { "R", "Flask" }, { "E", "Interact" }, { "I", "Inventory" }, { "K", "Skills" }, { "V", "Camera" }, { "M", "Pause" }, { "Alt", "Free cursor" } }
HUD.CONTROLS = { CONTROLS_1, CONTROLS_2 }

local function buildCentre()
	-- bottom-centre group (hidden while a dialogue box is up)
	local bc = UI.frame(root, { Name = "BottomCentre" })
	w.bottomGroup = bc
	-- tutorial hint
	local t = UI.frame(bc, { Name = "Tutorial", Size = UDim2.fromOffset(1000, 48), Position = UDim2.new(0.5, 0, 1, -226), AnchorPoint = V2(0.5, 1), color = COL.Ink, t = 0.3, Visible = false })
	UI.gradient(t, nil, UI.FADE_BOTH, 0)
	UI.hline(t, { Size = UDim2.new(0.7, 0, 0, 1), Position = UDim2.fromScale(0.5, 0), AnchorPoint = V2(0.5, 0), color = COL.Gold, t = 0.4 })
	UI.hline(t, { Size = UDim2.new(0.7, 0, 0, 1), Position = UDim2.fromScale(0.5, 1), AnchorPoint = V2(0.5, 1), color = COL.Gold, t = 0.4 })
	local row = UI.frame(t, { Name = "Row", Size = UDim2.fromScale(1, 1) })
	UI.list(row, 12, true, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	w.tutKey = UI.keycap(row, "E", nil, { h = 28, light = true, LayoutOrder = 1 })
	w.tutText = UI.text(row, "", { Name = "Text", Size = UDim2.fromOffset(0, 40), auto = Enum.AutomaticSize.X, font = UI.BODY, size = 21, color = COL.Bone, strokeT = 0.6, wrap = false, rich = true, LayoutOrder = 2 })
	w.tut = t

	-- first-time controls card
	local cc = UI.frame(bc, { Name = "Controls", Size = UDim2.fromOffset(1180, 104), Position = UDim2.new(0.5, 0, 1, -112), AnchorPoint = V2(0.5, 1), color = COL.Ink, t = 0.25, Visible = false })
	UI.gradient(cc, nil, UI.FADE_BOTH, 0)
	UI.flourish(cc, 520, UDim2.new(0.5, 0, 0, 2), { color = COL.Gold, t = 0.2 })
	UI.text(cc, "CONTROLS", { Name = "Head", Size = UDim2.fromOffset(200, 14), Position = UDim2.new(0.5, 0, 0, 16), AnchorPoint = V2(0.5, 0), font = UI.BOLD, size = 11, color = COL.Gold, x = Enum.TextXAlignment.Center })
	UI.keyRow(cc, CONTROLS_1, { h = 24, size = 12, gap = 20, Name = "Row1", Position = UDim2.new(0.5, 0, 0, 34), AnchorPoint = V2(0.5, 0) })
	UI.keyRow(cc, CONTROLS_2, { h = 24, size = 12, gap = 20, Name = "Row2", Position = UDim2.new(0.5, 0, 0, 68), AnchorPoint = V2(0.5, 0) })
	w.controls = cc

	-- boss bar
	local b = UI.frame(bc, { Name = "Boss", Size = UDim2.fromOffset(680, 60), Position = UDim2.new(0.5, 0, 1, -40), AnchorPoint = V2(0.5, 1), Visible = false })
	w.boss = b
	w.bossName = UI.text(b, "", { Name = "Name", Size = UDim2.fromOffset(700, 40), Position = UDim2.fromOffset(4, 0), font = UI.GOTHIC, size = 34, color = COL.Bone, strokeT = 0.3, wrap = false })
	UI.hline(b, { Size = UDim2.fromOffset(340, 1), Position = UDim2.fromOffset(0, 40), color = COL.Gold, fade = "right", t = 0.4 })
	w.bossBar = UI.soulsBar(b, { Name = "Bar", Size = UDim2.fromOffset(680, 12), Position = UDim2.fromOffset(0, 46), fill = { rgb(200, 36, 40), rgb(96, 10, 16) }, capSize = 10 })

	-- zone title card
	local z = UI.frame(over, { Name = "ZoneTitle", Size = UDim2.fromOffset(1500, 210), Position = UDim2.new(0.5, 0, 0.15, 0), AnchorPoint = V2(0.5, 0), Visible = false })
	local band = UI.frame(z, { Name = "Band", Size = UDim2.new(1, 0, 1, 0), color = COL.Ink, t = 0.45 })
	UI.gradient(band, nil, UI.FADE_BOTH, 0)
	UI.gradient(UI.frame(band, { Size = UDim2.fromScale(1, 1), color = COL.Ink, t = 1 }), nil, nil, 0)
	UI.flourish(z, 620, UDim2.new(0.5, 0, 0, 18), { color = COL.Gold })
	local _, zt = UI.display(z, "", { Name = "Title", Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, 30), size = 86, x = Enum.TextXAlignment.Center, from = COL.Bone, mid = COL.GoldBright, to = rgb(140, 118, 84), midAt = 0.6 })
	w.zoneTitleHolder = zt.Parent
	w.zoneSub = UI.text(z, "", { Name = "Sub", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 128), font = UI.SERIF, size = 27, color = COL.BoneDim, x = Enum.TextXAlignment.Center, strokeT = 0.6 })
	UI.flourish(z, 380, UDim2.new(0.5, 0, 0, 184), { color = COL.Gold, dots = false, t = 0.2 })
	w.zone = z

	-- level-up banner
	local lv = UI.frame(over, { Name = "LevelUp", Size = UDim2.fromOffset(1100, 220), Position = UDim2.fromScale(0.5, 0.64), AnchorPoint = V2(0.5, 0.5), Visible = false })
	local lband = UI.frame(lv, { Name = "Band", Size = UDim2.new(1, 0, 0, 150), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5), color = COL.Ink, t = 0.4 })
	UI.gradient(lband, nil, UI.FADE_BOTH, 0)
	UI.flourish(lv, 560, UDim2.new(0.5, 0, 0, 36), { color = COL.GoldBright })
	UI.wing(lv, V2(550, 100), -1, { angle = -4, spread = 7, n = 4, len = 110, gap = 236, color = COL.Gold, t = 0.1 })
	UI.wing(lv, V2(550, 100), 1, { angle = -4, spread = 7, n = 4, len = 110, gap = 236, color = COL.Gold, t = 0.1 })
	local _, lt = UI.display(lv, "LEVEL UP", { Name = "Title", Size = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, 50), size = 96, x = Enum.TextXAlignment.Center, from = COL.GoldBright, mid = COL.Gold, to = COL.GoldDeep })
	w.levelTitle = lt.Parent
	w.levelSub = UI.text(lv, "", { Name = "Sub", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 154), font = UI.BOLD, size = 18, color = COL.Bone, x = Enum.TextXAlignment.Center, strokeT = 0.5, rich = true })
	UI.flourish(lv, 360, UDim2.new(0.5, 0, 0, 196), { color = COL.Gold, dots = false, t = 0.2 })
	w.levelUp = lv
end

local function vignette(parent, name, color)
	local f = UI.frame(parent, { Name = name, Size = UDim2.fromScale(1, 1) })
	local edges = {}
	for _, e in {
		{ UDim2.new(1, 0, 0, 200), UDim2.new(), 90 },
		{ UDim2.new(1, 0, 0, 200), UDim2.new(0, 0, 1, -200), -90 },
		{ UDim2.new(0, 260, 1, 0), UDim2.new(), 0 },
		{ UDim2.new(0, 260, 1, 0), UDim2.new(1, -260, 0, 0), 180 },
	} do
		local fr = UI.frame(f, { Name = "Edge", Size = e[1], Position = e[2], color = color, t = 1 })
		UI.gradient(fr, nil, { { 0, 0 }, { 0.3, 0.55 }, { 1, 1 } }, e[3])
		table.insert(edges, fr)
	end
	return f, edges
end

local function buildOverlays()
	w.hurtRoot, w.hurtEdges = vignette(over, "HurtEdge", rgb(150, 6, 14))
	w.tsRoot, w.tsEdges = vignette(over, "TimeEdge", rgb(120, 96, 255))
	w.flash = UI.frame(over, { Name = "Flash", Size = UDim2.fromScale(1, 1), color = Color3.new(1, 1, 1), t = 1 })
	-- frozen notice
	local fz = UI.frame(over, { Name = "Frozen", Size = UDim2.fromOffset(1000, 110), Position = UDim2.fromScale(0.5, 0.28), AnchorPoint = V2(0.5, 0.5), Visible = false })
	local _, ft = UI.display(fz, "TIME HAS STOPPED", { Name = "Title", Size = UDim2.new(1, 0, 0, 64), size = 58, x = Enum.TextXAlignment.Center, from = rgb(230, 222, 255), to = COL.Violet })
	w.frozenTitle = ft.Parent
	UI.flourish(fz, 420, UDim2.new(0.5, 0, 0, 76), { color = COL.Violet })
	UI.text(fz, "you cannot move", { Name = "Sub", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 88), font = UI.SERIF, size = 20, color = COL.BoneDim, x = Enum.TextXAlignment.Center, strokeT = 0.6 })
	w.frozen = fz
	-- death screen
	local d = UI.frame(over, { Name = "Death", Size = UDim2.fromScale(1, 1), color = Color3.new(0, 0, 0), t = 0.5, Visible = false })
	local band = UI.frame(d, { Name = "Band", Size = UDim2.new(1, 0, 0, 300), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5), color = COL.Ink, t = 0 })
	UI.gradient(band, nil, { { 0, 1 }, { 0.28, 0.12 }, { 0.72, 0.12 }, { 1, 1 } }, 90)
	UI.hline(d, { Size = UDim2.new(0.6, 0, 0, 1), Position = UDim2.new(0.5, 0, 0.5, -96), AnchorPoint = V2(0.5, 0.5), color = COL.Blood, t = 0.3 })
	UI.hline(d, { Size = UDim2.new(0.6, 0, 0, 1), Position = UDim2.new(0.5, 0, 0.5, 70), AnchorPoint = V2(0.5, 0.5), color = COL.Blood, t = 0.3 })
	local _, dt = UI.display(d, "YOU DIED", { Name = "Title", Size = UDim2.new(1, 0, 0, 170), Position = UDim2.new(0, 0, 0.5, -98), size = 164, x = Enum.TextXAlignment.Center, from = rgb(236, 60, 60), mid = COL.Blood, to = rgb(90, 8, 14), outline = rgb(20, 0, 2), outlineSize = 2, shadowT = 0.3, shadowY = 7 })
	w.deathTitle = dt.Parent
	w.deathScale = UI.new("UIScale", { Parent = w.deathTitle, Name = "Zoom", Scale = 1 })
	w.deathLine = UI.text(d, "", { Name = "Line", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0.5, 80), font = UI.SERIF, size = 28, color = COL.Bone, x = Enum.TextXAlignment.Center, strokeT = 0.5 })
	w.deathRise = UI.text(d, "RISING AGAIN", { Name = "Rise", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0.5, 122), font = UI.BOLD, size = 13, color = COL.BoneFaint, x = Enum.TextXAlignment.Center })
	w.death = d
end

function HUD.build()
	gui = UI.screen("HUD", 5)
	root = UI.root(gui, "Root")
	root.Visible = false
	over = UI.root(gui, "Over")
	buildVitals()
	buildPowers()
	buildTop()
	buildRight()
	buildCentre()
	buildOverlays()
	rebuildDash(Config.Player.dashCharges or 2)
	rebuildFlasks(Config.Player.flaskCharges or 3, Config.Player.flaskCharges or 3)
	built = true
end

-- ------------------------------------------------------------------ profile
local lastAbilitySig = nil
function HUD.setProfile(p)
	if type(p) ~= "table" then
		return
	end
	C.profile = p
	if not built then
		return
	end
	local lvl = tonumber(p.level) or 1
	local points = tonumber(p.points) or 0
	w.level.Text = tostring(lvl)
	w.xpFill.Size = UDim2.fromScale(math.clamp((tonumber(p.xp) or 0) / math.max(tonumber(p.xpNext) or 1, 1), 0, 1), 1)
	local status = string.format('<font color="#%s">%s GOLD</font>', hex(COL.Gold), Util.fmt(tonumber(p.gold) or 0))
	if points > 0 then
		status ..= string.format('   <font color="#%s">+%d POINT%s</font>  <font color="#%s">[K]</font>', hex(COL.BloodBright), points, if points > 1 then "S" else "", hex(COL.Bone))
	end
	w.status.Text = status
	rebuildFlasks(tonumber(p.flasks) or 0, tonumber(p.maxFlasks) or 3)
	-- weapon
	local wname, wr = "", nil
	for _, it in p.inventory or {} do
		if it.id == p.equipped then
			wname, wr = it.name or "", it.rarity
		end
	end
	w.weapon.Text = string.upper(if wname ~= "" then wname else "UNARMED")
	w.weaponDot.BackgroundColor3 = Palette.rarity[wr or "Common"] or COL.Gold
	-- abilities
	local ab = p.abilities or {}
	local sig = tostring(ab.timestop) .. tostring(ab.aetherStep) .. tostring(ab.voidSlash) .. tostring(ab.flameRune) .. tostring(ab.stormWeb)
	if sig ~= lastAbilitySig then
		lastAbilitySig = sig
		w.abilitySlots.step.frame.Visible = ab.aetherStep == true
		w.abilitySlots.slash.frame.Visible = ab.voidSlash == true
		w.abilitySlots.rune.frame.Visible = ab.flameRune == true
		w.abilitySlots.storm.frame.Visible = ab.stormWeb == true
		w.clock.Visible = ab.timestop == true
		w.clockLabel.Visible = ab.timestop == true
	end
end

-- ------------------------------------------------------------------ style meter
local style = { points = 0, rank = 0, lastAdd = -99, entries = {}, shownRank = -1, visible = false, rowCache = {}, rows = -1 }

local function rankOf(points: number): number
	if points <= 0 then
		return 0
	end
	local r = 1
	for i, th in THRESH do
		if points >= th then
			r = i
		end
	end
	return r
end

function HUD.addStyle(label: string, points: number?)
	local pts = tonumber(points) or 0
	label = string.upper(tostring(label or "STYLE"))
	local now = os.clock()
	style.points = math.clamp(style.points + pts, 0, STYLE_MAX)
	if label == "" then
		return -- a pure penalty (damage taken)
	end
	style.lastAdd = now
	local top = style.entries[1]
	if top and top.label == label and now - top.t < 3 then
		top.count += 1
		top.t = now
		top.points += pts
	else
		table.insert(style.entries, 1, { label = label, count = 1, t = now, points = pts })
		if #style.entries > STYLE_ROWS then
			table.remove(style.entries)
		end
	end
end

function HUD.resetStyle()
	style.points = 0
	style.entries = {}
	style.lastAdd = -99
end

function HUD.getStyle()
	local r = rankOf(style.points)
	return style.points, r, RANKS[r] or ""
end

local function rankText(r: number): string
	local word = RANKS[r] or ""
	local first, rest = word:sub(1, 1), word:sub(2)
	return string.format('<font size="76">%s</font><font size="40">%s</font>', first, rest)
end

local function updateStyle(dt: number, now: number)
	local r = rankOf(style.points)
	-- decay: faster at high ranks, short grace after each bonus
	if now - style.lastAdd > 0.9 and style.points > 0 then
		style.points = math.max(0, style.points - (20 + math.max(r - 1, 0) * 16) * dt)
		r = rankOf(style.points)
	end
	local show = style.points > 0 or (now - style.lastAdd < 4 and #style.entries > 0)
	if show ~= style.visible then
		style.visible = show
		if show then
			w.style.Visible = true
		else
			w.style.Visible = false
		end
	end
	if not show then
		style.shownRank = -1
		return
	end
	if r ~= style.shownRank then
		local up = r > style.shownRank
		style.shownRank = r
		local col = RANK_COL[math.max(r, 1)] or COL.Bone
		w.styleRank.Text = rankText(math.max(r, 1))
		w.styleRank.TextColor3 = col
		w.styleFill.BackgroundColor3 = col
		if up and r > 1 then
			local sc = w.styleRank:FindFirstChild("Slam")
			if sc then
				sc.Scale = 1.3
				UI.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			end
			UI.sfx("Tick", { pitch = 0.6 + r * 0.12, vol = 0.5, ignoreTime = true })
		end
	end
	local rr = math.max(r, 1)
	local lo = THRESH[rr] or 0
	local hi = THRESH[rr + 1] or STYLE_MAX
	w.styleFill.Size = UDim2.fromScale(math.clamp((style.points - lo) / math.max(hi - lo, 1), 0, 1), 1)
	local shown = 0
	for i, row in w.styleRows do
		local e = style.entries[i]
		local txt = ""
		local alpha = 1
		if e then
			local age = now - e.t
			txt = "+ " .. e.label
			if e.count > 1 then
				txt ..= string.format('  <font color="#%s">x%d</font>', hex(COL.GoldBright), e.count)
			end
			alpha = math.clamp(1 - (age - 3.2) / 1.4, 0, 1)
			if alpha <= 0 then
				txt = ""
			end
		end
		if style.rowCache[i] ~= txt then
			style.rowCache[i] = txt
			row.Text = txt
			row.TextColor3 = if e and e.points >= 100 then COL.GoldBright else COL.Bone
		end
		row.TextTransparency = 1 - alpha
		row.TextStrokeTransparency = 1 - alpha * 0.5
		if txt ~= "" then
			shown = i
		end
	end
	if shown ~= style.rows then
		style.rows = shown
		w.style.Size = UDim2.fromOffset(340, 132 + shown * 21 + (if shown > 0 then 8 else 0))
	end
end

-- ------------------------------------------------------------------ per-frame update
local markerPos: Vector3? = nil
local hurtA, tsA = 0, 0
local speedAt, speedVal = -99, 0
local controlsShown = false
local firstMarkerHint = false
local lastObjDist = nil
local lastCompDist = nil

local function heading(v: Vector3): number
	return math.deg(math.atan2(v.X, -v.Z)) % 360
end

local function wrap180(a: number): number
	return (a + 180) % 360 - 180
end

local function updateVitals(dt: number)
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local frac = 1
	if hum then
		frac = hum.Health / math.max(hum.MaxHealth, 1)
		w.hp:set(frac)
		w.hpText.Text = string.format("%d / %d", math.max(0, math.ceil(hum.Health)), math.floor(hum.MaxHealth + 0.5))
	end
	w.hp:update(dt)
	-- low health pulse + hurt fade
	local low = hum and frac < 0.3 and hum.Health > 0
	hurtA = math.max(0, hurtA - dt * 1.6)
	local a = hurtA
	if low then
		a = math.max(a, 0.35 + math.sin(os.clock() * 5) * 0.15)
	end
	for _, e in w.hurtEdges do
		e.BackgroundTransparency = 1 - a * 0.72
	end
	-- dash charges
	local ctl = C.Controller
	if type(ctl) == "table" and type(ctl.dashInfo) == "function" then
		local ok, charges, max, rech = pcall(ctl.dashInfo)
		if ok and type(charges) == "number" and type(max) == "number" then
			if max ~= w.dashMax and max >= 1 and max <= 8 then
				rebuildDash(max)
			end
			local total = Config.Player.dashRecharge or 1
			for i, s in w.dashSegs do
				local f = if i <= charges then 1 elseif i == charges + 1 then math.clamp((rech or 0) / total, 0, 1) else 0
				s.fill.Size = UDim2.fromScale(f, 1)
				s.fill.BackgroundTransparency = if f >= 1 then 0.05 else 0.45
			end
		end
	end
	-- speed readout
	local showSpeed = os.clock() - speedAt < 1.5
	w.speedText.Visible = showSpeed
	if showSpeed then
		w.speedText.Text = string.format('SPEED  <font color="#%s">%.1f</font>', hex(COL.Bone), speedVal)
	end
end

local function updatePowers(dt: number)
	if w.clock.Visible then
		local cc = safeCombat()
		local lit = 12
		local text, tcol = "READY", COL.GoldBright
		local frozenHands = false
		if C.timeStop.active and C.timeStop.mine then
			frozenHands = true
			local fx = C.TimeStopFX
			local rem = if type(fx) == "table" and type(fx.remaining) == "function" then fx.remaining() else 0
			if C.timeStop.scripted then
				text = "∞"
			else
				lit = math.clamp(math.ceil(rem / math.max(C.timeStop.duration or 1, 0.01) * 12), 0, 12)
				text = string.format("%.1f", rem)
			end
			tcol = Color3.new(1, 1, 1)
		else
			local now = workspace:GetServerTimeNow()
			local rem = (cc.tsReady or 0) - now
			if rem > 0 then
				lit = math.clamp(math.floor((1 - rem / math.max(cc.tsTotal or 1, 0.1)) * 12), 0, 12)
				text = tostring(math.ceil(rem))
				tcol = COL.BoneDim
			end
		end
		for i, t in w.ticks do
			local on = i <= lit
			t.BackgroundColor3 = if on then (if frozenHands then Color3.new(1, 1, 1) else COL.Violet) else rgb(54, 48, 72)
		end
		w.clockText.Text = text
		w.clockText.TextColor3 = tcol
		w.clockRing.Transparency = if lit >= 12 then 0.15 else 0.6
		if not frozenHands then
			local t = os.clock()
			w.handFast.Rotation = (math.floor(t * 2) * 15) % 360
			w.handSlow.Rotation = (t * 6) % 360
		end
	end
	local cc = safeCombat()
	local now = os.clock()
	local step = w.abilitySlots.step
	if step.frame.Visible then
		local total = Config.Abilities.AetherStep.cooldown
		local rem = (cc.stepReady or 0) - now
		step.cd.Size = UDim2.fromScale(1, math.clamp(rem / total, 0, 1))
		step.text.Text = if rem > 0.05 then string.format("%.1f", rem) else ""
	end
	local slash = w.abilitySlots.slash
	if slash.frame.Visible then
		local total = Config.Abilities.VoidSlash.cooldown
		local rem = (cc.slashReady or 0) - now
		slash.cd.Size = UDim2.fromScale(1, math.clamp(rem / total, 0, 1))
		slash.text.Text = if rem > 0.05 then string.format("%.1f", rem) else ""
	end
	for id, key in { rune = "FlameRune", storm = "StormWeb" } do
		local sl = w.abilitySlots[id]
		if sl and sl.frame.Visible then
			local total = Config.Abilities[key].cooldown
			local rem = (cc[id .. "Ready"] or 0) - now
			sl.cd.Size = UDim2.fromScale(1, math.clamp(rem / total, 0, 1))
			sl.text.Text = if rem > 0.05 then string.format("%.1f", rem) else ""
		end
	end
end

local function updateTop()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local look = cam.CFrame.LookVector
	local h = heading(look)
	for _, t in w.compassTicks do
		local rel = wrap180(t.a - h)
		local vis = math.abs(rel) < 96
		t.o.Visible = vis
		if vis then
			local x = COMPASS_W / 2 + rel * PX_PER_DEG
			t.o.Position = if t.letter then UDim2.fromOffset(x, 0) else UDim2.fromOffset(x, 15)
		end
	end
	local ch = player.Character
	local rootPart = ch and (ch.PrimaryPart or ch:FindFirstChild("HumanoidRootPart"))
	local from = if rootPart then rootPart.Position else cam.CFrame.Position
	if markerPos then
		local d = markerPos - from
		local dist = math.floor(Vector3.new(d.X, 0, d.Z).Magnitude + math.abs(d.Y) * 0.25)
		local rel = wrap180(heading(d) - h)
		local x = COMPASS_W / 2 + math.clamp(rel, -88, 88) * PX_PER_DEG
		w.compassPip.Visible = true
		w.compassPip.Position = UDim2.fromOffset(x, 15)
		w.compassDist.Visible = true
		w.compassDist.Position = UDim2.fromOffset(x, 46)
		if lastCompDist ~= dist then
			lastCompDist = dist
			w.compassDist.Text = dist .. " m"
		end
		local label = string.upper(HUD.markerLabel or "OBJECTIVE")
		local ot = label .. "  ·  " .. dist .. " m"
		if lastObjDist ~= ot then
			lastObjDist = ot
			w.objDistText.Text = ot
		end
		w.objDist.Visible = w.obj.Visible
		-- world marker
		local sp, onScreen = cam:WorldToViewportPoint(markerPos)
		local vp = cam.ViewportSize
		local x2, y2 = sp.X, sp.Y
		local behind = sp.Z < 0
		if behind then
			x2, y2 = vp.X - x2, vp.Y - y2
			onScreen = false
		end
		local mx, my = toDesign(x2, y2)
		local ds = UI.designSize()
		local margin = 70
		if not onScreen then
			local cx, cy = ds.X / 2, ds.Y / 2
			local dx, dy = mx - cx, my - cy
			if behind and math.abs(dy) < 1 then
				dy = 1
			end
			local kx = if math.abs(dx) > 0.001 then (cx - margin) / math.abs(dx) else math.huge
			local ky = if math.abs(dy) > 0.001 then (cy - margin) / math.abs(dy) else math.huge
			local k = math.min(kx, ky, 1)
			mx, my = cx + dx * k, cy + dy * k
			w.markerArrow.Visible = true
			w.markerArrow.Rotation = math.deg(math.atan2(dx, -dy))
		else
			w.markerArrow.Visible = false
		end
		w.marker.Position = UDim2.fromOffset(mx, my)
		w.markerDist.Text = dist .. " m"
	else
		w.compassPip.Visible = false
		w.compassDist.Visible = false
		w.objDist.Visible = false
	end
end

RunService.RenderStepped:Connect(function(dt)
	if not built then
		return
	end
	local now = os.clock()
	over.Visible = not C.menuOpen
	local inv = C.Inventory
	local invOpen = type(inv) == "table" and type(inv.isOpen) == "function" and inv.isOpen()
	root.Visible = visibleHud and not C.inCutscene and not C.menuOpen and not C.paused and not invOpen and not HUD.dead
	w.bottomGroup.Visible = not C.dialogueOpen
	-- time stop edge glow (also during cutscenes)
	local tsTarget = if C.timeStop.active then 0.45 + math.sin(now * 3) * 0.06 else 0
	tsA += (tsTarget - tsA) * math.min(1, dt * 6)
	for _, e in w.tsEdges do
		e.BackgroundTransparency = 1 - tsA * 0.7
	end
	if not root.Visible then
		if not C.inCutscene then
			w.hp:update(dt)
		end
		return
	end
	if not controlsShown and not C.menuOpen and not C.inCutscene then
		controlsShown = true
		task.delay(1.2, function()
			HUD.controls(true, 18)
		end)
	end
	local ctl = C.Controller
	local playing = type(ctl) == "table" and ctl.mode == "play"
	w.crosshair.Visible = playing and not C.wantsCursor()
	w.cursorNote.Visible = C.cursor.alt == true
	local mineTs = C.timeStop.active and C.timeStop.mine and not C.timeStop.scripted
	w.tsLabel.Visible = mineTs == true
	if mineTs then
		local fx = C.TimeStopFX
		local rem = if type(fx) == "table" and type(fx.remaining) == "function" then fx.remaining() else 0
		w.tsLabel.Text = string.format("TIME STOPPED  %.1f", rem)
	end
	updateVitals(dt)
	updatePowers(dt)
	updateTop()
	updateStyle(dt, now)
	if w.boss.Visible then
		w.bossBar:update(dt)
	end
end)

-- ------------------------------------------------------------------ api
function HUD.show(on: boolean)
	visibleHud = on == true
end

function HUD.speed(sps: number)
	speedVal = tonumber(sps) or 0
	speedAt = os.clock()
end

function HUD.hurt(dmg: number, blocked: boolean?)
	local a = if blocked then 0.2 else math.clamp(0.3 + (tonumber(dmg) or 10) / 80, 0.3, 0.85)
	hurtA = math.max(hurtA, a)
end

function HUD.flash(color: Color3, t: number)
	if not built then
		return
	end
	w.flash.BackgroundColor3 = color or Color3.new(1, 1, 1)
	w.flash.BackgroundTransparency = 0.35
	UI.tween(w.flash, t or 0.2, { BackgroundTransparency = 1 })
end

function HUD.flashTimeStop()
	if not built then
		return
	end
	local c = w.clock
	c.Position = UDim2.fromOffset(CLOCK_C.X - 6, CLOCK_C.Y)
	UI.tween(c, 0.14, { Position = UDim2.fromOffset(CLOCK_C.X, CLOCK_C.Y) }, Enum.EasingStyle.Back)
	for _, t in w.ticks do
		t.BackgroundColor3 = COL.BloodBright
	end
end

function HUD.timeStop(on: boolean, mine: boolean?, duration: number?)
	if not built then
		return
	end
	if not on or mine then
		w.frozen.Visible = false
	end
	if on and mine then
		local sc = w.clock:FindFirstChild("Pop") or UI.new("UIScale", { Parent = w.clock, Name = "Pop" })
		sc.Scale = 1.25
		UI.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

function HUD.frozenNotice()
	if not built then
		return
	end
	UI.setDisplayText(w.frozenTitle, if C.timeStop.inverted then "SOMEONE STOPPED TIME" else "TIME HAS STOPPED")
	w.frozen.Visible = true
end

function HUD.objective(text: string?, sub: string?)
	if not built then
		return
	end
	if not text or text == "" then
		w.obj.Visible = false
		return
	end
	local changed = w.objText.Text ~= text
	w.obj.Visible = true
	w.objText.Text = text
	w.objSub.Text = sub or ""
	w.objSub.Visible = sub ~= nil and sub ~= ""
	if changed then
		w.objLabel.Text = "NEW OBJECTIVE"
		w.objLabel.TextColor3 = COL.BloodBright
		w.obj.Position = UDim2.fromOffset(10, 92)
		UI.tween(w.obj, 0.35, { Position = UDim2.fromOffset(40, 92) }, Enum.EasingStyle.Back)
		UI.sfx("Pickup", { pitch = 0.8, vol = 0.5 })
		local tok = text
		task.delay(3.5, function()
			if w.objText.Text == tok then
				w.objLabel.Text = "OBJECTIVE"
				w.objLabel.TextColor3 = COL.Gold
			end
		end)
	end
end

function HUD.marker(pos: Vector3?, label: string?)
	markerPos = if typeof(pos) == "Vector3" then pos else nil
	HUD.markerLabel = label
	lastObjDist = nil
	if not built then
		return
	end
	w.marker.Visible = markerPos ~= nil
	w.markerLabel.Text = string.upper(label or "")
	if markerPos and not firstMarkerHint then
		firstMarkerHint = true
		task.delay(2, function()
			if markerPos and not w.tut.Visible then
				HUD.tutorial("Follow the gold marker - the compass at the top points the way", nil, 7)
			end
		end)
	end
end

local tutToken = 0
function HUD.tutorial(text: string?, keyName: string?, dur: number?)
	tutToken += 1
	local tok = tutToken
	if not built then
		return
	end
	if not text or text == "" then
		UI.fadeOut(w.tut, 0.25)
		return
	end
	w.tutKey.Visible = keyName ~= nil and keyName ~= ""
	w.tutKey.Text = string.upper(keyName or "")
	w.tutText.Text = text
	UI.fadeIn(w.tut, 0.25)
	w.tut.Position = UDim2.new(0.5, 0, 1, -214)
	UI.tween(w.tut, 0.3, { Position = UDim2.new(0.5, 0, 1, -226) }, Enum.EasingStyle.Back)
	if dur then
		task.delay(dur, function()
			if tutToken == tok then
				UI.fadeOut(w.tut, 0.5)
			end
		end)
	end
end

local ctlToken = 0
function HUD.controls(on: boolean, dur: number?)
	ctlToken += 1
	local tok = ctlToken
	if not built then
		return
	end
	if on then
		UI.fadeIn(w.controls, 0.5)
		if dur then
			task.delay(dur, function()
				if ctlToken == tok then
					UI.fadeOut(w.controls, 1)
				end
			end)
		end
	else
		UI.fadeOut(w.controls, 0.4)
	end
end

function HUD.setCursorFree(on: boolean)
	C.cursor.alt = if on then true else nil
end

local toastCount = 0
function HUD.toast(d)
	if not built or type(d) ~= "table" then
		return
	end
	if d.kind == "level" then
		return HUD.levelUp(d.text, d.sub)
	end
	local color = if d.rarity then (Palette.rarity[d.rarity] or COL.Bone) elseif d.kind == "warn" then COL.BloodBright elseif d.kind == "quest" then COL.GoldBright else COL.Gold
	toastCount += 1
	local hasSub = d.sub ~= nil and d.sub ~= ""
	local t = UI.frame(w.toasts, { Name = "Toast", Size = UDim2.fromOffset(400, if hasSub then 60 else 42), color = COL.Ink, t = 0.15, LayoutOrder = -toastCount })
	UI.gradient(t, nil, { { 0, 1 }, { 0.35, 0.35 }, { 1, 0 } }, 0)
	UI.frame(t, { Name = "Accent", Size = UDim2.new(0, 3, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = V2(1, 0), color = color, t = 0 })
	UI.hline(t, { Size = UDim2.new(0.8, 0, 0, 1), Position = UDim2.new(1, 0, 1, 0), AnchorPoint = V2(1, 1), color = color, fade = "left", t = 0.5 })
	UI.diamond(t, 7, UDim2.new(1, -18, 0, 17), { color = color })
	UI.text(t, string.upper(d.text or ""), { Name = "Title", Size = UDim2.new(1, -42, 0, 24), Position = UDim2.fromOffset(0, 5), font = UI.BOLD, size = 17, color = color, x = Enum.TextXAlignment.Right, strokeT = 0.6, wrap = false })
	if hasSub then
		UI.text(t, d.sub, { Name = "Sub", Size = UDim2.new(1, -42, 0, 20), Position = UDim2.fromOffset(0, 31), font = UI.BODY, size = 14, color = COL.BoneDim, x = Enum.TextXAlignment.Right, strokeT = 0.7, wrap = false })
	end
	UI.fadeIn(t, 0.25)
	-- keep at most 5 toasts
	local list = {}
	for _, c in w.toasts:GetChildren() do
		if c:IsA("Frame") then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 6, #list do
		list[i]:Destroy()
	end
	task.delay(4.5, function()
		if t.Parent then
			UI.fadeOut(t, 0.5, true)
		end
	end)
end

local levelToken = 0
function HUD.levelUp(text: string?, sub: string?)
	if not built then
		return
	end
	levelToken += 1
	local tok = levelToken
	UI.setDisplayText(w.levelTitle, string.upper(text or "LEVEL UP"))
	local s = sub or ""
	local p = C.profile
	if p and (tonumber(p.points) or 0) > 0 then
		s ..= string.format('   <font color="#%s">·</font>   SPEND POINTS  <font color="#%s">[K]</font>', hex(COL.Gold), hex(COL.GoldBright))
	end
	w.levelSub.Text = s
	UI.fadeIn(w.levelUp, 0.35)
	local sc = w.levelTitle:FindFirstChild("Slam") or UI.new("UIScale", { Parent = w.levelTitle, Name = "Slam" })
	sc.Scale = 1.6
	UI.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.sfx("LevelUp", { vol = 0.8 })
	task.delay(2.8, function()
		if levelToken == tok then
			UI.fadeOut(w.levelUp, 0.8)
		end
	end)
end

function HUD.death()
	if not built then
		return
	end
	w.deathLine.Text = DEATH_LINES[math.random(1, #DEATH_LINES)]
	HUD.dead = true
	UI.fadeIn(w.death, 1.1)
	w.deathScale.Scale = 1.1
	UI.tween(w.deathScale, 3.5, { Scale = 1 }, Enum.EasingStyle.Quad)
	HUD.resetStyle()
	task.delay((Config.Player.respawnDelay or 3.5) + 0.4, function()
		HUD.dead = false
		UI.fadeOut(w.death, 0.7)
	end)
end

local zoneToken = 0
function HUD.zone(title: string?, sub: string?)
	if not title or title == "" or not built then
		return
	end
	zoneToken += 1
	local tok = zoneToken
	UI.setDisplayText(w.zoneTitleHolder, title)
	w.zoneSub.Text = sub or ""
	UI.fadeIn(w.zone, 0.9)
	task.delay(4.2, function()
		if zoneToken == tok then
			UI.fadeOut(w.zone, 1.3)
		end
	end)
end

local bossTarget, bossId = nil, nil
function HUD.boss(d)
	if not built or type(d) ~= "table" then
		return
	end
	if d.clear then
		UI.fadeOut(w.boss, 0.6)
		bossTarget = nil
		bossId = nil
		return
	end
	if d.name then
		w.bossName.Text = d.name
		bossTarget = d.target
		bossId = d.id
		w.bossBar:set(1, true)
		UI.fadeIn(w.boss, 0.6)
	end
	if d.hp and d.max and (not d.id or d.id == bossId) then
		w.bossBar:set(d.hp / math.max(d.max, 1))
	end
end

RunService.Heartbeat:Connect(function()
	if bossTarget and bossTarget.Parent and built then
		local hum = bossTarget:FindFirstChildOfClass("Humanoid")
		if hum then
			w.bossBar:set(hum.Health / math.max(hum.MaxHealth, 1))
		end
	end
end)

-- ------------------------------------------------------------------ custom prompts
local function promptShown(prompt: ProximityPrompt)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		return
	end
	local adornee = prompt.Parent
	if not adornee or not adornee:IsA("BasePart") and not adornee:IsA("Attachment") then
		return
	end
	local s = UI.scale
	local bb = Instance.new("BillboardGui")
	bb.Name = "TRSPrompt"
	bb.Adornee = adornee
	bb.Size = UDim2.fromOffset(340 * s, 66 * s)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Parent = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
	local r = UI.frame(bb, { Name = "Root", Size = UDim2.fromScale(1 / s, 1 / s) })
	UI.new("UIScale", { Parent = r, Scale = s })
	local b = UI.panel(r, UDim2.new(1, -12, 1, -12), UDim2.fromOffset(6, 6), { color = COL.Ink, t = 0.12, edgeT = 0.45, bracketLen = 9 })
	UI.frame(b, { Name = "Accent", Size = UDim2.new(0, 3, 1, 0), color = COL.GoldBright, t = 0 })
	local keyName = prompt.KeyboardKeyCode.Name
	UI.keycap(b, keyName, UDim2.fromOffset(16, 13), { h = 28, light = true })
	UI.text(b, string.upper(prompt.ActionText), { Name = "Action", Position = UDim2.fromOffset(58, 7), Size = UDim2.new(1, -66, 0, 22), font = UI.BOLD, size = 17, color = COL.Bone, wrap = false })
	UI.text(b, prompt.ObjectText, { Name = "Object", Position = UDim2.fromOffset(58, 29), Size = UDim2.new(1, -66, 0, 16), font = UI.BODY, size = 13, color = COL.BoneDim, wrap = false })
	local fill = UI.frame(b, { Name = "Hold", Size = UDim2.new(0, 0, 0, 2), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = V2(0, 1), color = COL.GoldBright, t = 0 })
	local c1 = prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			fill.Size = UDim2.new(0, 0, 0, 2)
			UI.tween(fill, prompt.HoldDuration, { Size = UDim2.new(1, 0, 0, 2) }, Enum.EasingStyle.Linear)
		end
	end)
	local c2 = prompt.PromptButtonHoldEnded:Connect(function()
		fill.Size = UDim2.new(0, 0, 0, 2)
	end)
	local c3
	c3 = prompt.PromptHidden:Connect(function()
		bb:Destroy()
		c1:Disconnect()
		c2:Disconnect()
		c3:Disconnect()
	end)
end

function HUD.init()
	HUD.build()
	Net.on("Profile", HUD.setProfile)
	Net.on("Objective", function(d)
		d = d or {}
		HUD.objective(d.text, d.sub)
	end)
	Net.on("Marker", function(d)
		d = d or {}
		HUD.marker(d.pos, d.label)
	end)
	Net.on("Tutorial", function(d)
		d = d or {}
		HUD.tutorial(d.text, d.key, d.dur)
	end)
	Net.on("Notify", function(d)
		if type(d) ~= "table" then
			return
		end
		if d.kind == "death" then
			HUD.death()
		else
			HUD.toast(d)
			if d.kind == "loot" then
				UI.sfx("Pickup", { pitch = 1.2 })
			end
		end
	end)
	Net.on("BossBar", HUD.boss)
	ProximityPromptService.PromptShown:Connect(promptShown)
	-- Left Alt frees / locks the cursor during play
	UserInputService.InputBegan:Connect(function(input, gp)
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			if C.menuOpen or UserInputService:GetFocusedTextBox() then
				return
			end
			HUD.setCursorFree(not C.cursor.alt)
		end
	end)
end

return HUD
