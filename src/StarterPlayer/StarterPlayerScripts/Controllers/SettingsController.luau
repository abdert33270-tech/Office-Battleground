--[[
	SettingsController — panneau SETTINGS (bouton du dock), construit depuis ClientSettings.SCHEMA (groupé par Section).
	Contrôles : toggle (ON/OFF), slider (glisser, valeur appliquée au relâchement ; boutons - / + pour la manette),
	choice (boutons). Tous les boutons sont Selectable (navigation manette : GamepadController).
	Applique lui-même :
		SFXVolume      -> SoundService SoundGroup "SFX" (créé côté client s'il manque ; CartoonFX le crée aussi).
		AmbienceVolume -> SoundService SoundGroup "Ambience" (boucles d'AmbienceController).
			Volume du groupe = valeur du réglage. (Pas de MusicVolume : aucune musique dans le jeu.)
		AutoShiftLock  -> active le shift-lock (ShiftLockController) à chaque apparition.
		ShowHints      -> PlayerGui.ControlsHint (bandeau des commandes de HintController) visible ou non.
		UIScale (0.8-1.2) -> taille de l'interface, en direct, SANS toucher au code des autres contrôleurs :
			chaque cadre racine (enfant direct) de chaque ScreenGui du PlayerGui reçoit l'échelle via la convention
			UIScale déjà utilisée par UITheme.pop/open/close : un UIScale « AutoScale » ou « PopScale » dont l'attribut
			Base est l'échelle de repos.
			- cadre avec AutoScale/PopScale : on l'adopte ; Base = base du propriétaire (gardée dans l'attribut
			  RawBase) x réglage. Si le propriétaire réécrit Base (changement de taille d'écran), on remultiplie.
			- cadre sans UIScale : on crée un « PopScale » (attribut UserScaleOwned) => UITheme.pop le réutilise.
			- cadre avec un AUTRE UIScale (animation maison) : laissé tel quel (un seul UIScale par objet).
			Ignorés : cadres plein écran (voiles, conteneurs), ScreenGui avec l'attribut NoUserScale, et
			TouchGui / MobileControls / RunButton / ShiftLock (boutons tactiles placés au pixel près, MobileController).
			Les autres contrôleurs peuvent lire SettingsController.uiScale() (ou ClientSettings.get("UIScale")).
		HideHUD -> désactive (Enabled = false) les ScreenGui HUD, MetaDock, ControlsHint, GuardMeter, GamepadHints ;
			un petit bouton « SHOW HUD » (ScreenGui HUDHiddenTab) reste en haut à gauche pour revenir.
			Les panneaux (Meta, CharacterSelect...) et les commandes tactiles restent.
	Les autres clés (ScreenShake, FOVKick, ComicWords, DamageNumbers, ReducedFlashes, Quality, UltCinematics)
	sont lues par les autres systèmes via ClientSettings.get / ClientSettings.Changed.
	API : SettingsController.group(name) -> SoundGroup (trouvé ou créé), SettingsController.uiScale() -> number
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
-- Volumes (SoundGroups)
------------------------------------------------------------------------
local VOLUME_GROUPS = { SFXVolume = "SFX", AmbienceVolume = "Ambience" }
local DEFAULTS = ClientSettings.DEFAULTS

local function groupVolume(key, value)
	return math.clamp(tonumber(value) or tonumber(DEFAULTS[key]) or 1, 0, 1)
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

-- SoundGroup name (créé tout de suite s'il manque, volume = réglage)
function SettingsController.group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not g or not g:IsA("SoundGroup") then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	for key, n in pairs(VOLUME_GROUPS) do
		if n == name then
			g.Volume = groupVolume(key, ClientSettings.get(key))
		end
	end
	return g
end

local function ensureGroups()
	for key, name in pairs(VOLUME_GROUPS) do
		-- "SFX" peut arriver d'ailleurs (CartoonFX) : on lui laisse 3 s avant d'en créer un
		if name == "SFX" and not SoundService:FindFirstChild(name) then
			SoundService:WaitForChild(name, 3)
		end
		SettingsController.group(name)
		applyVolume(key, ClientSettings.get(key))
	end
end

------------------------------------------------------------------------
-- Taille de l'interface (UIScale)
------------------------------------------------------------------------
local USER_SKIP_GUIS = { TouchGui = true, MobileControls = true, RunButton = true, ShiftLock = true }
local userScale = 1
local adopted = setmetatable({}, { __mode = "k" }) -- [UIScale] = true

function SettingsController.uiScale(): number
	return userScale
end

local function isFullScreen(obj: GuiObject): boolean
	local s = obj.Size
	return s.X.Scale >= 0.95 and s.Y.Scale >= 0.95
end

-- applique userScale à un UIScale adopté (Base = RawBase x réglage ; Scale suit en proportion)
local function refreshScale(s: UIScale)
	local raw = tonumber(s:GetAttribute("RawBase")) or 1
	local old = tonumber(s:GetAttribute("Base")) or raw
	local eff = raw * userScale
	s:SetAttribute("UserBase", eff)
	s:SetAttribute("Base", eff)
	if old > 0 then
		s.Scale = s.Scale * (eff / old)
	else
		s.Scale = eff
	end
end

local function adopt(s: UIScale)
	if adopted[s] then
		return
	end
	adopted[s] = true
	s:SetAttribute("RawBase", tonumber(s:GetAttribute("Base")) or 1)
	refreshScale(s)
	-- le propriétaire réécrit Base (taille d'écran) puis Scale = Base : on remultiplie juste après
	s:GetAttributeChangedSignal("Base"):Connect(function()
		local b = tonumber(s:GetAttribute("Base"))
		if not b or b == s:GetAttribute("UserBase") then
			return
		end
		s:SetAttribute("RawBase", b)
		local eff = b * userScale
		s:SetAttribute("UserBase", eff)
		s:SetAttribute("Base", eff)
		task.defer(function()
			if s.Parent and math.abs(s.Scale - b) < 1e-3 then
				s.Scale = eff
			end
		end)
	end)
end

local function scaleRoot(obj)
	if not obj:IsA("GuiObject") or isFullScreen(obj) then
		return
	end
	local s = obj:FindFirstChild("AutoScale") or obj:FindFirstChild("PopScale")
	if s and s:IsA("UIScale") then
		adopt(s)
		return
	end
	if obj:FindFirstChildOfClass("UIScale") then
		return -- UIScale d'animation maison : on ne superpose pas un 2e UIScale
	end
	if userScale == 1 then
		return -- rien à faire tant que le réglage est à 100 % (pas d'objet ajouté inutilement)
	end
	s = Instance.new("UIScale")
	s.Name = "PopScale"
	s:SetAttribute("Base", 1)
	s:SetAttribute("UserScaleOwned", true)
	s.Parent = obj
	adopt(s)
end

local function watchRoot(obj)
	if not obj:IsA("GuiObject") then
		return
	end
	-- un UIScale ajouté plus tard par le propriétaire : on lui cède la place
	obj.ChildAdded:Connect(function(c)
		if not c:IsA("UIScale") then
			return
		end
		task.defer(function()
			for _, other in ipairs(obj:GetChildren()) do
				if other ~= c and other:IsA("UIScale") and other:GetAttribute("UserScaleOwned") then
					other:Destroy()
				end
			end
			if c.Name == "AutoScale" or c.Name == "PopScale" then
				adopt(c)
			end
		end)
	end)
	scaleRoot(obj)
end

local function watchGui(gui)
	if not gui:IsA("ScreenGui") or USER_SKIP_GUIS[gui.Name] or gui:GetAttribute("NoUserScale") then
		return
	end
	for _, c in ipairs(gui:GetChildren()) do
		watchRoot(c)
	end
	gui.ChildAdded:Connect(function(c)
		-- laisse le propriétaire finir de construire le cadre (AutoScale, taille...)
		task.delay(0.3, function()
			if c.Parent == gui then
				watchRoot(c)
			end
		end)
	end)
end

local function applyUIScale(value)
	userScale = math.clamp(tonumber(value) or 1, 0.8, 1.2)
	for s in pairs(adopted) do
		if s.Parent then
			refreshScale(s)
		end
	end
	-- cadres pas encore équipés (réglage passé de 100 % à autre chose)
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		for _, gui in ipairs(pg:GetChildren()) do
			if gui:IsA("ScreenGui") and not USER_SKIP_GUIS[gui.Name] and not gui:GetAttribute("NoUserScale") then
				for _, c in ipairs(gui:GetChildren()) do
					scaleRoot(c)
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Cacher le HUD
------------------------------------------------------------------------
local HUD_GUIS = { "HUD", "MetaDock", "ControlsHint", "GuardMeter", "GamepadHints" }
local hidden = false
local hiddenWanted = {} -- [ScreenGui] = Enabled voulu par son propriétaire pendant qu'on le cache
local hiddenConns = {}
local showTab

local function applyHints(on)
	local pg = player:FindFirstChild("PlayerGui")
	local g = pg and pg:FindFirstChild("ControlsHint")
	if g and g:IsA("ScreenGui") then
		if hidden then
			hiddenWanted[g] = on ~= false
		else
			g.Enabled = on ~= false
		end
	end
end

local function hideGui(g)
	if hiddenConns[g] then
		return
	end
	hiddenWanted[g] = g.Enabled
	g.Enabled = false
	hiddenConns[g] = g:GetPropertyChangedSignal("Enabled"):Connect(function()
		if hidden and g.Enabled then
			hiddenWanted[g] = true
			g.Enabled = false
		end
	end)
end

local function ensureShowTab()
	if showTab then
		return showTab
	end
	local gui = UIKit.screen("HUDHiddenTab", 9)
	gui.Enabled = false
	local b = UIKit.button({
		Name = "ShowHUD",
		Text = "SHOW HUD",
		Color = TEAL,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.fromOffset(120, 34),
		BackgroundTransparency = 0.25,
		Parent = gui,
	})
	b.Activated:Connect(function()
		ClientSettings.set("HideHUD", false)
	end)
	showTab = gui
	return gui
end

local function applyHideHUD(on)
	hidden = on == true
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	if hidden then
		for _, n in ipairs(HUD_GUIS) do
			local g = pg:FindFirstChild(n)
			if g and g:IsA("ScreenGui") then
				hideGui(g)
			end
		end
	else
		for g, conn in pairs(hiddenConns) do
			conn:Disconnect()
			if g.Parent then
				g.Enabled = hiddenWanted[g] ~= false
			end
		end
		table.clear(hiddenConns)
		table.clear(hiddenWanted)
		applyHints(ClientSettings.get("ShowHints"))
	end
	ensureShowTab().Enabled = hidden
end

function SettingsController.isHUDHidden(): boolean
	return hidden
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
	elseif key == "UIScale" then
		applyUIScale(value)
	elseif key == "HideHUD" then
		applyHideHUD(value)
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
	local b = UIKit.button({ Text = "ON", Color = ON, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(92, 34), ZIndex = 23, Selectable = true, Parent = r })
	local function show(v)
		b.Label.Text = v and "ON" or "OFF"
		b.BackgroundColor3 = v and ON or OFF
	end
	b.Activated:Connect(function()
		ClientSettings.set(s.Key, not ClientSettings.get(s.Key))
	end)
	return show
end

-- slider : [-] ====o==== [+]  100 %   (la valeur affichée = valeur x 100 : 0-100 % ou 80-120 %)
local function sliderControl(r, s)
	local track = UIKit.new("Frame", { Name = "Track", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0), Size = UDim2.new(0.5, -150, 0, 14), BackgroundColor3 = UIKit.Colors.Slot, Active = true, Selectable = false, ZIndex = 23, Parent = r })
	UIKit.corner(track, UDim.new(0.5, 0))
	UIKit.stroke(track, 2, UIKit.Black, true)
	local fill = UIKit.new("Frame", { Name = "Fill", BackgroundColor3 = TEAL, Size = UDim2.fromScale(0.5, 1), ZIndex = 24, Parent = track })
	UIKit.corner(fill, UDim.new(0.5, 0))
	local knob = UIKit.new("Frame", { Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = UIKit.Colors.Paper, ZIndex = 25, Parent = track })
	UIKit.corner(knob, UDim.new(0.5, 0))
	UIKit.stroke(knob, 2, UIKit.Black, true)
	local val = UIKit.label({ Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(56, 16), TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2, ZIndex = 23 })
	val.Parent = r
	local minus = UIKit.button({ Name = "Minus", Text = "-", Color = OFF, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.5, 42, 0.5, 0), Size = UDim2.fromOffset(28, 28), ZIndex = 23, Selectable = true, Parent = r })
	local plus = UIKit.button({ Name = "Plus", Text = "+", Color = OFF, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -70, 0.5, 0), Size = UDim2.fromOffset(28, 28), ZIndex = 23, Selectable = true, Parent = r })
	local range = s.Max - s.Min
	local step = s.Step or 0.05
	local function show(v)
		local a = range > 0 and math.clamp((v - s.Min) / range, 0, 1) or 0
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		val.Text = math.floor(v * 100 + 0.5) .. "%"
	end
	local function snap(v)
		return math.clamp(s.Min + math.floor((v - s.Min) / step + 0.5) * step, s.Min, s.Max)
	end
	local dragging, current = false, nil
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		return snap(s.Min + a * range)
	end
	local function preview(v)
		current = v
		show(v)
		apply(s.Key, v) -- aperçu immédiat (volume...) ; envoyé au serveur au relâchement
	end
	local function nudge(dir)
		local v = snap((tonumber(ClientSettings.get(s.Key)) or s.Default) + dir * step)
		ClientSettings.set(s.Key, v)
		show(ClientSettings.get(s.Key))
	end
	minus.Activated:Connect(function()
		nudge(-1)
	end)
	plus.Activated:Connect(function()
		nudge(1)
	end)
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
				-- UIScale : on n'applique qu'au relâchement (sinon le panneau grossit sous le doigt pendant le glissé)
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
		local b = UIKit.button({ Text = string.upper(opt), Color = OFF, Size = UDim2.fromOffset(78, 34), LayoutOrder = i, ZIndex = 23, Selectable = true, Parent = holder })
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
		Selectable = false, -- manette : la sélection va directement aux boutons (le cadre défile pour les suivre)
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
	local reset = UIKit.button({ Name = "Reset", Text = "RESET DEFAULTS", Color = Color3.fromRGB(240, 120, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(240, 44), ZIndex = 22, Selectable = true, Parent = body })
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

	-- taille de l'interface : tous les ScreenGui du PlayerGui, présents et à venir
	local pg = player:WaitForChild("PlayerGui")
	userScale = math.clamp(tonumber(ClientSettings.get("UIScale")) or 1, 0.8, 1.2)
	for _, g in ipairs(pg:GetChildren()) do
		watchGui(g)
	end
	pg.ChildAdded:Connect(function(g)
		task.defer(function()
			if g.Parent == pg then
				watchGui(g)
			end
			-- HUD caché : un ScreenGui du HUD (re)créé plus tard est caché lui aussi
			if hidden and g:IsA("ScreenGui") and table.find(HUD_GUIS, g.Name) then
				hideGui(g)
			end
		end)
	end)
	if ClientSettings.get("HideHUD") then
		applyHideHUD(true)
	end

	-- bandeau des commandes : créé par HintController (peut arriver après nous)
	task.spawn(function()
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
