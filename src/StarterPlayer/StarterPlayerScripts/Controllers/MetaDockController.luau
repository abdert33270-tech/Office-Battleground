--[[
	MetaDockController — LE dock unique du jeu (un seul dock, un seul panneau ouvert) + fabrique de panneaux.
	Tous les boutons de menu y vivent : CHARACTER / TASKS / SHOP / COMBOS (HUD.addMenuButton délègue ici),
	PLAYERS, RANKS, DAILY, CODES, SETTINGS, AFK, ADMIN.
		ScreenGui "MetaDock" (DisplayOrder 4, sous le HUD) :
			PC : colonne en bas à gauche (sous la carte de statut du HUD, à gauche des attaques).
			Mobile : grille de 2 RANGÉES de tuiles en haut à gauche, juste sous la carte de statut (le bas-gauche = joystick).
			Tuiles mobiles : libellé court (≤ 6 lettres, police Body, taille mini 14 px).
		ScreenGui "Meta" (DisplayOrder 7) : panneaux centrés, sous la sélection de perso (8).
	Un seul panneau ouvert : chaque panneau est inscrit dans le registre d'UIKit (UIKit.registerPanel) ;
	la sélection de perso (CharacterSelect.Root) y est aussi inscrite (fermée par CharacterSelectController.close).
	API :
		MetaDock.addButton(id, text, color, icon, callback, order) -> bouton (même id = bouton existant réutilisé)
			icon = type d'icône UITheme ("Crate", "Admin"...) ou "glyph:Zz" (texte dessiné)
			Ordre conseillé : 1-9 jeu (CHARACTER 2, TASKS 4, COMBOS 5, SHOP 6, PLAYERS 7, RANKS 8), 10-40 méta, 95 admin
		MetaDock.setBadge(id, on, text?)   pastille rouge « ! » (ou text)
		MetaDock.setText(id, text) | MetaDock.setColor(id, color) | MetaDock.button(id) -> bouton?
		MetaDock.panel(name, title, color, size, icon?) -> panel, body   (panel.Visible = false au départ)
		MetaDock.open(panel) | MetaDock.close(panel) | MetaDock.toggle(panel) | MetaDock.isOpen(panel) | MetaDock.closeAll()
	Panneau ouvert => souris libérée même en shift-lock (TextButton Modal + RenderStep après celui du shift-lock).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)
local UITheme = UIKit.Theme

local MetaDock = {}
MetaDock.Priority = 45

local dockGui, panelGui, dock, grid
local buttons = {}
local order = {} -- ids dans l'ordre d'ajout
local touch = false
local ready = false

local TILE, TILE_PAD = 72, 6
local PC_W, PC_H, PC_PAD = 150, 40, 5

-- libellés courts des tuiles mobiles (1er mot du texte -> libellé)
local TOUCH_TEXT = {
	CHARACTER = "JOBS", SETTINGS = "SETUP", COMBOS = "MOVES", PLAYERS = "LIST", LEADERBOARD = "RANKS", ADMIN = "ADMIN",
}
local function touchText(text: string): string
	local first = string.upper(string.match(text or "", "^(%S+)") or "")
	local t = TOUCH_TEXT[first] or first
	return string.sub(t, 1, 6)
end

local function layoutDock()
	if not dock then
		return
	end
	local n = #order
	if touch then
		local cols = math.max(1, math.ceil(n / 2))
		if grid then
			grid.FillDirectionMaxCells = cols
		end
		dock.Size = UDim2.fromOffset(cols * TILE + (cols - 1) * TILE_PAD, 2 * TILE + TILE_PAD)
	else
		dock.Size = UDim2.fromOffset(PC_W + 8, math.max(1, n) * (PC_H + PC_PAD) + 4)
	end
end

local function ensure()
	if ready then
		return
	end
	ready = true
	touch = UIKit.isTouch()
	dockGui = UIKit.screen("MetaDock", 4)
	panelGui = UIKit.screen("Meta", 7)
	MetaDock.gui = panelGui

	dock = UIKit.new("Frame", {
		Name = "Dock",
		BackgroundTransparency = 1,
		Parent = dockGui,
	})
	if touch then
		-- 2 rangées en haut à gauche, sous la carte de statut du HUD (même calcul d'échelle que UIKit.autoScale)
		dock.AnchorPoint = Vector2.new(0, 0)
		local s = UIKit.new("UIScale", { Name = "AutoScale", Parent = dock })
		local function upd()
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(844, 390)
			local v = math.clamp(math.min(vp.Y / 480, vp.X / 900), 0.8, 1.15)
			s:SetAttribute("Base", v)
			s.Scale = v
			-- bas de la carte de statut (62 + 148 px) + ruban de l'ultime (40 px), à l'échelle du HUD
			local hv = math.clamp(math.min(vp.Y / 900, vp.X / 1440), 0.6, 1.15)
			dock.Position = UDim2.fromOffset(14, math.floor(62 + 196 * hv + 8))
		end
		upd()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(upd)
		end
		grid = UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(TILE, TILE),
			CellPadding = UDim2.fromOffset(TILE_PAD, TILE_PAD),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = 1,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = dock,
		})
	else
		dock.AnchorPoint = Vector2.new(0, 1)
		dock.Position = UDim2.new(0, 14, 1, -16)
		UIKit.autoScale(dock)
		UIKit.new("UIListLayout", { Padding = UDim.new(0, PC_PAD), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = dock })
	end
	layoutDock()
end

local function drawIcon(icon, holder, z)
	if type(icon) == "string" and string.sub(icon, 1, 6) == "glyph:" then
		local l = UIKit.label({ Name = "Glyph", Text = string.sub(icon, 7), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.8), Stroke = 2, ZIndex = z })
		l.Parent = holder
		return l
	end
	return UIKit.icon(icon or "Ult", holder, UIKit.White, z)
end

function MetaDock.addButton(id: string, text: string, color: Color3, icon: string?, callback, layoutOrder: number?)
	ensure()
	local existing = buttons[id]
	if existing and existing.button.Parent then
		existing.callback = callback
		return existing.button
	end
	local b = UIKit.button({
		Name = id,
		Text = touch and touchText(text) or text,
		Color = color,
		Size = touch and UDim2.fromOffset(TILE, TILE) or UDim2.fromOffset(PC_W, PC_H),
		LayoutOrder = layoutOrder or 50,
		Parent = dock,
	})
	local box = UIKit.new("Frame", { Name = "IconBox", BackgroundColor3 = UITheme.darken(color, 0.4), ZIndex = b.ZIndex + 1, Parent = b })
	UIKit.corner(box, UDim.new(0, 5))
	if touch then
		box.AnchorPoint = Vector2.new(0.5, 0)
		box.Position = UDim2.new(0.5, 0, 0, 6)
		box.Size = UDim2.fromOffset(36, 34)
		box.BackgroundTransparency = 1
		-- libellé lisible au doigt : police Body, 14 px minimum
		b.Label.FontFace = UITheme.Body
		b.Label.AnchorPoint = Vector2.new(0.5, 1)
		b.Label.Position = UDim2.new(0.5, 0, 1, -5)
		b.Label.Size = UDim2.new(1, -4, 0, 18)
		UITheme.sizeLimit(b.Label, 18, 14)
	else
		UIKit.stroke(box, 2, UIKit.Black, true)
		box.AnchorPoint = Vector2.new(0, 0.5)
		box.Position = UDim2.new(0, 6, 0.46, 0)
		box.Size = UDim2.fromOffset(28, 28)
		b.Label.AnchorPoint = Vector2.new(0, 0.5)
		b.Label.Position = UDim2.new(0, 42, 0.45, 0)
		b.Label.Size = UDim2.new(1, -50, 0.4, 0)
		b.Label.TextXAlignment = Enum.TextXAlignment.Left
	end
	local inner = UIKit.new("Frame", { Name = "Inner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), BackgroundTransparency = 1, ZIndex = b.ZIndex + 2, Parent = box })
	drawIcon(icon, inner, b.ZIndex + 2)
	-- pastille de notification
	local badge = UIKit.new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = UIKit.Colors.Red,
		Visible = false,
		ZIndex = b.ZIndex + 5,
		Parent = b,
	})
	UIKit.corner(badge, UDim.new(0.5, 0))
	UIKit.stroke(badge, 2, UIKit.Black, true)
	local bl = UIKit.label({ Name = "Text", Text = "!", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6), Stroke = 1.5, ZIndex = b.ZIndex + 6 })
	bl.Parent = badge
	local e = { button = b, badge = badge, badgeText = bl, color = color, box = box, callback = callback }
	b.Activated:Connect(function()
		local ok, err = pcall(e.callback)
		if not ok then
			warn("[MetaDock] " .. id .. " : " .. tostring(err))
		end
	end)
	buttons[id] = e
	table.insert(order, id)
	b.Destroying:Connect(function()
		local i = table.find(order, id)
		if i then
			table.remove(order, i)
		end
		if buttons[id] == e then
			buttons[id] = nil
		end
		layoutDock()
	end)
	layoutDock()
	return b
end

function MetaDock.button(id: string)
	local e = buttons[id]
	return e and e.button or nil
end

function MetaDock.setBadge(id: string, on: boolean, text: string?)
	local e = buttons[id]
	if not e then
		return
	end
	local was = e.badge.Visible
	e.badge.Visible = on == true
	e.badgeText.Text = text or "!"
	if on and not was then
		UIKit.pop(e.badge, 1.4)
	end
end

function MetaDock.setText(id: string, text: string)
	local e = buttons[id]
	if e then
		e.button.Label.Text = touch and touchText(text) or text
	end
end

function MetaDock.setColor(id: string, color: Color3)
	local e = buttons[id]
	if e then
		e.button.BackgroundColor3 = color
		if not touch then
			e.box.BackgroundColor3 = UITheme.darken(color, 0.4)
		end
	end
end

function MetaDock.panel(name: string, title: string, color: Color3, size: Vector2, icon: string?)
	ensure()
	local f = UIKit.panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		Accent = color,
		ZIndex = 20,
		Parent = panelGui,
	})
	f:SetAttribute("MetaMenu", true)
	UIKit.autoScale(f)
	-- en-tête coloré
	local h = UIKit.new("Frame", { Name = "Header", BackgroundColor3 = color, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 46), ZIndex = 21, Parent = f })
	UIKit.corner(h, UDim.new(0, 5))
	UIKit.stroke(h, 3, UIKit.Black, true)
	UITheme.bevel(h, 0.74, 0.72)
	UITheme.shine(h, 21)
	local tx = 14
	if icon then
		local ib = UIKit.new("Frame", { Name = "IconBox", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.46, 0), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, ZIndex = 22, Parent = h })
		drawIcon(icon, ib, 22)
		tx = 48
	end
	local t = UIKit.label({ Name = "Title", Text = title, MaxText = 26, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, tx, 0.46, 0), Size = UDim2.new(1, -(tx + 64), 0.56, 0), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3, ZIndex = 22 })
	t.Parent = h
	local close = UIKit.button({ Name = "Close", Text = "X", Color = UIKit.Colors.Red, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(40, 38), ZIndex = 23, Parent = h })
	close.Activated:Connect(function()
		MetaDock.close(f)
	end)
	-- souris libre même en shift-lock
	UIKit.new("TextButton", { Name = "ModalMouse", Modal = true, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), ZIndex = 20, Parent = f })
	local body = UIKit.new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 1, -78), ZIndex = 21, Parent = f })
	UIKit.registerPanel(f, { name = name })
	return f, body
end

function MetaDock.isOpen(panel): boolean
	return panel ~= nil and panel.Visible
end

function MetaDock.open(panel)
	UIKit.openPanel(panel)
end

function MetaDock.close(panel)
	UIKit.closePanel(panel)
end

function MetaDock.toggle(panel)
	UIKit.togglePanel(panel)
end

function MetaDock.closeAll()
	UIKit.closeAllPanels()
end

-- inscrit un écran d'un autre contrôleur dans le registre dès qu'il existe (sans modifier ce contrôleur)
local function adopt(guiName: string, childName: string, opts)
	task.spawn(function()
		local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
		local function try(g)
			if g.Name ~= guiName then
				return
			end
			local f = g:WaitForChild(childName, 30)
			if f and f:IsA("GuiObject") then
				UIKit.registerPanel(f, opts)
			end
		end
		pg.ChildAdded:Connect(try) -- UIKit.screen recrée l'écran : on suit les nouvelles instances
		local g = pg:FindFirstChild(guiName)
		if g then
			try(g)
		end
	end)
end

function MetaDock.init(ctx)
	ensure()
	-- sélection de perso : fermée par son API (cache aussi le voile) ; la boutique de caisses plein écran est
	-- « passive » (s'ouvre par-dessus la sélection, jamais fermée par le registre : tirage en cours)
	adopt("CharacterSelect", "Root", {
		name = "CharacterSelect",
		close = function()
			local cs = ctx and ctx.CharacterSelectController
			if cs and cs.close then
				cs.close()
			end
		end,
	})
	adopt("CharacterSelect", "CrateShop", { name = "CrateShop", passive = true })
	-- panneau ouvert : souris libre (passe après le shift-lock maison, qui la bloque à chaque image)
	RunService:BindToRenderStep("OB_MetaMouse", Enum.RenderPriority.Camera.Value + 4, function()
		if UIKit.anyPanelOpen() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	end)
end

return MetaDock
