--!nonstrict
-- Small helpers shared by server and client.
local Util = {}

-- ------------------------------------------------------------------ math
function Util.clamp(x: number, a: number, b: number): number
	return if x < a then a elseif x > b then b else x
end

function Util.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.smooth(t: number): number
	t = Util.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function Util.easeOut(t: number, p: number?): number
	t = Util.clamp(t, 0, 1)
	return 1 - (1 - t) ^ (p or 2)
end

function Util.easeIn(t: number, p: number?): number
	t = Util.clamp(t, 0, 1)
	return t ^ (p or 2)
end

function Util.easeInOut(t: number): number
	t = Util.clamp(t, 0, 1)
	return if t < 0.5 then 4 * t * t * t else 1 - (-2 * t + 2) ^ 3 / 2
end

function Util.backOut(t: number): number
	t = Util.clamp(t, 0, 1)
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

function Util.flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function Util.flatUnit(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	return f.Unit
end

function Util.flatDist(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function Util.angleBetween(a: Vector3, b: Vector3): number
	if a.Magnitude < 1e-5 or b.Magnitude < 1e-5 then
		return 0
	end
	return math.acos(Util.clamp(a.Unit:Dot(b.Unit), -1, 1))
end

function Util.yawOf(v: Vector3): number
	return math.atan2(-v.X, -v.Z)
end

function Util.approach(cur: number, target: number, rate: number, dt: number): number
	return target + (cur - target) * math.exp(-rate * dt)
end

-- ------------------------------------------------------------------ noise
function Util.noise(x: number, y: number, seed: number): number
	return math.noise(x, y, seed % 997 + 0.379)
end

function Util.fbm(x: number, y: number, octaves: number, seed: number): number
	local total, amp, freq, norm = 0, 1, 1, 0
	for i = 1, octaves do
		total += math.noise(x * freq, y * freq, (seed % 997) + i * 13.137 + 0.21) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.03
	end
	return Util.clamp(total / norm * 1.9, -1, 1)
end

function Util.ridge(x: number, y: number, octaves: number, seed: number): number
	return 1 - math.abs(Util.fbm(x, y, octaves, seed))
end

-- ------------------------------------------------------------------ tables
function Util.copy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = Util.copy(v)
	end
	return c
end

function Util.merge(a, b)
	local c = Util.copy(a)
	if b then
		for k, v in b do
			c[k] = Util.copy(v)
		end
	end
	return c
end

function Util.keys(t)
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	return out
end

function Util.count(t): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- ------------------------------------------------------------------ colors / serialization
function Util.c3(t): Color3
	if typeof(t) == "Color3" then
		return t
	end
	return Color3.new(t[1], t[2], t[3])
end

function Util.arr(c: Color3)
	return { c.R, c.G, c.B }
end

function Util.shade(c: Color3, f: number): Color3
	return Color3.new(Util.clamp(c.R * f, 0, 1), Util.clamp(c.G * f, 0, 1), Util.clamp(c.B * f, 0, 1))
end

function Util.mix(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

-- ------------------------------------------------------------------ text
function Util.fmt(n: number): string
	n = math.floor(n + 0.5)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-" else "") .. out
end

function Util.fill(template: string, vars): string
	return (template:gsub("{(%w+)}", function(k)
		local v = vars[k]
		if v == nil then
			return "{" .. k .. "}"
		end
		return tostring(v)
	end))
end

function Util.titleCase(s: string): string
	return (s:gsub("(%a)([%w']*)", function(a, b)
		return a:upper() .. b:lower()
	end))
end

-- ------------------------------------------------------------------ instances
function Util.findModel(part: Instance?): Model?
	local cur = part
	while cur and cur ~= workspace do
		if cur:IsA("Model") and cur:FindFirstChildOfClass("Humanoid") then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

function Util.setModelTransparency(model: Instance, t: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Transparency = t
		end
	end
end

function Util.serverNow(): number
	return workspace:GetServerTimeNow()
end

return Util
