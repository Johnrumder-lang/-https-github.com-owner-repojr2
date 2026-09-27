--!nonstrict
-- Applies zone lighting presets with smooth transitions + ambient particles.
-- In the Endless Tower the sky fades into deep space as you climb.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Zones = require(Shared.Zones)
local Util = require(Shared.Util)
local C = require(script.Parent.C)

local Mood = {}
local cam = workspace.CurrentCamera
local atmo, cc, bloom, rays, sky, dof
local current = "menu"
local ambient: any = nil

local function ensure()
	atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Parent = Lighting
	cc = Lighting:FindFirstChild("MoodCC") or Instance.new("ColorCorrectionEffect")
	cc.Name = "MoodCC"
	cc.Parent = Lighting
	bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Parent = Lighting
	rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Parent = Lighting
	sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.Parent = Lighting
	dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect") or Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 60
	dof.InFocusRadius = 70
	dof.NearIntensity = 0
	dof.Parent = Lighting
end

-- cloud layer per zone: {cover, density, colour}; zones not listed have a clear sky
local rgb = Color3.fromRGB
local CLOUDS = {
	Meadow = { 0.62, 0.62 },
	Autumn = { 0.55, 0.7, rgb(255, 225, 200) },
	Desert = { 0.18, 0.35 },
	Frost = { 0.82, 0.78 },
	Swamp = { 0.9, 0.85, rgb(170, 180, 160) },
	Volcanic = { 0.86, 0.9, rgb(80, 50, 45) },
	Crystal = { 0.4, 0.5, rgb(200, 190, 255) },
	Mushroom = { 0.6, 0.7, rgb(210, 180, 220) },
	Evil = { 0.9, 0.95, rgb(70, 20, 26) },
	Fjord = { 0.78, 0.75, rgb(215, 222, 232) },
	Giantwood = { 0.58, 0.62 },
	fields = { 0.6, 0.6 },
	arena = { 0.4, 0.5 },
	titan = { 0.85, 0.9, rgb(150, 90, 80) },
	village_burning = { 0.8, 0.85, rgb(120, 70, 60) },
	castle_burning = { 0.85, 0.9, rgb(90, 50, 40) },
	street_day = { 0.5, 0.55 },
	street_evening = { 0.6, 0.6, rgb(255, 190, 160) },
	ending = { 0.5, 0.55, rgb(255, 230, 210) },
	tower = { 0.7, 0.8, rgb(90, 30, 40) },
}
local clouds: any = nil
-- open-world zones run a slow day/night cycle; nights are moonlit and blue
local cycle: any = nil
local DAY_LENGTH = 16 * 60 -- seconds for a full day
local NIGHT = {
	Brightness = 1.2,
	Ambient = rgb(38, 42, 64),
	OutdoorAmbient = rgb(66, 76, 116),
	atmo = rgb(62, 74, 112),
	decay = rgb(24, 28, 54),
	tint = rgb(212, 222, 255),
}

local function tw(o, t, props)
	TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props):Play()
end

function Mood.apply(name: string, time: number?)
	local p = Zones.PRESETS[name]
	if not p then
		return
	end
	ensure()
	current = name
	local t = time or 2
	local clock = p.ClockTime
	-- tween clock the short way
	local cur = Lighting.ClockTime
	if math.abs(clock - cur) > 12 then
		Lighting.ClockTime = clock
	else
		tw(Lighting, t, { ClockTime = clock })
	end
	tw(Lighting, t, {
		Brightness = p.Brightness,
		Ambient = p.Ambient,
		OutdoorAmbient = p.OutdoorAmbient,
		ExposureCompensation = p.ExposureCompensation,
		EnvironmentDiffuseScale = p.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = p.EnvironmentSpecularScale,
	})
	tw(atmo, t, p.atmosphere)
	tw(cc, t, p.cc)
	tw(bloom, t, p.bloom)
	tw(rays, t, p.rays)
	sky.StarCount = p.sky.StarCount or 3000
	sky.CelestialBodiesShown = p.sky.CelestialBodiesShown ~= false
	sky.MoonAngularSize = p.sky.MoonAngularSize or 14
	cycle = if p.cycle then { p = p, t0 = os.clock(), start = p.ClockTime, after = os.clock() + t } else nil
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		if not clouds or not clouds.Parent then
			clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
			clouds.Parent = terrain
		end
		local cl = CLOUDS[name]
		if cl then
			clouds.Enabled = true
			tw(clouds, t, { Cover = cl[1], Density = cl[2], Color = cl[3] or Color3.new(1, 1, 1) })
		else
			tw(clouds, math.min(t, 0.5), { Cover = 0 })
		end
	end
	Mood.ambientParticles(name)
end

function Mood.ambientParticles(name: string)
	if ambient then
		ambient:Destroy()
		ambient = nil
	end
	local kinds = {
		pit = { color = Color3.fromRGB(180, 120, 255), rate = 14, speed = 0.4, size = 0.14, light = 1 },
		whiteroom = { color = Color3.fromRGB(255, 255, 255), rate = 10, speed = 0.3, size = 0.2, light = 1 },
		elder = { color = Color3.fromRGB(255, 220, 150), rate = 16, speed = 0.3, size = 0.18, light = 1 },
		village_burning = { color = Color3.fromRGB(255, 140, 40), rate = 30, speed = 2, size = 0.18, light = 1, up = 3 },
		castle_burning = { color = Color3.fromRGB(255, 140, 40), rate = 40, speed = 2, size = 0.2, light = 1, up = 4 },
		titan = { color = Color3.fromRGB(120, 100, 90), rate = 30, speed = 1, size = 0.3, light = 0 },
		Frost = { color = Color3.fromRGB(255, 255, 255), rate = 60, speed = 3, size = 0.2, light = 0.3, up = -6 },
		Desert = { color = Color3.fromRGB(240, 210, 150), rate = 18, speed = 5, size = 0.14, light = 0 },
		Swamp = { color = Color3.fromRGB(200, 255, 120), rate = 12, speed = 0.3, size = 0.16, light = 1 },
		Mushroom = { color = Color3.fromRGB(150, 255, 200), rate = 20, speed = 0.4, size = 0.16, light = 1 },
		Crystal = { color = Color3.fromRGB(180, 160, 255), rate = 20, speed = 0.4, size = 0.16, light = 1 },
		Volcanic = { color = Color3.fromRGB(255, 120, 30), rate = 40, speed = 2, size = 0.16, light = 1, up = 3 },
		Evil = { color = Color3.fromRGB(255, 40, 40), rate = 26, speed = 1.5, size = 0.16, light = 1, up = 2 },
		Autumn = { color = Color3.fromRGB(230, 120, 40), rate = 10, speed = 1.2, size = 0.3, light = 0, up = -2 },
		Fjord = { color = Color3.fromRGB(235, 240, 255), rate = 18, speed = 2.2, size = 0.12, light = 0.2, up = -2 },
		Giantwood = { color = Color3.fromRGB(210, 245, 150), rate = 16, speed = 0.5, size = 0.14, light = 0.7, up = -0.4 },
		tower = { color = Color3.fromRGB(255, 60, 60), rate = 20, speed = 1, size = 0.16, light = 1, up = 2 },
		space = { color = Color3.fromRGB(200, 200, 255), rate = 10, speed = 0.2, size = 0.12, light = 1 },
		street_night = { color = Color3.fromRGB(180, 200, 255), rate = 4, speed = 0.3, size = 0.08, light = 0.5 },
		menu = { color = Color3.fromRGB(180, 170, 255), rate = 10, speed = 0.3, size = 0.12, light = 1 },
	}
	local k = kinds[name]
	if not k then
		return
	end
	local p = Instance.new("Part")
	p.Name = "AmbientFX"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(90, 40, 90)
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(k.color)
	e.LightEmission = k.light
	e.Rate = k.rate
	e.Lifetime = NumberRange.new(4, 8)
	e.Speed = NumberRange.new(k.speed * 0.5, k.speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, k.up or 0, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, k.size), NumberSequenceKeypoint.new(0.8, k.size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.2)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = p
	ambient = p
end

local function nightAmount(clock: number): number
	-- 1 between 20:30 and 04:30, easing over two hours at dusk and dawn
	if clock >= 20.5 or clock <= 4.5 then
		return 1
	elseif clock > 18.5 then
		return (clock - 18.5) / 2
	elseif clock < 6.5 then
		return 1 - (clock - 4.5) / 2
	end
	return 0
end

local function stepCycle()
	if not cycle or os.clock() < cycle.after then
		return
	end
	local p = cycle.p
	local clock = (cycle.start + (os.clock() - cycle.t0) / DAY_LENGTH * 24) % 24
	Lighting.ClockTime = clock
	local n = nightAmount(clock)
	n = n * n * (3 - 2 * n)
	Lighting.Brightness = Util.lerp(p.Brightness, NIGHT.Brightness, n)
	Lighting.Ambient = p.Ambient:Lerp(NIGHT.Ambient, n)
	Lighting.OutdoorAmbient = p.OutdoorAmbient:Lerp(NIGHT.OutdoorAmbient, n)
	if atmo then
		atmo.Color = p.atmosphere.Color:Lerp(NIGHT.atmo, n)
		atmo.Decay = p.atmosphere.Decay:Lerp(NIGHT.decay, n)
	end
	if cc then
		cc.TintColor = p.cc.TintColor:Lerp(NIGHT.tint, n)
	end
	if sky then
		sky.StarCount = math.floor(Util.lerp(p.sky.StarCount or 3000, 5000, n))
	end
end

RunService.RenderStepped:Connect(function()
	if ambient then
		ambient.CFrame = CFrame.new(cam.CFrame.Position)
	end
	stepCycle()
	-- the Endless Tower: climb into space
	if current == "tower" and atmo then
		local y = cam.CFrame.Position.Y
		local k = math.clamp((y - 300) / 8500, 0, 1)
		atmo.Density = Util.lerp(0.4, 0, k)
		atmo.Haze = Util.lerp(2, 0, k)
		Lighting.ClockTime = Util.lerp(19.6, 24, k) % 24
		Lighting.Brightness = Util.lerp(0.9, 0.3, k)
		sky.StarCount = math.floor(Util.lerp(500, 5000, k))
	end
end)

function Mood.init()
	ensure()
	Mood.apply("menu", 0.1)
	Net.on("Zone", function(d)
		if d.preset then
			Mood.apply(d.preset, d.time)
		end
		if d.title then
			C.HUD.zone(d.title, d.sub)
		end
	end)
end

return Mood
