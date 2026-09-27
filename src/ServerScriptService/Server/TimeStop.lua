--!nonstrict
-- TIME STOP. While active, everything except the stopper is frozen in place.
-- Every hit on a frozen target is stored and applied ALL AT ONCE when time resumes:
-- summed damage, summed knockback (big sums launch ragdolls).
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local S = require(script.Parent.S)

local TimeStop = {}
TimeStop.active = false
TimeStop.stopper = nil -- entity
TimeStop.startedAt = 0
TimeStop.endsAt = 0
TimeStop.cooldownUntil = {} -- [player] = os.clock()
TimeStop.queue = {} -- [entity] = { hits = {}, attacker = e }
TimeStop.frozen = {} -- [part] = { vel, ang }
TimeStop.frozenEntities = {}
TimeStop.totalFrozen = 0 -- accumulated frozen seconds (boss clocks use this)
TimeStop.listeners = {}

function TimeStop.on(fn)
	table.insert(TimeStop.listeners, fn)
end

local function emit(phase, data)
	for _, fn in TimeStop.listeners do
		task.spawn(fn, phase, data)
	end
end

function TimeStop.affects(e): boolean
	return TimeStop.active and e ~= TimeStop.stopper and not (TimeStop.stopper and e.team == "hero" and TimeStop.stopper.team == "hero" and e.kind ~= "player")
end

function TimeStop.isFrozen(e): boolean
	return TimeStop.active and e.frozen == true
end

-- A boss clock that pauses during time stop: returns "unfrozen seconds since t0".
function TimeStop.clock(): number
	local now = os.clock()
	if TimeStop.active then
		return TimeStop.startedAt - TimeStop.totalFrozen
	end
	return now - TimeStop.totalFrozen
end

local function freezePart(p: BasePart)
	if p.Anchored or TimeStop.frozen[p] then
		return
	end
	TimeStop.frozen[p] = { vel = p.AssemblyLinearVelocity, ang = p.AssemblyAngularVelocity }
	p.Anchored = true
end

local function freezeEntity(e)
	if e.frozen then
		return
	end
	e.frozen = true
	table.insert(TimeStop.frozenEntities, e)
	if e.model then
		e.model:SetAttribute("Frozen", true)
		for _, c in e.model:GetChildren() do
			if c:IsA("BasePart") then
				freezePart(c)
			end
		end
	end
	if e.player then
		Net.fire(e.player, "TimeStop", "frozen", { by = TimeStop.stopper and TimeStop.stopper.model })
	end
	if e.brain and e.brain.onFreeze then
		pcall(e.brain.onFreeze, e.brain)
	end
end

local function unfreezeEntity(e, frozenFor: number)
	if not e.frozen then
		return
	end
	e.frozen = false
	if e.model and e.model.Parent then
		e.model:SetAttribute("Frozen", false)
		-- shift the animation clock so attacks continue where they stopped
		local t0 = e.model:GetAttribute("ActT0")
		if t0 then
			e.model:SetAttribute("ActT0", t0 + frozenFor)
		end
	end
	if e.brain and e.brain.onUnfreeze then
		pcall(e.brain.onUnfreeze, e.brain, frozenFor)
	end
end

function TimeStop.canUse(player: Player): (boolean, number)
	local p = S.State.profile(player)
	if not p.abilities.timestop then
		return false, 0
	end
	local cd = TimeStop.cooldownUntil[player] or 0
	return os.clock() >= cd, math.max(0, cd - os.clock())
end

function TimeStop.request(player: Player)
	local e = S.Entities.forPlayer(player)
	if not e or not S.Entities.isAlive(e) then
		return
	end
	if player.Character and player.Character:GetAttribute("Locked") then
		return
	end
	if TimeStop.active then
		if TimeStop.stopper == e and not TimeStop.scripted then
			TimeStop.stop()
		end
		return
	end
	local ok = TimeStop.canUse(player)
	if not ok then
		return
	end
	local d = S.State.derived(player)
	TimeStop.start(e, d.tsDuration)
end

-- opts: { scripted = bool (no auto-end, no cooldown), silent = bool, inverted = bool }
function TimeStop.start(stopper, duration: number, opts)
	opts = opts or {}
	if TimeStop.active then
		return false
	end
	TimeStop.active = true
	TimeStop.stopper = stopper
	TimeStop.scripted = opts.scripted or false
	TimeStop.startedAt = os.clock()
	TimeStop.endsAt = if opts.scripted then math.huge else os.clock() + duration
	TimeStop.duration = duration
	TimeStop.queue = {}
	TimeStop.frozenEntities = {}
	for _, e in S.Entities.list do
		if e ~= stopper and TimeStop.affects(e) then
			freezeEntity(e)
		end
	end
	-- dead bodies and loose debris freeze mid-air too
	for _, m in CollectionService:GetTagged("Rig") do
		if m:IsDescendantOf(workspace) and not S.Entities.fromModel(m) and m ~= (stopper and stopper.model) then
			m:SetAttribute("Frozen", true)
			for _, c in m:GetChildren() do
				if c:IsA("BasePart") then
					freezePart(c)
				end
			end
		end
	end
	for _, p in CollectionService:GetTagged("Physical") do
		if p:IsA("BasePart") then
			freezePart(p)
		end
	end
	if S.Projectiles then
		S.Projectiles.pause(true)
	end
	local origin = S.Entities.position(stopper)
	Net.fireAll("TimeStop", "start", {
		stopper = stopper.model,
		duration = duration,
		origin = origin,
		scripted = opts.scripted,
		inverted = opts.inverted or stopper.team ~= "hero",
	})
	emit("start", { stopper = stopper })
	return true
end

function TimeStop.stop()
	if not TimeStop.active then
		return
	end
	local frozenFor = os.clock() - TimeStop.startedAt
	TimeStop.totalFrozen += frozenFor
	TimeStop.active = false
	local stopper = TimeStop.stopper
	TimeStop.stopper = nil
	-- unfreeze physics
	for p, st in TimeStop.frozen do
		if p.Parent then
			p.Anchored = false
			p.AssemblyLinearVelocity = st.vel
			p.AssemblyAngularVelocity = st.ang
		end
	end
	TimeStop.frozen = {}
	for _, m in CollectionService:GetTagged("Rig") do
		if m:GetAttribute("Frozen") and not S.Entities.fromModel(m) then
			m:SetAttribute("Frozen", false)
		end
	end
	for _, e in TimeStop.frozenEntities do
		unfreezeEntity(e, frozenFor)
		if e.player and e.root and e.root.Parent then
			pcall(function()
				e.root:SetNetworkOwner(e.player)
			end)
		elseif e.root and e.root.Parent and not e.root.Anchored then
			pcall(function()
				e.root:SetNetworkOwner(nil)
			end)
		end
	end
	TimeStop.frozenEntities = {}
	if S.Projectiles then
		S.Projectiles.pause(false)
	end
	if stopper and stopper.player and not TimeStop.scripted then
		local d = S.State.derived(stopper.player)
		TimeStop.cooldownUntil[stopper.player] = os.clock() + d.tsCooldown
		Net.fire(stopper.player, "TimeStop", "cooldown", { ready = workspace:GetServerTimeNow() + d.tsCooldown, total = d.tsCooldown })
	end
	TimeStop.scripted = false
	Net.fireAll("TimeStop", "end", { stopper = stopper and stopper.model })
	emit("end", { stopper = stopper })
	-- release every stored hit
	local q = TimeStop.queue
	TimeStop.queue = {}
	task.defer(function()
		for target, entry in q do
			if S.Entities.isAlive(target) then
				local total, kb, crit, pos, attacker = 0, Vector3.zero, false, nil, entry.attacker
				for _, h in entry.hits do
					total += h.dmg
					kb += h.kb or Vector3.zero
					crit = crit or h.crit
					pos = h.pos or pos
				end
				local n = #entry.hits
				-- stacked knockback gets a bonus so multi-hits feel explosive
				if n > 1 then
					kb *= 1 + math.min(n, 12) * 0.12
				end
				S.Combat.apply(attacker, target, {
					dmg = total,
					kb = kb,
					crit = crit,
					pos = pos,
					hits = n,
					released = true,
					posture = entry.posture,
					ragdollAt = Config.TimeStop.ragdollThreshold,
				})
			end
		end
	end)
end

function TimeStop.queueHit(attacker, target, info)
	local entry = TimeStop.queue[target]
	if not entry then
		entry = { hits = {}, attacker = attacker, posture = 0 }
		TimeStop.queue[target] = entry
	end
	table.insert(entry.hits, info)
	entry.posture += info.posture or 0
	return #entry.hits
end

function TimeStop.remaining(): number
	if not TimeStop.active then
		return 0
	end
	return math.max(0, TimeStop.endsAt - os.clock())
end

RunService.Heartbeat:Connect(function()
	if TimeStop.active and not TimeStop.scripted and os.clock() >= TimeStop.endsAt then
		TimeStop.stop()
	end
	-- a stopper that dies ends the time stop
	if TimeStop.active and TimeStop.stopper and not S.Entities.isAlive(TimeStop.stopper) then
		TimeStop.stop()
	end
end)

Players.PlayerRemoving:Connect(function(p)
	TimeStop.cooldownUntil[p] = nil
	if TimeStop.active and TimeStop.stopper and TimeStop.stopper.player == p then
		TimeStop.stop()
	end
end)

return TimeStop
