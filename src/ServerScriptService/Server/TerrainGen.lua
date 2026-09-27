--!nonstrict
-- Real Roblox terrain for the big outdoor worlds. A height function is sampled on
-- the 4-stud voxel grid in 64x64-stud chunks and written with WriteVoxels (smooth
-- occupancy, so slopes and hills come out round). Chunks near the centre are built
-- synchronously during the loading screen; the rest stream in, nearest first, in
-- the background with a per-frame time budget. `ensure` builds the chunks around
-- a point immediately (spawns, teleports).
local RunService = game:GetService("RunService")

local TG = {}
local RES = 4
local CH = 64
local N = CH // RES
local AIR = Enum.Material.Air
local WATER = Enum.Material.Water

TG.job = nil

local function terrain(): Terrain
	return workspace:FindFirstChildOfClass("Terrain") :: Terrain
end

-- spec: {
--   key: string,                         -- identifies the world + seed
--   radius: number,                      -- world XZ radius around the origin to cover
--   height: (x, z) -> (number, any?),    -- surface height (+ a tag passed to paint)
--   paint: (x, z, h, slope, tag) -> Material, -- surface material (slope = rise/run)
--   water: number?,                      -- global water level (fills air below it)
--   depth: number?,                      -- solid skin under the lowest surface (studs)
--   carves: { {x0, x1, z0, z1, y0, y1} }?, -- boxes forced to air (shafts, cellars)
--   budget: number?,                     -- background ms per frame
-- }
function TG.start(spec)
	local t = terrain()
	if TG.job and TG.job.key == spec.key and TG.job.alive then
		return TG.job
	end
	TG.clear()
	local job = { key = spec.key, spec = spec, done = {}, alive = true, count = 0, total = 0 }
	-- every chunk inside the radius, nearest first
	local cr = math.ceil(spec.radius / CH)
	local list = {}
	for ci = -cr, cr - 1 do
		for ck = -cr, cr - 1 do
			local cx, cz = (ci + 0.5) * CH, (ck + 0.5) * CH
			local d = math.sqrt(cx * cx + cz * cz)
			if d < spec.radius + CH then
				table.insert(list, { ci, ck, d })
			end
		end
	end
	table.sort(list, function(a, b)
		return a[3] < b[3]
	end)
	job.queue = list
	job.total = #list
	TG.job = job
	if t then
		t:SetAttribute("GenKey", spec.key)
	end
	return job
end

local function carved(spec, x: number, z: number)
	local out = nil
	for _, c in spec.carves or {} do
		if x >= c[1] and x <= c[2] and z >= c[3] and z <= c[4] then
			out = out or {}
			table.insert(out, c)
		end
	end
	return out
end

-- Writes the voxel box over columns [i0, i1] x [k0, k1] of a sampled chunk. Steep
-- boxes are split into quarters first: a box has to span from its lowest to its
-- highest column, so a mountainside in one big box is mostly solid rock and air.
local function writeBox(job, S, i0: number, i1: number, k0: number, k1: number)
	local spec = job.spec
	local H, T, x0, z0 = S.H, S.T, S.x0, S.z0
	local lo, hi = math.huge, -math.huge
	for i = i0 - 1, i1 + 1 do
		local row = H[i]
		for k = k0 - 1, k1 + 1 do
			local h = row[k]
			if h < lo then
				lo = h
			end
			if i >= i0 and i <= i1 and k >= k0 and k <= k1 and h > hi then
				hi = h
			end
		end
	end
	local w = i1 - i0 + 1
	if (hi - lo) / RES > 22 and w >= 8 then
		local im, km = i0 + w // 2 - 1, k0 + w // 2 - 1
		writeBox(job, S, i0, im, k0, km)
		writeBox(job, S, im + 1, i1, k0, km)
		writeBox(job, S, i0, im, km + 1, k1)
		writeBox(job, S, im + 1, i1, km + 1, k1)
		return
	end
	local water = spec.water
	local top = hi
	if water and lo < water and water > top then
		top = water
	end
	local y0 = math.floor((lo - (spec.depth or 8)) / RES) * RES
	local y1 = math.ceil((top + 2) / RES) * RES
	local ny = (y1 - y0) // RES
	if ny < 1 then
		return
	end
	local paint = spec.paint
	local nk = k1 - k0 + 1
	local mats = table.create(w)
	local occ = table.create(w)
	for ii = 1, w do
		local mi, oi = table.create(ny), table.create(ny)
		for j = 1, ny do
			mi[j] = table.create(nk, AIR)
			oi[j] = table.create(nk, 0)
		end
		mats[ii], occ[ii] = mi, oi
	end
	local bx0, bz0 = x0 + (i0 - 1) * RES, z0 + (k0 - 1) * RES
	local bx1, bz1 = x0 + i1 * RES, z0 + k1 * RES
	local anyCarve = false
	for _, c in spec.carves or {} do
		if c[2] >= bx0 and c[1] <= bx1 and c[4] >= bz0 and c[3] <= bz1 then
			anyCarve = true
		end
	end
	for i = i0, i1 do
		local Hi, Hm, Hp, Ti = H[i], H[i - 1], H[i + 1], T[i]
		local x = x0 + (i - 0.5) * RES
		local mi, oi = mats[i - i0 + 1], occ[i - i0 + 1]
		for k = k0, k1 do
			local kk = k - k0 + 1
			local h = Hi[k]
			local z = z0 + (k - 0.5) * RES
			local sx = math.abs(Hp[k] - Hm[k])
			local sz = math.abs(Hi[k + 1] - Hi[k - 1])
			local slope = (if sx > sz then sx else sz) / (2 * RES)
			local m = paint(x, z, h, slope, Ti[k])
			local cuts = if anyCarve then carved(spec, x, z) else nil
			for j = 1, ny do
				local yb = y0 + (j - 1) * RES
				local o = (h - yb) / RES
				if o > 0 then
					mi[j][kk] = m
					oi[j][kk] = if o > 1 then 1 else o
				elseif water and yb < water then
					mi[j][kk] = WATER
					local wo = (water - yb) / RES
					oi[j][kk] = if wo > 1 then 1 else wo
				end
				if cuts then
					for _, c in cuts do
						if yb + RES > c[5] and yb < c[6] then
							mi[j][kk] = AIR
							oi[j][kk] = 0
						end
					end
				end
			end
		end
	end
	local t = terrain()
	if t and job.alive then
		t:WriteVoxels(Region3.new(Vector3.new(bx0, y0, bz0), Vector3.new(bx1, y1, bz1)), RES, mats, occ)
	end
end

local function genChunk(job, ci: number, ck: number)
	local id = ci * 100003 + ck
	if job.done[id] then
		return
	end
	job.done[id] = true
	job.count += 1
	local height = job.spec.height
	local x0, z0 = ci * CH, ck * CH
	-- heights at the voxel column centres, with a one-column border for slopes
	local H = table.create(N + 2)
	local T = table.create(N + 2)
	for i = 0, N + 1 do
		local row = table.create(N + 2)
		local trow = table.create(N + 2)
		local x = x0 + (i - 0.5) * RES
		for k = 0, N + 1 do
			local h, tag = height(x, z0 + (k - 0.5) * RES)
			row[k] = h
			trow[k] = tag
		end
		H[i] = row
		T[i] = trow
	end
	writeBox(job, { H = H, T = T, x0 = x0, z0 = z0 }, 1, N, 1, N)
end

-- Builds everything within `radius` of the origin now (yields a little so the
-- loading screen keeps animating).
function TG.runSync(job, radius: number)
	local t0 = os.clock()
	for _, c in job.queue do
		if not job.alive then
			return
		end
		if c[3] > radius + CH then
			break
		end
		genChunk(job, c[1], c[2])
		if os.clock() - t0 > 0.05 then
			task.wait()
			t0 = os.clock()
		end
	end
end

-- Streams the rest in, nearest first.
function TG.background(job)
	task.spawn(function()
		local budget = (job.spec.budget or 6) / 1000
		local idx = 1
		while job.alive and idx <= #job.queue do
			local t0 = os.clock()
			while idx <= #job.queue and os.clock() - t0 < budget do
				local c = job.queue[idx]
				genChunk(job, c[1], c[2])
				idx += 1
			end
			RunService.Heartbeat:Wait()
		end
		if job.alive then
			job.finished = true
		end
	end)
end

-- Makes sure the terrain around a point exists (spawns, teleports, packs).
function TG.ensure(pos: Vector3, r: number?)
	local job = TG.job
	if not job or not job.alive then
		return
	end
	local rr = r or 96
	local i0, i1 = math.floor((pos.X - rr) / CH), math.floor((pos.X + rr) / CH)
	local k0, k1 = math.floor((pos.Z - rr) / CH), math.floor((pos.Z + rr) / CH)
	for ci = i0, i1 do
		for ck = k0, k1 do
			local cx, cz = (ci + 0.5) * CH, (ck + 0.5) * CH
			if math.sqrt(cx * cx + cz * cz) < job.spec.radius + CH then
				genChunk(job, ci, ck)
			end
		end
	end
end

function TG.progress(): number
	local job = TG.job
	if not job or job.total == 0 then
		return 1
	end
	return job.count / job.total
end

function TG.active(key: string?): boolean
	local job = TG.job
	return job ~= nil and job.alive and (key == nil or job.key == key)
end

function TG.clear()
	if TG.job then
		TG.job.alive = false
	end
	TG.job = nil
	local t = terrain()
	if t then
		t:Clear()
		t:SetAttribute("GenKey", nil)
	end
end

return TG
