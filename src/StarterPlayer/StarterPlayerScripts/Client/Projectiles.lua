--!nonstrict
-- Client-side projectile visuals mirroring the server simulation.
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Kit = require(Shared.Kit)
local C = require(script.Parent.C)

local P = {}
local active = {}
local paused = false
local folder: any = nil

function P.pause(on: boolean)
	paused = on
end

local function getFolder()
	if folder and folder.Parent then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "ClientProjectiles"
	folder.Parent = workspace
	return folder
end

local function makeVisual(d)
	local style = d.style
	local col = d.color or Color3.new(1, 1, 1)
	local size = d.size or 1
	local m = Instance.new("Model")
	local main = Instance.new("Part")
	main.Anchored = true
	main.CanCollide = false
	main.CanQuery = false
	main.CanTouch = false
	main.CastShadow = false
	main.Material = Enum.Material.Neon
	main.Color = col
	if style == "arrow" then
		main.Size = Vector3.new(0.14, 0.14, 2.6)
		main.Material = Enum.Material.Wood
		main.Color = Color3.fromRGB(150, 110, 70)
		local tip = Instance.new("Part")
		tip.Anchored = true
		tip.CanCollide = false
		tip.CanQuery = false
		tip.CanTouch = false
		tip.Size = Vector3.new(0.26, 0.26, 0.4)
		tip.Color = Color3.fromRGB(180, 185, 195)
		tip.Material = Enum.Material.Metal
		tip.Name = "Tip"
		tip.Parent = m
	elseif style == "rock" then
		main.Size = Vector3.one * size * 1.6
		main.Material = Enum.Material.Slate
		main.Color = Color3.fromRGB(110, 100, 95)
	elseif style == "slash" then
		main.Size = Vector3.new(size * 1.6, 0.25, size * 0.45)
		main.Transparency = 0.15
	else
		main.Shape = Enum.PartType.Ball
		main.Size = Vector3.one * size
		local l = Instance.new("PointLight")
		l.Color = col
		l.Range = size * 8
		l.Brightness = 2
		l.Parent = main
	end
	main.Name = "Main"
	main.Parent = m
	if style ~= "arrow" and style ~= "rock" then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, size * 0.3, 0)
		a0.Parent = main
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -size * 0.3, 0)
		a1.Parent = main
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = ColorSequence.new(col)
		tr.LightEmission = 1
		tr.Lifetime = if style == "slash" then 0.25 else 0.18
		tr.Transparency = NumberSequence.new(0.2, 1)
		tr.Parent = main
	end
	if style == "fire" then
		Kit.fire(main, col, size * 0.6)
	end
	m.Parent = getFolder()
	return m, main
end

local function place(p)
	local dir = if p.vel.Magnitude > 0.01 then p.vel.Unit else Vector3.new(0, 0, -1)
	local cf = CFrame.lookAt(p.pos, p.pos + dir)
	if p.style == "rock" then
		p.spin += 0.1
		cf *= CFrame.Angles(p.spin, p.spin * 0.7, 0)
	end
	p.main.CFrame = cf
	local tip = p.model:FindFirstChild("Tip")
	if tip then
		tip.CFrame = cf * CFrame.new(0, 0, -1.4)
	end
end

RunService.RenderStepped:Connect(function(dt)
	if paused then
		return
	end
	for id, p in active do
		p.pos += p.vel * dt
		p.vel += Vector3.new(0, -p.gravity * dt, 0)
		p.age += dt
		if p.age > 8 then
			p.model:Destroy()
			active[id] = nil
		else
			place(p)
		end
	end
end)

function P.init()
	Net.on("Projectile", function(kind, d)
		if kind == "spawn" then
			local m, main = makeVisual(d)
			local p = { model = m, main = main, pos = d.pos, vel = d.vel, gravity = d.gravity or 0, style = d.style, age = 0, spin = 0 }
			active[d.id] = p
			place(p)
			C.Audio.play(if d.style == "arrow" then "Swing" else "Magic", { pos = d.pos, pitch = if d.style == "arrow" then 1.5 else 0.7, vol = 0.6 })
		elseif kind == "sync" or kind == "redirect" then
			local p = active[d.id]
			if p then
				p.pos = d.pos
				p.vel = d.vel
				if kind == "redirect" then
					p.gravity = 0
					p.main.Color = Color3.fromRGB(140, 230, 255)
					C.FX.flash(d.pos, Color3.fromRGB(200, 240, 255), 5, 0.15)
				end
			end
		elseif kind == "end" then
			local p = active[d.id]
			if p then
				active[d.id] = nil
				p.model:Destroy()
			end
			if d.explode then
				C.FX.flash(d.pos, d.color or Color3.fromRGB(255, 150, 60), d.explode * 1.6, 0.3)
				C.FX.ring(d.pos, d.explode, d.color or Color3.fromRGB(255, 150, 60), 0.35)
				C.FX.burst(d.pos, Color3.fromRGB(70, 60, 55), 10, 24, 0.4, false, 1.2)
				C.Audio.play("Explosion", { pos = d.pos, pitch = 0.8 })
			elseif d.pos then
				C.FX.burst(d.pos, d.color or Color3.new(1, 1, 1), 6, 12, 0.2, true, 0.4)
			end
		end
	end)
end

return P
