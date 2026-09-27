-- Generates several bestiaries and checks every species is sane.
local Beasts = require(script.Parent.Beasts)
local RNG = require(script.Parent.RNG)
local plans, fails = {}, 0
for seed = 1, 40 do
	local roster = Beasts.roster(seed * 7919, 20)
	assert(#roster == 20, "roster size")
	for _, d in roster do
		plans[d.plan] = (plans[d.plan] or 0) + 1
		if not (d.hp > 0 and d.dmg > 0 and d.speed > 0 and #d.attacks > 0 and d.tier >= 1 and d.tier <= 5) then
			fails += 1
			print("BAD", d.name, d.hp, d.dmg, d.speed, #d.attacks, d.tier)
		end
		for _, a in d.attacks do
			assert(a.id and a.anim and a.range and a.w and a.kind, "attack fields " .. tostring(a.id))
		end
		-- no contradicting traits
		local set = {}
		for _, t in d.traits do
			set[t] = true
		end
		assert(not (set.huge and set.air), "huge air")
		assert(not (set.tiny and set.destructive), "tiny destructive")
		assert(not (set.slow and set.air), "slow air")
	end
	if seed == 1 then
		for _, d in roster do
			print(string.format("%-26s tier %d  %-8s %-26s hp %4d dmg %5.1f spd %4.1f  %s", d.name, d.tier, d.plan, Beasts.describe(d), d.hp, d.dmg, d.speed, d.ai))
		end
	end
end
local b = Beasts.boss(RNG.new(5), 10)
print("BOSS:", b.name, b.plan, Beasts.describe(b), b.hp, #b.attacks)
local out = {}
for k, v in plans do
	table.insert(out, k .. "=" .. v)
end
table.sort(out)
print("plans: " .. table.concat(out, " "))
print(if fails == 0 then "OK" else "FAILS " .. fails)
