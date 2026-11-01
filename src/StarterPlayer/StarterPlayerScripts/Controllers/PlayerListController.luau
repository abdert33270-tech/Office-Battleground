--[[
	PlayerListController — liste des joueurs du serveur (remplace la PlayerList Roblox, qui reste désactivée).
	Ouverture : touche TAB (PC) ou bouton PLAYERS du dock unique ; panneau "PlayerListPanel" de l'écran "Meta".
	Une ligne par joueur, triée par niveau (puis XP, puis nom) :
		icône du perso joué (UITheme.attackIcon "Ult:<perso>" sur la couleur du perso ; repli : silhouette)
		nom + titre de carrière (attributs "Title" / "TitleColor", TaskService), LV, grade (couleur Config/Grades), K.O.
	Rafraîchie chaque seconde tant que le panneau est ouvert (lignes réutilisées, icône refaite seulement si le perso change).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent.UIKit)
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Characters = require(Config:WaitForChild("Characters"))
local Grades = require(Config:WaitForChild("Grades"))

local PlayerList = {}
PlayerList.Priority = 60

local player = Players.LocalPlayer
local panel, list, title
local rows = {} -- [Player] = { frame, icon, iconKey, name, title, lv, grade, kos }
local COLOR = UIKit.Colors.Cyan

local gradeColor = {}
for _, g in ipairs(Grades.List) do
	gradeColor[g.Name] = g.Color
end

local function charOf(p)
	local c = p.Character
	return (c and c:GetAttribute("CharacterName")) or p:GetAttribute("CharacterName")
end

local function setIcon(r, charName)
	local key = charName or "-"
	if r.iconKey == key then
		return
	end
	r.iconKey = key
	r.icon:ClearAllChildren()
	local kit = charName and Characters[charName]
	r.icon.BackgroundColor3 = kit and kit.Color or UIKit.Colors.Slot
	local ok = false
	if kit then
		ok = pcall(function()
			return UIKit.Theme.attackIcon("Ult:" .. charName, r.icon, nil, { Color = kit.Color, NoBadge = true })
		end)
		ok = ok and #r.icon:GetChildren() > 0
	end
	if not ok then
		r.icon:ClearAllChildren()
		local inner = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), BackgroundTransparency = 1, ZIndex = 24, Parent = r.icon })
		UIKit.icon("Person", inner, UIKit.White, 24)
	end
end

local function makeRow(p)
	local me = p == player
	local f = UIKit.new("Frame", {
		Name = "Row_" .. p.UserId,
		Size = UDim2.new(1, -8, 0, 48),
		BackgroundColor3 = me and UIKit.Theme.darken(UIKit.Colors.Gold, 0.55) or UIKit.Colors.PanelDark,
		BackgroundTransparency = 0.1,
		ZIndex = 22,
		Parent = list,
	})
	UIKit.corner(f, UDim.new(0, 5))
	UIKit.stroke(f, 2, me and UIKit.Colors.Gold or UIKit.Black, true)
	local icon = UIKit.new("Frame", { Name = "Icon", Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = UIKit.Colors.Slot, ZIndex = 23, Parent = f })
	UIKit.corner(icon, UDim.new(0, 5))
	UIKit.stroke(icon, 2, UIKit.Black, true)
	local name = UIKit.label({ Name = "PlayerName", Text = p.DisplayName, Font = UIKit.Body, Position = UDim2.fromOffset(54, 4), Size = UDim2.new(1, -330, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = me and UIKit.Colors.Yellow or UIKit.White, Stroke = 1.5, MaxText = 20, ZIndex = 23 })
	name.Parent = f
	local tl = UIKit.label({ Name = "Title", Text = "", Font = UIKit.Body, Position = UDim2.fromOffset(54, 26), Size = UDim2.new(1, -330, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, MaxText = 16, ZIndex = 23 })
	tl.Parent = f
	local lv = UIKit.label({ Name = "Level", Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -212, 0.5, 0), Size = UDim2.fromOffset(62, 18), TextColor3 = UIKit.Colors.Yellow, Stroke = 2, ZIndex = 23 })
	lv.Parent = f
	local gr = UIKit.label({ Name = "Grade", Text = "", Font = UIKit.Body, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -76, 0.5, 0), Size = UDim2.fromOffset(130, 18), Stroke = 1.5, MaxText = 18, ZIndex = 23 })
	gr.Parent = f
	local kos = UIKit.label({ Name = "KOs", Text = "0", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(60, 18), TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2, ZIndex = 23 })
	kos.Parent = f
	local r = { frame = f, icon = icon, name = name, title = tl, lv = lv, grade = gr, kos = kos }
	rows[p] = r
	return r
end

local function stat(p, name)
	local ls = p:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild(name)
	return v and v.Value or nil
end

local function refresh()
	if not panel then
		return
	end
	local all = Players:GetPlayers()
	for p, r in pairs(rows) do
		if not p.Parent then
			r.frame:Destroy()
			rows[p] = nil
		end
	end
	table.sort(all, function(a, b)
		local la, lb = tonumber(a:GetAttribute("Level")) or 1, tonumber(b:GetAttribute("Level")) or 1
		if la ~= lb then
			return la > lb
		end
		local xa, xb = tonumber(a:GetAttribute("XP")) or 0, tonumber(b:GetAttribute("XP")) or 0
		if xa ~= xb then
			return xa > xb
		end
		return string.lower(a.DisplayName) < string.lower(b.DisplayName)
	end)
	for i, p in ipairs(all) do
		local r = rows[p] or makeRow(p)
		r.frame.LayoutOrder = i
		setIcon(r, charOf(p))
		local t = p:GetAttribute("Title")
		r.title.Text = (type(t) == "string" and t ~= "") and string.upper(t) or "NEW HIRE"
		local tc = p:GetAttribute("TitleColor")
		r.title.TextColor3 = typeof(tc) == "Color3" and tc or UIKit.Colors.Muted
		r.lv.Text = "LV " .. tostring(p:GetAttribute("Level") or stat(p, "Level") or 1)
		local g = p:GetAttribute("Grade") or stat(p, "Grade") or "Trainee"
		r.grade.Text = string.upper(tostring(g))
		r.grade.TextColor3 = gradeColor[g] or UIKit.White
		r.kos.Text = tostring(stat(p, "KOs") or 0)
	end
	title.Text = "PLAYERS (" .. #all .. ")"
end

local function toggle()
	UIKit.togglePanel(panel)
	if panel.Visible then
		refresh()
	end
end
PlayerList.toggle = toggle

function PlayerList.init(ctx)
	-- la PlayerList Roblox reste coupée (le HUD le fait aussi ; SetCoreGuiEnabled peut échouer très tôt)
	task.spawn(function()
		for _ = 1, 5 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)
			if ok then
				break
			end
			task.wait(1)
		end
	end)
	local dock = ctx.MetaDockController
	if not dock then
		warn("[PlayerList] MetaDockController manquant")
		return
	end
	local body
	panel, body = dock.panel("PlayerListPanel", "PLAYERS", COLOR, Vector2.new(640, 470), "Person")
	title = panel.Header.Title
	-- en-têtes de colonnes
	local function col(text, props)
		local l = UIKit.label({ Text = text, Font = UIKit.Body, Size = UDim2.fromOffset(130, 16), TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, ZIndex = 22 })
		for k, v in pairs(props) do
			l[k] = v
		end
		l.Parent = body
	end
	col("NAME / TITLE", { Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -330, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
	col("LEVEL", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -220, 0, 0), Size = UDim2.fromOffset(62, 16) })
	col("GRADE", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -84, 0, 0), Size = UDim2.fromOffset(130, 16) })
	col("K.O.", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 0), Size = UDim2.fromOffset(60, 16), TextXAlignment = Enum.TextXAlignment.Right })
	list = UIKit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
		Parent = body,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local hint = UIKit.label({ Text = UIKit.isTouch() and "Sorted by level" or "Sorted by level  -  TAB to close", Font = UIKit.Body, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 16), TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, ZIndex = 22 })
	hint.Parent = body

	dock.addButton("Players", "PLAYERS", COLOR, "Person", toggle, 7)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Tab then
			toggle()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if panel.Visible then
				refresh()
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible then
				local ok, err = pcall(refresh)
				if not ok and not PlayerList._warned then
					PlayerList._warned = true
					warn("[PlayerList] " .. tostring(err))
				end
			end
		end
	end)
end

return PlayerList
