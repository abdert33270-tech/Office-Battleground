--[[
	TrainingController — interface d'entraînement (voir docs/Entrainement.md).
	- ProximityPrompt "DummyModePrompt" (mannequin) : petit menu des modes -> remote "Training" ("SetMode", dummy, mode).
	- ProximityPrompt "SparPrompt" (borne SPAR) : difficulté du bot -> ("Spar", difficulté) / ("DismissBot").
	- Relevé d'entraînement (serveur -> client "Readout") : coups du combo, dégâts, DROPPED, dernier coup + windup /
	  endlag (Config/Combat, Config/Attacks). Le serveur valide tout ; ici on ne fait qu'afficher.
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.UIKit)
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Net"))

local TrainingController = {}
TrainingController.Priority = 60

local player = Players.LocalPlayer
local C = UIKit.Colors

local MODES = {
	{ id = "Idle", label = "IDLE", desc = "Stands still", color = C.Muted },
	{ id = "Block", label = "BLOCK", desc = "Holds guard", color = C.Blue },
	{ id = "PerfectBlock", label = "PERFECT BLOCK", desc = "Parries your hits", color = C.Cyan },
	{ id = "CounterM1", label = "COUNTER", desc = "Punches back", color = C.Orange },
	{ id = "Evasive", label = "EVASIVE", desc = "Breaks out at 3 hits", color = C.Purple },
}
local DIFFS = {
	{ id = "Easy", color = C.Green, desc = "Slow reactions" },
	{ id = "Normal", color = C.Yellow, desc = "Blocks and dashes" },
	{ id = "Hard", color = C.Red, desc = "Fast reactions, evasive" },
}

local remote
local gui, menu, menuTitle, menuList, menuSource
local readout, rTitle, rHits, rDmg, rMove, rTiming, rEvent
local lastReadout = 0

local function send(...)
	if remote then
		remote:FireServer(...)
	end
end

------------------------------------------------------------------------
-- Menu (modes du mannequin / difficulté du bot)
------------------------------------------------------------------------
local function closeMenu()
	menuSource = nil
	if menu then
		UIKit.close(menu)
	end
end

local function clearList()
	for _, c in ipairs(menuList:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function addRow(text: string, sub: string, color: Color3, selected: boolean, order: number, onClick)
	local b = UIKit.button({
		Text = text,
		Color = color,
		TextColor3 = C.White,
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = UDim2.fromScale(0.9, 0.42),
		LayoutOrder = order,
	})
	b.Label.Position = UDim2.fromScale(0.5, 0.32)
	b.Parent = menuList
	UIKit.label({
		Text = (selected and "> " or "") .. sub,
		Body = true,
		TextColor3 = selected and C.Yellow or C.Paper,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.9, 0.32),
		ZIndex = b.ZIndex + 1,
		Stroke = 1.5,
		Parent = b,
	})
	if selected then
		UIKit.stroke(b, 3, C.Yellow, true)
	end
	b.Activated:Connect(onClick)
	return b
end

local function openModeMenu(dummy: Model)
	menuSource = dummy:FindFirstChild("HumanoidRootPart")
	menuTitle.Text = "DUMMY MODE"
	clearList()
	local current = dummy:GetAttribute("DummyMode") or "Idle"
	for i, m in ipairs(MODES) do
		addRow(m.label, m.desc, m.color, m.id == current, i, function()
			send("SetMode", dummy, m.id)
			closeMenu()
		end)
	end
	UIKit.open(menu)
end

local function openSparMenu(pole: BasePart)
	menuSource = pole
	menuTitle.Text = "SPARRING BOT"
	clearList()
	for i, d in ipairs(DIFFS) do
		addRow(string.upper(d.id), d.desc, d.color, false, i, function()
			send("Spar", d.id)
			closeMenu()
		end)
	end
	addRow("DISMISS", "Remove my bot", C.PanelLight, false, #DIFFS + 1, function()
		send("DismissBot")
		closeMenu()
	end)
	UIKit.open(menu)
end

local function buildMenu()
	menu = UIKit.panel({
		Name = "TrainingMenu",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(280, 330),
		Visible = false,
		Accent = C.Yellow,
		Parent = gui,
	})
	UIKit.autoScale(menu)
	menuTitle = UIKit.label({
		Text = "TRAINING",
		TextColor3 = C.Yellow,
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.new(1, -60, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = menu,
	})
	local close = UIKit.button({
		Text = "X",
		Color = C.Red,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(32, 30),
		ZIndex = 3,
	})
	close.Parent = menu
	close.Activated:Connect(closeMenu)
	menuList = UIKit.new("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 46),
		Size = UDim2.new(1, -28, 1, -58),
		ZIndex = 3,
		Parent = menu,
	})
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menuList,
	})
end

------------------------------------------------------------------------
-- Relevé d'entraînement
------------------------------------------------------------------------
local function fmt(v): string
	if type(v) ~= "number" then
		return "--"
	end
	return string.format("%.2fs", v)
end

local function row(y: number, h: number, color: Color3, body: boolean)
	return UIKit.label({
		Text = "",
		Body = body,
		TextColor3 = color,
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -24, 0, h),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = readout,
	})
end

local function buildReadout()
	readout = UIKit.panel({
		Name = "TrainingReadout",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.4, 0),
		Size = UDim2.fromOffset(250, 150),
		Visible = false,
		Accent = C.Cyan,
		Parent = gui,
	})
	UIKit.autoScale(readout)
	rTitle = row(10, 14, C.Cyan, false)
	rHits = row(28, 24, C.Yellow, false)
	rDmg = row(56, 16, C.Paper, true)
	rMove = row(76, 16, C.White, true)
	rTiming = row(96, 14, C.Muted, true)
	rEvent = row(116, 20, C.Red, false)
end

local function showReadout(d)
	if type(d) ~= "table" then
		return
	end
	lastReadout = os.clock()
	rTitle.Text = "TRAINING · " .. tostring(d.target or "")
	local hits = tonumber(d.hits) or 0
	rHits.Text = hits .. (hits == 1 and " HIT" or " HITS")
	rDmg.Text = "Damage: " .. tostring(d.dmg or 0)
	rMove.Text = "Last: " .. tostring(d.move or "--")
	rTiming.Text = "Windup " .. fmt(d.windup) .. "  |  Endlag " .. fmt(d.endlag)
	if d.dropped then
		rEvent.Text = "DROPPED! (" .. tostring(d.prev or 0) .. " hits)"
		rEvent.TextColor3 = C.Red
	elseif d.ev then
		rEvent.Text = tostring(d.ev) .. "!"
		rEvent.TextColor3 = d.ev == "GUARD BREAK" and C.Orange or C.Cyan
	else
		rEvent.Text = ""
	end
	if not readout.Visible then
		UIKit.open(readout)
	end
	if d.dropped or d.ev then
		UIKit.pop(rEvent)
	else
		UIKit.pop(rHits)
	end
end

------------------------------------------------------------------------
function TrainingController.init()
	gui = UIKit.screen("TrainingUI", 12)
	buildMenu()
	buildReadout()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "DummyModePrompt" then
			local dummy = prompt:FindFirstAncestorOfClass("Model")
			if dummy then
				openModeMenu(dummy)
			end
		elseif prompt.Name == "SparPrompt" then
			local pole = prompt.Parent
			if pole and pole:IsA("BasePart") then
				openSparMenu(pole)
			end
		end
	end)

	-- ferme le menu si on s'éloigne, cache le relevé après 5 s sans coup
	RunService.Heartbeat:Connect(function()
		if menu.Visible and menuSource then
			local c = player.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if not menuSource.Parent or not r or (r.Position - menuSource.Position).Magnitude > 18 then
				closeMenu()
			end
		end
		if readout.Visible and os.clock() - lastReadout > 5 then
			UIKit.close(readout)
		end
	end)

	-- la remote est créée par TrainingService.init : attente hors de init (ne bloque pas les autres contrôleurs)
	task.spawn(function()
		remote = Net.get("Training")
		remote.OnClientEvent:Connect(function(op, data)
			if op == "Readout" then
				showReadout(data)
			end
		end)
	end)
end

return TrainingController
