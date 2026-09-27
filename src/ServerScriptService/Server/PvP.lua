--!nonstrict
-- Player vs player. Two ways to fight another player:
--   * DUEL anywhere: hold E on another player to challenge, they hold E on you to
--     accept. 3-2-1-FIGHT, nobody really dies: the loser is launched as a ragdoll.
--   * the PVP ARENA (main menu): everyone against everyone, respawns, kill feed.
-- Every combat system asks PvP.canHit(a, b) before one player may hurt another.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local S = require(script.Parent.S)

local PvP = {}
PvP.ffa = false -- arena mode: everyone vs everyone
PvP.duels = {} -- [player] = opponent player
PvP.pending = {} -- [challenger] = { target = player, t = os.clock() }
PvP.kills = {} -- [player] = kills this arena session
PvP.spawnProtect = {} -- [player] = os.clock() until which the player can't be hit

local function ent(p: Player)
	return S.Entities.forPlayer(p)
end

function PvP.canHit(a, b): boolean
	local pa, pb = a.player, b.player
	if not pa or not pb or pa == pb then
		return false
	end
	local now = os.clock()
	if (PvP.spawnProtect[pb] or 0) > now then
		return false
	end
	if PvP.ffa then
		return true
	end
	return PvP.duels[pa] == pb and a.duelLive == true and b.duelLive == true
end

function PvP.stun(e, t: number)
	if not e or not e.model then
		return
	end
	local m = e.model
	local tok = (m:GetAttribute("StunTok") or 0) + 1
	m:SetAttribute("StunTok", tok)
	m:SetAttribute("Stun", true)
	task.delay(t, function()
		if m.Parent and m:GetAttribute("StunTok") == tok then
			m:SetAttribute("Stun", nil)
		end
	end)
end

local function heal(e)
	if e and e.hum and e.hum.Health > 0 then
		e.hum.Health = e.hum.MaxHealth
	end
end

local function endDuel(a: Player, b: Player?)
	for _, p in { a, b } do
		if p then
			PvP.duels[p] = nil
			local e = ent(p)
			if e then
				e.duelWith = nil
				e.duelLive = nil
				e.duelOver = nil
				e.minHealth = nil
			end
		end
	end
end

function PvP.start(a: Player, b: Player)
	PvP.pending[a] = nil
	PvP.pending[b] = nil
	local ea, eb = ent(a), ent(b)
	if not ea or not eb or not S.Entities.isAlive(ea) or not S.Entities.isAlive(eb) then
		return
	end
	PvP.duels[a] = b
	PvP.duels[b] = a
	ea.duelWith, eb.duelWith = eb, ea
	ea.minHealth, eb.minHealth = 1, 1
	heal(ea)
	heal(eb)
	Net.fire(a, "PvP", { kind = "countdown", opponent = b.DisplayName, oppModel = b.Character })
	Net.fire(b, "PvP", { kind = "countdown", opponent = a.DisplayName, oppModel = a.Character })
	task.delay(3, function()
		if PvP.duels[a] == b and PvP.duels[b] == a then
			ea.duelLive, eb.duelLive = true, true
			Net.fire(a, "PvP", { kind = "fight" })
			Net.fire(b, "PvP", { kind = "fight" })
		end
	end)
	-- walk away = forfeit
	task.spawn(function()
		while PvP.duels[a] == b do
			task.wait(1)
			local pa, pb = S.Entities.position(ea), S.Entities.position(eb)
			if not a.Parent or not b.Parent or (pa - pb).Magnitude > 320 or not S.Entities.isAlive(ea) or not S.Entities.isAlive(eb) then
				if PvP.duels[a] == b then
					endDuel(a, b)
					for _, p in { a, b } do
						if p.Parent then
							Net.fire(p, "PvP", { kind = "cancel" })
						end
					end
				end
				break
			end
		end
	end)
end

-- the duel's final blow: nobody dies, the loser flies
function PvP.onDefeat(loser, winner, info)
	local lp = loser.player
	local wp = PvP.duels[lp]
	if not lp or not wp or loser.duelOver then
		return
	end
	loser.duelOver = true
	loser.duelLive = false
	local we = ent(wp)
	if we then
		we.duelLive = false
	end
	local kb = (info and info.kb) or Vector3.zero
	local dir = if kb.Magnitude > 0.1 then Vector3.new(kb.X, 0, kb.Z) else Vector3.new(0, 0, 1)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(0, 0, 1)
	end
	if loser.model then
		S.Ragdoll.knock(loser.model, dir.Unit * 70 + Vector3.new(0, 55, 0), 3)
	end
	Net.fireAll("FX", "Text", { pos = S.Entities.position(loser) + Vector3.new(0, 4, 0), text = "DEFEATED", color = Color3.fromRGB(255, 70, 70), size = 1.6 })
	Net.fire(lp, "PvP", { kind = "result", win = false, name = wp.DisplayName })
	Net.fire(wp, "PvP", { kind = "result", win = true, name = lp.DisplayName })
	if wp then
		S.Combat.style(wp, { { "DUEL WON", 250 } })
	end
	task.delay(3.5, function()
		endDuel(lp, wp)
		heal(ent(lp))
		heal(ent(wp))
	end)
end

function PvP.onKill(killer, victim)
	local kp, vp = killer.player, victim.player
	if not kp or not vp then
		return
	end
	PvP.kills[kp] = (PvP.kills[kp] or 0) + 1
	Net.fireAll("PvP", { kind = "feed", killer = kp.DisplayName, victim = vp.DisplayName, score = PvP.scores() })
end

function PvP.scores()
	local out = {}
	for _, p in Players:GetPlayers() do
		table.insert(out, { name = p.DisplayName, kills = PvP.kills[p] or 0 })
	end
	table.sort(out, function(a, b)
		return a.kills > b.kills
	end)
	return out
end

-- a challenge prompt on every player's body (hidden on your own screen by the client)
function PvP.attach(player: Player, model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "DuelPrompt"
	pp.ActionText = "Challenge to a duel"
	pp.ObjectText = player.DisplayName
	pp.HoldDuration = 0.5
	pp.MaxActivationDistance = 14
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = root
	pp.Triggered:Connect(function(by: Player)
		if by == player or PvP.ffa or PvP.duels[by] or PvP.duels[player] then
			return
		end
		local now = os.clock()
		local theirs = PvP.pending[player]
		if theirs and theirs.target == by and now - theirs.t < 30 then
			PvP.start(by, player)
			return
		end
		PvP.pending[by] = { target = player, t = now }
		Net.fire(player, "Notify", { kind = "info", text = by.DisplayName .. " challenges you to a duel!", sub = "Hold E on them to accept." })
		Net.fire(by, "Notify", { kind = "info", text = "Challenge sent", sub = "Waiting for " .. player.DisplayName .. " to accept..." })
	end)
end

function PvP.setArena(on: boolean)
	PvP.ffa = on
	PvP.kills = {}
	for p in PvP.duels do
		endDuel(p, nil)
	end
end

Players.PlayerRemoving:Connect(function(p)
	local o = PvP.duels[p]
	if o then
		endDuel(p, o)
		if o.Parent then
			Net.fire(o, "PvP", { kind = "cancel" })
		end
	end
	PvP.pending[p] = nil
	PvP.kills[p] = nil
	PvP.spawnProtect[p] = nil
end)

return PvP
