--!nonstrict
-- Floor plan for the underground: rooms on a coarse grid (grown as a random
-- tree + a few loops), sized per room kind, packed into variable-width grid
-- columns/rows, joined by straight corridors that climb with stairs where the
-- room floors differ in height.
local L = {}
local V = Vector3.new

-- kind -> {sx range, sz range, ceiling range}
local SIZES = {
	spawn = { { 78, 90 }, { 78, 90 }, { 50, 56 } },
	hall = { { 130, 160 }, { 64, 80 }, { 56, 72 } },
	crypt = { { 76, 100 }, { 76, 100 }, { 38, 44 } },
	cathedral = { { 140, 160 }, { 96, 112 }, { 96, 118 } },
	cistern = { { 100, 136 }, { 100, 136 }, { 52, 66 } },
	cavern = { { 96, 140 }, { 96, 140 }, { 56, 86 } },
	mine = { { 110, 150 }, { 70, 96 }, { 50, 64 } },
	chasm = { { 120, 150 }, { 92, 116 }, { 64, 90 } },
	forge = { { 110, 140 }, { 84, 108 }, { 56, 72 } },
	exit = { { 100, 120 }, { 100, 120 }, { 70, 84 } },
	arena = { { 150, 150 }, { 150, 150 }, { 84, 96 } },
	throne = { { 168, 168 }, { 168, 168 }, { 100, 116 } },
}
L.SIZES = SIZES

local DIRS = { { 1, 0, "xp", "xn" }, { -1, 0, "xn", "xp" }, { 0, 1, "zp", "zn" }, { 0, -1, "zn", "zp" } }

-- opts {G, rooms, big, throne, kinds = {{kind, weight}}}
function L.plan(rng, origin: Vector3, opts)
	local G = opts.G
	local N = math.min(opts.rooms, G * G)
	local cells = {}
	local list = {}
	local function key(x, z)
		return x * 100 + z
	end
	local sx0, sz0 = rng:int(1, G), rng:int(1, G)
	local first = { gx = sx0, gz = sz0, links = {}, tree = {} }
	cells[key(sx0, sz0)] = first
	table.insert(list, first)
	local edges = {}
	local guard = 0
	while #list < N and guard < 5000 do
		guard += 1
		local r = list[rng:int(1, #list)]
		local d = DIRS[rng:int(1, 4)]
		local nx, nz = r.gx + d[1], r.gz + d[2]
		if nx >= 1 and nx <= G and nz >= 1 and nz <= G and not cells[key(nx, nz)] then
			local n = { gx = nx, gz = nz, links = {}, tree = {} }
			cells[key(nx, nz)] = n
			table.insert(list, n)
			table.insert(edges, { a = r, b = n, tree = true })
			table.insert(r.tree, n)
			table.insert(n.tree, r)
		end
	end
	-- farthest pair over the tree
	local function bfs(start)
		local dist = { [start] = 0 }
		local q = { start }
		local far = start
		local qi = 1
		while qi <= #q do
			local r = q[qi]
			qi += 1
			for _, n in r.tree do
				if dist[n] == nil then
					dist[n] = dist[r] + 1
					table.insert(q, n)
					if dist[n] > dist[far] then
						far = n
					end
				end
			end
		end
		return far, dist
	end
	local exitR = bfs(list[1])
	local spawnR, dist = bfs(exitR)
	-- loops (never touching spawn or exit)
	for _, r in list do
		for _, d in { DIRS[1], DIRS[3] } do
			local n = cells[key(r.gx + d[1], r.gz + d[2])]
			if n and r ~= spawnR and n ~= spawnR and r ~= exitR and n ~= exitR and rng:chance(opts.loops or 0.3) then
				local already = false
				for _, t in r.tree do
					if t == n then
						already = true
					end
				end
				if not already then
					table.insert(edges, { a = r, b = n, tree = false })
				end
			end
		end
	end
	-- kinds
	local weights = opts.kinds
	for _, r in list do
		if r == spawnR then
			r.kind = "spawn"
		elseif r == exitR then
			r.kind = if opts.throne then "throne" elseif opts.big then "arena" else "exit"
		else
			local k
			for _ = 1, 6 do
				k = rng:weighted(weights)
				local clash = false
				for _, t in r.tree do
					if t.kind == k then
						clash = true
					end
				end
				if not clash then
					break
				end
			end
			r.kind = k
		end
		r.dist = dist[r] or 0
	end
	-- sizes (long rooms get a random orientation)
	for _, r in list do
		local sz = SIZES[r.kind] or SIZES.hall
		local a = rng:int(sz[1][1], sz[1][2])
		local b = rng:int(sz[2][1], sz[2][2])
		if r.kind ~= "arena" and r.kind ~= "throne" and rng:chance(0.5) then
			a, b = b, a
		end
		r.sx = math.floor(a / 4) * 4
		r.sz = math.floor(b / 4) * 4
		r.h = rng:int(sz[3][1], sz[3][2])
		r.round = r.kind == "arena" or r.kind == "throne"
	end
	-- column widths / row depths
	local gap = opts.gap or 48
	local colW, rowD = {}, {}
	for i = 1, G do
		colW[i] = 60
		rowD[i] = 60
	end
	for _, r in list do
		colW[r.gx] = math.max(colW[r.gx], r.sx + gap)
		rowD[r.gz] = math.max(rowD[r.gz], r.sz + gap)
	end
	local totalX, totalZ = 0, 0
	for i = 1, G do
		totalX += colW[i]
		totalZ += rowD[i]
	end
	local colX, rowZ = {}, {}
	local acc = origin.X - totalX / 2
	for i = 1, G do
		colX[i] = acc + colW[i] / 2
		acc += colW[i]
	end
	acc = origin.Z - totalZ / 2
	for i = 1, G do
		rowZ[i] = acc + rowD[i] / 2
		acc += rowD[i]
	end
	local MARGIN = 17
	for _, r in list do
		local slackX = (colW[r.gx] - gap - r.sx) / 2
		local slackZ = (rowD[r.gz] - gap - r.sz) / 2
		-- keep the grid centre lines inside the room so straight corridors fit
		local jx = math.min(slackX, r.sx / 2 - MARGIN - 6)
		local jz = math.min(slackZ, r.sz / 2 - MARGIN - 6)
		if r.round then
			jx, jz = 0, 0
		end
		r.cx = colX[r.gx] + rng:float(-jx, jx)
		r.cz = rowZ[r.gz] + rng:float(-jz, jz)
		r.x0, r.x1 = r.cx - r.sx / 2, r.cx + r.sx / 2
		r.z0, r.z1 = r.cz - r.sz / 2, r.cz + r.sz / 2
		r.doors = { xn = {}, xp = {}, zn = {}, zp = {} }
		r.occ = {}
		r.spots = {}
		r.lines = { x = colX[r.gx], z = rowZ[r.gz] }
	end
	-- corridors
	local cors = {}
	for _, e in edges do
		local a, b = e.a, e.b
		if a.gx > b.gx or a.gz > b.gz then
			a, b = b, a
		end
		local c = { a = a, b = b, tree = e.tree }
		c.w = rng:pick({ 16, 18, 20, 20, 24 })
		c.ch = rng:int(20, 26)
		if a.gz == b.gz then
			c.axis = "x"
			local line = rowZ[a.gz]
			local lo = math.max(a.z0, b.z0) + c.w / 2 + 6
			local hi = math.min(a.z1, b.z1) - c.w / 2 - 6
			c.c = if a.round or b.round then line else math.clamp(line + rng:float(-12, 12), lo, math.max(lo, hi))
			c.s0 = a.x1
			c.s1 = b.x0
			c.sideA, c.sideB = "xp", "xn"
		else
			c.axis = "z"
			local line = colX[a.gx]
			local lo = math.max(a.x0, b.x0) + c.w / 2 + 6
			local hi = math.min(a.x1, b.x1) - c.w / 2 - 6
			c.c = if a.round or b.round then line else math.clamp(line + rng:float(-12, 12), lo, math.max(lo, hi))
			c.s0 = a.z1
			c.s1 = b.z0
			c.sideA, c.sideB = "zp", "zn"
		end
		c.len = c.s1 - c.s0
		table.insert(cors, c)
	end
	-- elevations: walk the tree from the spawn, climbing on average
	spawnR.y = origin.Y
	local q = { spawnR }
	local qi = 1
	local function corBetween(x, y)
		for _, c in cors do
			if (c.a == x and c.b == y) or (c.a == y and c.b == x) then
				return c
			end
		end
		return nil
	end
	while qi <= #q do
		local r = q[qi]
		qi += 1
		for _, n in r.tree do
			if n.y == nil then
				local c = corBetween(r, n)
				local maxRise = math.floor(((c and c.len or 40) - 16) / 1.7)
				local dy = rng:pick({ 0, 0, 6, 8, 10, 12, 16, -6, -8 })
				dy = math.clamp(dy, -maxRise, maxRise)
				local y = math.clamp(r.y + dy, origin.Y - 16, origin.Y + 56)
				n.y = y
				table.insert(q, n)
			end
		end
	end
	for _, r in list do
		r.y = r.y or origin.Y
	end
	-- drop loops that cannot climb; finish corridors
	local kept = {}
	for _, c in cors do
		c.ya, c.yb = c.a.y, c.b.y
		local dy = math.abs(c.ya - c.yb)
		local maxRise = math.floor((c.len - 16) / 1.7)
		if c.tree or dy <= maxRise then
			table.insert(kept, c)
			table.insert(c.a.links, c.b)
			table.insert(c.b.links, c.a)
		end
	end
	-- doors on the room walls (along-wall coordinate is measured from x0 / z0)
	for _, c in kept do
		for _, endp in { { c.a, c.sideA, c.ya }, { c.b, c.sideB, c.yb } } do
			local r, side, y = endp[1], endp[2], endp[3]
			local along = if c.axis == "x" then c.c - r.z0 else c.c - r.x0
			table.insert(r.doors[side], { c = along, w = c.w, h = c.ch, cor = c })
		end
	end
	return {
		rooms = list,
		cors = kept,
		spawn = spawnR,
		exit = exitR,
		G = G,
		extent = V(totalX, 0, totalZ),
		colX = colX,
		rowZ = rowZ,
	}
end

-- occupancy helpers ---------------------------------------------------------
function L.block(room, x0, z0, x1, z1)
	table.insert(room.occ, { math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1) })
end

function L.free(room, x, z, r)
	if x - r < room.x0 + 1 or x + r > room.x1 - 1 or z - r < room.z0 + 1 or z + r > room.z1 - 1 then
		return false
	end
	if room.round then
		local dx, dz = x - room.cx, z - room.cz
		if math.sqrt(dx * dx + dz * dz) + r > room.sx / 2 - 3 then
			return false
		end
	end
	for _, o in room.occ do
		if x + r > o[1] and x - r < o[3] and z + r > o[2] and z - r < o[4] then
			return false
		end
	end
	return true
end

-- random free spot with clearance r, marks it; returns Vector3 at floor height or nil
function L.spot(rng, room, r, margin, mark, area)
	local m = margin or 4
	for _ = 1, 40 do
		local x0, x1, z0, z1 = room.x0 + m, room.x1 - m, room.z0 + m, room.z1 - m
		if area then
			x0, z0, x1, z1 = area[1], area[2], area[3], area[4]
		end
		if x1 > x0 and z1 > z0 then
			local x = rng:float(x0, x1)
			local z = rng:float(z0, z1)
			if L.free(room, x, z, r) then
				if mark ~= false then
					L.block(room, x - r, z - r, x + r, z + r)
				end
				return V(x, room.y, z)
			end
		end
	end
	return nil
end

-- wall frame info for a side: a (corner at floor), u (along), n (inward), length
function L.side(room, side)
	if side == "xn" then
		return V(room.x0, room.y, room.z0), V(0, 0, 1), V(1, 0, 0), room.sz
	elseif side == "xp" then
		return V(room.x1, room.y, room.z0), V(0, 0, 1), V(-1, 0, 0), room.sz
	elseif side == "zn" then
		return V(room.x0, room.y, room.z0), V(1, 0, 0), V(0, 0, 1), room.sx
	end
	return V(room.x0, room.y, room.z1), V(1, 0, 0), V(0, 0, -1), room.sx
end

L.SIDES = { "xn", "xp", "zn", "zp" }
L.OPP = { xn = "xp", xp = "xn", zn = "zp", zp = "zn" }

return L
