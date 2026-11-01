--[[
	AFKController — bouton AFK du dock (devient EXIT dans la salle) + compteur en haut de l'écran :
		« AFK 03:12 - next +25 in 0:48 - earned 150 » + barre jusqu'au prochain versement + bouton EXIT.
	Lit les attributs Player posés par AFKService : AFKActive, AFKSince, AFKNextPay, AFKNextBonus, AFKEarned, AFKCapLeft.
	Remote "AFK" : "Enter" / "Exit". Fondu noir rapide à l'entrée / la sortie.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UIKit = require(script.Parent.UIKit)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.AFK)
local Net = require(Shared.Modules.Net)

local AFK = {}
AFK.Priority = 58

local player = Players.LocalPlayer
local BLUE = Color3.fromRGB(90, 140, 255)
local EXIT_COLOR = Color3.fromRGB(240, 90, 70)

local remote
local gui, counter, line, sub, barFill, fade
local lastSend = 0

local function send(op)
	if not remote or os.clock() - lastSend < 0.6 then
		return
	end
	lastSend = os.clock()
	remote:FireServer(op)
end

local function active()
	return player:GetAttribute("AFKActive") == true
end

local function fmt(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then
		return string.format("%d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
	end
	return string.format("%02d:%02d", sec // 60, sec % 60)
end

local function build()
	gui = UIKit.screen("AFKHud", 6)
	counter = UIKit.panel({
		Name = "AFKCounter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(560, 78),
		Accent = BLUE,
		Visible = false,
		Parent = gui,
	})
	UIKit.autoScale(counter)
	local title = UIKit.label({ Text = "AFK BREAK ROOM", Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -150, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Colors.Yellow, Stroke = 2, ZIndex = 2 })
	title.Parent = counter
	line = UIKit.label({ Text = "", Font = UIKit.Body, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -150, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5, ZIndex = 2 })
	line.Parent = counter
	local bar = UIKit.new("Frame", { Name = "Bar", BackgroundColor3 = UIKit.Colors.Slot, Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -150, 0, 10), ZIndex = 2, Parent = counter })
	UIKit.corner(bar, UDim.new(0.5, 0))
	UIKit.stroke(bar, 2, UIKit.Black, true)
	barFill = UIKit.new("Frame", { Name = "Fill", BackgroundColor3 = UIKit.Colors.Cash, Size = UDim2.fromScale(0, 1), ZIndex = 3, Parent = bar })
	UIKit.corner(barFill, UDim.new(0.5, 0))
	sub = UIKit.label({ Text = "", Font = UIKit.Body, Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -150, 0, 10), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Colors.Muted, Stroke = 1, ZIndex = 2 })
	sub.Parent = counter
	local exit = UIKit.button({ Name = "Exit", Text = "EXIT", Color = EXIT_COLOR, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(116, 48), ZIndex = 3, Parent = counter })
	exit.Activated:Connect(function()
		send("Exit")
	end)

	fade = UIKit.new("Frame", { Name = "Fade", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Active = false, ZIndex = 50, Parent = gui })
end

local function flash()
	if not fade then
		return
	end
	fade.BackgroundTransparency = 0.05
	UIKit.tween(fade, 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

local function update()
	if not counter or not counter.Visible then
		return
	end
	local now = workspace:GetServerTimeNow()
	local since = tonumber(player:GetAttribute("AFKSince")) or now
	local nextPay = tonumber(player:GetAttribute("AFKNextPay")) or now
	local nextBonus = tonumber(player:GetAttribute("AFKNextBonus"))
	local earned = tonumber(player:GetAttribute("AFKEarned")) or 0
	local capLeft = tonumber(player:GetAttribute("AFKCapLeft")) or -1
	local toPay = math.max(0, nextPay - now)
	if capLeft == 0 then
		line.Text = "AFK " .. fmt(now - since) .. "  -  daily cap reached  -  earned " .. earned
		barFill.Size = UDim2.fromScale(1, 1)
		barFill.BackgroundColor3 = UIKit.Colors.Orange
		sub.Text = "Come back tomorrow for more AFK Cash!"
	else
		line.Text = "AFK " .. fmt(now - since) .. "  -  next +" .. Config.PayAmount .. " in " .. fmt(toPay) .. "  -  earned " .. earned
		barFill.Size = UDim2.fromScale(math.clamp(1 - toPay / Config.PayInterval, 0, 1), 1)
		barFill.BackgroundColor3 = UIKit.Colors.Cash
		if nextBonus then
			sub.Text = "Bonus +" .. Config.BonusAmount .. " in " .. fmt(nextBonus - now) .. (capLeft > 0 and ("   |   " .. capLeft .. " Cash left today") or "")
		else
			sub.Text = ""
		end
	end
end

local function refresh(dock, animate)
	local on = active()
	if counter then
		if on and not counter.Visible then
			UIKit.open(counter)
		elseif not on and counter.Visible then
			UIKit.close(counter)
		end
	end
	if dock then
		dock.setText("AFK", on and "EXIT" or "AFK")
		dock.setColor("AFK", on and EXIT_COLOR or BLUE)
	end
	if animate then
		flash()
	end
	update()
end

function AFK.init(ctx)
	build()
	local dock = ctx.MetaDockController
	if dock then
		dock.addButton("AFK", "AFK", BLUE, "glyph:Zz", function()
			send(active() and "Exit" or "Enter")
		end, 40)
	else
		warn("[AFK] MetaDockController manquant")
	end
	refresh(dock, false)
	player:GetAttributeChangedSignal("AFKActive"):Connect(function()
		refresh(dock, true)
	end)
	task.spawn(function()
		remote = Net.get("AFK")
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local ok, err = pcall(update)
		if not ok and not AFK._warned then
			AFK._warned = true
			warn("[AFK] " .. tostring(err))
		end
	end)
end

return AFK
