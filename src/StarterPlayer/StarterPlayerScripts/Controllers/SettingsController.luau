--[[
	SettingsController — panneau SETTINGS (bouton du dock), construit depuis ClientSettings.SCHEMA (groupé par Section).
	Contrôles : toggle (ON/OFF), slider (glisser, valeur appliquée au relâchement), choice (boutons).
	Applique lui-même :
		MusicVolume / SFXVolume -> SoundService SoundGroups "Music" / "SFX" (créés côté client s'ils manquent).
			Volume du groupe = valeur / défaut du schéma (défaut = volume d'origine des sons, max = 1 / défaut).
		AutoShiftLock -> active le shift-lock (ShiftLockController) à chaque apparition.
		ShowHints     -> PlayerGui.ControlsHint (bandeau des commandes de HintController) visible ou non.
	Les autres clés (ScreenShake, FOVKick, ComicWords, DamageNumbers, ReducedFlashes, Quality, UltCinematics)
	sont lues par les autres systèmes via ClientSettings.get / ClientSettings.Changed.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)
local ClientSettings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("ClientSettings"))

local SettingsController = {}
SettingsController.Priority = 57

local player = Players.LocalPlayer
local TEAL = Color3.fromRGB(80, 190, 220)
local ON = Color3.fromRGB(70, 200, 90)
local OFF = Color3.fromRGB(110, 110, 130)

local panel
local refreshers = {} -- [key] = function(value)
local ctxRef

------------------------------------------------------------------------
-- Application des réglages
------------------------------------------------------------------------
local VOLUME_GROUPS = { MusicVolume = "Music", SFXVolume = "SFX" }
local DEFAULTS = ClientSettings.DEFAULTS

local function groupVolume(key, value)
	local def = tonumber(DEFAULTS[key]) or 1
	if def <= 0 then
		def = 1
	end
	return math.clamp((tonumber(value) or def) / def, 0, 10)
end

local function applyVolume(key, value)
	local name = VOLUME_GROUPS[key]
	if not name then
		return
	end
	local v = groupVolume(key, value)
	for _, g in ipairs(SoundService:GetChildren()) do
		if g:IsA("SoundGroup") and g.Name == name then
			g.Volume = v
		end
	end
end

local function ensureGroups()
	for key, name in pairs(VOLUME_GROUPS) do
		local g = SoundService:FindFirstChild(name) or SoundService:WaitForChild(name, 3)
		if not g then
			g = Instance.new("SoundGroup")
			g.Name = name
			g.Parent = SoundService
		end
		applyVolume(key, ClientSettings.get(key))
	end
	-- groupe ajouté plus tard (serveur ou autre script) : on lui applique tout de suite le réglage
	SoundService.ChildAdded:Connect(function(c)
		if c:IsA("SoundGroup") then
			for key, name in pairs(VOLUME_GROUPS) do
				if c.Name == name then
					applyVolume(key, ClientSettings.get(key))
				end
			end
		end
	end)
end

local function applyHints(on)
	local pg = player:FindFirstChild("PlayerGui")
	local g = pg and pg:FindFirstChild("ControlsHint")
	if g and g:IsA("ScreenGui") then
		g.Enabled = on ~= false
	end
end

local function applyShiftLockOnSpawn()
	if not ClientSettings.get("AutoShiftLock") then
		return
	end
	local sl = ctxRef and ctxRef.ShiftLockController
	if sl and sl.set and sl.isEnabled and not sl.isEnabled() then
		pcall(sl.set, true)
	end
end

local function apply(key, value)
	if VOLUME_GROUPS[key] then
		applyVolume(key, value)
	elseif key == "ShowHints" then
		applyHints(value)
	end
end

------------------------------------------------------------------------
-- Contrôles
------------------------------------------------------------------------
local function row(parent, order, label)
	local r = UIKit.new("Frame", { Name = "Row", BackgroundColor3 = UIKit.Colors.PanelDark, BackgroundTransparency = 0.3, Size = UDim2.new(1, -8, 0, 44), LayoutOrder = order, ZIndex = 22, Parent = parent })
	UIKit.corner(r, UDim.new(0, 5))
	local l = UIKit.label({ Text = label, Font = UIKit.Body, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.new(0.45, -12, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5, ZIndex = 23 })
	l.Parent = r
	return r
end

local function toggleControl(r, s)
	local b = UIKit.button({ Text = "ON", Color = ON, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(92, 34), ZIndex = 23, Parent = r })
	local function show(v)
		b.Label.Text = v and "ON" or "OFF"
		b.BackgroundColor3 = v and ON or OFF
	end
	b.Activated:Connect(function()
		ClientSettings.set(s.Key, not ClientSettings.get(s.Key))
	end)
	return show
end

local function sliderControl(r, s)
	local track = UIKit.new("Frame", { Name = "Track", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -74, 0.5, 0), Size = UDim2.new(0.5, -84, 0, 14), BackgroundColor3 = UIKit.Colors.Slot, Active = true, ZIndex = 23, Parent = r })
	UIKit.corner(track, UDim.new(0.5, 0))
	UIKit.stroke(track, 2, UIKit.Black, true)
	local fill = UIKit.new("Frame", { Name = "Fill", BackgroundColor3 = TEAL, Size = UDim2.fromScale(0.5, 1), ZIndex = 24, Parent = track })
	UIKit.corner(fill, UDim.new(0.5, 0))
	local knob = UIKit.new("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = UIKit.Colors.Paper, ZIndex = 25, Parent = track })
	UIKit.corner(knob, UDim.new(0.5, 0))
	UIKit.stroke(knob, 2, UIKit.Black, true)
	local val = UIKit.label({ Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(56, 16), TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2, ZIndex = 23 })
	val.Parent = r
	local range = s.Max - s.Min
	local function show(v)
		local a = range > 0 and math.clamp((v - s.Min) / range, 0, 1) or 0
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		val.Text = math.floor(a * 100 + 0.5) .. "%"
	end
	local dragging, current = false, nil
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local v = s.Min + a * range
		local step = s.Step or 0.05
		v = math.clamp(math.floor(v / step + 0.5) * step, s.Min, s.Max)
		return v
	end
	local function preview(v)
		current = v
		show(v)
		apply(s.Key, v) -- aperçu immédiat (volume...) ; envoyé au serveur au relâchement
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			preview(fromX(input.Position.X))
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			preview(fromX(input.Position.X))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			if current ~= nil then
				ClientSettings.set(s.Key, current)
				show(ClientSettings.get(s.Key))
				apply(s.Key, ClientSettings.get(s.Key))
			end
		end
	end)
	return function(v)
		if not dragging then
			show(v)
		end
	end
end

local function choiceControl(r, s)
	local holder = UIKit.new("Frame", { Name = "Choices", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.55, -10, 0, 34), BackgroundTransparency = 1, ZIndex = 23, Parent = r })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	local btns = {}
	for i, opt in ipairs(s.Options) do
		local b = UIKit.button({ Text = string.upper(opt), Color = OFF, Size = UDim2.fromOffset(78, 34), LayoutOrder = i, ZIndex = 23, Parent = holder })
		b.Activated:Connect(function()
			ClientSettings.set(s.Key, opt)
		end)
		btns[opt] = b
	end
	return function(v)
		for opt, b in pairs(btns) do
			b.BackgroundColor3 = (opt == v) and TEAL or OFF
		end
	end
end

local function build(dock)
	local p, body = dock.panel("SettingsPanel", "SETTINGS", TEAL, Vector2.new(560, 470), "Admin")
	panel = p
	local scroll = UIKit.new("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -54),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = UIKit.Colors.Muted,
		ZIndex = 22,
		Parent = body,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	local order, lastSection = 0, nil
	for _, s in ipairs(ClientSettings.SCHEMA) do
		if s.Section ~= lastSection then
			lastSection = s.Section
			order += 1
			local h = UIKit.label({ Text = string.upper(s.Section or "General"), Size = UDim2.new(1, -8, 0, 22), LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Colors.Yellow, Stroke = 2.5, ZIndex = 23 })
			h.Parent = scroll
		end
		order += 1
		local r = row(scroll, order, s.Label or s.Key)
		local refresh
		if s.Type == "toggle" then
			refresh = toggleControl(r, s)
		elseif s.Type == "slider" then
			refresh = sliderControl(r, s)
		elseif s.Type == "choice" then
			refresh = choiceControl(r, s)
		end
		if refresh then
			refreshers[s.Key] = refresh
			refresh(ClientSettings.get(s.Key))
		end
	end
	local reset = UIKit.button({ Name = "Reset", Text = "RESET DEFAULTS", Color = Color3.fromRGB(240, 120, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(240, 44), ZIndex = 22, Parent = body })
	reset.Activated:Connect(function()
		ClientSettings.resetAll()
	end)
end

function SettingsController.init(ctx)
	ctxRef = ctx
	local dock = ctx.MetaDockController
	if dock then
		build(dock)
		dock.addButton("Settings", "SETTINGS", TEAL, "Admin", function()
			dock.toggle(panel)
		end, 30)
	else
		warn("[Settings] MetaDockController manquant")
	end

	ClientSettings.Changed:Connect(function(key, value)
		apply(key, value)
		local r = refreshers[key]
		if r then
			r(value)
		end
	end)

	task.spawn(ensureGroups)
	-- bandeau des commandes : créé par HintController (peut arriver après nous)
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui")
		local g = pg:WaitForChild("ControlsHint", 30)
		if g then
			applyHints(ClientSettings.get("ShowHints"))
		end
	end)
	-- shift-lock à l'apparition (après le CharacterAdded de ShiftLockController qui remet son propre état)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		applyShiftLockOnSpawn()
	end)
	task.delay(3, function()
		if player.Character then
			applyShiftLockOnSpawn()
		end
	end)
end

return SettingsController
