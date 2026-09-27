--!nonstrict
-- Places outside the world: the god's white room, the old god's golden void,
-- the final white arena high above everything, and the empty space after the end.
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local RNG = require(Shared.RNG)
local Rig = require(Shared.Rig)
local S = require(script.Parent.S)

local Heaven = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB

Heaven.WHITE = V(0, 3000, 0)
Heaven.ELDER = V(0, 3000, 2000)
Heaven.FINAL = V(0, 12000, 0)
Heaven.VOID = V(4000, 6000, 4000)

-- Anchors only the root so procedural animation still moves the limbs.
function Heaven.pin(model: Model)
	local r = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if r then
		r.Anchored = true
	end
end

-- The kind god. Big, bright, smug.
function Heaven.god(parent: Instance, cf: CFrame, bible, scale: number?, dark: boolean?)
	local d = {
		name = bible.god,
		race = "Human",
		outfit = "robeGod",
		skin = if dark then rgb(8, 8, 10) else rgb(255, 238, 215),
		hair = if dark then rgb(0, 0, 0) else rgb(255, 250, 240),
		hairStyle = "long",
		beard = "long",
		shirt = if dark then rgb(4, 4, 6) else rgb(252, 250, 244),
		accent = if dark then rgb(20, 20, 24) else Palette.metal.gold,
		mood = if dark then "hollow" else "god",
		glow = if dark then rgb(255, 255, 255) else rgb(255, 225, 120),
		halo = if dark then rgb(20, 20, 20) else rgb(255, 230, 140),
		scale = scale or 3,
		health = 1000,
	}
	local m = Rig.build(d)
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

function Heaven.whiteRoom(bible)
	local W = S.World
	local f = W.sub("Heaven")
	local c = Heaven.WHITE
	local refs = {}
	W.solid(f, V(400, 2, 400), CF(c - V(0, 1, 0)), rgb(255, 255, 255), Enum.Material.SmoothPlastic)
	-- faint grid of lines to the horizon
	for i = -10, 10 do
		W.deco(f, V(0.2, 0.05, 400), CF(c + V(i * 20, 0.03, 0)), rgb(230, 232, 240))
		W.deco(f, V(400, 0.05, 0.2), CF(c + V(0, 0.03, i * 20)), rgb(230, 232, 240))
	end
	-- invisible walls
	for _, o in { V(200, 0, 0), V(-200, 0, 0), V(0, 0, 200), V(0, 0, -200) } do
		W.solid(f, if o.X ~= 0 then V(2, 200, 400) else V(400, 200, 2), CF(c + o + V(0, 100, 0)), rgb(255, 255, 255), nil, { Transparency = 1 })
	end
	-- throne of light
	local throneBase = c + V(0, 0, -40)
	for i = 0, 5 do
		W.solid(f, V(30 - i * 4, 2, 20 - i * 2), CF(throneBase + V(0, 1 + i * 2, 0)), rgb(255, 250, 235), Enum.Material.Marble)
	end
	W.solid(f, V(16, 40, 4), CF(throneBase + V(0, 20, -9)), rgb(255, 245, 220), Enum.Material.Marble)
	local sun = W.deco(f, V(10, 10, 1), CF(throneBase + V(0, 36, -11.5)), rgb(255, 230, 150), Enum.Material.Neon)
	Kit.pointLight(sun, rgb(255, 235, 170), 80, 2)
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		W.deco(f, V(1.2, 8, 0.6), CF(throneBase + V(0, 36, -11.4)) * ANG(0, 0, a) * CF(0, 10, 0), rgb(255, 220, 120), Enum.Material.Neon)
	end
	refs.god = Heaven.god(f, CF(throneBase + V(0, 12 + 6.5, -1)), bible, 3.2)
	refs.god:SetAttribute("Pose", "Throne")
	Heaven.pin(refs.god)
	-- floating cubes
	local rng = RNG.new(99)
	for i = 1, 40 do
		local p = W.deco(f, V(1, 1, 1) * rng:float(1, 4), CF(c + V(rng:float(-120, 120), rng:float(5, 60), rng:float(-120, 60))) * ANG(rng:angle(), rng:angle(), 0), rgb(245, 245, 250))
	end
	refs.spawn = CFrame.lookAt(c + V(0, 3, 30), c + V(0, 3, -40))
	refs.cam = CFrame.lookAt(c + V(12, 8, 18), throneBase + V(0, 22, 0))
	refs.godCam = CFrame.lookAt(c + V(0, 22, -8), throneBase + V(0, 25, 0))
	refs.throne = throneBase
	return refs
end

function Heaven.elderRoom(bible)
	local W = S.World
	local f = W.sub("Elder")
	local c = Heaven.ELDER
	local refs = {}
	local rng = RNG.new(77)
	-- floating broken platform of golden cubes
	for x = -5, 5 do
		for z = -5, 5 do
			if math.sqrt(x * x + z * z) < 5.5 + rng:float(-0.8, 0.5) then
				local h = rng:float(1.5, 4)
				W.solid(f, V(6, h, 6), CF(c + V(x * 6, -h / 2 + rng:float(-0.3, 0.3), z * 6)), Palette.jitter(rgb(210, 180, 120), 0.1, rng:float()), Enum.Material.Sandstone)
			end
		end
	end
	-- a giant stopped clock behind
	local cc = c + V(0, 40, -60)
	for i = 1, 60 do
		local a = i / 60 * math.pi * 2
		W.deco(f, V(2, 2, 2), CF(cc + V(math.cos(a) * 34, math.sin(a) * 34, 0)), if i % 5 == 0 then rgb(255, 240, 200) else rgb(200, 170, 110), Enum.Material.Neon)
	end
	W.deco(f, V(2, 26, 1), CF(cc) * ANG(0, 0, 0.3) * CF(0, 13, 0), rgb(255, 240, 200), Enum.Material.Neon)
	W.deco(f, V(3, 18, 1), CF(cc) * ANG(0, 0, -1.2) * CF(0, 9, 0), rgb(255, 240, 200), Enum.Material.Neon)
	for i = 1, 60 do
		W.deco(f, V(1, 1, 1) * rng:float(1, 5), CF(c + V(rng:float(-150, 150), rng:float(-60, 80), rng:float(-150, 150))) * ANG(rng:angle(), rng:angle(), 0), rgb(230, 200, 140), Enum.Material.Sandstone)
	end
	local elder = Rig.build({
		name = bible.elder,
		outfit = "robeGod",
		skin = rgb(220, 196, 170),
		hair = rgb(235, 230, 220),
		hairStyle = "long",
		beard = "ancient",
		shirt = rgb(150, 130, 100),
		accent = rgb(200, 170, 110),
		mood = "calm",
		glowEye = rgb(255, 220, 140),
		scale = 2.4,
		health = 1000,
	})
	elder:PivotTo(CFrame.lookAt(c + V(0, 8, -14), c + V(0, 8, 20)))
	elder.Parent = f
	elder:SetAttribute("Pose", "Meditate")
	Heaven.pin(elder)
	refs.elder = elder
	refs.spawn = CFrame.lookAt(c + V(0, 3, 14), c + V(0, 3, -14))
	refs.cam = CFrame.lookAt(c + V(10, 9, 10), c + V(0, 8, -14))
	return refs
end

-- The final white place where the god waits (and where you can fight him).
function Heaven.finalArena(bible)
	local W = S.World
	local f = W.sub("FinalWhite")
	local c = Heaven.FINAL
	local refs = {}
	W.solid(f, V(260, 4, 260), CF(c - V(0, 2, 0)), rgb(250, 250, 252), Enum.Material.Marble)
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		local p = c + V(math.cos(a) * 120, 0, math.sin(a) * 120)
		W.solid(f, V(8, 60, 8), CF(p + V(0, 30, 0)), rgb(245, 245, 250), Enum.Material.Marble)
		W.solid(f, V(12, 3, 12), CF(p + V(0, 61.5, 0)), rgb(255, 235, 170), Enum.Material.Marble)
	end
	for _, o in { V(130, 0, 0), V(-130, 0, 0), V(0, 0, 130), V(0, 0, -130) } do
		W.solid(f, if o.X ~= 0 then V(2, 300, 260) else V(260, 300, 2), CF(c + o + V(0, 150, 0)), rgb(255, 255, 255), nil, { Transparency = 1 })
	end
	W.circle(f, c + V(0, 0.2, 0), 40, rgb(255, 225, 140), false)
	refs.center = c
	refs.spawn = CFrame.lookAt(c + V(0, 3, 60), c)
	refs.godSpot = CFrame.lookAt(c + V(0, 12, -30), c + V(0, 12, 60))
	return refs
end

function Heaven.void()
	local W = S.World
	local f = W.sub("Void")
	local c = Heaven.VOID
	-- a tiny invisible floor so the player floats in nothing
	W.solid(f, V(60, 1, 60), CF(c - V(0, 3.5, 0)), rgb(0, 0, 0), nil, { Transparency = 1 })
	local rng = RNG.new(5)
	for i = 1, 30 do
		W.deco(f, V(1, 1, 1) * rng:float(0.5, 3), CF(c + V(rng:float(-200, 200), rng:float(-100, 100), rng:float(-200, 200))), rgb(60, 60, 70))
	end
	return { spawn = CFrame.new(c), center = c }
end

return Heaven
