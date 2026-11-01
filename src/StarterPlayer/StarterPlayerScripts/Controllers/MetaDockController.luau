--[[
	MetaDockController — colonne de boutons des méta-systèmes (DAILY, CODES, SETTINGS, AFK) + fabrique de panneaux.
	Ne touche pas au HUD : ses propres ScreenGui.
		"MetaDock" (DisplayOrder 4, sous le HUD : les menus du HUD passent par-dessus)
			PC : colonne en bas à gauche (zone libre : le menu du HUD est au milieu à gauche, les attaques au centre)
			Mobile : 3e colonne de tuiles juste à droite des tuiles du menu du HUD (le bas-gauche = joystick)
		"Meta" (DisplayOrder 7) : panneaux centrés (un seul ouvert à la fois), sous la sélection de perso (8).
	API :
		MetaDock.addButton(id, text, color, icon, callback, order) -> bouton
			icon = type d'icône UITheme ("Crate", "Admin"...) ou "glyph:Zz" (texte dessiné)
		MetaDock.setBadge(id, on, text?)   pastille rouge « ! » (ou text)
		MetaDock.setText(id, text) | MetaDock.setColor(id, color)
		MetaDock.panel(name, title, color, size, icon?) -> panel, body   (panel.Visible = false au départ)
		MetaDock.open(panel) | MetaDock.close(panel) | MetaDock.toggle(panel) | MetaDock.isOpen(panel)
	Chaque panneau contient un TextButton Modal : la souris est libérée même en shift-lock.
]]
local UIKit = require(script.Parent.UIKit)
local UITheme = UIKit.Theme

local MetaDock = {}
MetaDock.Priority = 45

local dockGui, panelGui, dock
local buttons = {}
local panels = {}
local touch = false
local ready = false

local TILE = 62
local PC_W, PC_H = 150, 42

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
		-- même échelle que les tuiles du menu du HUD (HUDController.buildMenu) ; on se place à leur droite
		dock.AnchorPoint = Vector2.new(0, 0.5)
		dock.Size = UDim2.fromOffset(TILE, 4 * TILE + 3 * 8)
		local s = UIKit.new("UIScale", { Name = "AutoScale", Parent = dock })
		local function upd()
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(844, 390)
			local v = math.clamp(math.min(vp.Y / 480, vp.X / 900), 0.8, 1.15)
			s:SetAttribute("Base", v)
			s.Scale = v
			dock.Position = UDim2.new(0, math.floor(14 + 146 * v), 0.5, 30)
		end
		upd()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(upd)
		end
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = dock })
	else
		dock.AnchorPoint = Vector2.new(0, 1)
		dock.Position = UDim2.new(0, 14, 1, -16)
		dock.Size = UDim2.fromOffset(PC_W + 8, 4 * PC_H + 3 * 6 + 8)
		UIKit.autoScale(dock)
		UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = dock })
	end
end

local function drawIcon(icon, holder, z)
	if type(icon) == "string" and string.sub(icon, 1, 6) == "glyph:" then
		local l = UIKit.label({ Name = "Glyph", Text = string.sub(icon, 7), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.8), Stroke = 2, ZIndex = z })
		l.Parent = holder
		return l
	end
	return UIKit.icon(icon or "Ult", holder, Color3.new(1, 1, 1), z)
end

function MetaDock.addButton(id: string, text: string, color: Color3, icon: string?, callback, order: number?)
	ensure()
	local b = UIKit.button({
		Name = id,
		Text = text,
		Color = color,
		Size = touch and UDim2.fromOffset(TILE, TILE) or UDim2.fromOffset(PC_W, PC_H),
		LayoutOrder = order or 50,
		Parent = dock,
	})
	local box = UIKit.new("Frame", { Name = "IconBox", BackgroundColor3 = UITheme.darken(color, 0.4), ZIndex = b.ZIndex + 1, Parent = b })
	UIKit.corner(box, UDim.new(0, 5))
	if touch then
		box.AnchorPoint = Vector2.new(0.5, 0)
		box.Position = UDim2.new(0.5, 0, 0, 6)
		box.Size = UDim2.fromOffset(32, 30)
		box.BackgroundTransparency = 1
		b.Label.Position = UDim2.new(0.5, 0, 1, -11)
		b.Label.Size = UDim2.new(1, -6, 0, 11)
	else
		UIKit.stroke(box, 2, UIKit.Black, true)
		box.AnchorPoint = Vector2.new(0, 0.5)
		box.Position = UDim2.new(0, 6, 0.46, 0)
		box.Size = UDim2.fromOffset(30, 30)
		b.Label.AnchorPoint = Vector2.new(0, 0.5)
		b.Label.Position = UDim2.new(0, 44, 0.45, 0)
		b.Label.Size = UDim2.new(1, -52, 0.4, 0)
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
	b.Activated:Connect(function()
		local ok, err = pcall(callback)
		if not ok then
			warn("[MetaDock] " .. id .. " : " .. tostring(err))
		end
	end)
	buttons[id] = { button = b, badge = badge, badgeText = bl, color = color, box = box }
	return b
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
		e.button.Label.Text = text
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
	-- souris libre même en shift-lock (ShiftLockController ne connaît pas ces panneaux)
	UIKit.new("TextButton", { Name = "ModalMouse", Modal = true, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), ZIndex = 20, Parent = f })
	local body = UIKit.new("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 1, -78), ZIndex = 21, Parent = f })
	table.insert(panels, f)
	return f, body
end

function MetaDock.isOpen(panel): boolean
	return panel ~= nil and panel.Visible
end

function MetaDock.open(panel)
	for _, p in ipairs(panels) do
		if p ~= panel and p.Visible then
			UIKit.close(p)
		end
	end
	UIKit.open(panel)
end

function MetaDock.close(panel)
	UIKit.close(panel)
end

function MetaDock.toggle(panel)
	if panel.Visible then
		MetaDock.close(panel)
	else
		MetaDock.open(panel)
	end
end

function MetaDock.init()
	ensure()
end

return MetaDock
