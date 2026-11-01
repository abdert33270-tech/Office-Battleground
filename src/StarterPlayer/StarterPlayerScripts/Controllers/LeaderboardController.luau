--[[
	LeaderboardController — panneau "LeaderboardPanel" (écran "Meta") : classements mondiaux de LeaderboardService.
	Bouton RANKS du dock unique. Onglets : LEVEL (XP totale -> niveau), K.O.s (total), THIS WEEK (K.O. de la semaine ISO,
	compte à rebours jusqu'à lundi 00:00 UTC). Bascule WORLD / SERVER.
	Hors ligne (Studio sans accès API, place non publiée) : texte d'explication + classement de ce serveur.
	Remote "Leaderboard" : FireServer("Get") à l'ouverture puis toutes les 30 s tant que c'est ouvert ; réponse = payload
	(voir LeaderboardService).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Levels = require(Shared:WaitForChild("Config"):WaitForChild("Levels"))
local Net = require(Shared:WaitForChild("Modules"):WaitForChild("Net"))

local Leaderboard = {}
Leaderboard.Priority = 60

local player = Players.LocalPlayer
local COLOR = UIKit.Colors.Gold
local TABS = {
	{ id = "Level", text = "LEVEL" },
	{ id = "KOs", text = "K.O.s" },
	{ id = "Weekly", text = "THIS WEEK" },
}
local MEDAL = { UIKit.Colors.Gold, UIKit.Theme.HUD.Silver, UIKit.Colors.Orange }

local panel, list, status, empty, scopeBtn
local tabButtons = {}
local tab, scope = "Level", "World"
local data = nil
local remote
local lastAsk = 0

local function fmtNum(n)
	local s = tostring(math.floor(math.abs(tonumber(n) or 0)))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return s .. out
end

local function valueText(v)
	if tab == "Level" then
		local lv = Levels.levelFor(v)
		return "LV " .. lv, fmtNum(v) .. " XP"
	end
	return fmtNum(v) .. " K.O.", nil
end

local function ago(t)
	local d = math.max(0, os.time() - (tonumber(t) or 0))
	if d < 60 then
		return "just now"
	end
	return math.floor(d / 60) .. " min ago"
end

local function renderStatus()
	local online = data and data.online == true
	local useWorld = scope == "World" and online
	local line
	if not data then
		line = "Loading..."
	elseif scope == "World" and not online then
		line = data.pending and "Global leaderboards are loading (first update within 2 min). Showing this server:"
			or ((data.reason or "Global leaderboards are offline here.") .. " Showing this server:")
	elseif useWorld then
		line = "Top 50 worldwide  -  updated " .. ago(data.updated)
	else
		line = "Players in this server"
	end
	if tab == "Weekly" and data and data.weekEnds then
		line ..= "  -  week " .. tostring(data.week or "") .. ", resets in " .. UIKit.fmtLong(data.weekEnds - workspace:GetServerTimeNow())
	end
	status.Text = line
end

local function render()
	if not panel then
		return
	end
	for _, t in ipairs(TABS) do
		local b = tabButtons[t.id]
		b.BackgroundColor3 = t.id == tab and COLOR or UIKit.Colors.Slot
	end
	local online = data and data.online == true
	local useWorld = scope == "World" and online
	scopeBtn.Label.Text = scope == "World" and "WORLD" or "SERVER"
	local entries = {}
	if data then
		local src = useWorld and data.boards or data.server
		entries = (type(src) == "table" and src[tab]) or {}
	end
	renderStatus()
	-- lignes
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	empty.Visible = #entries == 0
	for i, e in ipairs(entries) do
		local me = e.userId == player.UserId
		local row = UIKit.new("Frame", {
			Size = UDim2.new(1, -8, 0, 34),
			BackgroundColor3 = me and UIKit.Theme.darken(UIKit.Colors.Gold, 0.55) or (i % 2 == 0 and UIKit.Colors.PanelDark or UIKit.Colors.Slot),
			BackgroundTransparency = 0.1,
			LayoutOrder = i,
			ZIndex = 22,
			Parent = list,
		})
		UIKit.corner(row, UDim.new(0, 4))
		UIKit.stroke(row, 2, me and UIKit.Colors.Gold or UIKit.Black, true)
		local rank = tonumber(e.rank) or i
		local medal = UIKit.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0), Size = UDim2.fromOffset(40, 26), BackgroundColor3 = MEDAL[rank] or UIKit.Colors.PanelLight, ZIndex = 23, Parent = row })
		UIKit.corner(medal, UDim.new(0, 4))
		UIKit.stroke(medal, 2, UIKit.Black, true)
		local rl = UIKit.label({ Text = "#" .. rank, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -6, 0.6, 0), TextColor3 = rank <= 3 and UIKit.Colors.Ink or UIKit.White, Stroke = rank > 3 and 1.5 or false, ZIndex = 24 })
		rl.Parent = medal
		local nm = UIKit.label({ Text = tostring(e.name or "?"), Font = UIKit.Body, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 54, 0.5, 0), Size = UDim2.new(1, -250, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = me and UIKit.Colors.Yellow or UIKit.White, Stroke = 1.5, MaxText = 18, ZIndex = 23 })
		nm.Parent = row
		local main, sub = valueText(e.value)
		local vl = UIKit.label({ Text = main, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, sub and -6 or 0), Size = UDim2.fromOffset(180, sub and 14 or 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UIKit.Colors.Yellow, Stroke = 2, ZIndex = 23 })
		vl.Parent = row
		if sub then
			local sl = UIKit.label({ Text = sub, Font = UIKit.Body, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 9), Size = UDim2.fromOffset(180, 12), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UIKit.Colors.Muted, Stroke = 1, ZIndex = 23 })
			sl.Parent = row
		end
	end
end

local function ask()
	if remote and os.clock() - lastAsk > 1.2 then
		lastAsk = os.clock()
		remote:FireServer("Get")
	end
end

function Leaderboard.init(ctx)
	local dock = ctx.MetaDockController
	if not dock then
		warn("[Leaderboard] MetaDockController manquant")
		return
	end
	local body
	panel, body = dock.panel("LeaderboardPanel", "LEADERBOARDS", COLOR, Vector2.new(600, 510), "List")
	for i, t in ipairs(TABS) do
		local b = UIKit.button({ Name = "Tab" .. t.id, Text = t.text, Color = UIKit.Colors.Slot, Position = UDim2.fromOffset((i - 1) * 132, 0), Size = UDim2.fromOffset(124, 38), ZIndex = 22, Parent = body })
		b.Activated:Connect(function()
			tab = t.id
			render()
		end)
		tabButtons[t.id] = b
	end
	scopeBtn = UIKit.button({ Name = "Scope", Text = "WORLD", Color = UIKit.Colors.Blue, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(150, 38), ZIndex = 22, Parent = body })
	scopeBtn.Activated:Connect(function()
		scope = scope == "World" and "Server" or "World"
		render()
	end)
	status = UIKit.label({ Text = "Loading...", Font = UIKit.Body, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 32), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, MaxText = 15, ZIndex = 22 })
	status.Parent = body
	list = UIKit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 1, -84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
		Parent = body,
	})
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	empty = UIKit.label({ Text = "Nobody here yet - go fire some coworkers!", Font = UIKit.Body, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.new(1, -20, 0, 18), TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, Visible = false, ZIndex = 23 })
	empty.Parent = body

	dock.addButton("Ranks", "RANKS", COLOR, "List", function()
		dock.toggle(panel)
		if panel.Visible then
			render()
			ask()
		end
	end, 8)

	task.spawn(function()
		remote = Net.get("Leaderboard")
		remote.OnClientEvent:Connect(function(p)
			if type(p) == "table" then
				data = p
				if panel.Visible then
					render()
				end
			end
		end)
	end)
	task.spawn(function()
		local t = 0
		while true do
			task.wait(1)
			if panel.Visible then
				t += 1
				if t % 30 == 0 then
					ask()
				end
				-- compte à rebours de la semaine (le texte d'état seulement)
				if tab == "Weekly" and data then
					pcall(renderStatus)
				end
			else
				t = 0
			end
		end
	end)
end

return Leaderboard
