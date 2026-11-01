--[[
	GamepadController — parité manette : attaques 1/2/3, navigation des menus, aide à l'écran.
	Boutons déjà pris par CombatController / RunController (on n'y touche pas) :
		A saut (Roblox) · R2 frappe · L2 garde · B dash · X ramasser · Y lancer · L1 Overtime / ultime · L3 course.
	Ajouts (ContextActionService, priorité High = 3000 > Default de CombatController) :
		Croix gauche / bas / droite -> ctx.CombatController.ability(1 / 2 / 3)   (croix haut = carte des commandes de
		HintController : non liée ici)
		SELECT (ButtonSelect) -> entre / sort du mode menu :
			- un panneau est ouvert (registre UIKit, attribut MetaMenu, ou la sélection de perso) : sélection
			  (GuiService.SelectedObject) sur son premier bouton (en haut à gauche, hors « X » de fermeture) ;
			- sinon : premier bouton du dock (ScreenGui MetaDock ; à défaut HUD) => croix / stick pour naviguer, A pour
			  ouvrir ; le panneau ouvert reçoit alors la sélection tout seul ;
			- déjà en mode menu : ferme le panneau ouvert et rend la main au combat.
		B en mode menu : ferme le panneau (retour au dock) ; dans le dock : quitte le mode menu. Hors menu : DASH.
		En mode menu, X / Y / R2 / L1 / L2 (appui) sont avalés pour ne pas attaquer en naviguant (relâcher passe
		toujours : une garde tenue avant d'ouvrir le menu se relâche normalement).
	GuiService.AutoSelectGuiEnabled = false : SELECT est géré ici (sinon Roblox sélectionnerait n'importe quoi).
	Panneau qui s'ouvre tout seul (récompense, sélection de perso...) alors que la manette est la dernière entrée :
	sélection posée sur son premier bouton. Sélection sur un objet devenu invisible : effacée.
	Aide (ScreenGui « GamepadHints », coin bas-droit) : glyphes UserInputService:GetImageForKeyCode (Xbox / PS selon la
	manette ; repli texte), noms des attaques du perso (HUDController), liste « menu » en mode menu. Visible seulement
	si la dernière entrée est une manette et que le réglage ShowHints est actif (HideHUD : SettingsController la cache).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)
local ClientSettings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("ClientSettings"))

local Gamepad = {}
Gamepad.Priority = 62

local player = Players.LocalPlayer
local ctxRef
local HIGH = Enum.ContextActionPriority.High.Value
local KC = Enum.KeyCode
local ABILITY_KEYS = { [KC.DPadLeft] = 1, [KC.DPadDown] = 2, [KC.DPadRight] = 3 } -- croix haut = carte des commandes (HintController)
local SKIP_NAMES = { Close = true, ModalMouse = true }

local hints -- { gui, root, combat, menu, attackLabels }
local lastPanel = nil

local function pgui()
	return player:FindFirstChild("PlayerGui")
end

local function isGamepadInput(t)
	return t == Enum.UserInputType.Gamepad1 or t == Enum.UserInputType.Gamepad2 or t == Enum.UserInputType.Gamepad3
		or t == Enum.UserInputType.Gamepad4
end

local function gamepadActive(): boolean
	return isGamepadInput(UserInputService:GetLastInputType())
end

local function inMenu(): boolean
	return GuiService.SelectedObject ~= nil
end

-- visible à l'écran : l'objet et tous ses ancêtres jusqu'au ScreenGui (activé)
local function shown(obj): boolean
	local o = obj
	while o and not o:IsA("LayerCollector") do
		if o:IsA("GuiObject") and not o.Visible then
			return false
		end
		o = o.Parent
	end
	return o ~= nil and o.Enabled
end

-- premier bouton sélectionnable (de haut en bas, puis de gauche à droite)
local function firstButton(container)
	if not container then
		return nil
	end
	local best, bestY, bestX = nil, math.huge, math.huge
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("GuiButton") then
			if d.Name == "ModalMouse" then
				d.Selectable = false -- bouton 1x1 qui libère la souris : jamais une cible de navigation
			elseif d.Selectable and not SKIP_NAMES[d.Name] and d.AbsoluteSize.X > 8 and d.AbsoluteSize.Y > 8 and shown(d) then
				local y = math.floor(d.AbsolutePosition.Y / 8)
				local x = d.AbsolutePosition.X
				if y < bestY or (y == bestY and x < bestX) then
					best, bestY, bestX = d, y, x
				end
			end
		end
	end
	return best
end

local function isPanelRoot(gui, root): boolean
	if root:GetAttribute("MetaMenu") then
		return true
	end
	if type(UIKit.isPanel) == "function" then
		local ok, yes = pcall(UIKit.isPanel, root)
		if ok and yes then
			return true
		end
	end
	return gui.Name == "CharacterSelect"
end

-- panneau ouvert (ScreenGui au DisplayOrder le plus haut d'abord) qui contient au moins un bouton
local function openPanel()
	local pg = pgui()
	if not pg then
		return nil
	end
	local guis = {}
	for _, g in ipairs(pg:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "GamepadHints" then
			table.insert(guis, g)
		end
	end
	table.sort(guis, function(a, b)
		return a.DisplayOrder > b.DisplayOrder
	end)
	for _, g in ipairs(guis) do
		for _, root in ipairs(g:GetChildren()) do
			if root:IsA("GuiObject") and root.Visible and isPanelRoot(g, root) and firstButton(root) then
				return root
			end
		end
	end
	return nil
end

local function dockButton()
	local pg = pgui()
	if not pg then
		return nil
	end
	for _, name in ipairs({ "MetaDock", "HUD", "HUDHiddenTab" }) do
		local g = pg:FindFirstChild(name)
		if g and g:IsA("ScreenGui") and g.Enabled then
			local b = firstButton(g)
			if b then
				return b
			end
		end
	end
	return nil
end

local function closePanel(p)
	local g = p and p:FindFirstAncestorWhichIsA("ScreenGui")
	if not p or (g and g.Name == "CharacterSelect") then
		return -- la sélection de perso gère sa propre fermeture (choix obligatoire à l'arrivée)
	end
	local dock = ctxRef and ctxRef.MetaDockController
	if p:GetAttribute("MetaMenu") and dock and type(dock.close) == "function" then
		pcall(dock.close, p)
	elseif type(UIKit.closePanel) == "function" then
		pcall(UIKit.closePanel, p)
	end
end

local function setSelected(obj)
	GuiService.SelectedObject = obj
end

local function toggleMenu()
	if inMenu() then
		local p = openPanel()
		if p and GuiService.SelectedObject:IsDescendantOf(p) then
			closePanel(p)
		end
		setSelected(nil)
		return
	end
	local p = openPanel()
	local target = (p and firstButton(p)) or dockButton()
	if target then
		setSelected(target)
	end
end

local function back()
	local so = GuiService.SelectedObject
	local p = openPanel()
	if p and so and so:IsDescendantOf(p) then
		closePanel(p)
		task.defer(function()
			if not shown(p) then
				setSelected(dockButton())
			end
		end)
	else
		setSelected(nil)
	end
end

------------------------------------------------------------------------
-- Aide à l'écran (glyphes)
------------------------------------------------------------------------
local FALLBACK = {
	[KC.DPadLeft] = "LEFT", [KC.DPadUp] = "UP", [KC.DPadRight] = "RIGHT", [KC.DPadDown] = "DOWN",
	[KC.ButtonA] = "A", [KC.ButtonB] = "B", [KC.ButtonX] = "X", [KC.ButtonY] = "Y",
	[KC.ButtonL1] = "L1", [KC.ButtonL2] = "L2", [KC.ButtonR1] = "R1", [KC.ButtonR2] = "R2",
	[KC.ButtonL3] = "L3", [KC.ButtonSelect] = "SEL", [KC.Thumbstick1] = "LS",
}

local function glyph(parent, kc)
	local ok, img = pcall(UserInputService.GetImageForKeyCode, UserInputService, kc)
	if ok and type(img) == "string" and img ~= "" then
		UIKit.new("ImageLabel", { Name = "Glyph", BackgroundTransparency = 1, Image = img, Size = UDim2.fromOffset(22, 22), ScaleType = Enum.ScaleType.Fit, LayoutOrder = 1, Parent = parent })
	else
		UIKit.Theme.keycap({ Name = "Glyph", Text = FALLBACK[kc] or kc.Name, Size = UDim2.fromOffset(34, 20), Parent = parent }).LayoutOrder = 1
	end
end

local function hintRow(list, order, kc, text)
	local r = UIKit.new("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromOffset(190, 22), LayoutOrder = order, Parent = list })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = r })
	glyph(r, kc)
	local l = UIKit.label({ Name = "Text", Text = text, Font = UIKit.Body, Size = UDim2.fromOffset(150, 15), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5, LayoutOrder = 2 })
	l.Parent = r
	return l
end

local function buildHints()
	local gui = UIKit.screen("GamepadHints", 5)
	local root = UIKit.new("Frame", {
		Name = "Hints",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(206, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UIKit.Colors.PanelDark,
		BackgroundTransparency = 0.35,
		Visible = false,
		Parent = gui,
	})
	UIKit.corner(root, UDim.new(0, 6))
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = root })
	local function list(name)
		local f = UIKit.new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = root })
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
		return f
	end
	local combat, menu = list("Combat"), list("Menu")
	local attackLabels = {
		hintRow(combat, 1, KC.DPadLeft, "Attack 1"),
		hintRow(combat, 2, KC.DPadDown, "Attack 2"),
		hintRow(combat, 3, KC.DPadRight, "Attack 3"),
	}
	hintRow(combat, 4, KC.ButtonR2, "Hit (hold = combo)")
	hintRow(combat, 5, KC.ButtonL2, "Block")
	hintRow(combat, 6, KC.ButtonB, "Dash")
	hintRow(combat, 7, KC.ButtonX, "Pick up / drop")
	hintRow(combat, 8, KC.ButtonY, "Throw")
	hintRow(combat, 9, KC.ButtonL1, "Overtime / ULT")
	hintRow(combat, 10, KC.ButtonSelect, "Menu")
	hintRow(menu, 1, KC.Thumbstick1, "Move selection")
	hintRow(menu, 2, KC.ButtonA, "Choose")
	hintRow(menu, 3, KC.ButtonB, "Back")
	hintRow(menu, 4, KC.ButtonSelect, "Close menu")
	menu.Visible = false
	hints = { gui = gui, root = root, combat = combat, menu = menu, attackLabels = attackLabels }
end

local function refreshHints()
	if not hints or not hints.gui.Parent then
		return
	end
	local show = gamepadActive() and ClientSettings.get("ShowHints") ~= false
	hints.root.Visible = show
	if not show then
		return
	end
	local m = inMenu()
	hints.combat.Visible = not m
	hints.menu.Visible = m
	if m then
		return
	end
	local hud = ctxRef and ctxRef.HUDController
	local kit
	if hud and type(hud.currentKit) == "function" then
		local ok, k = pcall(hud.currentKit)
		kit = ok and k or nil
	end
	local c = player.Character
	local list = kit and (c and c:GetAttribute("Transformed") and kit.TransAttacks or kit.Attacks) or {}
	for i, l in ipairs(hints.attackLabels) do
		local id = list[i]
		local name = id and hud and type(hud.attackName) == "function" and hud.attackName(id) or (id and UIKit.pretty(id)) or ("Attack " .. i)
		l.Text = i .. "  " .. tostring(name)
	end
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
local function bindAll()
	ContextActionService:BindActionAtPriority("OB_PadAbility", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if inMenu() then
			return Enum.ContextActionResult.Pass -- la croix navigue dans le menu
		end
		local i = input and ABILITY_KEYS[input.KeyCode]
		local combat = ctxRef and ctxRef.CombatController
		if i and combat and type(combat.ability) == "function" then
			local ok, err = pcall(combat.ability, i)
			if not ok then
				warn("[Gamepad] ability: " .. tostring(err))
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, HIGH, KC.DPadLeft, KC.DPadDown, KC.DPadRight)

	ContextActionService:BindActionAtPriority("OB_PadMenu", function(_, state)
		if state == Enum.UserInputState.Begin then
			toggleMenu()
		end
		return Enum.ContextActionResult.Sink
	end, false, HIGH, KC.ButtonSelect)

	ContextActionService:BindActionAtPriority("OB_PadBack", function(_, state)
		if state == Enum.UserInputState.Begin and inMenu() then
			back()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass -- hors menu : DASH (CombatController)
	end, false, HIGH, KC.ButtonB)

	ContextActionService:BindActionAtPriority("OB_PadMenuSink", function(_, state)
		if state == Enum.UserInputState.Begin and inMenu() then
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, HIGH, KC.ButtonX, KC.ButtonY, KC.ButtonR2, KC.ButtonL1, KC.ButtonL2)
end

function Gamepad.init(ctx)
	ctxRef = ctx
	pcall(function()
		GuiService.AutoSelectGuiEnabled = false
	end)
	bindAll()
	buildHints()
	UserInputService.LastInputTypeChanged:Connect(refreshHints)
	ClientSettings.Changed:Connect(function(key)
		if key == "ShowHints" then
			refreshHints()
		end
	end)
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(refreshHints)

	-- suivi des panneaux : sélection auto à l'ouverture (manette), nettoyage d'une sélection devenue invisible
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.2)
			tick += 1
			local so = GuiService.SelectedObject
			if so and (not so.Parent or not shown(so)) then
				setSelected(nil)
				so = nil
			end
			local p = openPanel()
			if p ~= lastPanel then
				lastPanel = p
				if p and gamepadActive() and not (so and so:IsDescendantOf(p)) then
					setSelected(firstButton(p))
				end
			end
			if tick % 5 == 0 then
				refreshHints()
			end
		end
	end)
end

return Gamepad
