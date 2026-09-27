--!nonstrict
-- One-off scripted visuals (v3, film-intro style): kinetic chapter titles (words slam
-- in; modern times get a heavy sans + blood bar, fantasy titles a blackletter card),
-- the TV death report, the truck, the isekai STATUS appraisal (with a WEAK stamp), phone
-- chat, bursting out of the ground, prison bubble, power-ups, glitches, endings &
-- credits, typing QTE, loading screen (rotating diamonds + tips), tower ascent.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Kit = require(Shared.Kit)
local Util = require(Shared.Util)
local Palette = require(Shared.Palette)
local C = require(script.Parent.C)
local UI = require(script.Parent.UI)

local Scenes: any = {}
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local rgb = Color3.fromRGB
local V2 = Vector2.new
local COL = UI.COL
local H = {}

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function clear(root: Instance)
	for _, c in root:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function typeInto(label: TextLabel, speed: number?, alive: () -> boolean)
	local text = label.Text
	local n = utf8.len(text) or #text
	label.MaxVisibleGraphemes = 0
	task.spawn(function()
		local i = 0
		while i < n and alive() do
			i += 1
			label.MaxVisibleGraphemes = i
			task.wait(1 / (speed or 40))
		end
		if alive() then
			label.MaxVisibleGraphemes = -1
		end
	end)
end

-- ------------------------------------------------------------------ title cards
local titleToken = 0
local function words(text: string)
	local out = {}
	for wd in string.gmatch(text, "%S+") do
		table.insert(out, wd)
	end
	return out
end

function H.title(d)
	local _, r = UI.layer("Title", 35)
	titleToken += 1
	local tok = titleToken
	clear(r)
	local text = tostring(d.text or "")
	local sub = tostring(d.sub or "")
	local modern = text:find("%d") ~= nil
	local card = UI.frame(r, { Name = "Card" })
	local band = UI.frame(card, { Name = "Band", Size = UDim2.new(1, 0, 0, 320), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = V2(0.5, 0.5), color = COL.Ink, t = 0.35 })
	UI.gradient(band, nil, { { 0, 1 }, { 0.3, 0.2 }, { 0.7, 0.2 }, { 1, 1 } }, 90)
	if modern then
		-- kinetic typography: every word slams in, digits in blood red, a bar sweeps under
		local list = words(text)
		local size = if #text > 18 then 96 else 120
		local widths, total = {}, 0
		for i, wd in list do
			widths[i] = UI.measure(wd, size, UI.BLACK).X + 8
			total += widths[i] + 30
		end
		local row = UI.frame(card, { Name = "Words", Size = UDim2.fromOffset(total, size + 20), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = V2(0.5, 0.5) })
		UI.list(row, 30, true, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		for i, wd in list do
			local slot = UI.frame(row, { Name = "Slot" .. i, Size = UDim2.fromOffset(widths[i], size + 20), LayoutOrder = i })
			local l = UI.text(slot, wd, { Name = "Word", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5), font = UI.BLACK, size = size, color = if wd:find("%d") then COL.BloodBright else COL.Bone, x = Enum.TextXAlignment.Center, wrap = false, TextTransparency = 1 })
			UI.stroke(l, rgb(10, 4, 6), 2, 0.2, true)
			task.delay(0.1 + (i - 1) * 0.17, function()
				if titleToken ~= tok then
					return
				end
				UI.slam(l, 2.6, 0.24)
				UI.sfx("Rumble", { pitch = 1.3 + i * 0.08, vol = 0.35, ignoreTime = true })
				if C.Controller and C.Controller.shake then
					C.Controller.shake(0.6, 0.12)
				end
				row.Position = UDim2.new(0.5, math.random(-6, 6), 0.42, math.random(-4, 4))
				tween(row, 0.12, { Position = UDim2.fromScale(0.5, 0.42) })
			end)
		end
		local bar = UI.frame(card, { Name = "Bar", Size = UDim2.fromOffset(0, 10), Position = UDim2.new(0.5, 0, 0.42, size / 2 + 22), AnchorPoint = V2(0.5, 0.5), color = COL.Blood, t = 0 })
		UI.gradient(bar, nil, { { 0, 1 }, { 0.12, 0 }, { 0.88, 0 }, { 1, 1 } }, 0)
		task.delay(0.1 + #list * 0.17, function()
			tween(bar, 0.45, { Size = UDim2.fromOffset(total + 80, 10) }, Enum.EasingStyle.Quint)
		end)
		local s = UI.text(card, sub, { Name = "Sub", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.42, size / 2 + 42), font = UI.SERIF, size = 32, color = COL.BoneDim, x = Enum.TextXAlignment.Center, strokeT = 0.6 })
		s.MaxVisibleGraphemes = 0
		task.delay(0.35 + #list * 0.17, function()
			if titleToken == tok then
				typeInto(s, 38, function()
					return titleToken == tok and card.Parent ~= nil
				end)
			end
		end)
	else
		-- blackletter title card with flourishes that grow out of the centre
		local top = UI.flourish(card, 700, UDim2.fromScale(0.5, 0.31), { color = COL.Gold, Name = "Top" })
		local holder, t = UI.display(card, text, { Name = "Title", Size = UDim2.new(1, 0, 0, 140), Position = UDim2.fromScale(0, 0.335), size = if #text > 22 then 96 else 128, x = Enum.TextXAlignment.Center, wrap = false, from = COL.Bone, mid = COL.GoldBright, to = rgb(130, 108, 80), midAt = 0.6, outlineSize = 2 })
		local _ = t
		local sc = UI.new("UIScale", { Parent = holder, Name = "Slam", Scale = 1.25 })
		tween(sc, 0.9, { Scale = 1 }, Enum.EasingStyle.Quint)
		UI.text(card, sub, { Name = "Sub", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0, 0.475), font = UI.SERIF, size = 32, color = COL.BoneDim, x = Enum.TextXAlignment.Center, strokeT = 0.6 })
		local bottom = UI.flourish(card, 440, UDim2.fromScale(0.5, 0.56), { color = COL.Gold, dots = false, Name = "Bottom" })
		for _, f in { top, bottom } do
			local w = f.Size.X.Offset
			f.Size = UDim2.fromOffset(0, 16)
			tween(f, 1.1, { Size = UDim2.fromOffset(w, 16) }, Enum.EasingStyle.Quint)
		end
		UI.setAlpha(card, 0)
		UI.fadeTo(card, 1, 0.9)
	end
	UI.sfx("Rumble", { pitch = 0.4, vol = 0.6 })
	task.delay(d.dur or 3.5, function()
		if titleToken == tok and card.Parent then
			UI.fadeOut(card, 0.9, true)
		end
	end)
end

function H.skip()
	C.skipAll = true
	task.delay(0.5, function()
		C.skipAll = false
	end)
end

function H.teleported(d)
	if d.cf then
		local _, y = d.cf:ToOrientation()
		C.Controller.setYaw(y, 0)
	end
end

function H.face(d)
	if d.pos then
		C.Controller.face(d.pos)
	end
end

-- ------------------------------------------------------------------ blink / flashes
function H.blink(d)
	local g = UI.screen("Blink", 90)
	local top = UI.new("Frame", { Parent = g, Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 })
	local bot = UI.new("Frame", { Parent = g, Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 })
	local times = d.times or 2
	task.spawn(function()
		for i = 1, times do
			tween(top, 0.35, { Position = UDim2.fromScale(0, -0.5 + (if i < times then 0.3 else 0)) })
			tween(bot, 0.35, { Position = UDim2.fromScale(0, 1 - (if i < times then 0.3 else 0)) })
			task.wait(0.5)
			if i < times then
				tween(top, 0.15, { Position = UDim2.fromScale(0, 0) })
				tween(bot, 0.15, { Position = UDim2.fromScale(0, 0.5) })
				task.wait(0.35)
			end
		end
		task.wait(0.4)
		top:Destroy()
		bot:Destroy()
	end)
end

function H.flashWhite(d)
	local g = UI.screen("Flash", 95)
	local f = UI.new("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = d.color or Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0 })
	tween(f, d.inT or 0.15, { BackgroundTransparency = 0 })
	task.delay((d.inT or 0.15) + (d.hold or 0.3), function()
		tween(f, d.outT or 1.2, { BackgroundTransparency = 1 })
		Debris:AddItem(f, (d.outT or 1.2) + 0.1)
	end)
	C.Audio.play("Glass", { pitch = 0.3, vol = 0.7, ignoreTime = true })
end

-- ------------------------------------------------------------------ phone
local phoneToken = 0
function H.phone(d)
	local _, r = UI.layer("Phone", 36)
	phoneToken += 1
	local tok = phoneToken
	clear(r)
	local ph = UI.frame(r, { Name = "Phone", Size = UDim2.fromOffset(372, 660), Position = UDim2.new(1, -90, 1, 700), AnchorPoint = V2(1, 1), color = rgb(18, 18, 22), t = 0 })
	UI.corner(ph, 44)
	UI.stroke(ph, rgb(58, 58, 66), 5, 0)
	local scr = UI.frame(ph, { Name = "Screen", Size = UDim2.new(1, -22, 1, -22), Position = UDim2.fromOffset(11, 11), color = rgb(8, 8, 12), t = 0, clip = true })
	UI.corner(scr, 34)
	UI.gradient(scr, { rgb(22, 22, 30), rgb(8, 8, 12) }, nil, 90)
	local notch = UI.frame(scr, { Name = "Notch", Size = UDim2.fromOffset(104, 28), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = V2(0.5, 0), color = Color3.new(0, 0, 0), t = 0 })
	UI.corner(notch, 14)
	UI.text(scr, d.time or "7:02", { Name = "Clock", Size = UDim2.fromOffset(80, 20), Position = UDim2.fromOffset(28, 14), font = UI.BOLD, size = 15, color = Color3.new(1, 1, 1) })
	for i = 1, 4 do
		UI.frame(scr, { Name = "Signal", Size = UDim2.fromOffset(3, 3 + i * 2), Position = UDim2.new(1, -86 + i * 5, 0, 30), AnchorPoint = V2(0, 1), color = Color3.new(1, 1, 1), t = if i == 4 then 0.6 else 0 })
	end
	local bat = UI.frame(scr, { Name = "Battery", Size = UDim2.fromOffset(24, 11), Position = UDim2.new(1, -50, 0, 19), t = 1 })
	UI.stroke(bat, Color3.new(1, 1, 1), 1, 0.3)
	UI.corner(bat, 3)
	UI.frame(bat, { Name = "Level", Size = UDim2.fromScale(0.14, 1), color = rgb(255, 60, 60), t = 0 })
	-- header
	local head = UI.frame(scr, { Name = "Header", Size = UDim2.new(1, 0, 0, 62), Position = UDim2.fromOffset(0, 46), color = rgb(20, 20, 26), t = 0.2 })
	UI.text(head, "<", { Size = UDim2.fromOffset(20, 62), Position = UDim2.fromOffset(16, 0), font = UI.BOLD, size = 24, color = rgb(70, 140, 255) })
	local name = d.from or "Friend"
	local av = UI.frame(head, { Name = "Avatar", Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(44, 11), color = rgb(90, 90, 110), t = 0 })
	UI.corner(av, 0, 0.5)
	UI.gradient(av, { rgb(140, 120, 200), rgb(70, 60, 120) }, nil, 45)
	UI.text(av, string.upper(name:sub(1, 1)), { font = UI.BOLD, size = 18, color = Color3.new(1, 1, 1), x = Enum.TextXAlignment.Center })
	UI.text(head, name, { Name = "Name", Size = UDim2.fromOffset(220, 22), Position = UDim2.fromOffset(94, 11), font = UI.BOLD, size = 17, color = Color3.new(1, 1, 1) })
	UI.text(head, "online", { Name = "Status", Size = UDim2.fromOffset(220, 16), Position = UDim2.fromOffset(94, 33), font = UI.BODY, size = 12, color = rgb(110, 200, 130) })
	UI.frame(scr, { Name = "Divider", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 108), color = Color3.new(1, 1, 1), t = 0.9 })
	-- messages
	local msgs = UI.frame(scr, { Name = "Messages", Size = UDim2.new(1, -28, 1, -186), Position = UDim2.fromOffset(14, 120) })
	UI.list(msgs, 8)
	-- input bar
	local input = UI.frame(scr, { Name = "Input", Size = UDim2.new(1, -70, 0, 38), Position = UDim2.new(0, 14, 1, -52), color = rgb(30, 30, 38), t = 0 })
	UI.corner(input, 19)
	UI.text(input, "Message", { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -16, 1, 0), font = UI.BODY, size = 15, color = rgb(110, 110, 120) })
	local send = UI.frame(scr, { Name = "Send", Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -52, 1, -52), color = rgb(40, 118, 255), t = 0 })
	UI.corner(send, 0, 0.5)
	UI.text(send, "^", { font = UI.BLACK, size = 18, color = Color3.new(1, 1, 1), x = Enum.TextXAlignment.Center })
	tween(ph, 0.55, { Position = UDim2.new(1, -90, 1, -40) }, Enum.EasingStyle.Back)
	UI.sfx("Phone", { pitch = 1.4 })

	local function bubble(text, mine, order)
		local maxW = 236
		local ts = UI.measure(text, 16, UI.BODY, maxW - 28)
		local w = math.min(maxW, ts.X + 40)
		local h = ts.Y + 20
		local row = UI.frame(msgs, { Name = "Row", Size = UDim2.new(1, 0, 0, h), LayoutOrder = order })
		local b = UI.frame(row, { Name = if mine then "Mine" else "Theirs", Size = UDim2.fromOffset(w, h), Position = UDim2.fromScale(if mine then 1 else 0, 0), AnchorPoint = V2(if mine then 1 else 0, 0), color = if mine then rgb(40, 118, 255) else rgb(48, 48, 58), t = 0 })
		UI.corner(b, 16)
		UI.text(b, text, { Name = "Text", Size = UDim2.new(1, -28, 1, -16), Position = UDim2.fromOffset(14, 8), font = UI.BODY, size = 16, color = Color3.new(1, 1, 1), y = Enum.TextYAlignment.Top })
		b.Size = UDim2.fromOffset(w * 0.6, h * 0.6)
		tween(b, 0.18, { Size = UDim2.fromOffset(w, h) }, Enum.EasingStyle.Back)
		return row
	end
	task.spawn(function()
		local order = 0
		for _, msg in d.messages or {} do
			if phoneToken ~= tok then
				return
			end
			order += 1
			if not msg.me then
				local typing = UI.frame(msgs, { Name = "Typing", Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order })
				local tb = UI.frame(typing, { Size = UDim2.fromOffset(62, 34), color = rgb(48, 48, 58), t = 0 })
				UI.corner(tb, 17)
				local dots = {}
				for k = 1, 3 do
					local dot = UI.frame(tb, { Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 10 + k * 12, 0.5, 0), AnchorPoint = V2(0.5, 0.5), color = Color3.new(1, 1, 1), t = 0.4 })
					UI.corner(dot, 0, 0.5)
					table.insert(dots, dot)
				end
				local t0 = os.clock()
				while os.clock() - t0 < 0.9 and phoneToken == tok do
					for k, dot in dots do
						dot.BackgroundTransparency = 0.25 + (math.sin((os.clock() - t0) * 9 - k) * 0.5 + 0.5) * 0.6
					end
					task.wait(0.05)
				end
				if phoneToken ~= tok then
					return
				end
				typing:Destroy()
			else
				task.wait(0.8)
			end
			if phoneToken ~= tok then
				return
			end
			bubble(tostring(msg.text or ""), msg.me == true, order)
			UI.sfx("Phone", { pitch = if msg.me then 1.8 else 1.5, vol = 0.6 })
		end
		task.wait(d.hold or 3)
		if phoneToken == tok then
			tween(ph, 0.45, { Position = UDim2.new(1, -90, 1, 700) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.5, function()
				ph:Destroy()
			end)
		end
	end)
end

-- ------------------------------------------------------------------ appraisal
function H.appraisal(d)
	local _, r = UI.layer("Appraisal", 37)
	clear(r)
	local VIO = COL.Violet
	local card = UI.panel(r, UDim2.fromOffset(600, 640), UDim2.new(0.5, 0, 0.5, -10), { AnchorPoint = V2(0.5, 0.5), color = COL.Ink, t = 0.06, edge = VIO, edgeT = 0.35, bracketColor = VIO, bracketLen = 18, Name = "Status" })
	UI.gradient(card, { rgb(120, 104, 190), rgb(255, 255, 255) }, nil, 90)
	UI.text(card, "APPRAISAL OF THE SUMMONED", { Name = "Kicker", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 24), font = UI.BOLD, size = 12, color = VIO, x = Enum.TextXAlignment.Center })
	UI.display(card, "STATUS", { Name = "Header", Size = UDim2.new(1, 0, 0, 76), Position = UDim2.fromOffset(0, 40), size = 72, x = Enum.TextXAlignment.Center, from = rgb(240, 236, 255), to = VIO })
	UI.flourish(card, 420, UDim2.new(0.5, 0, 0, 124), { color = VIO })
	local rows = {
		{ "STRENGTH", 3, 100 },
		{ "MAGIC", 0, 100 },
		{ "AGILITY", 6, 100 },
		{ "LUCK", 1, 100 },
		{ "CHARISMA", 2, 100 },
	}
	for i, row in rows do
		local y = 150 + (i - 1) * 44
		UI.text(card, row[1], { Name = "Stat", Position = UDim2.fromOffset(52, y), Size = UDim2.fromOffset(160, 30), font = UI.BOLD, size = 16, color = COL.Bone })
		local back = UI.frame(card, { Name = "Track", Position = UDim2.fromOffset(212, y + 11), Size = UDim2.fromOffset(250, 8), color = rgb(30, 26, 48), t = 0 })
		UI.stroke(back, VIO, 1, 0.6)
		local fill = UI.frame(back, { Name = "Fill", Size = UDim2.fromScale(0, 1), color = VIO, t = 0 })
		local num = UI.text(card, "", { Name = "Num", Position = UDim2.fromOffset(476, y), Size = UDim2.fromOffset(70, 30), font = UI.BLACK, size = 18, color = COL.Bone, x = Enum.TextXAlignment.Right })
		task.delay(0.4 + i * 0.32, function()
			if not card.Parent then
				return
			end
			tween(fill, 0.5, { Size = UDim2.fromScale(math.max(row[2] / row[3], 0.012), 1) })
			num.Text = tostring(row[2]) .. " / " .. row[3]
			UI.sfx("Tick", { pitch = 1.2 })
		end)
	end
	UI.hline(card, { Size = UDim2.new(1, -100, 0, 1), Position = UDim2.new(0.5, 0, 0, 380), AnchorPoint = V2(0.5, 0), color = VIO, t = 0.5 })
	UI.text(card, "SKILL", { Name = "SkillTag", Position = UDim2.fromOffset(52, 392), Size = UDim2.fromOffset(120, 26), font = UI.BOLD, size = 12, color = VIO })
	UI.text(card, "TIME STOP  ·  1.0 s", { Name = "Skill", Position = UDim2.fromOffset(52, 412), Size = UDim2.fromOffset(460, 30), font = UI.BLACK, size = 20, color = rgb(214, 204, 255) })
	UI.text(card, "POWER LEVEL", { Name = "PowerTag", Position = UDim2.fromOffset(0, 460), Size = UDim2.new(1, 0, 0, 18), font = UI.BOLD, size = 13, color = COL.BoneDim, x = Enum.TextXAlignment.Center })
	local PX = -110
	local pl = UI.text(card, "", { Name = "Power", Position = UDim2.new(0.5, PX, 0, 530), AnchorPoint = V2(0.5, 0.5), Size = UDim2.fromOffset(240, 110), font = UI.GOTHIC, size = 120, x = Enum.TextXAlignment.Center, color = COL.BloodBright, strokeT = 0.2 })
	UI.text(card, "(average farmhand: 12)", { Name = "Farmhand", Position = UDim2.new(0.5, PX, 0, 600), AnchorPoint = V2(0.5, 0.5), Size = UDim2.fromOffset(300, 24), font = UI.SERIF, size = 19, x = Enum.TextXAlignment.Center, color = COL.BoneFaint })
	-- the verdict stamp
	local stamp = UI.frame(card, { Name = "Stamp", Size = UDim2.fromOffset(250, 96), Position = UDim2.new(0.5, 125, 0, 540), AnchorPoint = V2(0.5, 0.5), Rotation = -12, Visible = false })
	UI.stroke(stamp, COL.BloodBright, 5, 0.1)
	UI.text(stamp, "WEAK", { Name = "Word", font = UI.BLACK, size = 74, color = COL.BloodBright, x = Enum.TextXAlignment.Center, TextTransparency = 0.05 })
	task.delay(2.8, function()
		if not card.Parent then
			return
		end
		pl.Text = tostring(d.power or 4)
		UI.slam(pl, 2.2, 0.3)
		UI.sfx("Glass", { pitch = 0.6 })
		for _ = 1, 12 do
			if not card.Parent then
				return
			end
			pl.Position = UDim2.new(0.5, PX + math.random(-7, 7), 0, 530 + math.random(-4, 4))
			task.wait(0.03)
		end
		if card.Parent then
			pl.Position = UDim2.new(0.5, PX, 0, 530)
		end
	end)
	task.delay(4, function()
		if card.Parent then
			stamp.Visible = true
			local sc = UI.new("UIScale", { Parent = stamp, Scale = 3 })
			tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			UI.sfx("Explosion", { pitch = 1.6, vol = 0.5 })
			if C.Controller and C.Controller.shake then
				C.Controller.shake(1.5, 0.25)
			end
		end
	end)
	task.delay(d.dur or 8, function()
		if card.Parent then
			UI.fadeOut(card, 0.5, true)
		end
	end)
end

-- ------------------------------------------------------------------ TV news
function H.tv(d)
	local base = CFrame.new(6000, 300, 6000)
	local room = Instance.new("Model")
	room.Name = "TVRoom"
	local wall = rgb(40, 44, 64)
	Kit.part(room, Vector3.new(40, 1, 40), base, rgb(60, 44, 36), Enum.Material.WoodPlanks)
	Kit.part(room, Vector3.new(40, 16, 1), base * CFrame.new(0, 8, -14), wall)
	Kit.part(room, Vector3.new(40, 16, 1), base * CFrame.new(0, 8, 14), wall)
	Kit.part(room, Vector3.new(1, 16, 40), base * CFrame.new(-14, 8, 0), wall)
	Kit.part(room, Vector3.new(1, 16, 40), base * CFrame.new(14, 8, 0), wall)
	Kit.part(room, Vector3.new(40, 1, 40), base * CFrame.new(0, 16, 0), rgb(30, 30, 40))
	-- TV
	Kit.part(room, Vector3.new(10, 3, 3), base * CFrame.new(0, 2, -11), rgb(50, 36, 28), Enum.Material.WoodPlanks)
	local tvBody = Kit.part(room, Vector3.new(9, 6, 1.2), base * CFrame.new(0, 6.6, -11.5), rgb(20, 20, 22))
	local screen = Kit.part(room, Vector3.new(8.2, 5.2, 0.1), base * CFrame.new(0, 6.6, -10.85), rgb(10, 10, 20), Enum.Material.SmoothPlastic)
	local glow = Kit.part(room, Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, 6.6, -9), rgb(0, 0, 0), nil, { Transparency = 1 })
	local tvLight = Kit.pointLight(glow, rgb(140, 170, 255), 26, 2.5, true)
	-- couch silhouette
	Kit.part(room, Vector3.new(12, 2.5, 4), base * CFrame.new(0, 1.8, 6), rgb(60, 30, 40), Enum.Material.Fabric)
	Kit.part(room, Vector3.new(12, 4, 1.4), base * CFrame.new(0, 3.5, 8), rgb(56, 28, 38), Enum.Material.Fabric)
	-- a pixel cat on the couch
	Kit.part(room, Vector3.new(1.6, 1.2, 2.4), base * CFrame.new(3, 3.6, 5.8), rgb(230, 150, 60))
	Kit.part(room, Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(3, 4.2, 4.4), rgb(230, 150, 60))
	room.Parent = workspace
	-- broadcast (SurfaceGui on the TV screen)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(820, 520)
	sg.LightInfluence = 0
	sg.Brightness = 1.6
	sg.Parent = screen
	local bg = UI.new("Frame", { Parent = sg, Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(14, 22, 50), BorderSizePixel = 0 })
	UI.new("UIGradient", { Parent = bg, Color = ColorSequence.new(rgb(34, 58, 120), rgb(8, 10, 24)), Rotation = 90 })
	-- studio backdrop: skyline blocks
	for i = 0, 11 do
		local hgt = 60 + (i * 37) % 110
		UI.new("Frame", { Parent = bg, Size = UDim2.fromOffset(62, hgt), Position = UDim2.new(0, i * 70, 1, -110), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = rgb(20, 30, 64), BorderSizePixel = 0 })
	end
	-- channel bug + LIVE + clock
	local bug = UI.new("Frame", { Parent = bg, Size = UDim2.fromOffset(120, 44), Position = UDim2.fromOffset(22, 18), BackgroundColor3 = rgb(210, 24, 34), BorderSizePixel = 0 })
	UI.text(bug, d.channel or "CH 9", { font = UI.BLACK, size = 26, color = Color3.new(1, 1, 1), x = Enum.TextXAlignment.Center })
	UI.text(bg, "NEWS TONIGHT", { Position = UDim2.fromOffset(152, 18), Size = UDim2.fromOffset(300, 44), font = UI.BLACK, size = 24, color = Color3.new(1, 1, 1) })
	local live = UI.new("Frame", { Parent = bg, Size = UDim2.fromOffset(96, 34), Position = UDim2.new(1, -118, 0, 22), BackgroundColor3 = rgb(230, 30, 40), BorderSizePixel = 0 })
	UI.new("Frame", { Parent = live, Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 12, 0.5, -5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	UI.text(live, "LIVE", { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -30, 1, 0), font = UI.BLACK, size = 20, color = Color3.new(1, 1, 1) })
	UI.text(bg, d.clock or "7:58 PM", { Position = UDim2.new(1, -118, 0, 58), Size = UDim2.fromOffset(96, 20), font = UI.BOLD, size = 15, color = rgb(210, 220, 255), x = Enum.TextXAlignment.Center })
	-- anchor (pixel bust)
	local anchor = UI.new("Frame", { Parent = bg, Size = UDim2.fromOffset(200, 260), Position = UDim2.fromOffset(80, 100), BackgroundTransparency = 1 })
	UI.new("Frame", { Parent = anchor, Size = UDim2.fromOffset(200, 120), Position = UDim2.fromOffset(0, 140), BackgroundColor3 = rgb(34, 36, 56), BorderSizePixel = 0 })
	UI.new("Frame", { Parent = anchor, Size = UDim2.fromOffset(30, 90), Position = UDim2.fromOffset(85, 140), BackgroundColor3 = rgb(180, 30, 40), BorderSizePixel = 0 })
	local head = UI.new("Frame", { Parent = anchor, Size = UDim2.fromOffset(110, 110), Position = UDim2.fromOffset(45, 30), BackgroundColor3 = rgb(236, 190, 150), BorderSizePixel = 0 })
	UI.new("Frame", { Parent = head, Size = UDim2.fromOffset(120, 30), Position = UDim2.fromOffset(-5, -10), BackgroundColor3 = rgb(60, 40, 30), BorderSizePixel = 0 })
	UI.new("Frame", { Parent = head, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(28, 45), BackgroundColor3 = rgb(30, 30, 30), BorderSizePixel = 0 })
	UI.new("Frame", { Parent = head, Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(68, 45), BackgroundColor3 = rgb(30, 30, 30), BorderSizePixel = 0 })
	local mouth = UI.new("Frame", { Parent = head, Size = UDim2.fromOffset(40, 8), Position = UDim2.fromOffset(35, 80), BackgroundColor3 = rgb(120, 40, 40), BorderSizePixel = 0 })
	-- victim photo
	local photo = UI.new("ViewportFrame", { Parent = bg, Size = UDim2.fromOffset(250, 220), Position = UDim2.fromOffset(500, 100), BackgroundColor3 = rgb(200, 200, 205), Ambient = rgb(200, 200, 200), LightDirection = Vector3.new(-0.5, -1, -1) })
	UI.stroke(photo, Color3.new(1, 1, 1), 6)
	local tag = UI.new("Frame", { Parent = bg, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(500, 326), BackgroundColor3 = rgb(10, 12, 24), BorderSizePixel = 0 })
	UI.text(tag, "VICTIM  ·  AGE UNKNOWN", { font = UI.BOLD, size = 15, color = rgb(255, 220, 120), x = Enum.TextXAlignment.Center })
	local vcam = Instance.new("Camera")
	vcam.FieldOfView = 30
	vcam.Parent = photo
	photo.CurrentCamera = vcam
	local ch = player.Character
	if ch then
		ch.Archivable = true
		local ok, clone = pcall(function()
			return ch:Clone()
		end)
		if ok and clone then
			for _, x in clone:GetDescendants() do
				if x:IsA("Script") or x:IsA("LocalScript") or x:IsA("Humanoid") then
					x:Destroy()
				elseif x:IsA("BasePart") then
					x.Anchored = true
					x.LocalTransparencyModifier = 0
				elseif x:IsA("SurfaceGui") then
					x.Enabled = true
				end
			end
			clone:PivotTo(CFrame.new(0, 0, 0))
			clone.Parent = photo
			local headPart = clone:FindFirstChild("Head")
			local hp = if headPart then headPart.Position else Vector3.new(0, 1.6, 0)
			vcam.CFrame = CFrame.lookAt(hp + Vector3.new(0, 0.2, -6.5), hp - Vector3.new(0, 0.6, 0))
		end
	end
	-- lower third: BREAKING NEWS block + headline bar + ticker
	local lower = UI.new("Frame", { Parent = bg, Size = UDim2.new(1, -40, 0, 96), Position = UDim2.new(0, 20, 1, -126), BackgroundTransparency = 1 })
	local brk = UI.new("Frame", { Parent = lower, Size = UDim2.fromOffset(250, 40), BackgroundColor3 = rgb(210, 24, 34), BorderSizePixel = 0 })
	UI.text(brk, "BREAKING NEWS", { font = UI.BLACK, size = 24, color = Color3.new(1, 1, 1), x = Enum.TextXAlignment.Center })
	local hl = UI.new("Frame", { Parent = lower, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 42), BackgroundColor3 = rgb(244, 244, 246), BorderSizePixel = 0 })
	UI.new("Frame", { Parent = hl, Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = rgb(210, 24, 34), BorderSizePixel = 0 })
	UI.text(hl, string.upper(d.headline or "LOCAL NOBODY HIT BY TRUCK"), { Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -30, 1, 0), font = UI.BLACK, size = 25, color = rgb(16, 16, 22) })
	local tickerBack = UI.new("Frame", { Parent = bg, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -24), BackgroundColor3 = rgb(10, 10, 16), BorderSizePixel = 0, ClipsDescendants = true })
	local ticker = UI.text(tickerBack, d.ticker or "", { Size = UDim2.fromOffset(3000, 24), Position = UDim2.fromOffset(820, 0), font = UI.BOLD, size = 16, wrap = false, color = rgb(255, 214, 90) })
	-- camera push-in + animation
	C.inCutscene = true
	C.Mood.apply("tvroom", 0.1)
	local t0 = os.clock()
	local dur = d.dur or 26
	local conn
	local alive = true
	conn = RunService.RenderStepped:Connect(function()
		if not alive then
			return
		end
		local t = os.clock() - t0
		local k = Util.easeInOut(math.clamp(t / dur, 0, 1))
		local from = base * CFrame.new(0, 7.5, 12)
		local to = base * CFrame.new(0, 6.7, -5.5)
		cam.CFrame = CFrame.lookAt(from.Position:Lerp(to.Position, k), (base * CFrame.new(0, 6.6, -11)).Position) * CFrame.Angles(math.sin(t * 0.7) * 0.004, 0, 0)
		cam.FieldOfView = 55
		mouth.Size = UDim2.fromOffset(40, 6 + math.abs(math.sin(t * 11)) * 12)
		ticker.Position = UDim2.fromOffset(820 - (t * 90) % 3800, 0)
		tvLight.Brightness = 2.2 + math.noise(t * 3, 0.5) * 0.8
		if t > dur + 1 then
			alive = false
			conn:Disconnect()
		end
	end)
	Scenes.tvCleanup = function()
		alive = false
		if conn then
			conn:Disconnect()
		end
		room:Destroy()
		C.inCutscene = false
	end
end

function H.tvEnd()
	if Scenes.tvCleanup then
		Scenes.tvCleanup()
		Scenes.tvCleanup = nil
	end
end

-- ------------------------------------------------------------------ truck
local function buildTruck(company: string, color: Color3)
	local m = Instance.new("Model")
	m.Name = "Truck"
	local cab = Kit.part(m, Vector3.new(9, 9, 8), CFrame.new(0, 5.5, -13), color, Enum.Material.SmoothPlastic, { CanCollide = false })
	m.PrimaryPart = cab
	Kit.part(m, Vector3.new(8.6, 3.5, 0.3), CFrame.new(0, 7.5, -17.1), rgb(140, 190, 230), Enum.Material.Glass, { Transparency = 0.2, CanCollide = false })
	Kit.part(m, Vector3.new(9.2, 2, 1), CFrame.new(0, 2.4, -17.3), rgb(40, 40, 44), nil, { CanCollide = false })
	local trailer = Kit.part(m, Vector3.new(9.4, 11, 30), CFrame.new(0, 7, 6), rgb(235, 235, 240), nil, { CanCollide = false })
	for _, x in { -3.2, 3.2 } do
		local hl = Kit.part(m, Vector3.new(1.6, 1, 0.3), CFrame.new(x, 3.6, -17.2), rgb(255, 255, 230), Enum.Material.Neon, { CanCollide = false })
		local s = Kit.spotLight(hl, rgb(255, 250, 220), 120, 12, 50, Enum.NormalId.Front)
		s.Shadows = false
	end
	for _, z in { -12, 0, 12, 18 } do
		for _, x in { -4.4, 4.4 } do
			Kit.cyl(m, 1.4, 3.4, CFrame.new(x, 1.7, z), rgb(20, 20, 20), nil, { CanCollide = false })
		end
	end
	for _, side in { Enum.NormalId.Left, Enum.NormalId.Right } do
		Kit.label(trailer, side, company, rgb(220, 30, 40), Enum.Font.Arcade, nil, 8)
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	m.Parent = workspace
	return m
end

function H.truck(d)
	local m = buildTruck(d.company or "ISEKAI LOGISTICS", d.color or rgb(200, 40, 40))
	local from, to = d.from, d.to
	local dur = d.dur or 2
	local t0 = os.clock()
	C.Audio.play("Horn", { pos = from.Position, pitch = 0.9, vol = 1, spread = 0 })
	local conn
	local done = false
	conn = RunService.RenderStepped:Connect(function()
		if done then
			return
		end
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		m:PivotTo(from:Lerp(to, k))
		if k >= 1 then
			done = true
			conn:Disconnect()
			task.delay(4, function()
				m:Destroy()
			end)
		end
	end)
	task.delay(d.honkAt or 0.8, function()
		C.Audio.play("Horn", { pos = from.Position:Lerp(to.Position, 0.4), pitch = 1.1, vol = 1, spread = 0 })
	end)
end

-- ------------------------------------------------------------------ bursts & power
function H.burst(d)
	local pos = d.pos
	C.FX.flash(pos, rgb(255, 250, 220), 30, 0.5)
	C.FX.ring(pos, 30, rgb(200, 180, 150), 0.9)
	for _ = 1, 60 do
		local v = Vector3.new(math.random() - 0.5, math.random() * 1.5 + 0.8, math.random() - 0.5) * 70
		C.FX.cube(pos + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)), math.random(8, 22) / 10, Palette.jitter(rgb(110, 80, 56), 0.2, math.random()), v, 5)
	end
	C.Controller.shake(5, 1.2)
	C.Audio.play("Explosion", { pos = pos, pitch = 0.5 })
	C.Audio.play("Rumble", { pos = pos, pitch = 0.4 })
end

function H.power(d)
	local target = d.target or player.Character
	local root = target and target.PrimaryPart
	if not root then
		return
	end
	local col = d.color or rgb(140, 230, 255)
	for i = 0, 5 do
		task.delay(i * 0.15, function()
			if root.Parent then
				C.FX.ring(root.Position - Vector3.new(0, 2.8 - i, 0), 10 + i * 2, col, 0.7)
			end
		end)
	end
	local pillar = Kit.deco(workspace, Vector3.new(6, 200, 6), CFrame.new(root.Position + Vector3.new(0, 100, 0)), col, Enum.Material.Neon, { Transparency = 0.2 })
	tween(pillar, 1.6, { Size = Vector3.new(0.2, 200, 0.2), Transparency = 1 })
	Debris:AddItem(pillar, 1.7)
	C.FX.burst(root.Position, col, 40, 30, 0.35, true, 1.2)
	C.Controller.shake(3, 0.6)
	C.Audio.play("LevelUp", { pitch = 0.7 })
end

local bubbles = {}
function H.bubble(d)
	local target = d.target
	if not target then
		return
	end
	local s = Instance.new("Part")
	s.Shape = Enum.PartType.Ball
	s.Anchored = true
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = false
	s.Material = Enum.Material.ForceField
	s.Color = rgb(190, 120, 255)
	s.Size = Vector3.one * 0.5
	s.Parent = workspace
	local inner = s:Clone()
	inner.Material = Enum.Material.Glass
	inner.Transparency = 0.75
	inner.Parent = workspace
	tween(s, 1.2, { Size = Vector3.one * 11 }, Enum.EasingStyle.Back)
	tween(inner, 1.2, { Size = Vector3.one * 10.6 }, Enum.EasingStyle.Back)
	local conn
	local entry = { conn = nil, parts = { s, inner }, done = false }
	conn = RunService.RenderStepped:Connect(function()
		if entry.done then
			return
		end
		if not target.Parent then
			entry.done = true
			conn:Disconnect()
			s:Destroy()
			inner:Destroy()
			return
		end
		local p = target:GetPivot().Position
		s.CFrame = CFrame.new(p) * CFrame.Angles(0, os.clock(), 0)
		inner.CFrame = CFrame.new(p)
	end)
	entry.conn = conn
	table.insert(bubbles, entry)
	C.Audio.play("Magic", { pitch = 0.4, vol = 1 })
end

function H.bubbleEnd()
	for _, b in bubbles do
		if not b.done then
			b.done = true
			b.conn:Disconnect()
			for _, p in b.parts do
				p:Destroy()
			end
		end
	end
	bubbles = {}
end

-- ------------------------------------------------------------------ glitch (pooled bars)
local glitchToken = 0
function H.glitch(d)
	local g = UI.screen("Glitch", 96)
	glitchToken += 1
	local tok = glitchToken
	local dur = d.dur or 1.5
	local t0 = os.clock()
	local bars = {}
	for _ = 1, 8 do
		table.insert(bars, UI.new("Frame", { Parent = g, Size = UDim2.new(1, 0, 0, 10), BorderSizePixel = 0, BackgroundTransparency = 1 }))
	end
	local cols = { rgb(255, 0, 60), rgb(0, 255, 220), rgb(255, 255, 255), rgb(0, 0, 0), COL.Blood }
	task.spawn(function()
		while os.clock() - t0 < dur and glitchToken == tok do
			for _, f in bars do
				f.Size = UDim2.new(1, 0, 0, math.random(4, 44))
				f.Position = UDim2.new(math.random(-8, 8) / 100, 0, math.random(), 0)
				f.BackgroundColor3 = cols[math.random(1, #cols)]
				f.BackgroundTransparency = if math.random() < 0.3 then 1 else math.random() * 0.5
			end
			if math.random() < 0.3 then
				UI.sfx("Glass", { pitch = math.random(3, 12) / 10, vol = 0.3, ignoreTime = true })
			end
			if C.Controller and C.Controller.shake then
				C.Controller.shake(1.5, 0.1)
			end
			task.wait(0.05)
		end
		for _, f in bars do
			f:Destroy()
		end
	end)
end

-- ------------------------------------------------------------------ endings
function H.ending(d)
	local _, r = UI.layer("Ending", 98)
	clear(r)
	local f = UI.frame(r, { Name = "Ending", color = Color3.new(0, 0, 0), t = 1 })
	tween(f, 2, { BackgroundTransparency = 0 })
	C.inCutscene = true
	local col = d.color or COL.Bone
	task.spawn(function()
		task.wait(2.2)
		local card = UI.frame(f, { Name = "Card" })
		UI.flourish(card, 640, UDim2.fromScale(0.5, 0.16), { color = COL.Gold })
		UI.display(card, d.title or "THE END", { Name = "Title", Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromScale(0, 0.18), size = 110, x = Enum.TextXAlignment.Center, from = col, to = Palette.shade(col, 0.55) })
		UI.flourish(card, 380, UDim2.fromScale(0.5, 0.31), { color = COL.Gold, dots = false })
		UI.setAlpha(card, 0)
		UI.fadeTo(card, 1, 1.5)
		task.wait(1.8)
		local y = 0.38
		for i, line in d.lines or {} do
			local l = UI.text(card, line, { Name = "Line" .. i, Size = UDim2.new(1, -300, 0, 40), Position = UDim2.new(0, 150, y, 0), font = UI.SERIF, size = 30, x = Enum.TextXAlignment.Center, color = COL.Bone, TextTransparency = 1 })
			tween(l, 1.2, { TextTransparency = 0 })
			y += 0.075
			task.wait(2.6)
		end
		task.wait(2)
		if d.credits then
			local credits = {
				{ "h", "THE RANDOM STORY" }, { "", "" }, { "t", "a game by John" }, { "", "" },
				{ "h", "STORY" }, { "t", "John" }, { "", "" },
				{ "h", "CODE, CUBES & CHAOS" }, { "t", "a Python pipeline and too much Luau" }, { "", "" },
				{ "h", "SEED" }, { "t", tostring(C.seed or "?") }, { "", "" },
				{ "h", "KILLS" }, { "t", tostring(C.profile and C.profile.kills or 0) }, { "", "" },
				{ "h", "DEATHS" }, { "t", tostring(C.profile and C.profile.deaths or 0) }, { "", "" },
				{ "h", "SPECIAL THANKS" }, { "t", "the truck" }, { "t", "the cat who learned to open doors" }, { "", "" },
				{ "t", "thank you for playing" },
			}
			UI.fadeOut(card, 1)
			local roll = UI.frame(f, { Name = "Roll", Size = UDim2.new(1, 0, 0, #credits * 44), Position = UDim2.fromScale(0, 1) })
			for i, c in credits do
				if c[1] == "h" then
					UI.text(roll, c[2], { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, (i - 1) * 44 + 8), font = UI.BOLD, size = 16, x = Enum.TextXAlignment.Center, color = COL.Gold })
				elseif c[1] == "t" then
					UI.text(roll, c[2], { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, (i - 1) * 44), font = UI.SERIF, size = 30, x = Enum.TextXAlignment.Center, color = COL.Bone })
				end
			end
			tween(roll, 28, { Position = UDim2.new(0, 0, 0, -#credits * 44) }, Enum.EasingStyle.Linear)
			task.wait(28)
		end
		task.wait(d.hold or 1)
		UI.fadeOut(f, 1.5, true)
		task.wait(1.6)
		C.inCutscene = false
		Net.send("Menu", "CutsceneDone", { id = d.id })
	end)
end

function H.delete(d)
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	local center = cam.CFrame.Position
	local parts = {}
	for _, p in world:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	table.sort(parts, function(a, b)
		return (a.Position - center).Magnitude > (b.Position - center).Magnitude
	end)
	task.spawn(function()
		local n = #parts
		for i, p in parts do
			if p.Parent then
				p.LocalTransparencyModifier = 1
			end
			if i % math.max(1, math.floor(n / 120)) == 0 then
				task.wait()
			end
		end
	end)
end

-- ------------------------------------------------------------------ QTE (typing at work)
function H.qte(d)
	local _, r = UI.layer("QTE", 45)
	clear(r)
	local p = UI.panel(r, UDim2.fromOffset(480, 280), UDim2.fromScale(0.5, 0.45), { AnchorPoint = V2(0.5, 0.5), color = COL.Ink, t = 0.1, Name = "QTE" })
	UI.text(p, string.upper(d.title or "TYPE!"), { Name = "Title", Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 30), font = UI.BLACK, size = 24, x = Enum.TextXAlignment.Center, color = COL.Bone })
	UI.flourish(p, 300, UDim2.new(0.5, 0, 0, 58), { color = COL.Gold })
	local key = UI.keycap(p, "?", UDim2.new(0.5, 0, 0, 142), { h = 110, size = 68, light = true, AnchorPoint = V2(0.5, 0.5), Name = "Key" })
	local score = UI.text(p, "", { Name = "Score", Position = UDim2.new(0, 0, 1, -50), Size = UDim2.new(1, 0, 0, 30), font = UI.BOLD, size = 20, x = Enum.TextXAlignment.Center, color = COL.GoldBright })
	local timer = UI.frame(p, { Name = "Timer", Size = UDim2.new(1, -60, 0, 3), Position = UDim2.new(0, 30, 1, -14), color = COL.Blood, t = 0 })
	local keys = d.keys or { "A", "S", "D", "F", "J", "K" }
	local hits = 0
	task.spawn(function()
		for _, k in keys do
			key.Text = string.upper(k)
			key.TextColor3 = COL.Ink
			key.BackgroundColor3 = COL.Bone
			UI.slam(key, 1.4, 0.12)
			local t0 = os.clock()
			local got = false
			local conn = UserInputService.InputBegan:Connect(function(input)
				if input.KeyCode.Name == k then
					got = true
				end
			end)
			local per = d.per or 1.2
			while not got and os.clock() - t0 < per do
				timer.Size = UDim2.new(1 - (os.clock() - t0) / per, -60 * (1 - (os.clock() - t0) / per), 0, 3)
				task.wait()
			end
			conn:Disconnect()
			if got then
				hits += 1
				key.BackgroundColor3 = COL.Good
				UI.sfx("Type", { pitch = 1.3 })
			else
				key.BackgroundColor3 = COL.BloodBright
			end
			score.Text = string.format("%d / %d", hits, #keys)
			task.wait(0.15)
		end
		p:Destroy()
		Net.send("Menu", "QTE", { id = d.id, result = hits })
	end)
end

-- ------------------------------------------------------------------ loading overlay
local TIPS = {
	"Parry (RMB) right before a hit lands to stagger the attacker.",
	"Q stops time. Every hit you land is dealt the moment time resumes.",
	"Dash (SHIFT) through attacks - you are briefly untouchable.",
	"Slide (CTRL), then jump: momentum is everything.",
	"Level-up points are spent in the inventory (I).",
	"Lost? The compass at the top always points to your objective.",
	"ALT frees your cursor without pausing.",
	"A perfect parry refunds a second of time stop cooldown.",
	"Look both ways before crossing the street.",
}
local loading: any = nil
local loadToken = 0
local function buildLoading()
	local _, r = UI.layer("Loading2", 101)
	local f = UI.frame(r, { Name = "Loading", color = COL.Ink, t = 0, Visible = false })
	local glow = UI.frame(f, { Name = "Glow", Size = UDim2.new(1, 0, 0, 520), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5), color = COL.BloodDeep, t = 0.35 })
	UI.gradient(glow, nil, { { 0, 1 }, { 0.5, 0.3 }, { 1, 1 } }, 90)
	UI.wing(f, V2(0, 0), -1, { angle = -4, spread = 7, n = 3, len = 150, gap = 330, color = COL.Gold, t = 0.4, Name = "WingL" }).Position = UDim2.fromScale(0.5, 0.5)
	UI.wing(f, V2(0, 0), 1, { angle = -4, spread = 7, n = 3, len = 150, gap = 330, color = COL.Gold, t = 0.4, Name = "WingR" }).Position = UDim2.fromScale(0.5, 0.5)
	UI.display(f, "THE RANDOM STORY", { Name = "Title", Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 0.5, -170), size = 64, x = Enum.TextXAlignment.Center, from = COL.Bone, to = rgb(140, 124, 104) })
	UI.flourish(f, 420, UDim2.new(0.5, 0, 0.5, -86), { color = COL.Gold })
	local spin = UI.frame(f, { Name = "Spinner", Size = UDim2.fromOffset(84, 84), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5) })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		UI.diamond(spin, if k == 0 then 13 else 9, UDim2.new(0.5, math.sin(a) * 34, 0.5, -math.cos(a) * 34), { color = if k == 0 then COL.BloodBright else COL.Gold, t = if k == 0 then 0 else 0.3 })
	end
	local spin2 = UI.frame(f, { Name = "Inner", Size = UDim2.fromOffset(40, 40), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = V2(0.5, 0.5) })
	UI.diamond(spin2, 16, UDim2.fromScale(0.5, 0.5), { t = 1, stroke = COL.GoldBright, strokeT = 0.1, inner = COL.Violet })
	local label = UI.text(f, "BUILDING THE WORLD", { Name = "Label", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0.5, 70), font = UI.BOLD, size = 14, color = COL.GoldBright, x = Enum.TextXAlignment.Center })
	UI.hline(f, { Size = UDim2.fromOffset(700, 1), Position = UDim2.new(0.5, 0, 1, -120), AnchorPoint = V2(0.5, 0.5), color = COL.Gold, t = 0.5 })
	UI.text(f, "TIP", { Name = "TipTag", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -104), font = UI.BOLD, size = 11, color = COL.Gold, x = Enum.TextXAlignment.Center })
	local tip = UI.text(f, "", { Name = "Tip", Size = UDim2.new(1, -200, 0, 30), Position = UDim2.new(0, 100, 1, -86), font = UI.SERIF, size = 22, color = COL.BoneDim, x = Enum.TextXAlignment.Center })
	loading = { frame = f, spin = spin, inner = spin2, label = label, tip = tip }
end

RunService.RenderStepped:Connect(function(dt)
	if loading and loading.frame.Visible then
		local t = os.clock()
		loading.spin.Rotation = (t * 120) % 360
		loading.inner.Rotation = -(t * 200) % 360
		loading.label.Text = "BUILDING THE WORLD" .. string.rep(".", math.floor(t * 2.5) % 4)
	end
end)

function H.loading(d)
	if not loading then
		buildLoading()
	end
	loadToken += 1
	local tok = loadToken
	if d.on then
		loading.tip.Text = TIPS[math.random(1, #TIPS)]
		UI.fadeIn(loading.frame, 0.35)
		task.delay(90, function()
			if loadToken == tok then
				UI.fadeOut(loading.frame, 0.6)
			end
		end)
	else
		UI.fadeOut(loading.frame, 0.6)
	end
end

-- ------------------------------------------------------------------ ascending the tower
function H.ascend(d)
	C.inCutscene = true
	local from, to = d.from, d.to
	local dur = d.dur or 6
	local t0 = os.clock()
	local _, r = UI.layer("Ascend", 34)
	clear(r)
	local card = UI.frame(r, { Name = "Altitude", Size = UDim2.fromOffset(900, 110), Position = UDim2.fromScale(0.5, 0.8), AnchorPoint = V2(0.5, 0.5) })
	UI.text(card, "ALTITUDE", { Name = "Tag", Size = UDim2.new(1, 0, 0, 18), font = UI.BOLD, size = 14, color = COL.Gold, x = Enum.TextXAlignment.Center })
	local label = UI.text(card, "", { Name = "Value", Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 20), font = UI.BLACK, size = 56, color = COL.Bone, x = Enum.TextXAlignment.Center, strokeT = 0.4 })
	UI.flourish(card, 420, UDim2.new(0.5, 0, 0, 96), { color = COL.Gold })
	local conn
	local done = false
	conn = RunService.RenderStepped:Connect(function()
		if done then
			return
		end
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = Util.easeInOut(k)
		local y = from.Y + (to.Y - from.Y) * e
		local c = d.center or Vector3.new(from.X, 0, from.Z)
		local a = e * math.pi * 1.5
		local pos = Vector3.new(c.X + math.cos(a) * (d.radius or 120), y, c.Z + math.sin(a) * (d.radius or 120))
		cam.CFrame = CFrame.lookAt(pos, Vector3.new(c.X, y + 40, c.Z))
		cam.FieldOfView = 70
		label.Text = Util.fmt(y)
		if k >= 1 then
			done = true
			conn:Disconnect()
			card:Destroy()
			C.inCutscene = false
		end
	end)
	UI.sfx("Rumble", { pitch = 0.5, vol = 0.8 })
end

-- ------------------------------------------------------------------ spinning pickups
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for _, m in CollectionService:GetTagged("Spin") do
		if m:IsA("Model") and m.Parent then
			local base = m:GetAttribute("SpinBase")
			if not base then
				base = m:GetPivot()
				m:SetAttribute("SpinBase", base)
			end
			m:PivotTo(CFrame.new(base.Position + Vector3.new(0, math.sin(t * 2) * 0.3, 0)) * CFrame.Angles(0, t * 1.5, 0) * (base - base.Position))
		end
	end
end)

function Scenes.init()
	Net.on("Scene", function(name, d)
		local h = H[name]
		if h then
			local ok, err = pcall(h, d or {})
			if not ok then
				C.report("Scene " .. name, err)
			end
		end
	end)
end

Scenes.H = H

return Scenes
