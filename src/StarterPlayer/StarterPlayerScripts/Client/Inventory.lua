--!nonstrict
-- Inventory (I or TAB), v3 gothic style.
--   EQUIPMENT: paper doll (live 3D preview of your character + 10 slots), a bag
--              grid with 3D item icons, filters, and a details panel with stat
--              comparisons, equip / upgrade / salvage.
--   CHARACTER: level-up points.
--   JOURNAL:   quests.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Weapons = require(Shared.Weapons)
local Gear = require(Shared.Gear)
local Palette = require(Shared.Palette)
local Util = require(Shared.Util)
local C = require(script.Parent.C)
local UI = require(script.Parent.UI)

local Inv = {}
local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local V = Vector3.new
local COL = UI.COL
local gui, holder, body
local pages, tabButtons = {}, {}
local open = false
local currentPage = "equipment"
local filter = "all"
local selected = nil -- item table
local hovered = nil

-- equipment page widgets
local dollVP, dollCam, dollWorld, dollModel
local slotWidgets = {}
local gridFrame
local statsLabel
local detail: any = {}
local iconCache = {} -- id -> { vp, model }
local cellFor = {} -- id -> cell frame
local dollYaw = 0
local dragging = false
local lastSig = nil

-- character / journal widgets
local statLabels = {}
local pointsLabel, derivedLabel, questList, headerInfo
local filterButtons = {}

local STATS = {
	{ "dmg", "DAMAGE", "+7% weapon damage" },
	{ "hp", "HEALTH", "+14 max health" },
	{ "tsDur", "TIME STOP DURATION", "+0.25s frozen time" },
	{ "tsCd", "TIME STOP COOLDOWN", "-0.6s cooldown" },
}

local DOLL_LEFT = { "Head", "Amulet", "Chest", "Cloak", "Weapon" }
local DOLL_RIGHT = { "Hands", "Ring", "Legs", "Feet", "Offhand" }

local function rarityColor(r: string?): Color3
	return Palette.rarity[r or "Common"] or Color3.new(1, 1, 1)
end

local function isGear(it): boolean
	return Gear.isGear(it)
end

local function slotOf(it): string
	if isGear(it) then
		return it.slot
	end
	return "Weapon"
end

local function findItem(id: string?)
	local p = C.profile
	if not p or not id then
		return nil
	end
	for _, it in p.inventory or {} do
		if it.id == id then
			return it
		end
	end
	return nil
end

local function equippedIn(slot: string)
	local p = C.profile
	if not p then
		return nil
	end
	if slot == "Weapon" then
		return findItem(p.equipped)
	end
	return findItem(p.equipment and p.equipment[slot])
end

local function isEquipped(it): boolean
	local p = C.profile
	if not p or not it then
		return false
	end
	if p.equipped == it.id then
		return true
	end
	for _, id in p.equipment or {} do
		if id == it.id then
			return true
		end
	end
	return false
end

local function shortType(it): string
	if isGear(it) then
		return Gear.SLOT_INFO[it.slot].short
	end
	return string.upper(it.kind or "?")
end

local function score(it): number
	if isGear(it) then
		return Gear.score(it) / 60
	end
	return Weapons.score(it)
end

-- ------------------------------------------------------------------ 3D helpers
local function anchorAll(m: Instance)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = false
		end
	end
end

-- Builds a model of an item plus a camera frame that shows it nicely.
local function itemModel(it)
	if isGear(it) then
		local m = Gear.previewModel(it)
		anchorAll(m)
		local focus = m:GetAttribute("Focus") or V(0, 3, 0)
		local ext = m:GetAttribute("Extent") or 3
		local camCF = CFrame.lookAt(focus + V(ext * 0.55, ext * 0.35, -ext * 1.25), focus)
		return m, camCF
	end
	local m = Weapons.buildModel(it)
	anchorAll(m)
	m:PivotTo(CFrame.Angles(0, 0, math.rad(-45)))
	local tip = m:GetAttribute("TipY") or 4
	local mid = CFrame.Angles(0, 0, math.rad(-45)) * V(0, tip * 0.45, 0)
	m.WorldPivot = CFrame.new(mid) * (m:GetPivot() - m:GetPivot().Position)
	return m, CFrame.lookAt(mid + V(0, 0, -(tip * 1.25 + 1.5)), mid)
end

local function makeViewport(parent: Instance, size: UDim2, pos: UDim2, z: number)
	local vp = UI.new("ViewportFrame", {
		Parent = parent,
		Size = size,
		Position = pos,
		BackgroundTransparency = 1,
		Ambient = rgb(170, 170, 180),
		LightColor = rgb(255, 250, 240),
		LightDirection = V(-0.6, -1, 0.5),
		ZIndex = z,
	})
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	return vp, cam
end

local function setIcon(vp: ViewportFrame, cam: Camera, it)
	for _, c in vp:GetChildren() do
		if c:IsA("Model") then
			c:Destroy()
		end
	end
	if not it then
		return
	end
	local ok, m, camCF = pcall(itemModel, it)
	if ok and m then
		m.Parent = vp
		cam.CFrame = camCF
	end
end

-- ------------------------------------------------------------------ doll preview
local function refreshDoll()
	if not dollWorld then
		return
	end
	if dollModel then
		dollModel:Destroy()
		dollModel = nil
	end
	local ch = player.Character
	if not ch then
		return
	end
	local ok, clone = pcall(function()
		ch.Archivable = true
		return ch:Clone()
	end)
	if not ok or not clone then
		return
	end
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.LocalTransparencyModifier = 0
			if d.Name == "HumanoidRootPart" then
				d.Transparency = 1
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
		end
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = clone:FindFirstChild("HumanoidRootPart") :: BasePart
	local base = if root then root.CFrame else clone:GetPivot()
	-- store every part relative to the root so we can spin it freely
	clone:SetAttribute("BaseInv", true)
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("Rel", base:ToObjectSpace(d.CFrame))
		end
	end
	clone.Parent = dollWorld
	dollModel = clone
end

local function spinDoll()
	if not dollModel then
		return
	end
	local cf = CFrame.new(0, 3, 0) * CFrame.Angles(0, dollYaw, 0)
	for _, d in dollModel:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = d:GetAttribute("Rel")
			if rel then
				d.CFrame = cf * rel
			end
		end
	end
end

-- ------------------------------------------------------------------ page switching
local function showPage(name: string)
	currentPage = name
	for n, p in pages do
		p.Visible = n == name
	end
	for n, api in tabButtons do
		api.set(n == name)
	end
end

-- ------------------------------------------------------------------ details panel
local function statLinesFor(it)
	local lines = {}
	local cmp = equippedIn(slotOf(it))
	if cmp and cmp.id == it.id then
		cmp = nil
	end
	if isGear(it) then
		local s = Gear.stats(it)
		local o = if cmp then Gear.stats(cmp) else {}
		local b = Gear.BASES[it.base]
		table.insert(lines, string.format('<font color="#B4B4C0">%s %s  ·  Lv %d%s</font>', it.rarity, if b then Gear.SLOT_INFO[b.slot].label:lower() else "gear", it.level, if (it.up or 0) > 0 then "  ·  <b>+" .. it.up .. "</b>" else ""))
		for _, key in Gear.STAT_ORDER do
			local v, w = s[key] or 0, o[key] or 0
			if math.abs(v) > 0.0001 or (cmp and math.abs(w) > 0.0001) then
				local def = Gear.STATS[key]
				local diff = ""
				if cmp then
					local dv = v - w
					if math.abs(dv) > 0.0001 then
						diff = string.format('  <font color="#%s">%s%s</font>', if dv > 0 then "78E68C" else "FF6E6E", if dv > 0 then "▲ " else "▼ ", (Gear.fmt(key, math.abs(dv)):gsub("^[%+%-]", "")))
					end
				end
				if math.abs(v) > 0.0001 then
					table.insert(lines, def[1] .. "  <b>" .. Gear.fmt(key, v) .. "</b>" .. diff)
				else
					table.insert(lines, '<font color="#777780">' .. def[1] .. "  —</font>" .. diff)
				end
			end
		end
	else
		for _, l in Weapons.describe(it) do
			if l:sub(1, 1) ~= '"' then
				table.insert(lines, l)
			end
		end
		if cmp then
			local diff = Weapons.score(it) / math.max(Weapons.score(cmp), 0.001) - 1
			table.insert(lines, string.format('<font color="#%s">%s%d%% overall vs equipped</font>', if diff >= 0 then "78E68C" else "FF6E6E", if diff >= 0 then "+" else "", math.floor(diff * 100 + 0.5)))
		end
	end
	if it.desc then
		table.insert(lines, '<i><font color="#C8BEA0">"' .. it.desc .. '"</font></i>')
	end
	return lines
end

local function showDetail(it)
	if not detail.name then
		return
	end
	if not it then
		detail.name.Text = "Select an item"
		detail.name.TextColor3 = COL.BoneFaint
		detail.lines.Text = "Click an item to inspect it.\nDouble-click or right-click to equip."
		if detail.rarityBar then
			detail.rarityBar.BackgroundColor3 = COL.GoldDeep
		end
		setIcon(detail.vp, detail.cam, nil)
		detail.equip.Text = "EQUIP"
		detail.upgrade.Text = "UPGRADE"
		detail.salvage.Text = "SALVAGE"
		return
	end
	detail.name.Text = it.name
	detail.name.TextColor3 = rarityColor(it.rarity)
	if detail.rarityBar then
		detail.rarityBar.BackgroundColor3 = rarityColor(it.rarity)
	end
	detail.lines.Text = table.concat(statLinesFor(it), "\n")
	setIcon(detail.vp, detail.cam, it)
	local eq = isEquipped(it)
	detail.equip.Text = if eq then (if isGear(it) then "UNEQUIP" else "EQUIPPED") else "EQUIP"
	if (it.up or 0) >= Gear.MAX_UP then
		detail.upgrade.Text = "MAX +" .. Gear.MAX_UP
	else
		local gold, scrap
		if isGear(it) then
			gold, scrap = Gear.upgradeCost(it)
		else
			local up = it.up or 0
			local r = table.find(Weapons.RARITIES, it.rarity) or 1
			gold, scrap = math.floor((40 + it.level * 12) * (up + 1) ^ 1.35 * (0.8 + r * 0.2)), 1 + up + math.floor(r / 2)
		end
		detail.upgrade.Text = string.format("UPGRADE +%d  (%dg · %d scrap)", (it.up or 0) + 1, gold, scrap)
	end
	detail.salvage.Text = if it.unique then "UNIQUE" elseif eq then "EQUIPPED" else "SALVAGE"
end

local function select(it)
	selected = it
	showDetail(it)
	for id, cell in cellFor do
		local stroke = cell:FindFirstChild("Sel")
		if stroke then
			stroke.Enabled = it ~= nil and id == it.id
		end
	end
end

local function equip(it)
	if not it then
		return
	end
	Net.send("Menu", "Equip", { id = it.id })
	UI.sfx("Equip", { pitch = 1.1 })
end

-- ------------------------------------------------------------------ build
local WIN_W, WIN_H = 1220, 740
local PAGE_Y = 108
local PAGE_H = WIN_H - PAGE_Y - 24

local function sectionTitle(parent, text, x, y, w)
	UI.text(parent, text, { Name = "Section", Size = UDim2.fromOffset(w or 300, 16), Position = UDim2.fromOffset(x, y), font = UI.BOLD, size = 12, color = COL.Gold })
	UI.hline(parent, { Size = UDim2.fromOffset((w or 300) - 10, 1), Position = UDim2.fromOffset(x, y + 18), color = COL.Gold, fade = "right", t = 0.45 })
end

local function buildEquipment(parent)
	local page = UI.frame(parent, { Name = "Equipment", Size = UDim2.new(1, -48, 0, PAGE_H), Position = UDim2.fromOffset(24, PAGE_Y) })

	-- paper doll ---------------------------------------------------------
	local db = UI.panel(page, UDim2.fromOffset(384, PAGE_H), UDim2.fromOffset(0, 0), { color = COL.Ink, t = 0.25, Name = "Doll" })
	local stage = UI.frame(db, { Name = "Stage", Size = UDim2.fromOffset(204, 392), Position = UDim2.fromOffset(90, 10), color = rgb(26, 20, 24), t = 0.1, clip = true })
	UI.gradient(stage, { rgb(120, 60, 64), rgb(20, 16, 20) }, nil, 90)
	UI.stroke(stage, COL.Gold, 1, 0.7)
	UI.diamond(stage, 110, UDim2.new(0.5, 0, 1, 10), { color = COL.Blood, t = 0.82 })
	dollVP = UI.new("ViewportFrame", {
		Parent = stage,
		Name = "Viewport",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = rgb(150, 140, 150),
		LightColor = rgb(255, 236, 220),
		LightDirection = V(-0.5, -1, -0.4),
	})
	dollWorld = Instance.new("WorldModel")
	dollWorld.Parent = dollVP
	dollCam = Instance.new("Camera")
	dollCam.FieldOfView = 34
	dollCam.CFrame = CFrame.lookAt(V(0, 3.4, -11.5), V(0, 3.0, 0))
	dollCam.Parent = dollVP
	dollVP.CurrentCamera = dollCam
	UI.text(stage, "DRAG TO ROTATE", { Name = "Drag", Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 16), font = UI.BOLD, size = 10, x = Enum.TextXAlignment.Center, color = COL.BoneFaint })
	dollVP.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and open and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			dollYaw -= input.Delta.X * 0.012
		end
	end)
	local function slotButton(slot: string, x: number, y: number)
		local frame = UI.new("TextButton", { Parent = db, Name = "Slot_" .. slot, Size = UDim2.fromOffset(66, 66), Position = UDim2.fromOffset(x, y), BackgroundColor3 = COL.Ink3, BackgroundTransparency = 0.1, BorderSizePixel = 0, Text = "", AutoButtonColor = false })
		local stroke = UI.stroke(frame, COL.GoldDeep, 1, 0.1)
		UI.brackets(frame, COL.Gold, 7, 1, -3, 0.35)
		local vp, cam = makeViewport(frame, UDim2.fromScale(1, 1), UDim2.new(), 1)
		local label = UI.text(frame, if slot == "Weapon" then "WEAPON" else string.upper(Gear.SLOT_INFO[slot].label), { Name = "Label", Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 18), size = 9, font = UI.BOLD, x = Enum.TextXAlignment.Center, color = COL.BoneFaint })
		local up = UI.text(frame, "", { Name = "Up", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -5, 0, 14), size = 12, font = UI.BLACK, x = Enum.TextXAlignment.Right, color = COL.GoldBright, strokeT = 0.4 })
		frame.MouseButton1Click:Connect(function()
			local it = equippedIn(slot)
			if it then
				select(it)
			else
				filter = if slot == "Weapon" then "weapons" elseif slot == "Ring" or slot == "Amulet" then "trinkets" else "armor"
				Inv.refresh()
			end
			UI.onClick()
		end)
		frame.MouseButton2Click:Connect(function()
			if slot ~= "Weapon" and equippedIn(slot) then
				Net.send("Menu", "Unequip", { slot = slot })
			end
		end)
		frame.MouseEnter:Connect(function()
			hovered = equippedIn(slot)
			if hovered then
				showDetail(hovered)
			end
		end)
		frame.MouseLeave:Connect(function()
			hovered = nil
			showDetail(selected)
		end)
		slotWidgets[slot] = { frame = frame, stroke = stroke, vp = vp, cam = cam, label = label, up = up, id = nil }
	end
	for i, slot in DOLL_LEFT do
		slotButton(slot, 12, 12 + (i - 1) * 78)
	end
	for i, slot in DOLL_RIGHT do
		slotButton(slot, 306, 12 + (i - 1) * 78)
	end
	sectionTitle(db, "ATTRIBUTES", 16, 412, 350)
	statsLabel = UI.text(db, "", { Name = "Stats", Position = UDim2.fromOffset(16, 436), Size = UDim2.fromOffset(352, PAGE_H - 446), size = 14, font = UI.BODY, color = COL.BoneDim, rich = true, y = Enum.TextYAlignment.Top, lineHeight = 1.1 })

	-- bag -------------------------------------------------------------------
	local gb = UI.panel(page, UDim2.fromOffset(452, PAGE_H), UDim2.fromOffset(396, 0), { color = COL.Ink, t = 0.25, Name = "Bag" })
	local fx = 14
	filterButtons = {}
	for _, f in { { "all", "ALL" }, { "weapons", "WEAPONS" }, { "armor", "ARMOR" }, { "trinkets", "TRINKETS" } } do
		local _, _, api = UI.button(gb, f[2], UDim2.fromOffset(100, 30), UDim2.fromOffset(fx, 10), function()
			filter = f[1]
			Inv.refresh()
		end, { kind = "tab", textSize = 13, Name = "Filter_" .. f[1] })
		filterButtons[f[1]] = api
		fx += 106
	end
	UI.hline(gb, { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 42), color = COL.Gold, t = 0.55 })
	gridFrame = UI.new("ScrollingFrame", { Parent = gb, Name = "Grid", Size = UDim2.new(1, -20, 1, -106), Position = UDim2.fromOffset(10, 52), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = COL.Gold, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y })
	UI.new("UIGridLayout", { Parent = gridFrame, CellSize = UDim2.fromOffset(78, 78), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	UI.pad(gridFrame, 4)
	UI.button(gb, "SALVAGE JUNK  ·  COMMON & UNCOMMON", UDim2.new(1, -28, 0, 36), UDim2.new(0, 14, 1, -48), function()
		Net.send("Menu", "SalvageJunk", {})
	end, { textSize = 13, color = rgb(40, 12, 14), Name = "SALVAGE JUNK" })

	-- details -----------------------------------------------------------------
	local xb = UI.panel(page, UDim2.fromOffset(312, PAGE_H), UDim2.fromOffset(860, 0), { color = COL.Ink, t = 0.25, Name = "Details" })
	local vpBack = UI.frame(xb, { Name = "Preview", Size = UDim2.new(1, -24, 0, 156), Position = UDim2.fromOffset(12, 12), color = rgb(30, 24, 28), t = 0 })
	UI.gradient(vpBack, { rgb(90, 70, 70), rgb(16, 14, 18) }, nil, 90)
	UI.stroke(vpBack, COL.Gold, 1, 0.7)
	detail.vp, detail.cam = makeViewport(vpBack, UDim2.fromScale(1, 1), UDim2.new(), 1)
	detail.rarityBar = UI.frame(xb, { Name = "RarityBar", Size = UDim2.new(1, -24, 0, 2), Position = UDim2.fromOffset(12, 170), color = COL.GoldDeep, t = 0 })
	detail.name = UI.text(xb, "", { Name = "ItemName", Position = UDim2.fromOffset(14, 178), Size = UDim2.new(1, -28, 0, 50), font = UI.NAME, size = 19, color = COL.Bone, y = Enum.TextYAlignment.Top })
	detail.lines = UI.text(xb, "", { Name = "Lines", Position = UDim2.fromOffset(14, 230), Size = UDim2.new(1, -28, 0, PAGE_H - 230 - 150), size = 14, font = UI.BODY, color = COL.BoneDim, rich = true, y = Enum.TextYAlignment.Top, lineHeight = 1.08 })
	detail.equip = UI.button(xb, "EQUIP", UDim2.new(1, -24, 0, 38), UDim2.new(0, 12, 1, -140), function()
		if selected then
			equip(selected)
		end
	end, { kind = "primary", textSize = 16, Name = "Equip" })
	detail.upgrade = UI.button(xb, "UPGRADE", UDim2.new(1, -24, 0, 38), UDim2.new(0, 12, 1, -94), function()
		if selected then
			Net.send("Menu", "Upgrade", { id = selected.id })
		end
	end, { textSize = 12, color = rgb(46, 36, 16), Name = "Upgrade" })
	detail.salvage = UI.button(xb, "SALVAGE", UDim2.new(1, -24, 0, 38), UDim2.new(0, 12, 1, -48), function()
		if selected and not isEquipped(selected) and not selected.unique then
			Net.send("Menu", "Salvage", { id = selected.id })
			selected = nil
		end
	end, { textSize = 14, color = rgb(40, 12, 14), Name = "Salvage" })
	return page
end

local function buildCharacter(parent)
	local page = UI.frame(parent, { Name = "Character", Size = UDim2.new(1, -48, 0, PAGE_H), Position = UDim2.fromOffset(24, PAGE_Y) })
	local left = UI.panel(page, UDim2.fromOffset(640, PAGE_H), UDim2.new(), { color = COL.Ink, t = 0.25, Name = "Points" })
	pointsLabel = UI.text(left, "", { Name = "PointsLabel", Size = UDim2.fromOffset(600, 40), Position = UDim2.fromOffset(24, 16), font = UI.GOTHIC, size = 36, color = COL.GoldBright })
	UI.flourish(left, 420, UDim2.fromOffset(24, 64), { side = "left", AnchorPoint = Vector2.new(0, 0.5), color = COL.Gold })
	for i, s in STATS do
		local y = 90 + (i - 1) * 76
		local b = UI.frame(left, { Name = "Stat_" .. s[1], Size = UDim2.fromOffset(592, 64), Position = UDim2.fromOffset(24, y), color = COL.Ink3, t = 0.35 })
		UI.stroke(b, COL.Gold, 1, 0.75)
		UI.frame(b, { Name = "Accent", Size = UDim2.new(0, 3, 1, 0), color = COL.Blood, t = 0 })
		UI.text(b, s[2], { Name = "Name", Position = UDim2.fromOffset(18, 8), Size = UDim2.fromOffset(380, 26), font = UI.BOLD, size = 18, color = COL.Bone })
		UI.text(b, s[3], { Name = "Desc", Position = UDim2.fromOffset(18, 34), Size = UDim2.fromOffset(380, 20), size = 14, font = UI.BODY, color = COL.BoneFaint })
		statLabels[s[1]] = UI.text(b, "0", { Name = "Value", Position = UDim2.fromOffset(410, 8), Size = UDim2.fromOffset(90, 48), font = UI.GOTHIC, size = 40, x = Enum.TextXAlignment.Center, color = COL.GoldBright })
		UI.button(b, "+", UDim2.fromOffset(62, 44), UDim2.fromOffset(516, 10), function()
			Net.send("Menu", "Allocate", { stat = s[1] })
		end, { kind = "primary", textSize = 26, Name = "Allocate_" .. s[1] })
	end
	local right = UI.panel(page, UDim2.fromOffset(520, PAGE_H), UDim2.fromOffset(652, 0), { color = COL.Ink, t = 0.25, Name = "Summary" })
	sectionTitle(right, "SUMMARY", 24, 20, 470)
	derivedLabel = UI.text(right, "", { Name = "Derived", Position = UDim2.fromOffset(24, 50), Size = UDim2.fromOffset(470, PAGE_H - 70), size = 17, font = UI.BODY, color = COL.BoneDim, rich = true, y = Enum.TextYAlignment.Top, lineHeight = 1.25 })
	return page
end

local function buildQuests(parent)
	local page = UI.frame(parent, { Name = "Journal", Size = UDim2.new(1, -48, 0, PAGE_H), Position = UDim2.fromOffset(24, PAGE_Y) })
	local p = UI.panel(page, UDim2.fromScale(1, 1), UDim2.new(), { color = COL.Ink, t = 0.25, Name = "Quests" })
	sectionTitle(p, "QUESTS", 28, 20, 600)
	questList = UI.text(p, "", { Name = "QuestList", Position = UDim2.fromOffset(28, 52), Size = UDim2.new(1, -56, 1, -70), size = 18, font = UI.BODY, color = COL.Bone, y = Enum.TextYAlignment.Top, rich = true, lineHeight = 1.15 })
	return page
end

function Inv.build()
	local root
	gui, root = UI.layer("Inventory", 40)
	holder = UI.frame(root, { Name = "Holder", Size = UDim2.fromScale(1, 1), Visible = false })
	local dim = UI.frame(holder, { Name = "Dim", color = COL.Ink, t = 0.35 })
	UI.gradient(dim, nil, { { 0, 0.2 }, { 0.5, 0.5 }, { 1, 0.2 } }, 0)
	body = UI.panel(holder, UDim2.fromOffset(WIN_W, WIN_H), UDim2.fromScale(0.5, 0.52), { AnchorPoint = Vector2.new(0.5, 0.5), color = COL.Ink2, t = 0.08, edgeT = 0.4, bracketLen = 18, Name = "Window" })
	UI.new("UIScale", { Parent = body, Name = "Fit" })
	-- header: gothic tabs left, stats + close hint right
	local x = 26
	for _, t in { { "equipment", "EQUIPMENT" }, { "character", "CHARACTER" }, { "quests", "JOURNAL" } } do
		local _, _, api = UI.button(body, t[2], UDim2.fromOffset(210, 60), UDim2.fromOffset(x, 18), function()
			showPage(t[1])
		end, { kind = "tab", font = UI.GOTHIC, textSize = 36, Name = t[2] })
		tabButtons[t[1]] = api
		x += 218
	end
	UI.hline(body, { Size = UDim2.new(1, -52, 0, 1), Position = UDim2.fromOffset(26, 80), color = COL.Gold, t = 0.3 })
	UI.diamond(body, 7, UDim2.new(0.5, 0, 0, 80), { color = COL.GoldBright })
	headerInfo = UI.text(body, "", { Name = "HeaderInfo", Position = UDim2.new(1, -26, 0, 22), Size = UDim2.fromOffset(520, 22), AnchorPoint = Vector2.new(1, 0), font = UI.BOLD, size = 15, color = COL.BoneDim, rich = true, x = Enum.TextXAlignment.Right })
	UI.keyRow(body, { { { "I", "Tab" }, "Close" } }, { h = 20, size = 11, gap = 8, Name = "CloseHint", Position = UDim2.new(1, -26, 0, 62), AnchorPoint = Vector2.new(1, 0.5), color = COL.BoneFaint })
	pages.equipment = buildEquipment(body)
	pages.character = buildCharacter(body)
	pages.quests = buildQuests(body)
	showPage("equipment")
	showDetail(nil)
end

-- ------------------------------------------------------------------ refresh
local function filtered(p)
	local out = {}
	for _, it in p.inventory or {} do
		local ok = filter == "all"
			or (filter == "weapons" and not isGear(it))
			or (filter == "armor" and isGear(it) and it.slot ~= "Ring" and it.slot ~= "Amulet")
			or (filter == "trinkets" and isGear(it) and (it.slot == "Ring" or it.slot == "Amulet"))
		if ok then
			table.insert(out, it)
		end
	end
	local rIdx = function(it)
		return table.find(Weapons.RARITIES, it.rarity) or 1
	end
	table.sort(out, function(a, b)
		local ea, eb = isEquipped(a), isEquipped(b)
		if ea ~= eb then
			return ea
		end
		if rIdx(a) ~= rIdx(b) then
			return rIdx(a) > rIdx(b)
		end
		return score(a) > score(b)
	end)
	return out
end

local function makeCell(it, order: number)
	local col = rarityColor(it.rarity)
	local cell = UI.new("TextButton", { Parent = gridFrame, Name = "Cell", BackgroundColor3 = Palette.shade(col, 0.2), BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = order })
	UI.gradient(cell, { Palette.shade(col, 1.6), rgb(60, 60, 60) }, nil, 90)
	UI.stroke(cell, col, 1, 0.3)
	local sel = UI.stroke(cell, COL.Bone, 2, 0)
	sel.Name = "Sel"
	sel.Enabled = selected ~= nil and selected.id == it.id
	local vp, cam = makeViewport(cell, UDim2.fromScale(1, 1), UDim2.new(), 1)
	setIcon(vp, cam, it)
	UI.text(cell, shortType(it), { Name = "Type", Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 0, 13), size = 9, font = UI.BOLD, color = COL.BoneDim, strokeT = 0.5 })
	UI.text(cell, "LV " .. tostring(it.level or 1), { Name = "Lv", Position = UDim2.new(0, 4, 1, -16), Size = UDim2.new(1, -8, 0, 13), size = 10, font = UI.BOLD, x = Enum.TextXAlignment.Right, color = COL.Bone, strokeT = 0.4 })
	if (it.up or 0) > 0 then
		UI.text(cell, "+" .. it.up, { Name = "Up", Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 0, 13), size = 12, font = UI.BLACK, x = Enum.TextXAlignment.Right, color = COL.GoldBright, strokeT = 0.4 })
	end
	if isEquipped(it) then
		UI.diamond(cell, 12, UDim2.new(0, 11, 1, -11), { color = COL.GoldBright, stroke = COL.Ink, strokeT = 0.2, Name = "Equipped" })
		UI.text(cell, "E", { Name = "E", Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 11, 1, -11), AnchorPoint = Vector2.new(0.5, 0.5), size = 10, font = UI.BLACK, x = Enum.TextXAlignment.Center, color = COL.Ink })
	end
	local lastClick = 0
	cell.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastClick < 0.35 then
			equip(it)
		end
		lastClick = now
		select(it)
		UI.onClick()
	end)
	cell.MouseButton2Click:Connect(function()
		equip(it)
	end)
	cell.MouseEnter:Connect(function()
		hovered = it
		showDetail(it)
	end)
	cell.MouseLeave:Connect(function()
		if hovered == it then
			hovered = nil
			showDetail(selected)
		end
	end)
	return cell
end

function Inv.refresh()
	local p = C.profile
	if not p or not gui then
		return
	end
	local d = p.derived or {}
	headerInfo.Text = string.format('<font color="#E8E2D6">LV %d</font>   ·   <font color="#ECD08E">%s GOLD</font>   ·   %d SCRAP%s', p.level or 1, Util.fmt(p.gold or 0), p.scrap or 0, if p.landName and p.landName ~= "" then "   ·   " .. string.upper(p.landName) else "")
	for f, api in filterButtons do
		api.set(f == filter)
	end
	-- character page
	pointsLabel.Text = if (p.points or 0) > 0 then string.format("%d point%s to spend", p.points, if p.points > 1 then "s" else "") else "No points - level up by killing things"
	for k, lab in statLabels do
		lab.Text = tostring((p.stats or {})[k] or 0)
	end
	local summary = string.format(
		"<b>HEALTH</b>  %d\n<b>DAMAGE</b>  x%.2f\n<b>ARMOR</b>  %d  <font color=\"#9AA0B4\">(-%d%% damage taken)</font>\n<b>CRIT</b>  %d%%  ·  <b>CRIT DMG</b>  x%.2f\n<b>SPEED</b>  %d%%   <b>LIFESTEAL</b>  %.1f%%\n<b>TIME STOP</b>  %.2fs  ·  <b>CD</b>  %.1fs\n<b>BLOCK</b>  +%d%%   <b>REGEN</b>  %.1f/s",
		d.maxHp or 0,
		d.dmgMult or 1,
		d.armor or 0,
		math.floor((d.armorRed or 0) * 100 + 0.5),
		math.floor(((d.crit or 0) + 0.05) * 100 + 0.5),
		1.75 + (d.critDmg or 0),
		math.floor((d.speed or 1) * 100 + 0.5),
		(d.lifesteal or 0) * 100,
		d.tsDuration or 1,
		d.tsCooldown or 14,
		math.floor((d.block or 0) * 100 + 0.5),
		d.regen or 0
	)
	statsLabel.Text = summary
	derivedLabel.Text = summary .. string.format("\n\n<b>FLASKS</b>  %d / %d\n%s", p.flasks or 0, p.maxFlasks or 0, if p.blessed then '\n<font color="#ECD08E">BLESSED BY THE OLD GOD</font>' else "")
	-- doll slots
	for slot, w in slotWidgets do
		local it = equippedIn(slot)
		local id = it and (it.id .. ":" .. (it.up or 0))
		if w.id ~= id then
			w.id = id
			setIcon(w.vp, w.cam, it)
		end
		w.stroke.Color = if it then rarityColor(it.rarity) else COL.GoldDeep
		w.frame.BackgroundColor3 = if it then Palette.shade(rarityColor(it.rarity), 0.25) else COL.Ink3
		w.label.Visible = it == nil
		w.up.Text = if it and (it.up or 0) > 0 then "+" .. it.up else ""
	end
	-- bag grid: only rebuilt when the contents actually change
	local list = filtered(p)
	local sigParts = { filter }
	for _, it in list do
		table.insert(sigParts, it.id .. ":" .. (it.up or 0) .. (if isEquipped(it) then "E" else ""))
	end
	local sig = table.concat(sigParts, "|")
	if sig ~= lastSig then
		lastSig = sig
		for _, c in gridFrame:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		cellFor = {}
		for i, it in list do
			cellFor[it.id] = makeCell(it, i)
		end
	end
	-- keep the selection alive
	if selected then
		selected = findItem(selected.id)
	end
	showDetail(hovered or selected)
	-- quests
	local q = {}
	for _, quest in p.quests or {} do
		table.insert(q, string.format('<font color="#%s"><b>%s</b></font>%s\n<font color="#A8A092">%s%s</font>', if quest.done then "8ACC78" else "ECD08E", string.upper(quest.title or "?"), if quest.done then '  <font color="#8ACC78">·  DONE</font>' else "", quest.text or "", if quest.progress then "  (" .. quest.progress .. ")" else ""))
	end
	questList.Text = if #q > 0 then table.concat(q, "\n\n") else "No quests yet. Talk to people. Some of them even have problems you can stab."
end

function Inv.toggle(on: boolean?)
	if on == nil then
		on = not open
	end
	if C.menuOpen or C.inCutscene then
		on = false
	end
	open = on
	holder.Visible = on
	C.cursor.inventory = on or nil
	if on then
		local fit = body:FindFirstChild("Fit")
		if fit then
			local ds = UI.designSize()
			fit.Scale = math.min(1, (ds.X - 40) / WIN_W, (ds.Y - 40) / WIN_H)
		end
		refreshDoll()
		Inv.refresh()
		UI.onClick()
	end
end

function Inv.isOpen(): boolean
	return open
end

local function hidePlayerList()
	for _ = 1, 20 do
		local ok = pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end

function Inv.init()
	Inv.build()
	task.spawn(hidePlayerList)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp or UserInputService:GetFocusedTextBox() then
			return
		end
		if C.paused then
			return
		end
		if input.KeyCode == Enum.KeyCode.Tab or input.KeyCode == Enum.KeyCode.ButtonSelect or input.KeyCode == Enum.KeyCode.I then
			Inv.toggle()
		elseif open and input.KeyCode == Enum.KeyCode.Backspace then
			Inv.toggle(false)
		end
	end)
	Net.on("Profile", function()
		task.defer(function()
			if open then
				Inv.refresh()
			end
		end)
	end)
	Net.on("Scene", function(name)
		if name == "gearChanged" and open then
			task.delay(0.15, refreshDoll)
		end
	end)
	player.CharacterAdded:Connect(function()
		if open then
			task.delay(0.3, refreshDoll)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not open then
			return
		end
		if not dragging then
			dollYaw += dt * 0.25
		end
		spinDoll()
		if detail.vp then
			for _, m in detail.vp:GetChildren() do
				if m:IsA("Model") then
					m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, dt * 0.9, 0) * (m:GetPivot() - m:GetPivot().Position))
				end
			end
		end
	end)
end

return Inv
