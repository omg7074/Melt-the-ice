--!strict
-- Shared balance data. Server is the authority; the client only reads this for display.

local Config = {}

-- Size of one ice cube in studs
Config.CUBE_SIZE = 4
-- Seconds between server heat ticks
Config.TICK = 0.25

export type Heater = {
	id: string,
	name: string,
	price: number,
	heat: number, -- heat per second applied to each cube in range
	range: number, -- studs from the character
	maxTargets: number, -- cubes heated at once
	color: Color3,
	industrial: boolean,
}

-- Ordered heater ladder: small heater -> industrial heaters
Config.Heaters = {
	{ id = "candle", name = "Pocket Heater", price = 0, heat = 4, range = 8, maxTargets = 1, color = Color3.fromRGB(255, 170, 60), industrial = false },
	{ id = "hairdryer", name = "Hair Dryer", price = 60, heat = 10, range = 10, maxTargets = 2, color = Color3.fromRGB(255, 120, 200), industrial = false },
	{ id = "space", name = "Space Heater", price = 350, heat = 28, range = 12, maxTargets = 3, color = Color3.fromRGB(255, 90, 40), industrial = false },
	{ id = "torch", name = "Blowtorch", price = 1800, heat = 80, range = 14, maxTargets = 4, color = Color3.fromRGB(80, 170, 255), industrial = false },
	{ id = "furnace", name = "Industrial Furnace", price = 9000, heat = 240, range = 18, maxTargets = 6, color = Color3.fromRGB(255, 60, 20), industrial = true },
	{ id = "plasma", name = "Plasma Cannon", price = 50000, heat = 800, range = 24, maxTargets = 9, color = Color3.fromRGB(170, 80, 255), industrial = true },
	{ id = "sun", name = "Miniature Sun", price = 300000, heat = 3000, range = 32, maxTargets = 14, color = Color3.fromRGB(255, 230, 90), industrial = true },
} :: { Heater }

-- Power upgrade: multiplies heater heat. Cost grows geometrically.
Config.PowerUpgrade = { baseCost = 25, growth = 1.45, bonusPerLevel = 0.15, maxLevel = 50 }

export type Block = {
	name: string,
	cubes: number, -- cubes per side (odd so there is a centre cube)
	baseHp: number, -- hp of an outer cube
	coldness: number, -- hp multiplier per layer moving inward
	coinPerCube: number,
	tint: Color3,
	reward: number, -- bonus for reaching the centre
}

-- Each block is bigger and colder than the last
Config.Blocks = {
	{ name = "Freezer Cube", cubes = 5, baseHp = 10, coldness = 1.6, coinPerCube = 1, tint = Color3.fromRGB(190, 235, 255), reward = 100 },
	{ name = "Glacier Chunk", cubes = 7, baseHp = 40, coldness = 1.7, coinPerCube = 4, tint = Color3.fromRGB(140, 205, 255), reward = 800 },
	{ name = "Permafrost Slab", cubes = 9, baseHp = 160, coldness = 1.8, coinPerCube = 15, tint = Color3.fromRGB(100, 170, 240), reward = 6000 },
	{ name = "Polar Monolith", cubes = 11, baseHp = 700, coldness = 1.9, coinPerCube = 60, tint = Color3.fromRGB(80, 130, 220), reward = 40000 },
	{ name = "World's Biggest Ice Block", cubes = 13, baseHp = 3000, coldness = 2.0, coinPerCube = 250, tint = Color3.fromRGB(60, 90, 200), reward = 400000 },
} :: { Block }

-- Frozen treasures revealed by layer (1 = outermost shell). Picked randomly per inner cube.
Config.Treasures = {
	{ name = "Frozen Fish", minLayer = 2, chance = 0.12, coinMult = 10, color = Color3.fromRGB(255, 140, 60) },
	{ name = "Ancient Coin Chest", minLayer = 3, chance = 0.08, coinMult = 40, color = Color3.fromRGB(255, 205, 50) },
	{ name = "Mammoth Tusk", minLayer = 4, chance = 0.05, coinMult = 120, color = Color3.fromRGB(240, 230, 210) },
	{ name = "Frozen Caveman", minLayer = 5, chance = 0.03, coinMult = 400, color = Color3.fromRGB(150, 100, 70) },
}

function Config.powerCost(level: number): number
	return math.floor(Config.PowerUpgrade.baseCost * Config.PowerUpgrade.growth ^ level)
end

function Config.heaterById(id: string): (Heater?, number?)
	for i, h in Config.Heaters do
		if h.id == id then
			return h, i
		end
	end
	return nil, nil
end

return Config
