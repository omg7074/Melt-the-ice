--!strict
-- Melt the World's Biggest Ice Block: server authority.
-- Builds the shared ice block, applies heat from every player's equipped heater,
-- pays coins, reveals frozen treasures, and handles shop purchases + saving.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MaterialService = game:GetService("MaterialService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

---------------------------------------------------------------- remotes
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local BuyRemote = remote("Buy") -- client -> server: ("heater", id) | ("power")
local EquipRemote = remote("Equip") -- client -> server: (id)
local StateRemote = remote("State") -- server -> client: player state table
local BlockRemote = remote("Block") -- server -> all: block progress
local PopupRemote = remote("Popup") -- server -> client: (text, color)
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------- data
local store = DataStoreService:GetDataStore("MeltTheIce_v1")

type Data = { coins: number, owned: { [string]: boolean }, equipped: string, power: number, melted: number }
local data: { [Player]: Data } = {}
local lastRequest: { [Player]: number } = {}

local function defaultData(): Data
	return { coins = 0, owned = { candle = true }, equipped = "candle", power = 0, melted = 0 }
end

local function pushState(player: Player)
	local d = data[player]
	if d then
		StateRemote:FireClient(player, d)
	end
end

local function load(player: Player)
	local ok, saved = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	local d = defaultData()
	if ok and type(saved) == "table" then
		d.coins = tonumber(saved.coins) or 0
		d.power = tonumber(saved.power) or 0
		d.melted = tonumber(saved.melted) or 0
		if type(saved.owned) == "table" then
			for id, v in saved.owned do
				if Config.heaterById(id) and v then
					d.owned[id] = true
				end
			end
		end
		if type(saved.equipped) == "string" and d.owned[saved.equipped] then
			d.equipped = saved.equipped
		end
	end
	data[player] = d

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = stats
	local melted = Instance.new("IntValue")
	melted.Name = "Melted"
	melted.Parent = stats
	stats.Parent = player
	pushState(player)
end

local function save(player: Player)
	local d = data[player]
	if not d then
		return
	end
	pcall(function()
		store:SetAsync(tostring(player.UserId), d)
	end)
end

local function syncStats(player: Player)
	local d = data[player]
	local stats = player:FindFirstChild("leaderstats")
	if d and stats then
		(stats:FindFirstChild("Coins") :: IntValue).Value = math.floor(d.coins);
		(stats:FindFirstChild("Melted") :: IntValue).Value = d.melted
	end
end

local function addCoins(player: Player, amount: number)
	local d = data[player]
	if d then
		d.coins += amount
		syncStats(player)
	end
end

---------------------------------------------------------------- arena (stud style)
local hasVariants = MaterialService:FindFirstChild("Universal") ~= nil

local function brick(size: Vector3, cf: CFrame, color: Color3, pattern: string?, parent: Instance): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Plastic
	p.Anchored = true
	local pat = pattern or "Universal"
	if hasVariants then
		p.MaterialVariant = pat
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	else
		local name = pat:gsub("StudsNoGrid", "Studs")
		local surf = (Enum.SurfaceType :: any)[name] or Enum.SurfaceType.Studs
		for _, face in { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" } do
			(p :: any)[face] = surf
		end
	end
	p.Parent = parent
	return p
end

local arena = Instance.new("Model")
arena.Name = "Arena"
arena.Parent = workspace
brick(Vector3.new(160, 2, 160), CFrame.new(0, -1, 0), Color3.fromRGB(235, 245, 255), "Universal", arena) -- snowfield
brick(Vector3.new(70, 0.6, 70), CFrame.new(0, 0.3001, 0), Color3.fromRGB(120, 200, 240), "StudsNoGrid", arena) -- rink
for _, s in { -1, 1 } do -- fence rails around the rink
	brick(Vector3.new(72, 1, 1), CFrame.new(0, 2, s * 36), Color3.fromRGB(110, 80, 60), "Weld", arena)
	brick(Vector3.new(1, 1, 72), CFrame.new(s * 36, 2, 0), Color3.fromRGB(110, 80, 60), "Weld", arena)
end
local spawn = Instance.new("SpawnLocation")
spawn.Size = Vector3.new(8, 1, 8)
spawn.CFrame = CFrame.new(0, 1.1, 30)
spawn.Anchored = true
spawn.Material = Enum.Material.Plastic
spawn.Color = Color3.fromRGB(255, 170, 60)
spawn.Parent = arena

---------------------------------------------------------------- the ice block
local blockIndex = 1
type Cube = { part: Part, hp: number, maxHp: number, layer: number, key: Vector3, treasure: any? }
local cubes: { [Vector3]: Cube } = {}
local remaining, total = 0, 0
local blockFolder: Folder? = nil

local function layerOf(x: number, y: number, z: number, n: number): number
	return 1 + math.min(x, y, z, n - 1 - x, n - 1 - y, n - 1 - z)
end

local function broadcastBlock()
	local b = Config.Blocks[blockIndex]
	BlockRemote:FireAllClients({ index = blockIndex, name = b.name, remaining = remaining, total = total, count = #Config.Blocks })
end

local function buildBlock()
	if blockFolder then
		blockFolder:Destroy()
	end
	table.clear(cubes)
	local b = Config.Blocks[blockIndex]
	local n, s = b.cubes, Config.CUBE_SIZE
	local folder = Instance.new("Folder")
	folder.Name = "IceBlock"
	local origin = Vector3.new(-(n - 1) * s / 2, 0.6 + s / 2, -(n - 1) * s / 2)
	local center = (n + 1) / 2
	for x = 0, n - 1 do
		for y = 0, n - 1 do
			for z = 0, n - 1 do
				local layer = layerOf(x, y, z, n)
				local hp = b.baseHp * b.coldness ^ (layer - 1)
				-- deeper = darker, colder blue
				local t = (layer - 1) / math.max(center - 1, 1)
				local color = b.tint:Lerp(Color3.fromRGB(20, 40, 120), t * 0.6)
				local part = brick(Vector3.one * s, CFrame.new(origin + Vector3.new(x, y, z) * s), color, "Universal", folder)
				part.Material = Enum.Material.Ice
				part.MaterialVariant = ""
				part.Transparency = 0.15
				part.Name = "Ice"
				local treasure = nil
				for i = #Config.Treasures, 1, -1 do
					local tr = Config.Treasures[i]
					if layer >= tr.minLayer and math.random() < tr.chance then
						treasure = tr
						break
					end
				end
				if treasure then -- frozen object visible inside the cube
					local core = brick(Vector3.one * (s * 0.45), part.CFrame, treasure.color, "Studs", part)
					core.CanCollide = false
					core.Name = treasure.name
				end
				local key = Vector3.new(x, y, z)
				cubes[key] = { part = part, hp = hp, maxHp = hp, layer = layer, key = key, treasure = treasure }
			end
		end
	end
	total = n * n * n
	remaining = total
	folder.Parent = workspace
	blockFolder = folder
	broadcastBlock()
end

local DIRS = { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }
local function exposed(c: Cube): boolean
	for _, d in DIRS do
		if not cubes[c.key + d] then
			return true
		end
	end
	return false
end

local function completeBlock()
	local b = Config.Blocks[blockIndex]
	for _, p in Players:GetPlayers() do
		addCoins(p, b.reward)
		PopupRemote:FireClient(p, ("Reached the centre of the %s! +%d"):format(b.name, b.reward), Color3.fromRGB(255, 220, 80))
		pushState(p)
	end
	blockIndex = blockIndex % #Config.Blocks + 1
	task.delay(4, buildBlock)
end

local function meltCube(c: Cube, player: Player)
	cubes[c.key] = nil
	remaining -= 1
	local b = Config.Blocks[blockIndex]
	local d = data[player]
	if d then
		d.melted += 1
	end
	local reward = b.coinPerCube * c.layer
	if c.treasure then
		reward += b.coinPerCube * c.treasure.coinMult
		PopupRemote:FireClient(player, ("Found a %s! +%d"):format(c.treasure.name, b.coinPerCube * c.treasure.coinMult), c.treasure.color)
	end
	addCoins(player, reward)
	c.part:Destroy()
	broadcastBlock()
	if remaining == 0 then
		completeBlock()
	end
end

---------------------------------------------------------------- heat loop
local function heatFor(d: Data): (number, Config.Heater)
	local h = Config.heaterById(d.equipped) or Config.Heaters[1]
	return h.heat * (1 + d.power * Config.PowerUpgrade.bonusPerLevel), h
end

task.spawn(function()
	while true do
		task.wait(Config.TICK)
		if remaining == 0 then
			continue
		end
		for player, d in data do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local heat, h = heatFor(d)
			-- collect exposed cubes in range, nearest first
			local targets = {}
			for _, c in cubes do
				local dist = (c.part.Position - root.Position).Magnitude - Config.CUBE_SIZE / 2
				if dist <= h.range and exposed(c) then
					table.insert(targets, { c = c, dist = dist })
				end
			end
			table.sort(targets, function(a, b)
				return a.dist < b.dist
			end)
			local changed = false
			for i = 1, math.min(h.maxTargets, #targets) do
				local c = targets[i].c
				if cubes[c.key] then
					c.hp -= heat * Config.TICK
					changed = true
					if c.hp <= 0 then
						meltCube(c, player)
					else
						local f = c.hp / c.maxHp
						c.part.Transparency = 0.15 + (1 - f) * 0.5
						c.part.Size = Vector3.one * Config.CUBE_SIZE * (0.6 + 0.4 * f)
					end
				end
			end
			if changed then
				pushState(player)
			end
		end
	end
end)

---------------------------------------------------------------- shop (validated server-side)
local function rateLimited(player: Player): boolean
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 0.2 then
		return true
	end
	lastRequest[player] = now
	return false
end

BuyRemote.OnServerEvent:Connect(function(player, kind, id)
	local d = data[player]
	if not d or rateLimited(player) then
		return
	end
	if kind == "power" then
		if d.power >= Config.PowerUpgrade.maxLevel then
			return
		end
		local cost = Config.powerCost(d.power)
		if d.coins >= cost then
			d.coins -= cost
			d.power += 1
		end
	elseif kind == "heater" and type(id) == "string" then
		local h, idx = Config.heaterById(id)
		if not h or not idx or d.owned[id] then
			return
		end
		-- must own the previous tier (industrial heaters unlock in order)
		local prev = Config.Heaters[idx - 1]
		if prev and not d.owned[prev.id] then
			return
		end
		if d.coins >= h.price then
			d.coins -= h.price
			d.owned[id] = true
			d.equipped = id
			PopupRemote:FireClient(player, ("Unlocked %s!"):format(h.name), h.color)
		end
	end
	syncStats(player)
	pushState(player)
end)

EquipRemote.OnServerEvent:Connect(function(player, id)
	local d = data[player]
	if d and type(id) == "string" and d.owned[id] and not rateLimited(player) then
		d.equipped = id
		pushState(player)
	end
end)

---------------------------------------------------------------- lifecycle
Players.PlayerAdded:Connect(function(player)
	load(player)
	broadcastBlock()
end)
Players.PlayerRemoving:Connect(function(player)
	save(player)
	data[player] = nil
	lastRequest[player] = nil
end)
game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		save(p)
	end
end)
task.spawn(function() -- autosave
	while true do
		task.wait(60)
		for _, p in Players:GetPlayers() do
			save(p)
		end
	end
end)

buildBlock()
