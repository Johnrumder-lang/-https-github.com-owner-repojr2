--@server CapitalLand, TerrainGen
-- Plans a countryside, samples the height function over the whole ring and
-- runs the voxel generator against a counting fake terrain.
task = { wait = function() end, spawn = function(f, ...) f(...) end, delay = function() end, defer = function() end }
Region3 = { new = function(a, b) return { min = a, max = b } end }
local voxels, writes = 0, 0
local fakeTerrain = {
	WriteVoxels = function(self, region, res, mats, occ)
		writes += 1
		voxels += #mats * #mats[1] * #mats[1][1]
	end,
	SetAttribute = function() end,
	Clear = function() end,
}
rawset(workspace, "FindFirstChildOfClass", function() return fakeTerrain end)
local S = {}
__mods["srv:S"] = function() return S end
local Land = require(Server.CapitalLand)
local TG = require(Server.TerrainGen)

local t0 = os.clock()
local P = Land.plan(12345)
print(string.format("plan: %.3fs  villages=%d massifs=%d forests=%d lakes=%d roads=%d wilds=%d landmarks=%d", os.clock() - t0, #P.villages, #P.massifs, #P.forests, #P.lakes, #P.roads, #P.wilds, #P.landmarks))
assert(#P.villages >= 5, "too few villages")
for _, v in P.villages do
	assert(v.y and v.y > Land.WL + 5, "village below water")
end

-- height statistics over the ring
local lo, hi, n, wet, sum = math.huge, -math.huge, 0, 0, 0
local tags = {}
t0 = os.clock()
for x = -4800, 4800, 40 do
	for z = -4800, 4800, 40 do
		local r = math.sqrt(x * x + z * z)
		if r > 1414 and r < 4800 then
			local h, tag = Land.height(x, z, r)
			assert(h == h, "NaN height")
			lo, hi = math.min(lo, h), math.max(hi, h)
			sum += h
			n += 1
			if h < Land.WL then
				wet += 1
			end
			tags[tag] = (tags[tag] or 0) + 1
		end
	end
end
local dt = os.clock() - t0
print(string.format("heights: n=%d  %.1f us/sample  min=%.1f max=%.1f mean=%.1f  underwater=%.1f%%", n, dt / n * 1e6, lo, hi, sum / n, wet / n * 100))
local tagNames = {}
for k, v in Land.T do
	tagNames[v] = k
end
for t, c in tags do
	print(string.format("  tag %-8s %5.1f%%", tagNames[t] or tostring(t), c / n * 100))
end
assert(hi > 300, "no mountains")
assert(wet > 0, "no water")
-- villages must be flat and dry
for _, v in P.villages do
	local h1 = Land.height(v.x + 30, v.z, math.sqrt((v.x + 30) ^ 2 + v.z ^ 2))
	assert(math.abs(h1 - v.y) < 0.01, "village plateau not flat")
end
-- the pass must be low enough to walk
local passH = Land.height(0, -Land.PASS_R, Land.PASS_R)
print(string.format("pass height %.1f", passH))
assert(passH < 120, "pass too high")

-- the voxel generator (outer ring only, the city function isn't bundled here)
local function height(x, z)
	local r = math.sqrt(x * x + z * z)
	if r < 1414 then
		return 16, 0
	end
	return Land.height(x, z, r)
end
local job = TG.start({ key = "test", radius = Land.EDGE_R, height = height, paint = Land.paint, water = Land.WL, depth = 10 })
t0 = os.clock()
TG.runSync(job, Land.EDGE_R)
dt = os.clock() - t0
print(string.format("voxels: %d chunks, %.1f M voxels, %.2fs total (%.2f ms/chunk)", writes, voxels / 1e6, dt, dt / writes * 1000))
print("OK")
