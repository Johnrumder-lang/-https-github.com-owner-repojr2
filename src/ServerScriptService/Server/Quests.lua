--!nonstrict
-- Side quests & the land quest chain. Stored per player in profile.quests.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Weapons = require(Shared.Weapons)
local RNG = require(Shared.RNG)
local S = require(script.Parent.S)

local Quests = {}
local rng = RNG.new(os.time() % 999 + 17)

-- q = {id, title, text, kind = "tag"|"count"|"flag", tag, defId, anyTag, total, flag, reward = {gold, xp, item, rarity}}
-- (a "count" quest counts kills of defId, or of anything carrying anyTag)
function Quests.give(q)
	for _, p in Players:GetPlayers() do
		local prof = S.State.profile(p)
		local exists = false
		for _, old in prof.quests do
			if old.id == q.id then
				exists = true
			end
		end
		if not exists then
			local copy = table.clone(q)
			copy.progress = if q.kind == "count" then "0/" .. q.total else nil
			copy.count = 0
			table.insert(prof.quests, copy)
			Net.fire(p, "Notify", { kind = "info", text = "New quest: " .. q.title, sub = q.text })
			S.State.sync(p)
		end
	end
end

function Quests.has(id: string): boolean
	local l = S.State.leader()
	if not l then
		return false
	end
	for _, q in S.State.profile(l).quests do
		if q.id == id then
			return true
		end
	end
	return false
end

function Quests.isDone(id: string): boolean
	local l = S.State.leader()
	if not l then
		return false
	end
	for _, q in S.State.profile(l).quests do
		if q.id == id then
			return q.done == true
		end
	end
	return false
end

local function reward(p: Player, q)
	local r = q.reward or {}
	if r.gold then
		S.State.addGold(p, r.gold)
	end
	if r.xp then
		S.State.addXP(p, r.xp)
	end
	if r.rarity then
		S.State.addItem(p, Weapons.roll(rng, math.max(1, S.State.profile(p).level), { rarity = r.rarity }))
	end
	if r.flask then
		local prof = S.State.profile(p)
		prof.maxFlasks = math.min(8, prof.maxFlasks + 1)
		prof.flasks = prof.maxFlasks
	end
end

function Quests.complete(id: string)
	for _, p in Players:GetPlayers() do
		for _, q in S.State.profile(p).quests do
			if q.id == id and not q.done then
				q.done = true
				q.progress = "done"
				reward(p, q)
				Net.fire(p, "Notify", { kind = "level", text = "QUEST COMPLETE", sub = q.title })
				S.State.sync(p)
			end
		end
	end
end

function Quests.refresh()
	for _, p in Players:GetPlayers() do
		local changed = false
		for _, q in S.State.profile(p).quests do
			if not q.done then
				if q.kind == "tag" then
					local alive = S.Entities.countTag(q.tag)
					local total = q.total or 1
					local prog = string.format("%d/%d", math.max(0, total - alive), total)
					if prog ~= q.progress then
						q.progress = prog
						changed = true
					end
					if alive == 0 and (q.seen or S.State.run.cleared[q.tag]) then
						task.defer(Quests.complete, q.id)
					end
					if alive > 0 then
						q.seen = true
					end
				elseif q.kind == "flag" and S.State.flag(q.flag) then
					task.defer(Quests.complete, q.id)
				end
			end
		end
		if changed then
			S.State.sync(p)
		end
	end
end

function Quests.onDeath(e, killer)
	if e.kind == "player" then
		return
	end
	local id = e.def and (e.def.baseId or e.def.name)
	for _, p in Players:GetPlayers() do
		for _, q in S.State.profile(p).quests do
			local match = if q.anyTag then (e.tags ~= nil and e.tags[q.anyTag] == true) else (e.def ~= nil and (q.defId == e.def.baseId or q.defId == e.def.name))
			if not q.done and q.kind == "count" and match then
				q.count += 1
				q.progress = string.format("%d/%d", q.count, q.total)
				if q.count >= q.total then
					task.defer(Quests.complete, q.id)
				end
				S.State.sync(p)
			end
		end
	end
	task.defer(Quests.refresh)
end

function Quests.init()
	S.Entities.onDeath(Quests.onDeath)
	task.spawn(function()
		while true do
			task.wait(2)
			if S.State.run then
				pcall(Quests.refresh)
			end
		end
	end)
end

return Quests
