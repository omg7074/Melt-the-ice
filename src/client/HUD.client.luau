--!strict
-- HUD: coins, block progress bar, heater shop, power upgrade, popups, heat glow.
-- Display only; every purchase is validated on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	i.Parent = parent
	return i
end
local function round(parent: Instance, r: number)
	make("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end
local function stroke(parent: Instance)
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(20, 40, 80), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local gui = make("ScreenGui", { Name = "MeltHUD", ResetOnSpawn = false, IgnoreGuiInset = false }, player:WaitForChild("PlayerGui"))

-- top: block progress
local top = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(420, 64), BackgroundColor3 = Color3.fromRGB(30, 60, 110) }, gui)
round(top, 12)
stroke(top)
local blockName = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "Loading ice..." }, top)
local barBg = make("Frame", { Position = UDim2.new(0, 12, 0, 32), Size = UDim2.new(1, -24, 0, 22), BackgroundColor3 = Color3.fromRGB(15, 30, 60) }, top)
round(barBg, 8)
local bar = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 140, 50) }, barBg)
round(bar, 8)
local barText = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "0%" }, barBg)

-- left: coins + heater
local left = make("Frame", { Position = UDim2.new(0, 12, 0.5, -60), Size = UDim2.fromOffset(220, 120), BackgroundColor3 = Color3.fromRGB(30, 60, 110) }, gui)
round(left, 12)
stroke(left)
make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, left)
make("UIPadding", { PaddingTop = UDim.new(0, 8) }, left)
local coinsLbl = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 30), Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(255, 215, 70), Text = "0 coins" }, left)
local heaterLbl = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 22), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "" }, left)
local shopBtn = make("TextButton", { Size = UDim2.new(1, -16, 0, 34), BackgroundColor3 = Color3.fromRGB(255, 140, 50), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "Heater Shop" }, left)
round(shopBtn, 10)

-- shop panel
local shop = make("Frame", { Visible = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(460, 420), BackgroundColor3 = Color3.fromRGB(30, 60, 110) }, gui)
round(shop, 14)
stroke(shop)
make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "Heater Shop" }, shop)
local close = make("TextButton", { Position = UDim2.new(1, -40, 0, 6), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.fromRGB(220, 60, 60), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "X" }, shop)
round(close, 8)
local list = make("ScrollingFrame", { Position = UDim2.new(0, 12, 0, 48), Size = UDim2.new(1, -24, 1, -60), BackgroundTransparency = 1, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollBarThickness = 6 }, shop)
make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local state: any = nil
local rows: { [string]: TextButton } = {}

local function row(order: number, title: string, color: Color3): TextButton
	local f = make("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 52), BackgroundColor3 = Color3.fromRGB(45, 85, 150) }, list)
	round(f, 10)
	make("Frame", { Size = UDim2.fromOffset(8, 52), BackgroundColor3 = color }, f)
	make("TextLabel", { Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -150, 0, 24), Font = FONT, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1), Text = title }, f)
	make("TextLabel", { Name = "Sub", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -150, 0, 18), Font = Enum.Font.GothamMedium, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 225, 255), Text = "" }, f)
	local b = make("TextButton", { Position = UDim2.new(1, -126, 0, 9), Size = UDim2.fromOffset(116, 34), BackgroundColor3 = Color3.fromRGB(80, 200, 110), Font = FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Text = "" }, f)
	round(b, 8)
	return b
end

local powerBtn = row(0, "Heating Power", Color3.fromRGB(255, 200, 60))
powerBtn.Activated:Connect(function()
	remotes.Buy:FireServer("power")
end)
for i, h in Config.Heaters do
	local b = row(i, (h.industrial and "[Industrial] " or "") .. h.name, h.color)
	local sub = (b.Parent :: Frame):FindFirstChild("Sub") :: TextLabel
	sub.Text = ("%d heat/s  -  %d range  -  %d cubes"):format(h.heat, h.range, h.maxTargets)
	rows[h.id] = b
	b.Activated:Connect(function()
		if state and state.owned[h.id] then
			remotes.Equip:FireServer(h.id)
		else
			remotes.Buy:FireServer("heater", h.id)
		end
	end)
end

local function short(n: number): string
	for _, s in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= s[1] then
			return ("%.1f%s"):format(n / s[1], s[2])
		end
	end
	return tostring(math.floor(n))
end

local function refresh()
	if not state then
		return
	end
	coinsLbl.Text = short(state.coins) .. " coins"
	local h = Config.heaterById(state.equipped)
	heaterLbl.Text = (h and h.name or "?") .. "  (Power Lv " .. state.power .. ")"
	local powerSub = (powerBtn.Parent :: Frame):FindFirstChild("Sub") :: TextLabel
	powerSub.Text = ("Lv %d  -  +%d%% heat"):format(state.power, state.power * Config.PowerUpgrade.bonusPerLevel * 100)
	powerBtn.Text = short(Config.powerCost(state.power))
	for i, heater in Config.Heaters do
		local b = rows[heater.id]
		local prev = Config.Heaters[i - 1]
		if state.equipped == heater.id then
			b.Text, b.BackgroundColor3 = "Equipped", Color3.fromRGB(120, 120, 140)
		elseif state.owned[heater.id] then
			b.Text, b.BackgroundColor3 = "Equip", Color3.fromRGB(70, 140, 230)
		elseif prev and not state.owned[prev.id] then
			b.Text, b.BackgroundColor3 = "Locked", Color3.fromRGB(90, 90, 100)
		else
			b.Text = short(heater.price)
			b.BackgroundColor3 = state.coins >= heater.price and Color3.fromRGB(80, 200, 110) or Color3.fromRGB(160, 70, 70)
		end
	end
end

shopBtn.Activated:Connect(function()
	shop.Visible = not shop.Visible
end)
close.Activated:Connect(function()
	shop.Visible = false
end)

remotes.State.OnClientEvent:Connect(function(s)
	state = s
	refresh()
end)

remotes.Block.OnClientEvent:Connect(function(b)
	local pct = b.total > 0 and (1 - b.remaining / b.total) or 0
	blockName.Text = ("Block %d/%d: %s"):format(b.index, b.count, b.name)
	barText.Text = ("%d%% melted"):format(math.floor(pct * 100))
	TweenService:Create(bar, TweenInfo.new(0.3), { Size = UDim2.fromScale(pct, 1) }):Play()
end)

-- popups
remotes.Popup.OnClientEvent:Connect(function(text: string, color: Color3)
	local lbl = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(520, 44), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = color, Text = text }, gui)
	make("UIStroke", { Thickness = 3, Color = Color3.fromRGB(20, 30, 60) }, lbl)
	local tw = TweenService:Create(lbl, TweenInfo.new(1.8), { Position = UDim2.fromScale(0.5, 0.22), TextTransparency = 1 })
	tw:Play()
	tw.Completed:Once(function()
		lbl:Destroy()
	end)
end)

-- heat glow around the character, coloured by the equipped heater
local function attachGlow(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local light = make("PointLight", { Brightness = 2, Range = 10, Shadows = false }, root)
	local fire = make("Fire", { Size = 3, Heat = 6 }, root)
	local function apply()
		local h = state and Config.heaterById(state.equipped)
		if h then
			light.Color = h.color
			light.Range = h.range
			fire.Color = h.color
			fire.SecondaryColor = Color3.new(1, 1, 0.6)
			fire.Size = math.clamp(h.range / 4, 2, 10)
		end
	end
	apply()
	local conn = remotes.State.OnClientEvent:Connect(apply)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			conn:Disconnect()
		end
	end)
end
if player.Character then
	task.spawn(attachGlow, player.Character)
end
player.CharacterAdded:Connect(attachGlow)
