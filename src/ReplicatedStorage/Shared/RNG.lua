--!nonstrict
-- Seeded randomness. Everything that must be reproducible from the story seed goes
-- through RNG objects created from RNG.new(seed) or rng:fork("salt").
local RNG = {}
RNG.__index = RNG

local TWO32 = 4294967296

-- FNV-1a 32 bit over the string form of all arguments.
function RNG.hash(...: any): number
	local h = 2166136261
	for i = 1, select("#", ...) do
		local s = tostring((select(i, ...)))
		for j = 1, #s do
			h = bit32.bxor(h, string.byte(s, j))
			-- h * 16777619 (FNV prime = 2^24 + 403) without losing double precision
			h = (bit32.lshift(h, 24) + h * 403) % TWO32
		end
		h = bit32.bxor(h, 0x9E3779B9)
		h = (bit32.lshift(h, 24) + h * 403) % TWO32
	end
	return h
end

-- Converts any user text into a numeric seed ("12345" stays 12345).
function RNG.seedFrom(text: string?): number
	if text == nil or text == "" then
		return math.floor(os.clock() * 1000003 + tick() * 7) % 999999937 + 1
	end
	local n = tonumber(text)
	if n and n == math.floor(n) and n > 0 and n < 2 ^ 31 then
		return n
	end
	return RNG.hash(text) % 999999937 + 1
end

function RNG.new(seed: number)
	local self = setmetatable({}, RNG)
	self.seed = seed
	self.r = Random.new(seed)
	return self
end

function RNG:fork(...: any)
	return RNG.new(RNG.hash(self.seed, ...) % 2147483646 + 1)
end

function RNG:int(a: number, b: number): number
	if b < a then
		return a
	end
	return self.r:NextInteger(a, b)
end

function RNG:float(a: number?, b: number?): number
	local lo, hi = a or 0, b or 1
	return lo + (hi - lo) * self.r:NextNumber()
end

function RNG:chance(p: number): boolean
	return self.r:NextNumber() < p
end

function RNG:sign(): number
	return if self.r:NextNumber() < 0.5 then -1 else 1
end

function RNG:pick<T>(list: { T }): T
	return list[self.r:NextInteger(1, #list)]
end

-- entries = { {value, weight}, ... }
function RNG:weighted(entries: { any }): any
	local total = 0
	for _, e in entries do
		total += e[2]
	end
	local roll = self.r:NextNumber() * total
	for _, e in entries do
		roll -= e[2]
		if roll <= 0 then
			return e[1]
		end
	end
	return entries[#entries][1]
end

function RNG:shuffle<T>(list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self.r:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

function RNG:vec(a: number, b: number): Vector3
	return Vector3.new(self:float(a, b), self:float(a, b), self:float(a, b))
end

function RNG:flatDir(): Vector3
	local a = self:float(0, math.pi * 2)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

function RNG:angle(): number
	return self:float(0, math.pi * 2)
end

return RNG
