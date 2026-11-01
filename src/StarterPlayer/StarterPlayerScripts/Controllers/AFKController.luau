--[[
	AFKController — bouton AFK du dock (devient EXIT dans la salle) + tout le côté client de la salle de pause.
	- Compteur en haut de l'écran (compact, lisible sur mobile) :
		« AFK 03:12        $150 »  + barre jusqu'au prochain versement + « next +25 in 00:48 · $1,350 left today »
		+ ligne dorée mise en avant « NEXT BONUS +100 in 07:12 » avec sa propre barre (BonusEvery = 10 min)
		+ gros bouton EXIT. Échelle propre (UIScale) : téléphone ~0.9, PC 1.
	- Chaque versement : « +25 CASH » qui jaillit au-dessus du perso + son (CartoonFX « Ding », « LevelUp » pour le bonus).
	- Tableau des gains : SurfaceGui locale (PlayerGui, Adornee = BreakRoom.PayoutScreen, face Left = -X, vers la salle)
	  avec les chiffres DU joueur (session, prochain versement, reste du jour).
	- Ambiance (seulement quand on est dans la salle, caméra proche) : plantes qui ondulent (Models AmbSway),
	  lumières qui clignotent / pulsent (AmbBlink), nuages qui défilent (AmbCloud), fenêtres de la ville qui s'allument,
	  horloge à l'heure locale (AmbHand). Qualité « Low » => seulement l'horloge ; « Reduce flashes » => pas de créneaux.
	- Anti-inactivité : pendant AFKActive, Players.LocalPlayer.Idled => essai VirtualUser (pcall ; souvent réservé aux
	  scripts privilégiés => sans effet). Filet de sécurité : si l'inactivité (temps donné par Idled, remis à zéro par
	  toute entrée UserInputService) atteint Config.RejoinIdle (17 min) toujours AFK, remote "AFK" "Rejoin" : le serveur
	  reconnecte le joueur (TeleportService) et le remet dans la salle (attribut AFKRejoined => « Reconnected to keep
	  you AFK » dans le HUD pendant 10 s). Sinon Roblox expulse au bout de 20 min.
	Lit les attributs Player posés par AFKService : AFKActive, AFKSince, AFKNextPay, AFKNextBonus, AFKEarned, AFKCapLeft.
	Remote "AFK" : "Enter" / "Exit" / "Rejoin". Fondu noir rapide à l'entrée / la sortie.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local UIKit = require(script.Parent.UIKit)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.AFK)
local Net = require(Shared.Modules.Net)
local okSettings, ClientSettings = pcall(require, Shared.Modules.ClientSettings)
local okFX, CartoonFX = pcall(require, Shared.Modules.CartoonFX)

local AFK = {}
AFK.Priority = 58

local player = Players.LocalPlayer
local BLUE = Color3.fromRGB(90, 140, 255)
local EXIT_COLOR = Color3.fromRGB(240, 90, 70)
local ORIGIN = Config.Origin

local remote
local gui, counter, timeText, earnedText, sub, barFill, fade, bonusText, bonusFill
local board -- { gui, labels }
local lastSend = 0
local lastEarned = 0
local idleConn, inputConn
local idleStart -- os.clock() estimé du début de l'inactivité (d'après Players.LocalPlayer.Idled), nil = actif
local lastRejoinAsk = -math.huge
local REJOIN_NOTE = 10 -- s d'affichage de « Reconnected to keep you AFK »

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

local function setting(key)
	if okSettings and ClientSettings and ClientSettings.get then
		return ClientSettings.get(key)
	end
	return nil
end

local function fmt(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then
		return string.format("%d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
	end
	return string.format("%02d:%02d", sec // 60, sec % 60)
end

local function money(n)
	local s = tostring(math.floor(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return "$" .. s .. out
end

------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------
local function build()
	gui = UIKit.screen("AFKHud", 6)
	local touch = UIKit.isTouch()
	counter = UIKit.panel({
		Name = "AFKCounter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104), -- sous la barre de phase du HUD
		Size = UDim2.fromOffset(440, 104),
		Accent = BLUE,
		Visible = false,
		Parent = gui,
	})
	-- échelle dédiée : lisible sur téléphone (pas le plancher 0.6 de UIKit.autoScale), jamais plus large que l'écran
	local scale = UIKit.new("UIScale", { Name = "AutoScale", Parent = counter })
	local function rescale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1600, 900)
		local v = math.min(vp.Y / (touch and 420 or 900), (vp.X - 32) / 440, 1.1)
		v = math.max(v, 0.55)
		scale:SetAttribute("Base", v)
		scale.Scale = v
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	timeText = UIKit.label({ Name = "Time", Text = "AFK 00:00", Position = UDim2.fromOffset(14, 9), Size = UDim2.new(1, -230, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Colors.Yellow, Stroke = 2, ZIndex = 2 })
	timeText.Parent = counter
	earnedText = UIKit.label({ Name = "Earned", Text = "$0", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -116, 0, 9), Size = UDim2.fromOffset(110, 20), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UIKit.Colors.Cash, Stroke = 2, ZIndex = 2 })
	earnedText.Parent = counter
	local bar = UIKit.new("Frame", { Name = "Bar", BackgroundColor3 = UIKit.Colors.Slot, Position = UDim2.fromOffset(14, 35), Size = UDim2.new(1, -130, 0, 10), ZIndex = 2, Parent = counter })
	UIKit.corner(bar, UDim.new(0.5, 0))
	UIKit.stroke(bar, 2, UIKit.Black, true)
	barFill = UIKit.new("Frame", { Name = "Fill", BackgroundColor3 = UIKit.Colors.Cash, Size = UDim2.fromScale(0, 1), ZIndex = 3, Parent = bar })
	UIKit.corner(barFill, UDim.new(0.5, 0))
	sub = UIKit.label({ Name = "Sub", Text = "", Font = UIKit.Body, Position = UDim2.fromOffset(14, 51), Size = UDim2.new(1, -130, 0, 15), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, ZIndex = 2 })
	sub.Parent = counter
	-- prochain bonus : ligne dorée bien visible + barre (le gros versement des 10 min)
	bonusText = UIKit.label({ Name = "Bonus", Text = "", Position = UDim2.fromOffset(14, 70), Size = UDim2.new(1, -130, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Colors.Gold, Stroke = 2, ZIndex = 2 })
	bonusText.Parent = counter
	local bbar = UIKit.new("Frame", { Name = "BonusBar", BackgroundColor3 = UIKit.Colors.Slot, Position = UDim2.fromOffset(14, 89), Size = UDim2.new(1, -130, 0, 8), ZIndex = 2, Parent = counter })
	UIKit.corner(bbar, UDim.new(0.5, 0))
	UIKit.stroke(bbar, 2, UIKit.Black, true)
	bonusFill = UIKit.new("Frame", { Name = "Fill", BackgroundColor3 = UIKit.Colors.Gold, Size = UDim2.fromScale(0, 1), ZIndex = 3, Parent = bbar })
	UIKit.corner(bonusFill, UDim.new(0.5, 0))
	local exit = UIKit.button({ Name = "Exit", Text = "EXIT", Color = EXIT_COLOR, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(100, 56), ZIndex = 3, Parent = counter })
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

------------------------------------------------------------------------
-- Tableau des gains (SurfaceGui locale sur BreakRoom.PayoutScreen)
------------------------------------------------------------------------
local function roomModel()
	return workspace:FindFirstChild("BreakRoom")
end

local function ensureBoard()
	local room = roomModel()
	local screen = room and room:FindFirstChild("PayoutScreen")
	if not screen or not screen:IsA("BasePart") then
		if board then
			board.gui.Adornee = nil
		end
		return nil
	end
	if board and board.gui.Parent and board.gui.Adornee == screen then
		return board
	end
	if not board or not board.gui.Parent then
		local pg = player:FindFirstChild("PlayerGui")
		if not pg then
			return nil
		end
		local sg = UIKit.new("SurfaceGui", {
			Name = "AFKBoard",
			Face = Enum.NormalId.Left, -- écran sur le mur +X : sa face -X regarde l'intérieur de la salle
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 50,
			LightInfluence = 0,
			Brightness = 1.6,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
		UIKit.Theme.hookFonts(sg)
		local holder = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.04, 0.08), Size = UDim2.fromScale(0.92, 0.84), Parent = sg })
		UIKit.new("UIGridLayout", { CellSize = UDim2.fromScale(1 / 3, 0.5), CellPadding = UDim2.new(), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
		local labels = {}
		local function cell(order, title, color)
			local f = UIKit.new("Frame", { BackgroundTransparency = 1, LayoutOrder = order, Parent = holder })
			local t = UIKit.label({ Text = title, Font = UIKit.Body, Size = UDim2.fromScale(1, 0.36), TextColor3 = UIKit.Colors.Muted, Stroke = 2 })
			t.Parent = f
			local v = UIKit.label({ Text = "-", Position = UDim2.fromScale(0, 0.38), Size = UDim2.fromScale(1, 0.56), TextColor3 = color, Stroke = 3 })
			v.Parent = f
			return v
		end
		labels.earned = cell(1, "EARNED THIS BREAK", UIKit.Colors.Cash)
		labels.next = cell(2, "NEXT PAYOUT", UIKit.Colors.Yellow)
		labels.bonus = cell(3, "NEXT BONUS", UIKit.Colors.Gold)
		labels.time = cell(4, "TIME ON BREAK", Color3.fromRGB(150, 210, 255))
		labels.cap = cell(5, "LEFT TODAY", Color3.fromRGB(255, 190, 120))
		sg.Parent = pg
		board = { gui = sg, labels = labels }
	end
	board.gui.Adornee = screen
	return board
end

local function updateBoard(now, since, toPay, earned, capLeft, on, toBonus)
	local b = ensureBoard()
	if not b then
		return
	end
	local L = b.labels
	if not on then
		L.earned.Text, L.next.Text, L.time.Text = "-", "-", "-"
		L.cap.Text = "-"
		if L.bonus then
			L.bonus.Text = "-"
		end
		return
	end
	L.earned.Text = money(earned)
	L.time.Text = fmt(now - since)
	if L.bonus then
		L.bonus.Text = (capLeft == 0 or not toBonus) and "-" or ("+" .. Config.BonusAmount .. " in " .. fmt(toBonus))
	end
	if capLeft == 0 then
		L.next.Text = "CAP REACHED"
		L.cap.Text = "$0"
	else
		L.next.Text = "+" .. Config.PayAmount .. " in " .. fmt(toPay)
		L.cap.Text = capLeft < 0 and "NO CAP" or money(capLeft)
	end
end

------------------------------------------------------------------------
-- Mise à jour du compteur
------------------------------------------------------------------------
local function update()
	local on = active()
	local now = workspace:GetServerTimeNow()
	local since = tonumber(player:GetAttribute("AFKSince")) or now
	local nextPay = tonumber(player:GetAttribute("AFKNextPay")) or now
	local nextBonus = tonumber(player:GetAttribute("AFKNextBonus"))
	local earned = tonumber(player:GetAttribute("AFKEarned")) or 0
	local capLeft = tonumber(player:GetAttribute("AFKCapLeft")) or -1
	local toPay = math.max(0, nextPay - now)
	local toBonus = nextBonus and math.max(0, nextBonus - now) or nil
	if on or board then
		updateBoard(now, since, toPay, earned, capLeft, on, toBonus)
	end
	if not counter or not counter.Visible then
		return
	end
	timeText.Text = "AFK " .. fmt(now - since)
	earnedText.Text = money(earned)
	if capLeft == 0 then
		barFill.Size = UDim2.fromScale(1, 1)
		barFill.BackgroundColor3 = UIKit.Colors.Orange
		sub.Text = "Daily cap reached - come back tomorrow!"
		bonusText.Text = "NO MORE BONUS TODAY"
		bonusFill.Size = UDim2.fromScale(1, 1)
	else
		barFill.Size = UDim2.fromScale(math.clamp(1 - toPay / Config.PayInterval, 0, 1), 1)
		barFill.BackgroundColor3 = UIKit.Colors.Cash
		local parts = { "next +" .. Config.PayAmount .. " in " .. fmt(toPay) }
		local rj = tonumber(player:GetAttribute("AFKRejoined"))
		if rj and now - rj < REJOIN_NOTE then
			parts = { "Reconnected to keep you AFK" }
		end
		if toBonus then
			bonusText.Text = "NEXT BONUS +" .. Config.BonusAmount .. " in " .. fmt(toBonus)
			bonusFill.Size = UDim2.fromScale(math.clamp(1 - toBonus / Config.BonusEvery, 0, 1), 1)
			-- dernière minute : le texte pulse pour attirer l'oeil
			bonusText.TextTransparency = toBonus < 60 and (0.35 - 0.35 * math.abs(math.sin(now * 3))) or 0
		else
			bonusText.Text = "NEXT BONUS +" .. Config.BonusAmount
			bonusFill.Size = UDim2.fromScale(0, 1)
		end
		if capLeft > 0 then
			table.insert(parts, money(capLeft) .. " left today")
		end
		sub.Text = table.concat(parts, "  ·  ")
	end
end

------------------------------------------------------------------------
-- « +25 CASH » au-dessus du perso + son
------------------------------------------------------------------------
local function payPop(amount)
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	local big = amount >= (Config.BonusAmount or math.huge)
	if okFX and CartoonFX and CartoonFX.sound then
		pcall(CartoonFX.sound, big and "LevelUp" or "Ding", nil, big and 0.8 or 0.6, big and 1 or 1.15)
	end
	if earnedText then
		UIKit.pop(earnedText, 1.35)
	end
	if not head then
		return
	end
	local bb = UIKit.new("BillboardGui", {
		Name = "AFKPayPop",
		Adornee = head,
		Size = UDim2.fromOffset(big and 260 or 200, big and 64 or 50),
		StudsOffset = Vector3.new(0, 2.6, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
	})
	UIKit.Theme.hookFonts(bb)
	local l = UIKit.label({ Text = "+" .. amount .. " CASH", TextColor3 = big and UIKit.Colors.Gold or UIKit.Colors.Cash, Stroke = 3, Size = UDim2.fromScale(1, 1) })
	l.Parent = bb
	local s = UIKit.new("UIScale", { Scale = 0.2, Parent = l })
	bb.Parent = player:FindFirstChild("PlayerGui") or gui -- BillboardGui : directement dans PlayerGui (Adornee = tête)
	UIKit.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay(0.3, function()
		if bb.Parent then
			UIKit.tween(bb, 1.4, { StudsOffset = Vector3.new(0, 5.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			UIKit.tween(l, 1.4, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local st = l:FindFirstChildOfClass("UIStroke")
			if st then
				UIKit.tween(st, 1.4, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end
	end)
	Debris:AddItem(bb, 2)
end

------------------------------------------------------------------------
-- Anti-inactivité (salle AFK seulement)
------------------------------------------------------------------------
local function setAntiIdle(on)
	if on and not idleConn then
		local ok, vu = pcall(game.GetService, game, "VirtualUser")
		idleStart = nil
		idleConn = player.Idled:Connect(function(idleTime)
			if not active() then
				return
			end
			-- Idled donne le temps d'inactivité (s) : sert au filet de sécurité "Rejoin" (checkIdleRejoin)
			idleStart = os.clock() - (tonumber(idleTime) or 120)
			if not ok or not vu then
				return
			end
			local done, err = pcall(function()
				vu:CaptureController()
				vu:ClickButton2(Vector2.new())
			end)
			if not done and not AFK._idleWarned then
				AFK._idleWarned = true
				warn("[AFK] anti-idle VirtualUser indisponible (reconnexion à " .. math.floor((Config.RejoinIdle or 1020) / 60) .. " min) : " .. tostring(err))
			end
		end)
		-- vraie entrée du joueur (touche, clic, toucher, souris / stick qui bouge) : il n'est plus inactif
		local function wake()
			idleStart = nil
		end
		inputConn = { UserInputService.InputBegan:Connect(wake), UserInputService.InputChanged:Connect(wake) }
	elseif not on and idleConn then
		idleConn:Disconnect()
		idleConn = nil
		if inputConn then
			for _, c in ipairs(inputConn) do
				c:Disconnect()
			end
			inputConn = nil
		end
		idleStart = nil
	end
end

-- filet de sécurité : toujours inactif à RejoinIdle s (VirtualUser sans effet) => le serveur nous reconnecte
-- avant l'expulsion des 20 min (il refuse si on n'est pas AFK ou si on l'a déjà demandé il y a < 10 min)
local function checkIdleRejoin()
	if not idleStart or not active() or not remote then
		return
	end
	local now = os.clock()
	if now - idleStart < (Config.RejoinIdle or 1020) or now - lastRejoinAsk < 60 then
		return
	end
	lastRejoinAsk = now
	remote:FireServer("Rejoin")
end

------------------------------------------------------------------------
-- Ambiance de la salle (purement locale)
------------------------------------------------------------------------
local amb = { room = nil, sway = {}, blinks = {}, clouds = {}, windows = {}, hands = {}, nextWindow = 0 }

local function scan(room)
	amb.room = room
	amb.sway, amb.blinks, amb.clouds, amb.windows, amb.hands = {}, {}, {}, {}, {}
	for _, d in ipairs(room:GetDescendants()) do
		if d:IsA("Model") then
			local pivot = d:GetAttribute("AmbSway")
			if typeof(pivot) == "Vector3" then
				local parts = {}
				for _, p in ipairs(d:GetChildren()) do
					if p:IsA("BasePart") then
						table.insert(parts, { p = p, base = p.CFrame })
					end
				end
				table.insert(amb.sway, { pivot = CFrame.new(pivot), parts = parts, phase = tonumber(d:GetAttribute("AmbPhase")) or 0 })
			elseif tonumber(d:GetAttribute("AmbCloud")) then
				table.insert(amb.clouds, { m = d, base = d:GetPivot(), speed = d:GetAttribute("AmbCloud") })
			end
		elseif d:IsA("BasePart") then
			if tonumber(d:GetAttribute("AmbBlink")) then
				table.insert(amb.blinks, {
					p = d,
					period = math.max(0.2, d:GetAttribute("AmbBlink")),
					phase = tonumber(d:GetAttribute("AmbPhase")) or 0,
					mode = d:GetAttribute("AmbMode") or "pulse",
					baseT = tonumber(d:GetAttribute("AmbBaseT")) or d.Transparency,
				})
			elseif d.Name == "Window" then
				table.insert(amb.windows, { p = d, baseT = d.Transparency })
			end
			local hand = d:GetAttribute("AmbHand")
			local pv = d:GetAttribute("AmbPivot")
			if hand and typeof(pv) == "Vector3" then
				table.insert(amb.hands, { p = d, kind = hand, pivot = pv, len = d.Size.Y })
			end
		end
	end
end

local function animate(t)
	local quality = setting("Quality") or "High"
	local reduced = setting("ReducedFlashes") == true
	-- horloge (heure locale du joueur)
	local now = os.date("*t")
	local secs = (now.hour % 12) * 3600 + now.min * 60 + now.sec
	for _, h in ipairs(amb.hands) do
		if h.p.Parent then
			local turns = h.kind == "Hour" and secs / 43200 or (secs % 3600) / 3600
			-- rotation +Z : le haut part vers -X = la droite de qui regarde le mur (+Z) => sens horaire
			h.p.CFrame = CFrame.new(h.pivot) * CFrame.Angles(0, 0, turns * math.pi * 2) * CFrame.new(0, h.len / 2 - 0.15, 0)
		end
	end
	if quality == "Low" then
		return
	end
	for _, s in ipairs(amb.sway) do
		local rot = CFrame.Angles(math.sin(t * 0.9 + s.phase) * 0.045, 0, math.cos(t * 0.7 + s.phase * 1.3) * 0.055)
		local m = s.pivot * rot * s.pivot:Inverse()
		for _, e in ipairs(s.parts) do
			if e.p.Parent then
				e.p.CFrame = m * e.base
			end
		end
	end
	for _, b in ipairs(amb.blinks) do
		if b.p.Parent then
			local x = ((t + b.phase) % b.period) / b.period
			local dim
			if b.mode == "blink" and not reduced then
				dim = x < 0.5 and 0 or 0.8
			elseif b.mode == "chase" and not reduced then
				dim = x < 0.33 and 0 or 0.7
			else
				dim = 0.35 + 0.35 * math.cos(x * math.pi * 2)
			end
			b.p.Transparency = math.clamp(b.baseT + (1 - b.baseT) * dim, 0, 1)
		end
	end
	for _, c in ipairs(amb.clouds) do
		if c.m.Parent then
			local relX = c.base.Position.X - ORIGIN.X
			local x = ((relX + t * c.speed + 260) % 520) - 260
			c.m:PivotTo(c.base + Vector3.new(x - relX, 0, 0))
		end
	end
	-- fenêtres de la ville : quelques-unes s'allument / s'éteignent doucement
	if #amb.windows > 0 and t >= amb.nextWindow then
		amb.nextWindow = t + (reduced and 2.5 or 0.7)
		for _ = 1, 2 do
			local w = amb.windows[math.random(1, #amb.windows)]
			if w.p.Parent then
				local off = w.p.Transparency < 0.6
				UIKit.tween(w.p, 1.2, { Transparency = off and 0.88 or w.baseT })
			end
		end
	end
end

local function ambientStep(t)
	if not active() then
		return
	end
	local room = roomModel()
	if not room then
		amb.room = nil
		return
	end
	local cam = workspace.CurrentCamera
	if not cam or (cam.CFrame.Position - ORIGIN).Magnitude > 400 then
		return
	end
	if amb.room ~= room then
		scan(room)
	end
	animate(t)
end

------------------------------------------------------------------------
local function refresh(dock, animate_)
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
	setAntiIdle(on)
	if animate_ then
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
	lastEarned = tonumber(player:GetAttribute("AFKEarned")) or 0
	refresh(dock, false)
	player:GetAttributeChangedSignal("AFKActive"):Connect(function()
		refresh(dock, true)
	end)
	player:GetAttributeChangedSignal("AFKEarned"):Connect(function()
		local e = tonumber(player:GetAttribute("AFKEarned")) or 0
		local delta = e - lastEarned
		lastEarned = e
		if delta > 0 and active() then
			pcall(payPop, delta)
		end
		pcall(update)
	end)
	task.spawn(function()
		remote = Net.get("AFK")
	end)
	local acc, ambAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		ambAcc += dt
		if ambAcc >= 1 / 30 then
			ambAcc = 0
			local ok, err = pcall(ambientStep, os.clock())
			if not ok and not AFK._ambWarned then
				AFK._ambWarned = true
				warn("[AFK] ambiance : " .. tostring(err))
			end
		end
		if acc < 0.25 then
			return
		end
		acc = 0
		pcall(checkIdleRejoin)
		local ok, err = pcall(update)
		if not ok and not AFK._warned then
			AFK._warned = true
			warn("[AFK] " .. tostring(err))
		end
	end)
end

return AFK
