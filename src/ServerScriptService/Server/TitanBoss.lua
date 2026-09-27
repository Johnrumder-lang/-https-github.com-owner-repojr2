--!nonstrict
-- The Kingdom-Eater fight. Server side of the titan: builds the body, picks
-- actions on the titan clock (which pauses in time stop), resolves stomps,
-- sweeps, thrown chunks of city and roars, and owns the six weak-point cores.
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local TitanAnim = require(Shared.TitanAnim)
local Palette = require(Shared.Palette)
local Util = require(Shared.Util)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)

local TB = {}
local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB
local rng = RNG.new(8080)

local KINDS = {
	stone = { body = rgb(110, 104, 96), dark = rgb(80, 74, 70), accent = rgb(90, 130, 70), mat = Enum.Material.Slate, core = rgb(255, 150, 40) },
	flesh = { body = rgb(170, 90, 90), dark = rgb(120, 50, 56), accent = rgb(230, 220, 200), mat = Enum.Material.SmoothPlastic, core = rgb(255, 230, 90) },
	abyss = { body = rgb(40, 30, 50), dark = rgb(24, 18, 30), accent = rgb(140, 60, 220), mat = Enum.Material.Basalt, core = rgb(190, 90, 255) },
}

local function D_shake(i, t)
	if S.Director then
		S.Director.shake(i, t)
	end
end

function TB.clock(): number
	return S.TimeStop.clock()
end

local function mkPart(parent, name, size, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function TB.create(rootCF: CFrame, bible)
	local folder = S.World.sub("Titan")
	local model = Instance.new("Model")
	model.Name = "Titan"
	local k = KINDS[bible.titanKind] or KINDS.stone
	local parts = {}
	for _, n in TitanAnim.ORDER do
		local col = if n:find("Foot") or n:find("Hand") then k.dark else k.body
		parts[n] = mkPart(model, n, TitanAnim.SIZES[n], col, k.mat)
	end
	-- decorations that follow a limb (client reads Limb + Offset attributes).
	-- Sizes and offsets are given at scale 1 and scaled with the skeleton.
	local SC = TitanAnim.SCALE
	local decos = {}
	local function deco(limb, size, off, color, mat)
		local p = mkPart(model, "Deco", size * SC, color, mat or k.mat)
		local o = CF(off.Position * SC) * off.Rotation
		p:SetAttribute("Limb", limb)
		p:SetAttribute("Offset", o)
		table.insert(decos, { part = p, limb = limb, off = o })
		return p
	end
	local ANG = CFrame.Angles
	local bone = rgb(226, 216, 192)
	local black = rgb(20, 16, 18)
	local function glow(limb, size, off)
		local p = deco(limb, size, off, k.core, Enum.Material.Neon)
		p.Transparency = 0.15
		return p
	end
	-- torso: chest plates, belly plates, collar, spines, glowing cracks
	for _, sx in { -1, 1 } do
		deco("Torso", V(25, 17, 6), CF(sx * 13, 14, -19), k.dark)
		deco("Torso", V(6, 12, 30), CF(sx * 31, 18, 0), k.dark)
	end
	for i = 0, 2 do
		deco("Torso", V(21 - i * 2, 8, 5), CF(0, -2 - i * 9, -18.6), Palette.shade(k.dark, 1 + i * 0.05))
	end
	deco("Torso", V(66, 8, 42), CF(0, 30, 0), k.dark)
	for i = 0, 4 do
		deco("Torso", V(8, 14 - i * 1.5, 8), CF(0, 24 - i * 12, 20) * ANG(-0.5, 0, 0), k.dark)
		deco("Torso", V(4, 9, 4), CF((if i % 2 == 0 then -1 else 1) * 14, 20 - i * 11, 19.5) * ANG(-0.6, 0, 0), k.accent)
	end
	glow("Torso", V(1.4, 22, 1), CF(-8, 4, -18.4) * ANG(0, 0, 0.35))
	glow("Torso", V(1.4, 16, 1), CF(9, -6, -18.4) * ANG(0, 0, -0.5))
	glow("Torso", V(1.4, 18, 1), CF(-16, 16, 18.4) * ANG(0, 0, 0.2))
	-- a chunk of the city it carried off, still stuck on its shoulders
	deco("Torso", V(9, 7, 9), CF(-22, 37, 6) * ANG(0, 0.4, 0.1), rgb(222, 212, 190), Enum.Material.Plaster)
	deco("Torso", V(10, 3, 10), CF(-22, 42, 6) * ANG(0, 0.4, 0.1), rgb(150, 70, 50), Enum.Material.ClayRoofTiles)
	deco("Torso", V(7, 10, 7), CF(21, 38, 9) * ANG(0.1, -0.3, 0), rgb(170, 166, 158), Enum.Material.Cobblestone)
	-- head: brow, eye socket, jaw, teeth, nose, cheeks, curved horns
	deco("Head", V(34, 6, 10), CF(0, 8, -13), k.dark)
	deco("Head", V(14, 9, 1.2), CF(0, 3, -16.2), black, Enum.Material.SmoothPlastic)
	deco("Head", V(11, 11, 1.2), CF(0, 9.5, -16.3), black, Enum.Material.SmoothPlastic)
	deco("Head", V(28, 9, 22), CF(0, -17, -6), k.dark)
	for i = 0, 5 do
		deco("Head", V(3, 4.5, 3), CF(-10 + i * 4, -12.2, -16.4), bone, Enum.Material.SmoothPlastic)
	end
	deco("Head", V(6, 8, 4), CF(0, -3, -17.6), Palette.shade(k.body, 1.1))
	for _, sx in { -1, 1 } do
		deco("Head", V(4, 14, 18), CF(sx * 17, -4, -6), k.accent)
		deco("Head", V(7, 13, 7), CF(sx * 16, 20, -2) * ANG(0, 0, -sx * 0.55), bone)
		deco("Head", V(5.5, 12, 5.5), CF(sx * 23, 29, -3) * ANG(-0.15, 0, -sx * 0.2), bone)
		deco("Head", V(4, 11, 4), CF(sx * 25, 39, -6) * ANG(-0.4, 0, sx * 0.15), Palette.shade(bone, 0.9))
	end
	-- arms: pauldrons with spikes, bracers, elbow spikes, fingers, glowing veins
	for _, sd in { "L", "R" } do
		local sx = if sd == "L" then -1 else 1
		deco(sd .. "Upper", V(24, 11, 24), CF(0, 20, 0), k.dark)
		for j = -1, 1 do
			deco(sd .. "Upper", V(4, 11, 4), CF(sx * 6, 29, j * 7) * ANG(0, 0, -sx * 0.3), k.accent)
		end
		glow(sd .. "Upper", V(1.2, 16, 1), CF(0, -2, -7.6))
		deco(sd .. "Fore", V(15.5, 18, 15.5), CF(0, -8, 0), k.accent)
		deco(sd .. "Fore", V(4, 10, 4), CF(0, 21, 7.5) * ANG(0.6, 0, 0), bone)
		glow(sd .. "Fore", V(1.2, 12, 1), CF(0, 10, -6.6))
		for j = 0, 3 do
			deco(sd .. "Hand", V(3.6, 11, 4.4), CF(-6 + j * 4, -12, -3), k.dark)
			deco(sd .. "Hand", V(3, 3, 3), CF(-6 + j * 4, -18.5, -3.5), bone, Enum.Material.SmoothPlastic)
		end
		deco(sd .. "Hand", V(4.5, 9, 4.5), CF(sx * 9.5, -5, -4) * ANG(0, 0, sx * 0.5), k.dark)
		-- legs: thigh and knee plates, shin guards, toe claws
		deco(sd .. "Thigh", V(20, 6, 20), CF(0, -22, 0), k.accent)
		deco(sd .. "Thigh", V(14, 22, 3), CF(0, 6, -9.6), k.dark)
		deco(sd .. "Shin", V(18, 14, 4), CF(0, 14, -8.5), k.dark)
		deco(sd .. "Shin", V(5, 11, 5), CF(0, 24, -9) * ANG(-0.5, 0, 0), bone)
		glow(sd .. "Shin", V(1.2, 12, 1), CF(4, -2, -8.2))
		for j = 0, 2 do
			deco(sd .. "Foot", V(4.5, 5, 9), CF(-6 + j * 6, -1.5, -17.5), bone, Enum.Material.SmoothPlastic)
		end
	end
	-- pelvis: belt, loin plates, a broken chain
	deco("Pelvis", V(50, 8, 34), CF(0, -8, 0), k.dark)
	deco("Pelvis", V(22, 22, 3), CF(0, -19, -16), k.accent)
	deco("Pelvis", V(28, 24, 3), CF(0, -19, 16), k.accent)
	for i = 0, 3 do
		deco("Pelvis", V(3, 2.2, 5), CF(26, -8 - i * 4, -6 + i * 1.5) * ANG(0, 0, 0.3 * i), rgb(70, 68, 72), Enum.Material.Metal)
	end
	-- mossy patches from sleeping under the mountains
	deco("Torso", V(20, 2, 14), CF(-6, 31.5, 8), rgb(84, 120, 56), Enum.Material.Grass)
	deco("LThigh", V(12, 2, 10), CF(0, 25.5, 2), rgb(84, 120, 56), Enum.Material.Grass)
	-- cores
	local cores = {}
	for name, c in TitanAnim.CORES do
		local p = mkPart(model, name, V(9, 9, 9) * TitanAnim.SCALE, k.core, Enum.Material.Neon)
		local l = Instance.new("PointLight")
		l.Color = k.core
		l.Range = 60
		l.Brightness = 3
		l.Parent = p
		cores[name] = p
	end
	-- initial pose
	local solved = TitanAnim.solve(rootCF, TitanAnim.pose("idle", 0))
	for n, cf in solved do
		parts[n].CFrame = cf
	end
	for _, d in decos do
		d.part.CFrame = solved[d.limb] * d.off
	end
	for name, p in cores do
		p.CFrame = CF(TitanAnim.corePos(solved, name))
	end
	model.PrimaryPart = parts.Pelvis
	model.Parent = folder
	local st = {
		model = model,
		parts = parts,
		coreParts = cores,
		kind = k,
		root = rootCF,
		action = "idle",
		clock0 = TB.clock(),
		from = rootCF,
		to = rootCF,
		moveDur = 0,
		coreEntities = {},
		name = bible.titan .. ", " .. bible.titanTitle,
		phase = 1,
		dead = false,
	}
	Net.fireAll("Scene", "titanStart", { model = model, root = rootCF, clock = TB.clock() })
	return st
end

function TB.play(st, action: string, to: CFrame?, moveDur: number?)
	local now = TB.clock()
	-- where are we right now?
	local cur = TB.currentRoot(st)
	st.action = action
	st.clock0 = now
	st.from = cur
	st.to = to or cur
	st.moveDur = moveDur or 0
	Net.fireAll("Scene", "titanAction", { action = action, clock0 = now, clock = now, from = st.from, to = st.to, moveDur = st.moveDur })
end

function TB.currentRoot(st): CFrame
	local t = TB.clock() - st.clock0
	local k = if st.moveDur > 0 then Util.smooth(t / st.moveDur) else 1
	return st.from:Lerp(st.to, k)
end

function TB.solve(st)
	local t = TB.clock() - st.clock0
	local def = TitanAnim.ACTIONS[st.action]
	local loops = st.action == "idle" or st.action == "walk" or st.action == "down" or st.action == "hover"
	local tt = if loops then t else math.min(t, def.dur)
	return TitanAnim.solve(TB.currentRoot(st), TitanAnim.pose(st.action, tt))
end

function TB.elapsed(st): number
	return TB.clock() - st.clock0
end

-- waits on the titan clock (pauses during time stop)
function TB.waitUntil(st, t: number)
	while TB.elapsed(st) < t and not st.dead do
		task.wait(0.03)
	end
end

local function ground(p: Vector3): Vector3
	return S.World.ground(p) or V(p.X, 0, p.Z)
end

local SC = TitanAnim.SCALE

-- height of the ground under a point (the capital's heightfield when it's built)
local function floorY(x: number, z: number): number
	local ga = S.WorldCapital and S.WorldCapital.groundAt
	if ga then
		return ga(x, z)
	end
	return ground(V(x, 0, z)).Y
end

-- A root frame standing on the highest ground under the titan's feet, facing
-- `fwd`, so it never wades inside a city tier.
function TB.rootAt(x: number, z: number, fwd: Vector3): CFrame
	local right = fwd:Cross(V(0, 1, 0))
	local y = floorY(x, z)
	for _, o in { right * 30 * SC, -right * 30 * SC, fwd * 20 * SC, -fwd * 20 * SC } do
		y = math.max(y, floorY(x + o.X, z + o.Z))
	end
	local p = V(x, y, z)
	return CFrame.lookAt(p, p + fwd)
end

-- ------------------------------------------------------------------ cores
function TB.makeCores(st, names, hp: number, level: number)
	for _, name in names do
		local e = S.Entities.new(nil, {
			kind = "npc",
			team = "monster",
			name = st.name,
			virtual = true,
			boss = true,
			poise = true,
			radius = 11,
			hp = hp,
			level = level,
			xp = 400,
			blood = "gold",
			tags = { titanCore = true, ["core_" .. name] = true },
			noDrop = true,
			pos = function()
				local parts = TB.solve(st)
				return TitanAnim.corePos(parts, name)
			end,
		})
		e.noRagdoll = true
		e.onDie = function()
			local p = st.coreParts[name]
			if p then
				Net.fireAll("FX", "Explosion", { pos = p.Position, radius = 14, color = st.kind.core })
				Net.fireAll("FX", "Debris", { pos = p.Position, count = 30, speed = 50, size = 2, color = st.kind.body })
				p:Destroy()
				st.coreParts[name] = nil
			end
			D_shake(4, 0.8)
		end
		st.coreEntities[name] = e
	end
end

function TB.aliveCores(st, names)
	local n = 0
	for _, name in names do
		local e = st.coreEntities[name]
		if e and S.Entities.isAlive(e) then
			n += 1
		end
	end
	return n
end

function TB.hpFrac(st)
	local hp, max = 0, 0
	for _, e in st.coreEntities do
		max += e.maxHp or 1
		hp += math.max(0, e.hp or 0)
	end
	return hp, math.max(max, 1)
end

-- ------------------------------------------------------------------ attacks
local function nearestPlayer(p: Vector3)
	local best, bd = nil, math.huge
	for _, e in S.Entities.players() do
		local d = Util.flatDist(S.Entities.position(e), p)
		if d < bd then
			best, bd = e, d
		end
	end
	return best, bd
end

local function breakCity(center: Vector3, radius: number, force: number)
	local city = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("City")
	if not city then
		return
	end
	local n = 0
	for _, d in city:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored and n < 40 then
			if Util.flatDist(d.Position, center) < radius then
				n += 1
				S.World.breakPart(d, Util.flatUnit(d.Position - center) * force + V(0, force * 0.8, 0))
			end
		end
	end
end
TB.breakCity = breakCity

function TB.stomp(st, target, dmg: number)
	local tp = S.Entities.position(target)
	local cur = TB.currentRoot(st)
	local side = if rng:chance(0.5) then 1 else -1
	local action = if side > 0 then "stompR" else "stompL"
	local fwd = Util.flatUnit(tp - cur.Position)
	local right = fwd:Cross(V(0, 1, 0))
	local rootPos = V(tp.X, 0, tp.Z) - fwd * 49 * SC - right * 18 * SC * side
	local to = TB.rootAt(rootPos.X, rootPos.Z, fwd)
	TB.play(st, action, to, 1.5)
	local def = TitanAnim.ACTIONS[action]
	TB.waitUntil(st, def.hit - 0.9)
	-- warn where it lands
	local parts = TitanAnim.solve(to, TitanAnim.pose(action, def.hit + 0.1))
	local foot = parts[if side > 0 then "RFoot" else "LFoot"].Position
	local g = ground(foot)
	S.Bosses.circle(g, 26 * SC, 0.9, rgb(255, 60, 40))
	TB.waitUntil(st, def.hit)
	Net.fireAll("FX", "Shockwave", { pos = g, radius = 34 * SC, color = rgb(220, 190, 150) })
	Net.fireAll("FX", "Debris", { pos = g + V(0, 2, 0), count = 26, speed = 55, size = 1.6, color = rgb(120, 110, 100) })
	D_shake(5, 0.7)
	S.Combat.aoe(nil, g, 26 * SC, { dmg = dmg, kbPower = 70, kbUp = 45, attackType = "aoe", kind = "stomp" }, function(e)
		return e.team == "hero"
	end)
	breakCity(g, 30 * SC, 60)
	TB.waitUntil(st, def.dur)
end

function TB.sweep(st, target, dmg: number)
	local tp = S.Entities.position(target)
	local cur = TB.currentRoot(st)
	local fwd = Util.flatUnit(tp - cur.Position)
	local dist = Util.flatDist(tp, cur.Position)
	local rootPos = V(cur.Position.X, 0, cur.Position.Z)
	if dist > 90 * SC or dist < 40 * SC then
		rootPos = V(tp.X, 0, tp.Z) - fwd * 70 * SC
	end
	local to = TB.rootAt(rootPos.X, rootPos.Z, fwd)
	local action = if rng:chance(0.5) then "sweep" else "sweepL"
	TB.play(st, action, to, 1.2)
	local def = TitanAnim.ACTIONS[action]
	TB.waitUntil(st, def.hitFrom - 0.6)
	Net.fireAll("FX", "Text", { pos = tp + V(0, 6, 0), text = "JUMP!", color = rgb(255, 220, 60), size = 1.3 })
	TB.waitUntil(st, def.hitFrom)
	local hit = {}
	local hand = if action == "sweep" then "RHand" else "LHand"
	while TB.elapsed(st) < def.hitTo and not st.dead do
		local parts = TB.solve(st)
		local hp = parts[hand].Position
		for _, e in S.Entities.players() do
			if not hit[e] then
				local p = S.Entities.position(e)
				local g = ground(p)
				if Util.flatDist(p, hp) < 17 * SC and p.Y - g.Y < 6 then
					hit[e] = true
					S.Combat.hit(nil, e, { dmg = dmg, kb = Util.flatUnit(p - cur.Position) * 60 + V(0, 40, 0), attackType = "heavy", kind = "sweep", pos = p })
				end
			end
		end
		breakCity(hp, 14 * SC, 40)
		task.wait(0.06)
	end
	TB.waitUntil(st, def.dur)
end

function TB.throw(st, target, dmg: number)
	local tp = S.Entities.position(target)
	local cur = TB.currentRoot(st)
	local fwd = Util.flatUnit(tp - cur.Position)
	local to = TB.rootAt(cur.Position.X, cur.Position.Z, fwd)
	TB.play(st, "throw", to, 0.8)
	local def = TitanAnim.ACTIONS.throw
	TB.waitUntil(st, def.release)
	local parts = TB.solve(st)
	local from = parts.RHand.Position
	tp = S.Entities.position(target)
	local d = (tp - from)
	local speed = 150
	local t = d.Magnitude / speed
	local vel = d.Unit * speed + V(0, 0.5 * 60 * t, 0)
	S.Projectiles.fire(nil, from, vel, { size = 7, color = rgb(120, 110, 100), style = "rock", gravity = 60, explode = 16, life = 5 }, { dmg = dmg, kbPower = 60 })
	TB.waitUntil(st, def.dur)
end

function TB.roar(st, dmg: number)
	TB.play(st, "roar")
	local def = TitanAnim.ACTIONS.roar
	TB.waitUntil(st, def.hit)
	local c = TB.currentRoot(st).Position
	Net.fireAll("FX", "Shockwave", { pos = ground(c), radius = 80 * SC, color = rgb(255, 255, 255) })
	Net.fireAll("FX", "Text", { pos = c + V(0, 120 * SC, 0), text = "RRRROOOOAAARRR", color = rgb(255, 255, 255), size = 3 })
	D_shake(6, 1.5)
	S.Combat.aoe(nil, c, 75 * SC, { dmg = dmg * 0.4, kbPower = 90, kbUp = 30, attackType = "aoe", kind = "roar" }, function(e)
		return e.team == "hero"
	end)
	TB.waitUntil(st, def.dur)
end

function TB.walkToward(st, target)
	local tp = S.Entities.position(target)
	local cur = TB.currentRoot(st)
	local fwd = Util.flatUnit(tp - cur.Position)
	local dist = Util.flatDist(tp, cur.Position)
	local step = math.min(dist - 60 * SC, 70 * SC)
	if step < 10 then
		return
	end
	local p = V(cur.Position.X, 0, cur.Position.Z) + fwd * step
	local speed = 14 * SC
	TB.play(st, "walk", TB.rootAt(p.X, p.Z, fwd), step / speed)
	TB.waitUntil(st, step / speed)
end

-- The whole fight. Returns when the titan is dead.
function TB.fight(D, st, level: number)
	local dmg = 30 + level * 2.2
	local p1 = { "LShinCore", "RShinCore", "LHandCore", "RHandCore" }
	local p2 = { "EyeCore", "HornCore" }
	TB.makeCores(st, p1, 900 + level * 55, level)
	local virtualId = -777
	Net.fireAll("BossBar", { name = st.name, virtual = true, id = virtualId })
	local function bar()
		local hp, max = TB.hpFrac(st)
		Net.fireAll("BossBar", { hp = hp, max = max * (if st.phase == 1 then 1.6 else 1), id = virtualId })
	end
	local barLoop = true
	task.spawn(function()
		while barLoop do
			bar()
			task.wait(0.25)
		end
	end)
	D.objective("Destroy the titan's weak points", "Shins and hands glow")
	while TB.aliveCores(st, p1) > 0 do
		local target = nearestPlayer(TB.currentRoot(st).Position)
		if not target then
			task.wait(0.5)
			continue
		end
		local dist = Util.flatDist(S.Entities.position(target), TB.currentRoot(st).Position)
		local roll = rng:float()
		if dist > 150 * SC and roll < 0.5 then
			TB.walkToward(st, target)
		elseif roll < 0.4 then
			TB.stomp(st, target, dmg)
		elseif roll < 0.68 then
			TB.sweep(st, target, dmg * 0.9)
		elseif roll < 0.88 then
			TB.throw(st, target, dmg * 0.8)
		else
			TB.roar(st, dmg)
		end
		D.objective("Destroy the titan's weak points", string.format("%d / 4 left", TB.aliveCores(st, p1)))
		TB.play(st, "idle")
		TB.waitUntil(st, 0.8)
	end
	-- collapse
	st.phase = 2
	TB.play(st, "collapse")
	D.shake(7, 2.5)
	TB.waitUntil(st, 3.0)
	local c = TB.currentRoot(st)
	Net.fireAll("FX", "Shockwave", { pos = ground(c.Position + c.LookVector * 100 * SC), radius = 90 * SC, color = rgb(200, 180, 150) })
	breakCity(c.Position + c.LookVector * 100 * SC, 70 * SC, 80)
	TB.waitUntil(st, 3.5)
	TB.makeCores(st, p2, 1600 + level * 80, level)
	D.objective("It's down! Destroy its eye and the gem on its brow", "Both face you now - strike them")
	while TB.aliveCores(st, p2) > 0 do
		TB.play(st, "down")
		local def = TitanAnim.ACTIONS.down
		TB.waitUntil(st, def.hit)
		-- head flail
		local parts = TB.solve(st)
		local head = parts.Head.Position
		S.Combat.aoe(nil, ground(head), 30 * SC, { dmg = dmg * 0.7, kbPower = 70, kbUp = 30, attackType = "aoe", kind = "flail" }, function(e)
			return e.team == "hero"
		end)
		Net.fireAll("FX", "Shockwave", { pos = ground(head), radius = 30 * SC, color = rgb(220, 190, 150) })
		TB.waitUntil(st, def.dur)
		if rng:chance(0.3) then
			TB.play(st, "down")
			TB.waitUntil(st, 1)
			local cc = TB.currentRoot(st).Position
			S.Combat.aoe(nil, cc, 60 * SC, { dmg = dmg * 0.3, kbPower = 70, kbUp = 20, attackType = "aoe", kind = "roar" }, function(e)
				return e.team == "hero"
			end)
			Net.fireAll("FX", "Shockwave", { pos = ground(cc), radius = 60 * SC, color = rgb(255, 255, 255) })
		end
	end
	barLoop = false
	Net.fireAll("BossBar", { clear = true })
	st.dead = true
	TB.play(st, "die")
	D.shake(8, 4)
	return true
end

function TB.destroy(st)
	st.dead = true
	for _, e in st.coreEntities do
		if S.Entities.isAlive(e) then
			e.dead = true
			S.Entities.remove(e)
		end
	end
	Net.fireAll("Scene", "titanEnd", {})
	if st.model then
		st.model:Destroy()
	end
end

return TB
