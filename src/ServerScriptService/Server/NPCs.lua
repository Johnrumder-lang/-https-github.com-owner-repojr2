--!nonstrict
-- Friendly / neutral NPCs: townsfolk with little routines, talkable characters,
-- and cutscene actors. Attack a townsperson and they fight back (or run).
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Rig = require(Shared.Rig)
local Enemies = require(Shared.Enemies)
local Weapons = require(Shared.Weapons)
local Util = require(Shared.Util)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)

local NPCs = {}
local rng = RNG.new(os.time() % 4321 + 9)

-- ------------------------------------------------------------------ actors (cutscene puppets)
function NPCs.actor(look, cf: CFrame, opts)
	opts = opts or {}
	local m = Rig.build(look)
	m:PivotTo(cf)
	m.Parent = opts.parent or S.AI.folder()
	if opts.weapon then
		Rig.hold(m, Weapons.npcModel(opts.weapon))
	end
	if opts.pose then
		m:SetAttribute("Pose", opts.pose)
	end
	local root = m.PrimaryPart
	if opts.anchored and root then
		root.Anchored = true
	elseif root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	return m
end

function NPCs.pose(model: Model?, pose: string?)
	if model then
		model:SetAttribute("Pose", pose)
	end
end

function NPCs.act(model: Model?, anim: string, w: number?, a: number?, r: number?)
	if model then
		model:SetAttribute("ActW", w or 0.2)
		model:SetAttribute("ActA", a or 0.2)
		model:SetAttribute("ActR", r or 0.4)
		model:SetAttribute("ActT0", workspace:GetServerTimeNow())
		model:SetAttribute("Act", anim)
	end
end

function NPCs.face(model: Model?, pos: Vector3)
	local root = model and model.PrimaryPart
	if root then
		local p = root.Position
		root.CFrame = CFrame.lookAt(p, Vector3.new(pos.X, p.Y, pos.Z))
	end
end

-- ------------------------------------------------------------------ townsfolk brain
local Townsfolk = {}
Townsfolk.__index = Townsfolk

function Townsfolk.new(e, opts)
	local self = setmetatable({}, Townsfolk)
	self.e = e
	self.t = 0
	self.opts = opts
	self.home = e.root.Position
	self.points = opts.points or {}
	self.nextMove = rng:float(1, 5)
	self.poses = opts.poses or { "Talk", "Crossed", nil, nil }
	self.scared = 0
	return self
end

function Townsfolk:update(dt)
	local e = self.e
	if e.dead or not e.root.Parent then
		return
	end
	self.t += dt
	local hum = e.hum
	-- flee from nearby fighting
	if self.scared > 0 then
		self.scared -= dt
		local threat = S.Entities.nearestHostile(e, 60)
		local from = if threat then S.Entities.position(threat) else self.home
		local away = Util.flatUnit(e.root.Position - from)
		hum.WalkSpeed = 20
		hum:MoveTo(e.root.Position + away * 20)
		e.model:SetAttribute("Pose", nil)
		return
	end
	if self.opts.stationary then
		return
	end
	if self.t >= self.nextMove then
		self.nextMove = self.t + rng:float(5, 12)
		local target
		if #self.points > 0 and rng:chance(0.6) then
			target = rng:pick(self.points)
		else
			target = self.home + rng:flatDir() * rng:float(3, self.opts.wander or 16)
		end
		hum.WalkSpeed = rng:float(7, 11)
		hum:MoveTo(target)
		e.model:SetAttribute("Pose", nil)
		task.delay(rng:float(3, 6), function()
			if not e.dead and e.model.Parent and self.scared <= 0 then
				e.model:SetAttribute("Pose", rng:pick(self.poses))
			end
		end)
	end
end

function Townsfolk:onHit(attacker, info)
	local e = self.e
	if attacker and attacker.kind == "player" then
		-- betrayal: the town turns on you
		Net.fireAll("FX", "Shout", { target = e.model, text = rng:pick({ "Murderer!", "Guards! GUARDS!", "Why?!", "Help!" }) })
		if self.opts.onBetray then
			self.opts.onBetray(e)
		end
		if self.opts.fightBack then
			NPCs.turnHostile(e)
		else
			self.scared = 8
		end
	end
end

function Townsfolk:onDeath() end
function Townsfolk:destroy() end

function NPCs.turnHostile(e)
	if e.dead then
		return
	end
	e.team = "human"
	e.hostile = true
	e.def = Enemies.DEFS.Villager
	e.dmg = math.max(e.dmg, Enemies.DEFS.Villager.dmg * (1 + 0.13 * (e.level - 1)))
	local b = S.AI.Melee.new(e, { aggro = 120 })
	local idx = table.find(S.AI.brains, e.brain)
	e.brain = b
	if idx then
		S.AI.brains[idx] = b
	else
		table.insert(S.AI.brains, b)
	end
	e.model:SetAttribute("Pose", nil)
	e.model:SetAttribute("Team", "human")
end

-- Spawns a talkable townsperson. opts: {name, talk = lines | fn(player), points, poses, stationary, level, tags, fightBack, weapon, brain = fn(e, opts)}
function NPCs.townsfolk(look, cf: CFrame, opts)
	opts = opts or {}
	look.name = opts.name or look.name or "Townsperson"
	look.health = opts.hp or 60
	local m = Rig.build(look)
	m:PivotTo(cf)
	if opts.weapon then
		Rig.hold(m, Weapons.npcModel(opts.weapon))
	end
	m.Parent = S.AI.folder()
	pcall(function()
		m.PrimaryPart:SetNetworkOwner(nil)
	end)
	local e = S.Entities.new(m, {
		kind = "npc",
		team = "neutral",
		name = look.name,
		level = opts.level or 1,
		dmg = 8,
		posture = 40,
		hostile = false,
		tags = opts.tags or {},
		xp = opts.xp or 4,
		gold = opts.gold or { 1, 6 },
	})
	m:SetAttribute("DisplayName", look.name)
	local b = if opts.brain then opts.brain(e, opts) else Townsfolk.new(e, opts)
	e.brain = b
	table.insert(S.AI.brains, b)
	if opts.pose then
		m:SetAttribute("Pose", opts.pose)
	end
	if opts.talk then
		S.PlayerService.prompt(m.PrimaryPart, "Talk", look.name, function(player)
			if e.hostile or e.dead then
				return
			end
			NPCs.face(m, player.Character and player.Character:GetPivot().Position or m:GetPivot().Position)
			local prev = m:GetAttribute("Pose")
			m:SetAttribute("Pose", "Talk")
			if type(opts.talk) == "function" then
				opts.talk(player, e)
			else
				S.Director.say(opts.talk, { player = player })
			end
			if m.Parent then
				m:SetAttribute("Pose", prev)
			end
		end, { dist = 9 })
	end
	return e
end

return NPCs
