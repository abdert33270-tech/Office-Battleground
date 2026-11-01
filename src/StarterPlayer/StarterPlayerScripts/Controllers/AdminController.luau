--[[
	AdminController — panneau admin (F2 ou bouton ADMIN), visible seulement si l'attribut Player IsAdmin est vrai.
	Chaque bouton envoie une commande texte (ex. "/spawn Chair") à la remote "AdminCommand" ;
	le serveur (AdminService) revérifie TOUJOURS l'UserId.
	GIVE CASH : montant libre + boutons rapides (+1,000 / +10,000 / +100,000) -> "/cash <n>" (SkinService.addCash côté serveur).
	Téléphone : panneau plus court et cases plus hautes (cibles tactiles >= 44 px à l'écran).
	GIVE CHARACTER : choix du joueur (joueurs du serveur, moi par défaut) + grille de tous les persos (OWNED / prix)
	  + GIVE / REMOVE / GIVE ALL -> "/givechar <joueur> <perso|all>" / "/takechar ..." (UnlockService côté serveur).
	  AdminInfo { ownedUpdate = true, players, owned } ne rafraîchit que cette section.
	SERVER : SHUTDOWN (2e appui dans les 3 s pour confirmer) -> "/shutdown" (sauve tout puis expulse).
	  /kick <name> [reason] et /announce <text> : au chat (texte libre, filtré côté serveur).
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)

local Admin = {}
Admin.Priority = 80

local player = Players.LocalPlayer
local panel, content, hud
local built = false
local lastInfo = {}

local RED = Color3.fromRGB(235, 60, 50)
local CASH = Color3.fromRGB(60, 190, 85)
local TEAL = Color3.fromRGB(70, 200, 190)

-- configs partagées (couleurs des persos, paliers de déblocage)
local function cfg(name)
	local f = ReplicatedStorage:FindFirstChild("Shared")
	local m = f and f:FindFirstChild("Config") and f.Config:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, mod = pcall(require, m)
	return ok and mod or nil
end
local giveSel = { player = nil, char = nil }
local giveRefs = nil

local function remote(name)
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	return f and f:FindFirstChild(name)
end

local function run(cmd)
	local r = remote("AdminCommand")
	if r then
		r:FireServer(cmd)
	end
end

local function toast(text, color)
	if hud and hud.toast then
		hud.toast(text, color)
	end
end

local function fmt(n)
	local s = tostring(math.floor(math.abs(n)))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return (n < 0 and "-" or "") .. s .. out
end

local function cellHeight()
	return UIKit.isTouch() and 58 or 36
end

-- titre de section : pastille icône + texte + trait
local function sectionTitle(parent, title, icon, color, order)
	local row = UIKit.new("Frame", { Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order or 0, Parent = parent })
	local ib = UIKit.new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(0, 1), Parent = row })
	UIKit.corner(ib, UDim.new(0, 5))
	UIKit.stroke(ib, 2, UIKit.Black, true)
	UIKit.Theme.bevel(ib, 0.66, 0.72)
	local inner = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), BackgroundTransparency = 1, Parent = ib })
	UIKit.icon(icon, inner, Color3.new(1, 1, 1))
	local t = UIKit.label({ Text = title, Size = UDim2.new(1, -36, 0, 18), Position = UDim2.fromOffset(34, 5), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Theme.lighten(color, 0.35), Stroke = 2.5 })
	t.Parent = row
	local line = UIKit.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 34, 1, 0), Size = UDim2.new(1, -34, 0, 2), BackgroundColor3 = color, BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = row })
	UIKit.new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = line })
	return row
end

local function section(title, order, icon, color)
	local f = UIKit.new("Frame", {
		Name = "Section",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = content,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
	sectionTitle(f, title, icon or "Ult", color or UIKit.Colors.Yellow, 0)
	local grid = UIKit.new("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = f,
	})
	UIKit.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, cellHeight()), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	return grid, f
end

local function btn(grid, text, color, cmd)
	local b = UIKit.button({ Text = text, Color = color, TextSize = UDim2.fromScale(0.86, 0.4), Parent = grid })
	b.Activated:Connect(function()
		run(cmd)
	end)
	return b
end

-- GIVE CASH : montant + bouton GIVE, puis boutons rapides
local function buildCash(order)
	local f = UIKit.new("Frame", {
		Name = "GiveCash",
		BackgroundColor3 = Color3.fromRGB(26, 52, 36),
		BackgroundTransparency = 0.1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = content,
	})
	UIKit.corner(f, UDim.new(0, 6))
	UIKit.stroke(f, 3, UIKit.Black, true)
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(160, 170, 160)), Parent = f })
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), Parent = f })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
	sectionTitle(f, "GIVE CASH", "Cash", CASH, 0)
	local h = cellHeight()
	local row = UIKit.new("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), LayoutOrder = 1, Parent = f })
	local boxBg = UIKit.new("Frame", { Name = "AmountBg", BackgroundColor3 = Color3.fromRGB(14, 18, 24), Size = UDim2.new(0.66, -6, 1, 0), Parent = row })
	UIKit.corner(boxBg, UDim.new(0, 6))
	local bst = UIKit.stroke(boxBg, 3, UIKit.Black, true)
	local dollar = UIKit.label({ Text = "$", Size = UDim2.new(0, 22, 0.5, 0), Position = UDim2.new(0, 10, 0.25, 0), TextColor3 = UIKit.Colors.Cash, Stroke = 2 })
	dollar.Parent = boxBg
	local box = UIKit.new("TextBox", {
		Name = "Amount",
		PlaceholderText = "amount...",
		PlaceholderColor3 = Color3.fromRGB(120, 130, 125),
		Text = "",
		ClearTextOnFocus = false,
		Font = UIKit.Font,
		TextSize = UIKit.isTouch() and 20 or 16,
		TextColor3 = UIKit.Colors.Cash,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 36, 0, 0),
		Size = UDim2.new(1, -44, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = boxBg,
	})
	box.Focused:Connect(function()
		bst.Color = UIKit.Colors.Cash
	end)
	local give = UIKit.button({ Name = "Give", Text = "GIVE", Color = CASH, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.34, 0, 1, 0), TextSize = UDim2.fromScale(0.7, 0.42), Parent = row })
	local function send(n)
		n = math.floor(tonumber(n) or 0)
		if n == 0 then
			toast("Type an amount first (e.g. 2500)", Color3.fromRGB(255, 110, 90))
			return
		end
		n = math.clamp(n, -1e9, 1e9)
		run("/cash " .. n)
	end
	local function submit()
		local raw = string.gsub(box.Text, "[%s,%$]", "")
		local k = string.match(raw, "^(%d+%.?%d*)[kK]$")
		local mm = string.match(raw, "^(%d+%.?%d*)[mM]$")
		local n = k and tonumber(k) * 1000 or mm and tonumber(mm) * 1e6 or tonumber(raw)
		if not n then
			toast("Not a number: " .. box.Text, Color3.fromRGB(255, 110, 90))
			return
		end
		send(n)
		box.Text = ""
	end
	box.FocusLost:Connect(function(enter)
		bst.Color = UIKit.Black
		if enter and box.Text ~= "" then
			submit()
		end
	end)
	give.Activated:Connect(submit)
	local quick = UIKit.new("Frame", { Name = "Quick", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), LayoutOrder = 2, Parent = f })
	UIKit.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = quick })
	for i, amt in ipairs({ 1000, 10000, 100000 }) do
		local b = UIKit.button({ Name = "Q" .. amt, Text = "+" .. fmt(amt), Color = Color3.fromRGB(255, 200, 40), TextSize = UDim2.fromScale(0.86, 0.38), LayoutOrder = i, Parent = quick })
		b.Activated:Connect(function()
			send(amt)
		end)
	end
	local cur = UIKit.label({ Name = "Balance", Text = "", Font = UIKit.Body, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(190, 235, 195), Stroke = 1.5, LayoutOrder = 3 })
	cur.Parent = f
	local function refresh()
		cur.Text = "Balance: $" .. fmt(tonumber(player:GetAttribute("Cash")) or 0)
	end
	refresh()
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		if cur.Parent then
			refresh()
			UIKit.pop(cur, 1.15)
		end
	end)
end

-- GIVE CHARACTER : joueur + perso + GIVE / REMOVE / GIVE ALL
local function refreshGive()
	local r = giveRefs
	if not r or not r.frame.Parent then
		return
	end
	local players = lastInfo.players or {}
	if not giveSel.player or not table.find(players, giveSel.player) then
		giveSel.player = player.Name
	end
	-- boutons joueurs
	for _, c in ipairs(r.players:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local list = #players > 0 and players or { player.Name }
	for i, name in ipairs(list) do
		local on = name == giveSel.player
		local b = UIKit.button({
			Name = "P_" .. name,
			Text = (name == player.Name) and (name .. " (ME)") or name,
			Color = on and Color3.fromRGB(235, 160, 30) or Color3.fromRGB(80, 90, 130),
			TextColor3 = UIKit.White,
			Size = UDim2.new(0, math.clamp(#name * 9 + 70, 110, 220), 1, -6),
			TextSize = UDim2.fromScale(0.88, 0.4),
			LayoutOrder = i,
			Parent = r.players,
		})
		b.Activated:Connect(function()
			giveSel.player = name
			refreshGive()
		end)
	end
	local owned = (lastInfo.owned or {})[giveSel.player] or {}
	local Unlocks = cfg("Unlocks")
	local have, total = 0, 0
	for id, cell in pairs(r.cells) do
		total += 1
		local own = owned[id] == true
		if own then
			have += 1
		end
		local e = Unlocks and Unlocks.get(id) or { Tier = "Free" }
		local txt = own and (e.Tier == "Free" and "FREE" or "OWNED") or (Unlocks and Unlocks.priceText(id) or "?")
		cell.sub.Text = txt
		cell.sub.TextColor3 = own and Color3.fromRGB(150, 255, 150) or (e.Tier == "Robux" and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(255, 255, 255))
		cell.dim.Visible = not own
		local sel = giveSel.char == id
		cell.stroke.Color = sel and UIKit.Colors.Yellow or UIKit.Black
		cell.stroke.Thickness = sel and 4 or 3
	end
	local selName = giveSel.char and UIKit.pretty(giveSel.char) or "pick a character"
	r.status.Text = giveSel.player .. " owns " .. have .. "/" .. total .. "  -  selected: " .. selName
end

local function buildGiveChar(order)
	local f = UIKit.new("Frame", {
		Name = "GiveCharacter",
		BackgroundColor3 = Color3.fromRGB(22, 46, 52),
		BackgroundTransparency = 0.1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = content,
	})
	UIKit.corner(f, UDim.new(0, 6))
	UIKit.stroke(f, 3, UIKit.Black, true)
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(160, 170, 170)), Parent = f })
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), Parent = f })
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
	sectionTitle(f, "GIVE CHARACTER", "Person", TEAL, 0)
	local h = cellHeight()
	local function small(text, o)
		local l = UIKit.label({ Text = text, Font = UIKit.Body, Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(180, 235, 230), Stroke = 1.5, LayoutOrder = o })
		l.Parent = f
		return l
	end
	small("PLAYER", 1)
	local prow = UIKit.new("ScrollingFrame", {
		Name = "Players",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, h + 8),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		LayoutOrder = 2,
		Parent = f,
	})
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = prow })
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), Parent = prow })
	small("CHARACTER", 3)
	local grid = UIKit.new("Frame", { Name = "Chars", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = f })
	UIKit.new("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, h + 12), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local Characters = cfg("Characters") or {}
	local cells = {}
	for i, id in ipairs(lastInfo.characters or {}) do
		local kit = Characters[id]
		local nm = kit and kit.DisplayName and string.gsub(kit.DisplayName, "^The ", "") or UIKit.pretty(id)
		local b = UIKit.button({ Name = id, Text = string.upper(nm), Color = kit and kit.Color or TEAL, TextSize = UDim2.fromScale(0.9, 0.3), LayoutOrder = i, Parent = grid })
		b.Label.Position = UDim2.fromScale(0.5, 0.32)
		local dim = UIKit.new("Frame", { Name = "Locked", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.Black, BackgroundTransparency = 0.5, ZIndex = b.ZIndex, Active = false, Parent = b })
		UIKit.corner(dim, UDim.new(0, 6))
		local sub = UIKit.label({ Name = "Sub", Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.fromScale(0.86, 0.28), Stroke = 2, ZIndex = b.ZIndex + 2 })
		sub.Parent = b
		cells[id] = { btn = b, sub = sub, dim = dim, stroke = b:FindFirstChildOfClass("UIStroke") }
		b.Activated:Connect(function()
			giveSel.char = id
			refreshGive()
		end)
	end
	local brow = UIKit.new("Frame", { Name = "Actions", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), LayoutOrder = 5, Parent = f })
	UIKit.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = brow })
	local function action(name, text, color, o, fn)
		local b = UIKit.button({ Name = name, Text = text, Color = color, TextSize = UDim2.fromScale(0.86, 0.4), LayoutOrder = o, Parent = brow })
		b.Activated:Connect(fn)
		return b
	end
	local function target()
		return giveSel.player or player.Name
	end
	action("Give", "GIVE", CASH, 1, function()
		if not giveSel.char then
			return toast("Pick a character first", Color3.fromRGB(255, 110, 90))
		end
		run("/givechar " .. target() .. " " .. giveSel.char)
	end)
	action("Remove", "REMOVE", RED, 2, function()
		if not giveSel.char then
			return toast("Pick a character first", Color3.fromRGB(255, 110, 90))
		end
		run("/takechar " .. target() .. " " .. giveSel.char)
	end)
	action("GiveAll", "GIVE ALL", Color3.fromRGB(255, 190, 40), 3, function()
		run("/givechar " .. target() .. " all")
	end)
	local status = UIKit.label({ Name = "Status", Text = "", Font = UIKit.Body, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(190, 240, 235), Stroke = 1.5, LayoutOrder = 6 })
	status.Parent = f
	giveRefs = { frame = f, players = prow, cells = cells, status = status }
	refreshGive()
end

local function build(info)
	if type(info) == "table" and info.ownedUpdate then
		lastInfo.players = info.players or lastInfo.players
		lastInfo.owned = info.owned or lastInfo.owned
		refreshGive()
		return
	end
	lastInfo = info or {}
	for _, c in ipairs(content:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	buildCash(0)
	buildGiveChar(1)
	local quick = section("QUICK", 2, "Bolt", Color3.fromRGB(255, 170, 40))
	btn(quick, "GOD MODE", Color3.fromRGB(255, 200, 40), "/god")
	btn(quick, "FILL OVERTIME", Color3.fromRGB(255, 140, 30), "/overtime")
	btn(quick, "HEAL", Color3.fromRGB(110, 220, 110), "/heal")
	btn(quick, "RESPAWN DUMMY", Color3.fromRGB(150, 200, 255), "/dummy")
	btn(quick, "SKIP PHASE", Color3.fromRGB(200, 120, 255), "/skip")
	btn(quick, "COLLAPSE NOW", RED, "/collapse")
	btn(quick, "+500 XP", Color3.fromRGB(170, 110, 255), "/xp 500")
	btn(quick, "+100 XP", Color3.fromRGB(150, 120, 255), "/xp 100")
	btn(quick, "LEVEL 10", Color3.fromRGB(255, 220, 70), "/level 10")
	btn(quick, "+1 CRATE", Color3.fromRGB(90, 140, 255), "/crate 1")
	btn(quick, "ALL SKINS", Color3.fromRGB(255, 120, 200), "/allskins")

	local items = section("SPAWN ITEM", 3, "Crate", Color3.fromRGB(90, 140, 255))
	for _, id in ipairs(lastInfo.items or {}) do
		btn(items, UIKit.pretty(id), Color3.fromRGB(90, 140, 255), "/spawn " .. id)
	end
	local events = section("START EVENT", 4, "Ult", Color3.fromRGB(255, 170, 60))
	for _, name in ipairs(lastInfo.events or {}) do
		btn(events, UIKit.pretty(name), Color3.fromRGB(255, 170, 60), "/event " .. name)
	end
	local floors = section("COLLAPSE TO FLOOR", 5, "Slam", Color3.fromRGB(235, 90, 80))
	for _, name in ipairs(lastInfo.floors or {}) do
		btn(floors, UIKit.pretty(name), Color3.fromRGB(235, 90, 80), "/collapse " .. name)
	end
	local chars = section("CHARACTER", 6, "Person", Color3.fromRGB(110, 200, 160))
	for _, name in ipairs(lastInfo.characters or {}) do
		btn(chars, UIKit.pretty(name), Color3.fromRGB(110, 200, 160), "/char " .. name)
	end
	local grades = section("GRADE", 7, "Buff", Color3.fromRGB(170, 110, 255))
	for _, name in ipairs(lastInfo.grades or {}) do
		btn(grades, name, Color3.fromRGB(170, 110, 255), "/grade " .. name)
	end
	-- SERVER : arrêt propre, confirmation par un 2e appui (évite le clic accidentel)
	local server = section("SERVER", 8, "Slam", RED)
	local armedAt = -math.huge
	local shut = UIKit.button({ Text = "SHUTDOWN", Color = RED, TextSize = UDim2.fromScale(0.86, 0.4), Parent = server })
	shut.Activated:Connect(function()
		if os.clock() - armedAt <= 3 then
			armedAt = -math.huge
			run("/shutdown")
		else
			armedAt = os.clock()
			toast("Press SHUTDOWN again to save everyone and close the server", RED)
		end
	end)
	btn(server, "HELP", Color3.fromRGB(140, 220, 255), "/help")
end

local function toggle()
	if not panel then
		return
	end
	if UIKit.toggle(panel) then
		local r = remote("AdminInfo")
		if r then
			r:FireServer()
		end
	end
end

local function setup(ctx)
	if built then
		return
	end
	built = true
	hud = ctx.HUDController
	local touch = UIKit.isTouch()
	local gui = UIKit.screen("Admin", 20)
	panel = UIKit.panel({
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(470, touch and 480 or 600),
		Visible = false,
		Accent = RED,
		ZIndex = 1,
		Parent = gui,
	})
	if touch then
		-- téléphone : on garde des cases d'au moins ~44 px à l'écran
		local s = UIKit.new("UIScale", { Name = "AutoScale", Parent = panel })
		local function upd()
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(844, 390)
			local v = math.clamp(math.min(vp.Y * 0.96 / 480, vp.X * 0.9 / 470), 0.6, 1.1)
			s:SetAttribute("Base", v)
			s.Scale = v
		end
		upd()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(upd)
		end
	else
		UIKit.autoScale(panel)
	end
	-- bandeau titre
	local head = UIKit.new("Frame", { Name = "Header", BackgroundColor3 = RED, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 46), Parent = panel })
	UIKit.corner(head, UDim.new(0, 5))
	UIKit.stroke(head, 3, UIKit.Black, true)
	UIKit.Theme.bevel(head, 0.74, 0.72)
	UIKit.Theme.shine(head)
	local hib = UIKit.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.46, 0), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, Parent = head })
	UIKit.icon("Admin", hib, Color3.new(1, 1, 1))
	local title = UIKit.label({ Text = touch and "ADMIN TOOLS" or "ADMIN TOOLS (F2)", Size = UDim2.new(1, -120, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 48, 0.46, 0), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3 })
	title.Parent = head
	local close = UIKit.button({ Name = "Close", Text = "X", Color = Color3.fromRGB(170, 30, 30), Size = UDim2.fromOffset(touch and 52 or 42, touch and 52 or 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Parent = head })
	close.Activated:Connect(toggle)
	-- ligne de commande libre
	local cmdBg = UIKit.new("Frame", { Name = "CommandBg", BackgroundColor3 = Color3.fromRGB(16, 16, 26), Position = UDim2.new(0, 12, 0, 62), Size = UDim2.new(1, -24, 0, touch and 48 or 38), Parent = panel })
	UIKit.corner(cmdBg, UDim.new(0, 6))
	local cst = UIKit.stroke(cmdBg, 3, UIKit.Black, true)
	local prompt = UIKit.label({ Text = ">", Size = UDim2.new(0, 16, 0.44, 0), Position = UDim2.new(0, 10, 0.28, 0), TextColor3 = UIKit.Colors.Yellow, Stroke = 2 })
	prompt.Parent = cmdBg
	local box = UIKit.new("TextBox", {
		PlaceholderText = "/command ...",
		PlaceholderColor3 = Color3.fromRGB(120, 120, 140),
		Text = "",
		ClearTextOnFocus = false,
		Font = UIKit.Body,
		TextSize = touch and 22 or 20,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 32, 0, 0),
		Size = UDim2.new(1, -40, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = cmdBg,
	})
	box.Focused:Connect(function()
		cst.Color = UIKit.Colors.Yellow
	end)
	box.FocusLost:Connect(function(enter)
		cst.Color = UIKit.Black
		if enter and box.Text ~= "" then
			local t = box.Text
			if string.sub(t, 1, 1) ~= "/" then
				t = "/" .. t
			end
			run(t)
			box.Text = ""
		end
	end)
	local top = touch and 120 or 110
	content = UIKit.new("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.new(0, 12, 0, top),
		Size = UDim2.new(1, -18, 1, -(top + 14)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = touch and 10 or 6,
		ScrollBarImageColor3 = UIKit.Colors.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = content })
	build({})

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			toggle()
		end
	end)
	if ctx.HUDController then
		ctx.HUDController.addMenuButton("ADMIN", RED, toggle, 90)
	end
	task.spawn(function()
		local Net = require(ReplicatedStorage.Shared.Modules.Net)
		Net.get("AdminInfo").OnClientEvent:Connect(function(info)
			if type(info) == "table" then
				build(info)
			end
		end)
	end)
end

function Admin.init(ctx)
	if player:GetAttribute("IsAdmin") then
		setup(ctx)
	else
		player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
			if player:GetAttribute("IsAdmin") then
				setup(ctx)
			end
		end)
	end
end

return Admin
