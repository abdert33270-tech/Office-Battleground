--[[
	HintController — conseils contextuels NON bloquants (objectif : frapper avec un objet en < 30 s).
	- Étiquette "[E] PICK UP CHAIR" au-dessus de l'objet le plus proche (mains vides).
	- Bandeau discret en bas d'écran avec les commandes utiles du moment.
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.Combat)
local ItemsConfig = require(Shared.Config.Items)
local UITheme = require(Shared.Modules.UITheme)

local HintController = {}
local player = Players.LocalPlayer

local function isTouch()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function hexOf(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end
local KEY = hexOf(UITheme.Colors.Yellow)
-- "CLICK: punch" -> touche en jaune + action en blanc
local function chips(list)
	local parts = {}
	for _, pair in ipairs(list) do
		table.insert(parts, '<font color="' .. KEY .. '">' .. pair[1] .. '</font> ' .. pair[2])
	end
	return table.concat(parts, "   ")
end

function HintController.init()
	-- étiquette au-dessus de l'objet : [E] PICK UP CHAIR!
	local tag = Instance.new("BillboardGui")
	tag.Name = "PickupHint"
	tag.Size = UDim2.fromOffset(250, 44)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.Enabled = false
	tag.Parent = player:WaitForChild("PlayerGui")
	local pill = UITheme.new("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UITheme.Colors.PanelDark,
		BackgroundTransparency = 0.08,
		Parent = tag,
	})
	UITheme.corner(pill, 4)
	UITheme.stroke(pill, 3, UITheme.Colors.Ink, true)
	UITheme.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), Parent = pill })
	UITheme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = pill,
	})
	local keyBox = UITheme.new("Frame", {
		Name = "Key",
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = UITheme.Colors.Yellow,
		LayoutOrder = 1,
		Parent = pill,
	})
	UITheme.corner(keyBox, 3)
	UITheme.stroke(keyBox, 2, UITheme.Colors.Ink, true)
	UITheme.bevel(keyBox, 0.78, 0.75)
	local keyLabel = UITheme.label({ Text = "E", Size = UDim2.fromScale(0.62, 0.62), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), TextColor3 = UITheme.Colors.Ink, Stroke = false, Parent = keyBox })
	local tagLabel = UITheme.label({
		Name = "Text",
		Text = "",
		Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 14,
		TextColor3 = UITheme.Colors.White,
		LayoutOrder = 2,
		Stroke = 2,
		Parent = pill,
	})
	local tagScale = UITheme.new("UIScale", { Parent = pill })

	-- bandeau des commandes (touches en jaune)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ControlsHint"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player.PlayerGui
	local barBg = UITheme.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UITheme.Colors.PanelDark,
		BackgroundTransparency = 0.35,
		Parent = gui,
	})
	UITheme.corner(barBg, 4)
	local bs = UITheme.stroke(barBg, 2, UITheme.Colors.Ink, true)
	bs.Transparency = 0.3
	UITheme.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = barBg })
	local bar = UITheme.label({
		Name = "Text",
		Body = true,
		RichText = true,
		TextScaled = false,
		TextSize = 15,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = UITheme.Colors.White,
		Stroke = 1.5,
		Parent = barBg,
	})
	local barScale = UITheme.new("UIScale", { Parent = barBg })
	local function rescale()
		local cam = workspace.CurrentCamera
		local w = cam and cam.ViewportSize.X or 1200
		barScale.Scale = math.clamp(w / 1100, 0.6, 1.2)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	local lastBest
	task.spawn(function()
		while true do
			task.wait(0.15)
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local held = c and c:GetAttribute("HeldItem")
			local touch = isTouch()
			if held then
				bar.Text = touch and chips({ { "HIT", "swing" }, { "THROW", "throw it" }, { "GRAB", "drop" } })
					or chips({ { "CLICK", "swing" }, { "R", "throw" }, { "E", "drop" } })
			else
				bar.Text = touch and chips({ { "HIT", "punch" }, { "GRAB", "pick up anything!" } })
					or chips({ { "CLICK", "punch" }, { "E", "pick up anything!" }, { "W W", "run" }, { "SHIFT", "lock aim" } })
			end
			-- objet le plus proche
			local best, bestDist = nil, CombatConfig.PickupRange
			if root and not held then
				for _, m in ipairs(workspace.ActiveItems:GetChildren()) do
					local h = m.PrimaryPart
					if h then
						local d = (h.Position - root.Position).Magnitude
						if d < bestDist then
							best, bestDist = m, d
						end
					end
				end
			end
			if best then
				local cfg = ItemsConfig[best:GetAttribute("ItemId") or ""]
				tag.Adornee = best.PrimaryPart
				keyLabel.Text = touch and "+" or "E"
				tagLabel.Text = (touch and "GRAB " or "PICK UP ") .. string.upper(cfg and cfg.DisplayName or best.Name) .. "!"
				if best ~= lastBest then
					lastBest = best
					tagScale.Scale = 0.5
					UITheme.tween(tagScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
				end
				tag.Enabled = true
			else
				tag.Enabled = false
				lastBest = nil
			end
		end
	end)
end

return HintController
