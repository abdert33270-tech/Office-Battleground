--[[
	DailyRewardController — calendrier 7 jours (bouton DAILY du dock, pastille rouge quand c'est réclamable).
	- S'ouvre tout seul à la connexion s'il y a une récompense à prendre (après la fermeture de la sélection de perso).
	- Remote "DailyReward" : envoie "State" / "Claim" ; reçoit l'état (voir DailyRewardService).
	- Comptes à rebours en temps serveur (workspace:GetServerTimeNow() ~ os.time() du serveur).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.DailyRewards)
local Net = require(Shared.Modules.Net)

local Daily = {}
Daily.Priority = 55

local player = Players.LocalPlayer
local GREEN = Color3.fromRGB(70, 200, 90)
local GOLD = UIKit.Colors.Gold
local GREY = Color3.fromRGB(110, 110, 130)

local dockRef
local panel, cards, status, claimBtn
local state
local remote
local waiting = false
local autoShown = false

local function fmtMoney(n)
	local s = tostring(math.floor(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return "$" .. s .. out
end

local function fmtLong(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%02d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
end

local function buildCard(parent, i, reward)
	local big = reward.Big == true
	local holder, face = UIKit.Theme.shadowed({
		Name = "Day" .. i,
		Size = UDim2.fromOffset(74, 168),
		LayoutOrder = i,
		Color = big and Color3.fromRGB(120, 70, 30) or UIKit.Colors.Slot,
		ZIndex = 22,
		Parent = parent,
	}, 4)
	UIKit.Theme.bevel(face, 0.8, 0.8)
	local day = UIKit.label({ Text = "DAY " .. i, Position = UDim2.fromOffset(4, 8), Size = UDim2.new(1, -8, 0, 14), TextColor3 = big and GOLD or UIKit.Colors.White, Stroke = 2, ZIndex = 23 })
	day.Parent = face
	local iconBox = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 32), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, ZIndex = 23, Parent = face })
	UIKit.icon((reward.Crates or 0) > 0 and "Crate" or "Cash", iconBox, (reward.Crates or 0) > 0 and GOLD or UIKit.Colors.Cash, 23)
	local amt = UIKit.label({ Text = fmtMoney(reward.Cash or 0), Position = UDim2.fromOffset(4, 88), Size = UDim2.new(1, -8, 0, 14), TextColor3 = UIKit.Colors.Cash, Stroke = 2, ZIndex = 23 })
	amt.Parent = face
	if (reward.Crates or 0) > 0 then
		local cr = UIKit.label({ Text = "+" .. reward.Crates .. " CASE" .. (reward.Crates > 1 and "S" or ""), Font = UIKit.Body, Position = UDim2.fromOffset(4, 108), Size = UDim2.new(1, -8, 0, 14), TextColor3 = GOLD, Stroke = 1.5, ZIndex = 23 })
		cr.Parent = face
	end
	local tag = UIKit.label({ Name = "Tag", Text = "", Font = UIKit.Body, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -8, 0, 14), Stroke = 1.5, ZIndex = 24 })
	tag.Parent = face
	-- voile « réclamé » + coche
	local done = UIKit.new("Frame", { Name = "Done", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 25, Parent = face })
	UIKit.corner(done, UDim.new(0, 6))
	local ck = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, ZIndex = 26, Parent = done })
	UIKit.icon("Check", ck, GREEN, 26)
	local stroke = face:FindFirstChildOfClass("UIStroke")
	return { holder = holder, face = face, tag = tag, done = done, stroke = stroke, big = big }
end

local function build(dock)
	local p, body = dock.panel("DailyPanel", "DAILY REWARDS", Color3.fromRGB(255, 150, 40), Vector2.new(640, 330), "Crate")
	panel = p
	local row = UIKit.new("Frame", { Name = "Days", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 176), ZIndex = 21, Parent = body })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	cards = {}
	for i, r in ipairs(Config.Days) do
		cards[i] = buildCard(row, i, r)
	end
	status = UIKit.label({ Name = "Status", Text = "Loading...", Font = UIKit.Body, Position = UDim2.fromOffset(0, 184), Size = UDim2.new(1, -170, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5, ZIndex = 22 })
	status.Parent = body
	local sub = UIKit.label({ Name = "Sub", Text = "Claim once a day. Miss 2 days and your streak resets!", Font = UIKit.Body, Position = UDim2.fromOffset(0, 208), Size = UDim2.new(1, -170, 0, 14), TextColor3 = UIKit.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5, ZIndex = 22 })
	sub.Parent = body
	claimBtn = UIKit.button({ Name = "Claim", Text = "CLAIM!", Color = GREEN, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 182), Size = UDim2.fromOffset(160, 48), ZIndex = 22, Parent = body })
	claimBtn.Activated:Connect(function()
		if waiting or not state or not state.claimable or not remote then
			return
		end
		waiting = true
		claimBtn.Label.Text = "..."
		remote:FireServer("Claim")
		task.delay(4, function()
			waiting = false
		end)
	end)
end

local function render()
	if not panel or not state then
		return
	end
	for i, c in ipairs(cards) do
		local claimed = i <= (state.claimed or 0)
		local isNext = i == state.day
		c.done.Visible = claimed
		if claimed then
			c.tag.Text = "CLAIMED"
			c.tag.TextColor3 = GREEN
		elseif isNext and state.claimable then
			c.tag.Text = "TODAY!"
			c.tag.TextColor3 = UIKit.Colors.Yellow
		elseif isNext then
			c.tag.Text = "TOMORROW"
			c.tag.TextColor3 = UIKit.Colors.Muted
		else
			c.tag.Text = ""
		end
		if c.stroke then
			c.stroke.Color = (isNext and state.claimable) and UIKit.Colors.Yellow or UIKit.Colors.Ink
			c.stroke.Thickness = (isNext and state.claimable) and 4 or 3
		end
	end
	if state.claimable then
		claimBtn.BackgroundColor3 = GREEN
		claimBtn.Label.Text = waiting and "..." or "CLAIM!"
	else
		claimBtn.BackgroundColor3 = GREY
	end
end

-- texte d'état + compte à rebours (appelé souvent pendant que le panneau est ouvert)
local function tickText()
	if not state or not status then
		return
	end
	local now = workspace:GetServerTimeNow()
	if state.unsaved then
		-- chargement DataStore raté côté serveur : on ne réclame pas (ce serait perdu)
		status.Text = "Your progress didn't load. Rejoin to claim!"
		claimBtn.Label.Text = "REJOIN"
	elseif state.claimable then
		if state.lost then
			status.Text = "Streak lost! Back to day 1 - claim it now."
		elseif state.expiresAt and (state.claimed or 0) > 0 then
			status.Text = "Day " .. state.day .. " is ready! Keep your streak: " .. fmtLong(state.expiresAt - now) .. " left"
		else
			status.Text = "Day " .. state.day .. " is ready! Streak: " .. (state.claimed or 0) .. " day" .. ((state.claimed or 0) == 1 and "" or "s")
		end
	else
		local left = (state.nextAt or now) - now
		status.Text = "Next reward in " .. fmtLong(left) .. "  (streak " .. (state.streak or 0) .. ")"
		claimBtn.Label.Text = fmtLong(left)
		if left <= 0 and not waiting and remote then
			waiting = true
			remote:FireServer("State")
			task.delay(3, function()
				waiting = false
			end)
		end
	end
end

-- n'ouvre pas par-dessus la sélection de perso / une révélation de skin
local function blockingUIOpen()
	local pg = player:FindFirstChild("PlayerGui")
	local cs = pg and pg:FindFirstChild("CharacterSelect")
	local root = cs and cs:FindFirstChild("Root")
	if root and root:IsA("GuiObject") and root.Visible then
		return true
	end
	return false
end

local function autoOpen()
	if autoShown then
		return
	end
	autoShown = true
	task.spawn(function()
		task.wait(4)
		local t0 = os.clock()
		while blockingUIOpen() and os.clock() - t0 < 180 do
			task.wait(0.5)
		end
		task.wait(0.6)
		if state and state.claimable and panel and not panel.Visible then
			dockRef.open(panel)
		end
	end)
end

local function onState(st)
	if type(st) ~= "table" then
		return
	end
	local first = state == nil
	state = st
	waiting = false
	if dockRef then
		dockRef.setBadge("Daily", st.claimable == true)
	end
	render()
	tickText()
	if type(st.result) == "table" then
		local c = cards and cards[st.result.day]
		if c then
			UIKit.pop(c.holder, 1.25)
		end
	end
	if first and st.claimable then
		autoOpen()
	end
end

function Daily.init(ctx)
	local dock = ctx.MetaDockController
	if not dock then
		warn("[DailyReward] MetaDockController manquant")
		return
	end
	dockRef = dock
	build(dock)
	dock.addButton("Daily", "DAILY", Color3.fromRGB(255, 150, 40), "Crate", function()
		dock.toggle(panel)
		if panel.Visible and remote then
			remote:FireServer("State")
		end
	end, 10)
	dock.setBadge("Daily", player:GetAttribute("DailyClaimable") == true)
	player:GetAttributeChangedSignal("DailyClaimable"):Connect(function()
		dock.setBadge("Daily", player:GetAttribute("DailyClaimable") == true)
	end)

	task.spawn(function()
		remote = Net.get("DailyReward")
		remote.OnClientEvent:Connect(onState)
		remote:FireServer("State")
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if panel and panel.Visible then
				pcall(tickText)
			end
		end
	end)
end

return Daily
