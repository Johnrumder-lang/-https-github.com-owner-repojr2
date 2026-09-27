--!nonstrict
-- Camera cutscenes: shot lists with eased moves, focus/follow, subtitles,
-- letterbox (with blood hairlines), fades, hold-SPACE-to-skip with a progress line.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Util = require(Shared.Util)
local C = require(script.Parent.C)
local UI = require(script.Parent.UI)

local Cutscene = {}
local cam = workspace.CurrentCamera
local rgb = Color3.fromRGB
local COL = UI.COL

local gui, root, topBar, botBar, subtitle, subBand, skipBox, skipFill, fade
local playing = nil
local skipHeld = 0
local SKIP_TIME = 0.9
local BAR = 0.11

local function build()
	gui, root = UI.layer("Cutscene", 30)
	topBar = UI.frame(root, { Name = "Top", Size = UDim2.new(1, 0, 0, 0), color = Color3.new(0, 0, 0), t = 0 })
	botBar = UI.frame(root, { Name = "Bottom", Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), color = Color3.new(0, 0, 0), t = 0 })
	UI.hline(topBar, { Size = UDim2.new(0.7, 0, 0, 1), Position = UDim2.fromScale(0.5, 1), AnchorPoint = Vector2.new(0.5, 0), color = COL.Blood, t = 0.35 })
	UI.hline(botBar, { Size = UDim2.new(0.7, 0, 0, 1), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 1), color = COL.Blood, t = 0.35 })
	-- subtitles sit just above the lower bar on a soft band
	subBand = UI.frame(root, { Name = "SubBand", Size = UDim2.fromOffset(1300, 70), Position = UDim2.new(0.5, 0, 1 - BAR, -18), AnchorPoint = Vector2.new(0.5, 1), color = COL.Ink, t = 0.45, Visible = false })
	UI.gradient(subBand, nil, UI.FADE_BOTH, 0)
	subtitle = UI.text(subBand, "", { Name = "Subtitle", Size = UDim2.new(1, -120, 1, 0), Position = UDim2.fromOffset(60, 0), font = UI.BODY, size = 27, color = COL.Bone, x = Enum.TextXAlignment.Center, rich = true, strokeT = 0.35 })
	-- hold-to-skip hint
	skipBox = UI.frame(root, { Name = "Skip", Size = UDim2.fromOffset(260, 30), Position = UDim2.new(1, -40, 1, -34), AnchorPoint = Vector2.new(1, 0.5), Visible = false })
	UI.keyRow(skipBox, { { "Space", "Hold to skip" } }, { h = 20, size = 11, gap = 8, Name = "Keys", Position = UDim2.fromScale(1, 0.5), AnchorPoint = Vector2.new(1, 0.5), color = COL.BoneDim })
	local track = UI.frame(skipBox, { Name = "Track", Size = UDim2.fromOffset(150, 2), Position = UDim2.new(1, 0, 1, 4), AnchorPoint = Vector2.new(1, 0), color = COL.Ink3, t = 0.2 })
	skipFill = UI.frame(track, { Name = "Fill", Size = UDim2.fromScale(0, 1), color = COL.BloodBright, t = 0 })
	local _, fr = UI.layer("Fade", 100)
	fade = UI.frame(fr, { Name = "Fade", Size = UDim2.fromScale(1, 1), color = Color3.new(0, 0, 0), t = 1 })
end

function Cutscene.bars(on: boolean)
	if not topBar then
		return
	end
	UI.tween(topBar, 0.5, { Size = UDim2.new(1, 0, if on then BAR else 0, 0) })
	UI.tween(botBar, 0.5, { Size = UDim2.new(1, 0, if on then BAR else 0, 0) })
end

function Cutscene.fade(to: string, time: number, color: Color3?)
	if not fade then
		return
	end
	fade.BackgroundColor3 = color or (if to == "white" then Color3.new(1, 1, 1) else Color3.new(0, 0, 0))
	UI.tween(fade, time or 0.5, { BackgroundTransparency = if to == "clear" then 1 else 0 }, Enum.EasingStyle.Sine)
end

function Cutscene.subtitle(text: string?)
	if not subtitle then
		return
	end
	subtitle.Text = text or ""
	subBand.Visible = text ~= nil and text ~= ""
end

local function ease(name, t)
	if name == "linear" then
		return t
	elseif name == "out" then
		return Util.easeOut(t, 3)
	elseif name == "in" then
		return Util.easeIn(t, 2)
	end
	return Util.easeInOut(t)
end

local function shotCF(s, k: number): CFrame
	local cf = s.cf
	if s.to then
		cf = s.cf:Lerp(s.to, ease(s.ease, k))
	end
	if s.follow and s.follow.Parent then
		local p = s.follow:GetPivot().Position
		local off = s.offset or Vector3.new(0, 3, 10)
		local pos = p + off
		if s.offsetTo then
			pos = p + off:Lerp(s.offsetTo, ease(s.ease, k))
		end
		return CFrame.lookAt(pos, p + Vector3.new(0, s.lookY or 1.5, 0))
	end
	if s.focus then
		local f = s.focus
		if typeof(f) == "Instance" then
			f = (f :: any):GetPivot().Position
		end
		cf = CFrame.lookAt(cf.Position, f)
	end
	if s.orbit then
		local c = s.orbit.center
		local a = s.orbit.a0 + (s.orbit.a1 - s.orbit.a0) * ease(s.ease, k)
		local pos = c + Vector3.new(math.cos(a) * s.orbit.r, s.orbit.h or 5, math.sin(a) * s.orbit.r)
		cf = CFrame.lookAt(pos, c + Vector3.new(0, s.orbit.lookY or 2, 0))
	end
	return cf
end

function Cutscene.play(def)
	playing = def
	C.inCutscene = true
	skipHeld = 0
	if def.bars ~= false then
		Cutscene.bars(true)
	end
	skipBox.Visible = def.skippable ~= false
	if def.fadeIn then
		fade.BackgroundTransparency = 0
		Cutscene.fade("clear", def.fadeIn)
	end
	local t0 = os.clock()
	-- subtitles
	for _, st in def.text or {} do
		task.delay(st.at or 0, function()
			if playing == def then
				Cutscene.subtitle(st.text)
				task.delay(st.t or 3, function()
					if playing == def and subtitle.Text == st.text then
						Cutscene.subtitle(nil)
					end
				end)
			end
		end)
	end
	for _, s in def.shots or {} do
		local st = os.clock()
		local dur = s.t or 2
		if s.fadeTo then
			task.delay(math.max(0, dur - (s.fadeTime or 0.5)), function()
				if playing == def then
					Cutscene.fade(s.fadeTo, s.fadeTime or 0.5)
				end
			end)
		end
		if s.fromFade then
			Cutscene.fade("clear", s.fromFade)
		end
		while os.clock() - st < dur and playing == def do
			local k = math.clamp((os.clock() - st) / dur, 0, 1)
			local cf = shotCF(s, k)
			if s.shake then
				local n = os.clock() * 30
				cf *= CFrame.Angles(math.rad(math.noise(n, 1) * s.shake), math.rad(math.noise(2, n) * s.shake), 0)
			end
			cam.CFrame = cf
			cam.FieldOfView = if s.toFov then Util.lerp(s.fov or 70, s.toFov, ease(s.ease, k)) else (s.fov or 70)
			task.wait()
		end
		if playing ~= def then
			break
		end
	end
	if playing == def then
		Cutscene.finish(def)
	end
end

function Cutscene.finish(def)
	if playing ~= def then
		return
	end
	playing = nil
	Cutscene.subtitle(nil)
	skipBox.Visible = false
	if def.bars ~= false then
		Cutscene.bars(false)
	end
	if def.fadeOut then
		Cutscene.fade("clear", def.fadeOut)
	end
	if not C.dialogueCam then
		C.inCutscene = false
	end
	Net.send("Menu", "CutsceneDone", { id = def.id })
end

function Cutscene.isPlaying(): boolean
	return playing ~= nil
end

function Cutscene.init()
	build()
	Net.on("Cutscene", function(def)
		task.spawn(Cutscene.play, def)
	end)
	Net.on("Fade", function(d)
		Cutscene.fade(d.to or "black", d.time or 0.5, d.color)
	end)
	RunService.RenderStepped:Connect(function(dt)
		if playing and playing.skippable ~= false and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			skipHeld += dt
			skipFill.Size = UDim2.fromScale(math.clamp(skipHeld / SKIP_TIME, 0, 1), 1)
			if skipHeld > SKIP_TIME then
				local def = playing
				skipHeld = 0
				Net.send("Menu", "Skip")
				Cutscene.finish(def)
			end
		else
			skipHeld = math.max(0, skipHeld - dt * 3)
			if skipFill then
				skipFill.Size = UDim2.fromScale(math.clamp(skipHeld / SKIP_TIME, 0, 1), 1)
			end
		end
	end)
end

return Cutscene
