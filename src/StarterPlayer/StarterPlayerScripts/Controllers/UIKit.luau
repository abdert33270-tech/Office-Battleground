--[[
	UIKit — outils d'interface partagés par le HUD, la sélection, le mobile, l'admin.
	Délègue le style à ReplicatedStorage.Shared.Modules.UITheme (polices pixel, contours nets, boutons 3D).
	UIKit.Font / UIKit.Body restent utilisables partout : ils sont convertis en FontFace du thème
	(Display = Press Start 2P, Body = Silkscreen) par UIKit.new / UIKit.label et par le crochet de UIKit.screen.
	(Pas d'init : simple bibliothèque.)

	REGISTRE DES PANNEAUX (« un seul panneau ouvert ») :
		UIKit.registerPanel(obj, opts?) -> entrée   obj = GuiObject ; opts = { name, close = fn, noClose = bool }
			Dès que obj devient visible (quel que soit le code qui l'ouvre), tous les autres panneaux enregistrés se ferment.
			close = fermeture spéciale (ex. CharacterSelectController.close) ; noClose = jamais fermé par le registre
			(il ferme seulement les autres en s'ouvrant : boutique de caisses plein écran).
		UIKit.openPanel(obj) | UIKit.closePanel(obj) | UIKit.togglePanel(obj) | UIKit.closeAllPanels(except?)
		UIKit.anyPanelOpen() -> bool, nom   (ShiftLockController : souris libre)
		UIKit.isPanel(obj) -> bool
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UITheme"))

local UIKit = {}
UIKit.Theme = UITheme
UIKit.Font = Enum.Font.Arcade -- = Press Start 2P (converti en Bold)
UIKit.Body = Enum.Font.FredokaOne -- repère : converti en Silkscreen
UIKit.Black = UITheme.Colors.Ink
UIKit.White = Color3.new(1, 1, 1)
UIKit.Colors = UITheme.Colors
UIKit.Rarity = UITheme.Rarity

-- Enum.Font -> FontFace du thème
local function faceFor(v)
	if v == UIKit.Body or v == Enum.Font.FredokaOne or v == Enum.Font.Nunito then
		return UITheme.Body
	elseif v == UIKit.Font or v == Enum.Font.LuckiestGuy or v == Enum.Font.Bangers or v == Enum.Font.Arcade then
		return UITheme.Display
	end
	return nil
end
UIKit.faceFor = faceFor

function UIKit.new(class: string, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		elseif k == "Font" and faceFor(v) then
			inst.FontFace = faceFor(v)
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.corner(parent, radius)
	return UITheme.corner(parent, radius or UDim.new(0, 6))
end

-- contour : "Border" pour un cadre, "Contextual" pour un texte
function UIKit.stroke(parent, thickness, color, border)
	return UITheme.stroke(parent, thickness, color, border)
end

function UIKit.label(props)
	props = props or {}
	local p = {}
	for k, v in pairs(props) do
		if k == "Font" then
			local f = faceFor(v)
			if f then
				p.FontFace = f
			else
				p.Font = v
			end
		else
			p[k] = v
		end
	end
	return UITheme.label(p)
end

function UIKit.panel(props)
	return UITheme.panel(props)
end

-- bouton pixel : cadre coloré 3D + contour + texte contouré ; survol / appui / clic sonore
function UIKit.button(props)
	return UITheme.button(props)
end

function UIKit.tween(obj, time, props, style, dir)
	return UITheme.tween(obj, time, props, style, dir)
end

-- apparition « pop » (un seul UIScale par objet : si l'objet a déjà un AutoScale, on l'anime autour de sa base)
function UIKit.pop(obj, peak)
	return UITheme.pop(obj, peak)
end

function UIKit.screen(name: string, order: number?)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local gui = UIKit.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 0,
	})
	UITheme.hookFonts(gui)
	gui.Parent = pg
	return gui
end

-- échelle d'interface selon la taille d'écran (téléphone => plus petit, mais jamais illisible)
function UIKit.autoScale(frame: GuiObject, base: number?)
	local s = UIKit.new("UIScale", { Name = "AutoScale", Parent = frame })
	local function update()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1600, 900)
		local h = vp.Y
		-- en paysage étroit on tient aussi compte de la largeur
		local v = math.min(h / (base or 900), vp.X / ((base or 900) * 1.6))
		v = math.clamp(v, 0.6, 1.15)
		s:SetAttribute("Base", v)
		s.Scale = v
	end
	update()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return s
end

-- vrai sur téléphone / tablette (test PC : attribut ReplicatedStorage.DebugTouch = true)
function UIKit.isTouch(): boolean
	if ReplicatedStorage:GetAttribute("DebugTouch") == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- transitions et icônes du thème
function UIKit.open(obj)
	return UITheme.open(obj)
end
function UIKit.close(obj)
	return UITheme.close(obj)
end
function UIKit.toggle(obj)
	return UITheme.toggle(obj)
end
function UIKit.icon(kind, parent, color, z)
	return UITheme.icon(kind, parent, color, z)
end

------------------------------------------------------------------------
-- Registre des panneaux : un seul ouvert à la fois (HUD + Meta + sélection de perso)
------------------------------------------------------------------------
local registry = {} -- liste de { obj, name, close, noClose }

local function entryOf(obj)
	for _, e in ipairs(registry) do
		if e.obj == obj then
			return e
		end
	end
	return nil
end

local function closeEntry(e)
	if e.noClose or not e.obj.Parent or not e.obj.Visible then
		return
	end
	if e.close then
		local ok, err = pcall(e.close)
		if not ok then
			warn("[UIKit] fermeture de " .. tostring(e.name) .. " : " .. tostring(err))
			e.obj.Visible = false
		end
	else
		UITheme.close(e.obj)
	end
end

function UIKit.closeAllPanels(except)
	for _, e in ipairs(registry) do
		if e.obj ~= except then
			closeEntry(e)
		end
	end
end

function UIKit.registerPanel(obj: GuiObject, opts)
	local old = entryOf(obj)
	if old then
		return old
	end
	opts = opts or {}
	local e = { obj = obj, name = opts.name or obj.Name, close = opts.close, noClose = opts.noClose == true }
	table.insert(registry, e)
	obj:GetPropertyChangedSignal("Visible"):Connect(function()
		if obj.Visible then
			UIKit.closeAllPanels(obj)
		end
	end)
	obj.Destroying:Connect(function()
		local i = table.find(registry, e)
		if i then
			table.remove(registry, i)
		end
	end)
	return e
end

function UIKit.isPanel(obj): boolean
	return entryOf(obj) ~= nil
end

function UIKit.openPanel(obj)
	if not entryOf(obj) then
		UIKit.registerPanel(obj)
	end
	UIKit.closeAllPanels(obj)
	return UITheme.open(obj)
end

function UIKit.closePanel(obj)
	local e = entryOf(obj)
	if e and e.close then
		closeEntry(e)
		return false
	end
	return UITheme.close(obj)
end

function UIKit.togglePanel(obj)
	if obj.Visible then
		return UIKit.closePanel(obj)
	end
	return UIKit.openPanel(obj)
end

function UIKit.anyPanelOpen(): (boolean, string?)
	for _, e in ipairs(registry) do
		if e.obj.Parent and e.obj.Visible then
			local g = e.obj:FindFirstAncestorWhichIsA("LayerCollector")
			if not g or g.Enabled then
				return true, e.name
			end
		end
	end
	return false, nil
end

function UIKit.fmtTime(sec: number): string
	sec = math.max(0, math.floor(sec + 0.5))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

function UIKit.pretty(id: string?): string
	if not id then
		return ""
	end
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

function UIKit.hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

-- durée longue : "2d 05:12:09" / "05:12:09"
function UIKit.fmtLong(sec: number): string
	sec = math.max(0, math.floor(sec))
	local d = sec // 86400
	local hms = string.format("%02d:%02d:%02d", (sec % 86400) // 3600, (sec % 3600) // 60, sec % 60)
	return d > 0 and (d .. "d " .. hms) or hms
end

function UIKit.escape(s: string): string
	s = string.gsub(tostring(s), "&", "&amp;")
	s = string.gsub(s, "<", "&lt;")
	s = string.gsub(s, ">", "&gt;")
	return s
end

return UIKit
