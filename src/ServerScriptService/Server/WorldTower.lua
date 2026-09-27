--!nonstrict
-- THE ENDLESS TOWER: an obsidian spire 10,000 studs tall in the Evil Lands.
-- Challenge platforms cling to it; the last one floats in deep space.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(Shared.Kit)
local Palette = require(Shared.Palette)
local Util = require(Shared.Util)
local S = require(script.Parent.S)

local Tower = {}
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB

Tower.STOPS = { 420, 1300, 2400, 3700, 5200, 6800, 8400, 10000 }
Tower.HEIGHT = 10000

function Tower.build(base: Vector3)
	local W = S.World
	local f = W.sub("Tower")
	local refs = { stops = {}, base = base }
	local obs = rgb(22, 16, 24)
	local red = rgb(255, 30, 50)
	local seg = 500
	local n = math.ceil(Tower.HEIGHT / seg)
	for i = 0, n - 1 do
		local y = i * seg
		local k = y / Tower.HEIGHT
		local w = Util.lerp(80, 30, k)
		local cf = CF(base + V(0, y + seg / 2, 0)) * ANG(0, i * 0.08, 0)
		W.solid(f, V(w, seg, w), cf, Palette.shade(obs, 1 + (i % 2) * 0.15), Enum.Material.Basalt)
		local ring = W.deco(f, V(w + 3, 2, w + 3), CF(base + V(0, y + seg, 0)) * ANG(0, i * 0.08, 0), red, Enum.Material.Neon)
		if i % 2 == 0 then
			Kit.pointLight(ring, red, 60, 2)
		end
		for j = 1, 4 do
			local a = j * math.pi / 2 + i * 0.08
			local dir = V(math.sin(a), 0, math.cos(a))
			W.deco(f, V(3, 40, 1), CF(base + V(0, y + seg * 0.5, 0) + dir * (w / 2 + 0.1)) * ANG(0, a, 0), red, Enum.Material.Neon, { Transparency = 0.2 })
		end
	end
	-- base entrance
	local bw = 80
	local doorP = base + V(0, 0, bw / 2 + 0.5)
	local door = W.deco(f, V(16, 26, 1), CF(doorP + V(0, 13, 0)), rgb(5, 0, 5), Enum.Material.SmoothPlastic)
	local glow = W.deco(f, V(18, 28, 0.6), CF(doorP + V(0, 13, -0.3)), red, Enum.Material.Neon, { Transparency = 0.5 })
	Kit.pointLight(glow, red, 40, 3)
	refs.door = door
	refs.doorFront = CFrame.lookAt(doorP + V(0, 4, 14), doorP + V(0, 4, 0))
	-- challenge platforms
	for i, h in Tower.STOPS do
		local k = h / Tower.HEIGHT
		local w = Util.lerp(80, 30, k)
		local top = i == #Tower.STOPS
		local center = if top then base + V(0, h, 0) else base + V(0, h, w / 2 + 46)
		local size = if top then 130 else 90
		W.solid(f, V(size, 4, size), CF(center - V(0, 2, 0)), rgb(40, 30, 40), Enum.Material.Slate)
		-- edge walls & crenels
		for _, o in { V(size / 2, 0, 0), V(-size / 2, 0, 0), V(0, 0, size / 2), V(0, 0, -size / 2) } do
			local horiz = o.X ~= 0
			W.solid(f, if horiz then V(3, 3, size) else V(size, 3, 3), CF(center + o + V(0, 1.5, 0)), rgb(60, 40, 50), Enum.Material.Slate)
			W.solid(f, if horiz then V(2, 60, size) else V(size, 60, 2), CF(center + o + V(0, 30, 0)), rgb(0, 0, 0), nil, { Transparency = 1 })
		end
		for j = 1, 4 do
			local a = j / 4 * math.pi * 2 + math.pi / 4
			local p = center + V(math.cos(a) * size * 0.42, 0, math.sin(a) * size * 0.42)
			W.solid(f, V(3, 10, 3), CF(p + V(0, 5, 0)), rgb(30, 20, 30), Enum.Material.Basalt)
			local head = W.deco(f, V(2, 2, 2), CF(p + V(0, 11, 0)), red, Enum.Material.Neon)
			Kit.fire(head, rgb(255, 40, 60), 1.4)
			Kit.pointLight(head, red, 40, 2)
		end
		local circle = W.circle(f, center + V(0, 0.1, 0), if top then 30 else 12, if top then rgb(255, 255, 255) else red, false)
		table.insert(refs.stops, {
			height = h,
			center = center,
			spawn = CFrame.lookAt(center + V(0, 3, size * 0.3), center + V(0, 3, 0)),
			size = size,
			top = top,
		})
	end
	refs.top = refs.stops[#refs.stops]
	return refs
end

return Tower
