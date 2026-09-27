--!nonstrict
-- Dialogue box (v3): gothic bottom panel with a blackletter speaker plate, typewriter
-- text (punctuation pauses), advance hint, auto-advance with a progress line for
-- cinematics, numbered choices (1-9 / W S + E) incl. the glitching hidden choice,
-- optional camera shot per dialogue or line (adds letterbox bars).
-- Server protocol (Director D.say): {id, lines = {{speaker, text, slow?, cam?}}, choices?,
-- auto?, focus?, hiddenChoice? = {text, index, delay}, cam?} -> Net "Menu" "Dialogue" {id, choice}
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local C = require(script.Parent.C)
local UI = require(script.Parent.UI)

local Dialogue = {}
local rgb = Color3.fromRGB
local V2 = Vector2.new
local COL = UI.COL
local KC = Enum.KeyCode

local gui, root, box, plate, nameText, textLabel, hint, hintKey, autoTag, autoLine, choiceFrame
local queue = {}
local busy = false
local advance = false
local camShot = nil
local choosing = nil -- {buttons, sel, pick(i)}
local BOX_Y = -40

local function build()
	gui, root = UI.layer("Dialogue", 20)
	box = UI.panel(root, UDim2.fromOffset(1060, 196), UDim2.new(0.5, 0, 1, BOX_Y), { AnchorPoint = V2(0.5, 1), color = COL.Ink, t = 0.04, edgeT = 0.55, Name = "Box", Visible = false })
	UI.gradient(box, { rgb(255, 255, 255), rgb(150, 142, 142) }, { { 0, 0 }, { 1, 0.08 } }, 90)
	UI.flourish(box, 560, UDim2.new(0.5, 0, 0, 0), { color = COL.Gold, Name = "TopOrnament" })
	UI.hline(box, { Size = UDim2.new(0.9, 0, 0, 1), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = V2(0.5, 0.5), color = COL.Blood, t = 0.4 })
	-- speaker plate (auto-sized to the name)
	plate = UI.text(box, "", {
		Name = "Speaker",
		Size = UDim2.fromOffset(120, 46),
		Position = UDim2.fromOffset(34, -28),
		auto = Enum.AutomaticSize.X,
		font = UI.GOTHIC,
		size = 34,
		color = COL.GoldBright,
		bgT = 0.02,
		bg = COL.Ink,
		wrap = false,
		strokeT = 0.5,
	})
	UI.pad(plate, 36, 20, 0, 2)
	UI.stroke(plate, COL.Gold, 1, 0.45)
	UI.diamond(plate, 8, UDim2.new(0, -18, 0.5, 0), { color = COL.BloodBright, Name = "Bullet" })
	UI.frame(plate, { Name = "Under", Size = UDim2.new(1, 56, 0, 2), Position = UDim2.new(0, -36, 1, 2), AnchorPoint = V2(0, 1), color = COL.Blood, t = 0 })
	nameText = plate
	textLabel = UI.text(box, "", { Name = "Line", Position = UDim2.fromOffset(46, 36), Size = UDim2.new(1, -92, 1, -76), font = UI.BODY, size = 24, color = COL.Bone, y = Enum.TextYAlignment.Top, rich = true, lineHeight = 1.12, strokeT = 0.85 })
	-- advance hint
	hint = UI.frame(box, { Name = "Hint", Size = UDim2.fromOffset(240, 24), Position = UDim2.new(1, -30, 1, -18), AnchorPoint = V2(1, 1) })
	hintKey = UI.keyRow(hint, { { "E", "Continue" } }, { h = 20, size = 11, gap = 8, Name = "Keys", Position = UDim2.fromScale(1, 0.5), AnchorPoint = V2(1, 0.5) })
	autoTag = UI.text(hint, "AUTO", { Name = "Auto", Size = UDim2.fromOffset(80, 20), Position = UDim2.fromScale(1, 0.5), AnchorPoint = V2(1, 0.5), font = UI.BOLD, size = 11, color = COL.BoneFaint, x = Enum.TextXAlignment.Right, Visible = false })
	UI.diamond(hint, 6, UDim2.new(1, -150, 0.5, 0), { color = COL.GoldBright, Name = "Pulse" })
	autoLine = UI.frame(box, { Name = "AutoLine", Size = UDim2.new(0, 0, 0, 2), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = V2(0, 1), color = COL.Gold, t = 0.2 })
	-- choices
	choiceFrame = UI.frame(root, { Name = "Choices", Size = UDim2.fromOffset(780, 480), Position = UDim2.new(0.5, 0, 1, BOX_Y - 214), AnchorPoint = V2(0.5, 1), Visible = false })
	UI.list(choiceFrame, 8, false, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
end

local function setCam(shot)
	camShot = shot
	if shot then
		C.inCutscene = true
		C.dialogueCam = true
		if C.Cutscene and type(C.Cutscene.bars) == "function" then
			C.Cutscene.bars(true)
		end
	elseif C.dialogueCam then
		C.dialogueCam = false
		local playing = C.Cutscene and type(C.Cutscene.isPlaying) == "function" and C.Cutscene.isPlaying()
		if not playing then
			C.inCutscene = false
			if C.Cutscene and type(C.Cutscene.bars) == "function" then
				C.Cutscene.bars(false)
			end
		end
	end
end

RunService:BindToRenderStep("TRSDialogueCam", Enum.RenderPriority.Camera.Value + 2, function()
	if camShot and C.dialogueCam then
		local cam = workspace.CurrentCamera
		local cf = camShot.cf
		if camShot.follow and camShot.follow.Parent then
			local p = camShot.follow:GetPivot().Position
			cf = CFrame.lookAt(p + (camShot.offset or Vector3.new(0, 2, -8)), p + Vector3.new(0, camShot.lookY or 1.5, 0))
		elseif camShot.focus and cf then
			cf = CFrame.lookAt(cf.Position, camShot.focus)
		end
		if cf and cam then
			local t = os.clock()
			cam.CFrame = cf * CFrame.Angles(math.sin(t * 0.6) * 0.004, math.sin(t * 0.45) * 0.006, 0)
			cam.FieldOfView = camShot.fov or 60
		end
	end
end)

local function plainText(s: string): string
	return (s:gsub("<[^>]->", ""))
end

local function typeLine(line, auto)
	local speaker = line.speaker or ""
	plate.Visible = speaker ~= ""
	nameText.Text = speaker
	local text = line.text or ""
	textLabel.Text = text
	textLabel.MaxVisibleGraphemes = 0
	hint.Visible = false
	autoLine.Size = UDim2.new(0, 0, 0, 2)
	advance = false
	local plain = plainText(text)
	local n = utf8.len(plain) or #plain
	local i = 0
	local speed = if line.slow then 24 else 58
	-- the speaker's mouth moves while the line types out
	if C.FX and C.FX.speaker then
		local who = C.FX.speaker(speaker)
		if who then
			C.FX.talk(who, n / speed + 0.3)
		end
	end
	local acc = 0
	local pauseT = 0
	while i < n do
		local dt = task.wait() or 1 / 60
		if pauseT > 0 then
			pauseT -= dt
		else
			acc += dt * speed
			local step = math.floor(acc)
			if step > 0 then
				acc -= step
				local prev = i
				i = math.min(n, i + step)
				textLabel.MaxVisibleGraphemes = i
				if math.floor(i / 3) ~= math.floor(prev / 3) then
					UI.sfx("Type", { vol = 0.22, pitch = 1.6, spread = 0.2, ignoreTime = true })
				end
				local ch = plain:sub(i, i)
				if ch == "." or ch == "!" or ch == "?" then
					pauseT = 0.14
				elseif ch == "," or ch == ";" or ch == ":" then
					pauseT = 0.06
				end
			end
		end
		if advance or C.skipAll then
			advance = false
			i = n
		end
	end
	textLabel.MaxVisibleGraphemes = -1
	hint.Visible = true
	hintKey.Visible = not auto
	autoTag.Visible = auto ~= nil
end

local function waitAdvance(auto)
	advance = false
	local t0 = os.clock()
	local pulse = hint:FindFirstChild("Pulse")
	while not advance do
		task.wait()
		local t = os.clock()
		if pulse then
			pulse.Position = UDim2.new(1, -150 + math.sin(t * 6) * 3, 0.5, 0)
		end
		if auto then
			autoLine.Size = UDim2.new(math.clamp((t - t0) / auto, 0, 1), 0, 0, 2)
			if t - t0 > auto then
				break
			end
		end
		if C.skipAll then
			break
		end
	end
	advance = false
end

local function clearChoices()
	for _, c in choiceFrame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function choiceButton(i: number, text: string, onPick, hidden: boolean?)
	local b = UI.new("TextButton", {
		Parent = choiceFrame,
		Name = "Choice" .. i,
		Text = text,
		TextTransparency = 1,
		Size = UDim2.fromOffset(780, 50),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = if hidden then rgb(20, 0, 2) else COL.Ink,
		BackgroundTransparency = 0.12,
		Font = UI.BODY,
		TextSize = 20,
		LayoutOrder = if hidden then 999 else i,
	})
	local stroke = UI.stroke(b, if hidden then rgb(120, 0, 10) else COL.Gold, 1, 0.65)
	local hl = UI.frame(b, { Name = "Highlight", color = COL.Blood, t = 0.3, Visible = false, ZIndex = 1 })
	UI.gradient(hl, nil, { { 0, 0 }, { 0.75, 0.8 }, { 1, 1 } }, 0)
	local accent = UI.frame(b, { Name = "Accent", Size = UDim2.new(0, 3, 1, 0), color = COL.BloodBright, t = 0, Visible = false, ZIndex = 2 })
	UI.keycap(b, if hidden then "?" else tostring(i), UDim2.new(0, 16, 0.5, 0), { h = 28, AnchorPoint = V2(0, 0.5), light = not hidden })
	local label = UI.text(b, text, {
		Name = "Label",
		Size = UDim2.new(1, -90, 1, 0),
		Position = UDim2.fromOffset(66, 0),
		font = if hidden then UI.BOLD else UI.BODY,
		size = 20,
		color = if hidden then rgb(255, 50, 66) else COL.Bone,
		wrap = false,
		ZIndex = 3,
	})
	local api: any = { label = label }
	function api.set(on)
		hl.Visible = on
		accent.Visible = on
		stroke.Transparency = if on then 0.15 else 0.65
		stroke.Color = if on then COL.BloodBright elseif hidden then rgb(120, 0, 10) else COL.Gold
		if not hidden then
			label.TextColor3 = if on then Color3.new(1, 1, 1) else COL.Bone
		end
		UI.tween(label, 0.1, { Position = UDim2.fromOffset(if on then 74 else 66, 0) })
	end
	b.MouseEnter:Connect(function()
		if choosing then
			choosing.select(api)
		end
		UI.onHover()
	end)
	b.MouseButton1Click:Connect(function()
		UI.onClick()
		onPick()
	end)
	api.button = b
	api.pick = onPick
	return api
end

local function showChoices(choices, hidden)
	clearChoices()
	choiceFrame.Visible = true
	C.cursor.dialogue = true
	local picked = nil
	local head = UI.frame(choiceFrame, { Name = "Head", Size = UDim2.fromOffset(780, 22), LayoutOrder = 0 })
	UI.text(head, "CHOOSE", { Size = UDim2.fromOffset(200, 18), Position = UDim2.fromOffset(0, 0), font = UI.BOLD, size = 12, color = COL.Gold })
	UI.hline(head, { Size = UDim2.fromOffset(600, 1), Position = UDim2.fromOffset(70, 9), color = COL.Gold, fade = "right", t = 0.4 })
	local list = {}
	choosing = { list = list, sel = 1 }
	function choosing.select(api)
		for k, a in list do
			a.set(a == api)
			if a == api then
				choosing.sel = k
			end
		end
	end
	for i, txt in choices do
		local api = choiceButton(i, txt, function()
			picked = picked or i
		end)
		table.insert(list, api)
	end
	choosing.select(list[1])
	if hidden then
		task.delay(hidden.delay or 7, function()
			if picked or not choiceFrame.Visible then
				return
			end
			local api = choiceButton(#list + 1, hidden.text or "...", function()
				picked = picked or hidden.index
			end, true)
			table.insert(list, api)
			local lab = api.label
			task.spawn(function()
				while not picked and choiceFrame.Visible do
					lab.TextTransparency = 0.25 + math.random() * 0.6
					lab.Text = if math.random() < 0.15 then string.rep("#", math.random(4, 12)) else (hidden.text or "...")
					task.wait(0.07)
				end
			end)
			UI.sfx("Glass", { pitch = 0.4, vol = 0.4 })
		end)
	end
	while not picked do
		task.wait()
	end
	choosing = nil
	UI.sfx("Click")
	choiceFrame.Visible = false
	clearChoices()
	C.cursor.dialogue = nil
	return picked
end

local function run(d)
	busy = true
	C.dialogueOpen = true
	box.Visible = true
	box.Position = UDim2.new(0.5, 0, 1, BOX_Y + 24)
	UI.tween(box, 0.22, { Position = UDim2.new(0.5, 0, 1, BOX_Y) }, Enum.EasingStyle.Back)
	setCam(d.cam)
	for _, line in d.lines or {} do
		if type(line) == "table" then
			if line.cam then
				setCam(line.cam)
			end
			typeLine(line, d.auto)
			if C.skipAll then
				break
			end
			waitAdvance(d.auto)
		end
	end
	local choice = 0
	if type(d.choices) == "table" and #d.choices > 0 then
		choice = showChoices(d.choices, d.hiddenChoice)
	end
	box.Visible = false
	setCam(nil)
	C.dialogueOpen = false
	busy = false
	C.skipAll = false
	Net.send("Menu", "Dialogue", { id = d.id, choice = choice })
end

local function pump()
	if busy then
		return
	end
	local d = table.remove(queue, 1)
	if d then
		task.spawn(function()
			local ok, err = pcall(run, d)
			if not ok then
				C.report("Dialogue", err)
				busy = false
				C.dialogueOpen = false
				C.cursor.dialogue = nil
				box.Visible = false
				choiceFrame.Visible = false
				setCam(nil)
				Net.send("Menu", "Dialogue", { id = d.id, choice = 1 })
			end
			pump()
		end)
	end
end

function Dialogue.isOpen(): boolean
	return busy
end

function Dialogue.isChoosing(): boolean
	return choosing ~= nil
end

local NUM = { KC.One, KC.Two, KC.Three, KC.Four, KC.Five, KC.Six, KC.Seven, KC.Eight, KC.Nine }

function Dialogue.init()
	build()
	Net.on("Dialogue", function(d)
		if type(d) == "table" then
			table.insert(queue, d)
			pump()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gp)
		if not busy or C.paused then
			return
		end
		local k = input.KeyCode
		if choosing then
			local idx = table.find(NUM, k)
			if idx and choosing.list[idx] then
				choosing.list[idx].pick()
			elseif k == KC.W or k == KC.Up or k == KC.DPadUp then
				local n = #choosing.list
				choosing.select(choosing.list[((choosing.sel - 2) % n) + 1])
				UI.onHover()
			elseif k == KC.S or k == KC.Down or k == KC.DPadDown then
				local n = #choosing.list
				choosing.select(choosing.list[(choosing.sel % n) + 1])
				UI.onHover()
			elseif k == KC.E or k == KC.Return or k == KC.KeypadEnter or k == KC.ButtonA then
				local a = choosing.list[choosing.sel]
				if a then
					a.pick()
				end
			end
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			advance = true
		elseif k == KC.E or k == KC.Space or k == KC.Return or k == KC.KeypadEnter or k == KC.ButtonA then
			advance = true
		end
	end)
end

return Dialogue
