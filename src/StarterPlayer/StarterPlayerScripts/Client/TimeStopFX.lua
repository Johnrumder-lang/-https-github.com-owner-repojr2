--!nonstrict
-- The look of TIME STOP: the world drains to black & white behind an expanding
-- sphere, particles freeze mid-air, sounds drag. When time resumes, colour rushes back.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local C = require(script.Parent.C)

local TS = {}
local player = Players.LocalPlayer
local cc: any = nil
local frozenEmitters = {}
local tickConn = nil
local endsAt = 0

local function ensureCC()
	if cc and cc.Parent then
		return cc
	end
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "TimeStopCC"
	cc.Saturation = 0
	cc.Contrast = 0
	cc.Brightness = 0
	cc.Enabled = true
	cc.Parent = Lighting
	return cc
end

local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function sphere(origin: Vector3, color: Color3, fromR: number, toR: number, t: number, mat)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = mat or Enum.Material.ForceField
	p.Color = color
	p.Transparency = 0.1
	p.Size = Vector3.one * fromR * 2
	p.CFrame = CFrame.new(origin)
	p.Parent = workspace.CurrentCamera
	tween(p, t, { Size = Vector3.one * toR * 2, Transparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(t + 0.05, function()
		p:Destroy()
	end)
	return p
end

local function freezeParticles(on: boolean)
	if on then
		for _, d in workspace:GetDescendants() do
			if d:IsA("ParticleEmitter") and d.TimeScale > 0 then
				frozenEmitters[d] = d.TimeScale
				d.TimeScale = 0
			end
		end
	else
		for e, ts in frozenEmitters do
			if e.Parent then
				e.TimeScale = ts
			end
		end
		frozenEmitters = {}
	end
end

function TS.start(d)
	local mine = d.stopper ~= nil and d.stopper == player.Character
	C.timeStop.active = true
	C.timeStop.mine = mine
	C.timeStop.inverted = d.inverted == true
	C.timeStop.scripted = d.scripted
	endsAt = if d.scripted then math.huge else os.clock() + (d.duration or 1)
	C.timeStop.endsAt = endsAt
	C.timeStop.duration = d.duration or 1
	local c = ensureCC()
	local origin = d.origin or workspace.CurrentCamera.CFrame.Position
	-- negative flash then grey
	c.TintColor = if C.timeStop.inverted then Color3.fromRGB(255, 200, 210) else Color3.fromRGB(255, 255, 255)
	tween(c, 0.06, { Contrast = 0.6, Brightness = 0.15, Saturation = -0.4 })
	task.delay(0.06, function()
		if C.timeStop.active then
			tween(c, 0.35, { Contrast = 0.22, Brightness = -0.03, Saturation = -1 })
		end
	end)
	sphere(origin, if C.timeStop.inverted then Color3.fromRGB(255, 60, 90) else Color3.fromRGB(200, 190, 255), 1, 180, 0.55)
	sphere(origin, Color3.new(1, 1, 1), 1, 60, 0.3, Enum.Material.Neon)
	task.delay(0.35, function()
		if C.timeStop.active then
			sphere(origin, Color3.new(0.1, 0.1, 0.1), 140, 4, 0.5)
		end
	end)
	C.Audio.play("TimeStop", { pitch = 0.55, ignoreTime = true, spread = 0 })
	C.Audio.play("Glass", { pitch = 0.5, vol = 0.6, ignoreTime = true })
	C.Audio.setTimeStop(true)
	C.Controller.punch(if mine then 16 else 8)
	C.Controller.shake(2, 0.35)
	if C.FX then
		C.FX.impactFrame(1)
		C.FX.focusLines(0.6, if C.timeStop.inverted then Color3.fromRGB(255, 120, 140) else Color3.new(1, 1, 1), 48)
	end
	freezeParticles(true)
	if C.FX then
		C.FX.setFrozen(true)
	end
	if C.Projectiles then
		C.Projectiles.pause(true)
	end
	if C.HUD then
		C.HUD.timeStop(true, mine, d.duration)
	end
	-- clock ticks
	if tickConn then
		tickConn:Disconnect()
	end
	local nextTick = os.clock() + 0.5
	tickConn = RunService.Heartbeat:Connect(function()
		if os.clock() >= nextTick then
			nextTick += 1
			C.Audio.play("Tick", { pitch = 0.8, ignoreTime = true, vol = 0.8 })
			C.Audio.play("Heartbeat", { pitch = 0.4, ignoreTime = true, vol = 0.5 })
		end
	end)
end

function TS.stop(d)
	if not C.timeStop.active then
		return
	end
	C.timeStop.active = false
	C.timeStop.mine = false
	C.timeStop.frozenSelf = false
	if tickConn then
		tickConn:Disconnect()
		tickConn = nil
	end
	local c = ensureCC()
	-- colour rushes back with an overshoot
	tween(c, 0.12, { Saturation = 0.45, Contrast = 0.3, Brightness = 0.06 })
	task.delay(0.12, function()
		if not C.timeStop.active then
			tween(c, 0.5, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
		end
	end)
	C.Audio.play("TimeResume", { pitch = 0.7, ignoreTime = true, vol = 1 })
	C.Audio.setTimeStop(false)
	C.Controller.punch(-10)
	C.Controller.shake(1.4, 0.3)
	if C.FX then
		C.FX.impactFrame(0.7)
		C.FX.focusLines(0.35, nil, 30)
	end
	freezeParticles(false)
	if C.FX then
		C.FX.setFrozen(false)
	end
	if C.Projectiles then
		C.Projectiles.pause(false)
	end
	if C.HUD then
		C.HUD.timeStop(false)
	end
	local ch = player.Character
	local r = ch and ch.PrimaryPart
	if r then
		sphere(r.Position, Color3.fromRGB(255, 255, 255), 60, 1, 0.25)
	end
end

function TS.remaining(): number
	if not C.timeStop.active then
		return 0
	end
	return math.max(0, endsAt - os.clock())
end

function TS.init()
	ensureCC()
	Net.on("TimeStop", function(phase, d)
		d = d or {}
		if phase == "start" then
			TS.start(d)
		elseif phase == "end" then
			TS.stop(d)
		elseif phase == "frozen" then
			C.timeStop.frozenSelf = true
			if C.HUD then
				C.HUD.frozenNotice()
			end
		elseif phase == "cooldown" then
			C.CombatClient.tsReady = d.ready or 0
			C.CombatClient.tsTotal = d.total or 1
		end
	end)
end

return TS
