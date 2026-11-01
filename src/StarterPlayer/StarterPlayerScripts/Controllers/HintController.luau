--[[
	HintController — conseils contextuels NON bloquants (objectif : frapper avec un objet en < 30 s).
	- Étiquette "[E] PICK UP CHAIR" au-dessus de l'objet le plus proche (mains vides).
	- Bandeau discret en bas d'écran avec les commandes utiles du moment (combat ABA : combo x5, uppercut, block /
	  perfect block, dash directionnel ; pendant un combo subi : « Q = EVASIVE » ; pendant un guard break : avertissement).
	- Carte CONTRÔLES (refermable) à la première apparition de la session (si le tutoriel n'est pas terminé),
	  adaptée à l'appareil actif (clavier/souris, tactile, manette : UserInputService.PreferredInput, sinon le dernier
	  type d'entrée). Rouvrable : bouton « ? » du bandeau, touches H / ? (Maj + /), croix directionnelle haut (manette).
	API : HintController.device() -> "KBM" | "Touch" | "Gamepad" ; HintController.onDeviceChanged(fn) ;
	      HintController.showControls() / hideControls() / toggleControls()
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.Combat)
local ItemsConfig = require(Shared.Config.Items)
local UITheme = require(Shared.Modules.UITheme)

local HintController = {}
local player = Players.LocalPlayer

------------------------------------------------------------------------
-- Appareil actif
------------------------------------------------------------------------
local function lastInputDevice()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.find(last.Name, "Gamepad", 1, true) then
		return "Gamepad"
	elseif last == Enum.UserInputType.Keyboard or string.find(last.Name, "Mouse", 1, true) then
		return "KBM"
	end
	return nil
end

-- "KBM" | "Touch" | "Gamepad"
function HintController.device(): string
	if ReplicatedStorage:GetAttribute("DebugTouch") == true then
		return "Touch"
	end
	-- API récente : UserInputService.PreferredInput (Enum.PreferredInput) ; pcall si absente
	local ok, dev = pcall(function()
		local pref = UserInputService.PreferredInput
		if pref == Enum.PreferredInput.Touch then
			return "Touch"
		elseif pref == Enum.PreferredInput.Gamepad then
			return "Gamepad"
		elseif pref == Enum.PreferredInput.KeyboardAndMouse then
			return "KBM"
		end
		return nil
	end)
	if ok and dev then
		return dev
	end
	local okLast, last = pcall(lastInputDevice)
	if okLast and last then
		return last
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "KBM"
end

local deviceListeners = {}
function HintController.onDeviceChanged(fn)
	table.insert(deviceListeners, fn)
end

-- robuste : composante non numérique (environnement de test) => 255
local function byte(v)
	local n = tonumber(v)
	return n and math.clamp(math.floor(n * 255 + 0.5), 0, 255) or 255
end
local function hexOf(c)
	return string.format("#%02X%02X%02X", byte(c.R), byte(c.G), byte(c.B))
end
local KEY = hexOf(UITheme.Colors.Yellow)
-- "CLICK: punch" -> touche en jaune + action en blanc
local function chips(list)
	local parts = {}
	for _, pair in ipairs(list) do
		table.insert(parts, '<font color="' .. KEY .. '">' .. pair[1] .. '</font> ' .. pair[2])
	end
	return table.concat(parts, "   ")
end

------------------------------------------------------------------------
-- Carte des contrôles (vérifiés dans CombatController / RunController / ShiftLockController / MobileController)
------------------------------------------------------------------------
local CONTROLS = {
	KBM = {
		Title = "KEYBOARD & MOUSE",
		Reopen = "Press H or ? to reopen",
		Rows = {
			{ "CLICK x5", "M1 combo (hold to chain)" },
			{ "SPACE + 5th", "uppercut" },
			{ "F", "block (tap just before a hit = PERFECT)" },
			{ "Q + WASD", "directional dash" },
			{ "Q (when hit)", "EVASIVE: break a combo" },
			{ "1  2  3", "character abilities" },
			{ "G", "transform / ultimate" },
			{ "E", "pick up / drop item" },
			{ "R", "throw held item" },
			{ "W W", "run" },
			{ "SHIFT", "shift-lock camera" },
		},
	},
	Touch = {
		Title = "TOUCH",
		Reopen = "Tap ? to reopen",
		Rows = {
			{ "HIT x5", "M1 combo" },
			{ "JUMP + 5th HIT", "uppercut" },
			{ "BLOCK", "hold to guard (tap just before a hit = PERFECT)" },
			{ "DASH", "dash (joystick = direction)" },
			{ "DASH (when hit)", "EVASIVE: break a combo" },
			{ "1  2  3", "character abilities" },
			{ "OT / ULT", "transform / ultimate" },
			{ "PICK UP", "grab a nearby item" },
			{ "THROW", "throw the held item" },
		},
	},
	Gamepad = {
		Title = "GAMEPAD",
		Reopen = "D-pad UP to reopen",
		Rows = {
			{ "R2 x5", "M1 combo" },
			{ "A + 5th R2", "uppercut" },
			{ "L2", "block (tap just before a hit = PERFECT)" },
			{ "B", "dash (stick = direction)" },
			{ "B (when hit)", "EVASIVE: break a combo" },
			{ "L1", "transform / ultimate" },
			{ "X", "pick up / drop item" },
			{ "Y", "throw held item" },
			{ "L3", "run" },
		},
	},
}

local cardGui, cardRoot, cardList, cardTitle, cardFoot
local cardDevice

local function fillCard(dev)
	cardDevice = dev
	local def = CONTROLS[dev] or CONTROLS.KBM
	for _, ch in ipairs(cardList:GetChildren()) do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	cardTitle.Text = "CONTROLS  -  " .. def.Title
	cardFoot.Text = def.Reopen
	for i, row in ipairs(def.Rows) do
		local r = UITheme.new("Frame", { Name = "Row" .. i, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 25), LayoutOrder = i, Parent = cardList })
		local key = UITheme.new("Frame", {
			Name = "Key",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(150, 22),
			BackgroundColor3 = UITheme.Colors.Yellow,
			Parent = r,
		})
		UITheme.corner(key, 4)
		UITheme.stroke(key, 2, UITheme.Colors.Ink, true)
		UITheme.bevel(key, 0.7, 0.72)
		UITheme.label({ Text = row[1], AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.new(1, -10, 0, 12), TextColor3 = UITheme.Colors.Ink, Stroke = false, Parent = key })
		UITheme.label({
			Text = row[2],
			Body = true,
			TextScaled = false,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(162, 0),
			Size = UDim2.new(1, -162, 1, 0),
			Stroke = 1.5,
			Parent = r,
		})
	end
end

function HintController.showControls()
	if not cardRoot then
		return
	end
	local dev = HintController.device()
	if dev ~= cardDevice then
		fillCard(dev)
	end
	if not cardRoot.Visible then
		cardRoot.Visible = true
		UITheme.pop(cardRoot, 1.05)
	end
end

function HintController.hideControls()
	if cardRoot then
		cardRoot.Visible = false
	end
end

function HintController.toggleControls()
	if cardRoot and cardRoot.Visible then
		HintController.hideControls()
	else
		HintController.showControls()
	end
end

local function buildCard(pg)
	cardGui = Instance.new("ScreenGui")
	cardGui.Name = "ControlsCard"
	cardGui.ResetOnSpawn = false
	cardGui.IgnoreGuiInset = true
	cardGui.DisplayOrder = 6 -- sous la sélection de perso (8) et les panneaux Meta (7)
	cardGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	cardGui.Parent = pg
	cardRoot = UITheme.panel({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 420),
		Accent = UITheme.Colors.Yellow,
		Visible = false,
		Parent = cardGui,
	})
	-- échelle selon l'écran (téléphone : plus petit, jamais illisible) ; garde contre une taille non numérique
	local sc = UITheme.new("UIScale", { Name = "AutoScale", Parent = cardRoot })
	local function rescale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize
		local w, h = vp and tonumber(vp.X), vp and tonumber(vp.Y)
		if not w or not h or w <= 0 or h <= 0 then
			w, h = 1280, 720
		end
		local v = math.clamp(math.min((h - 40) / 440, (w - 32) / 540), 0.5, 1.15)
		sc:SetAttribute("Base", v)
		sc.Scale = v
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	-- souris libérée même en shift-lock
	UITheme.new("TextButton", { Name = "ModalMouse", Modal = true, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Parent = cardRoot })
	cardTitle = UITheme.label({ Name = "Title", Text = "CONTROLS", TextColor3 = UITheme.Colors.Yellow, Position = UDim2.fromOffset(18, 16), Size = UDim2.new(1, -36, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3, Parent = cardRoot })
	cardList = UITheme.new("Frame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -36, 1, -112), Parent = cardRoot })
	UITheme.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3), Parent = cardList })
	cardFoot = UITheme.label({ Name = "Foot", Text = "", Body = true, TextScaled = false, TextSize = 14, TextColor3 = UITheme.Colors.Muted, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -18), Size = UDim2.new(1, -200, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5, Parent = cardRoot })
	local ok = UITheme.button({ Name = "GotIt", Text = "GOT IT!", Color = UITheme.Colors.Green, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -14), Size = UDim2.fromOffset(150, 44), Parent = cardRoot })
	ok.Activated:Connect(HintController.hideControls)
	fillCard(HintController.device())
end

function HintController.init()
	-- étiquette au-dessus de l'objet : [E] PICK UP CHAIR!
	local tag = Instance.new("BillboardGui")
	tag.Name = "PickupHint"
	tag.Size = UDim2.fromOffset(250, 44)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.Enabled = false
	tag.Parent = player:WaitForChild("PlayerGui")
	local pill = UITheme.new("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UITheme.Colors.PanelDark,
		BackgroundTransparency = 0.08,
		Parent = tag,
	})
	UITheme.corner(pill, 4)
	UITheme.stroke(pill, 3, UITheme.Colors.Ink, true)
	UITheme.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10), Parent = pill })
	UITheme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = pill,
	})
	local keyBox = UITheme.new("Frame", {
		Name = "Key",
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = UITheme.Colors.Yellow,
		LayoutOrder = 1,
		Parent = pill,
	})
	UITheme.corner(keyBox, 3)
	UITheme.stroke(keyBox, 2, UITheme.Colors.Ink, true)
	UITheme.bevel(keyBox, 0.78, 0.75)
	local keyLabel = UITheme.label({ Text = "E", Size = UDim2.fromScale(0.62, 0.62), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), TextColor3 = UITheme.Colors.Ink, Stroke = false, Parent = keyBox })
	local tagLabel = UITheme.label({
		Name = "Text",
		Text = "",
		Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 14,
		TextColor3 = UITheme.Colors.White,
		LayoutOrder = 2,
		Stroke = 2,
		Parent = pill,
	})
	local tagScale = UITheme.new("UIScale", { Parent = pill })

	-- bandeau des commandes (touches en jaune)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ControlsHint"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player.PlayerGui
	local barBg = UITheme.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = UITheme.Colors.PanelDark,
		BackgroundTransparency = 0.35,
		Parent = gui,
	})
	UITheme.corner(barBg, 4)
	local bs = UITheme.stroke(barBg, 2, UITheme.Colors.Ink, true)
	bs.Transparency = 0.3
	UITheme.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12), Parent = barBg })
	UITheme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = barBg,
	})
	-- bouton « ? » : rouvre la carte des contrôles
	local help = UITheme.button({ Name = "Help", Text = "?", Color = UITheme.Colors.Yellow, TextColor3 = UITheme.Colors.Ink, Round = true, Size = UDim2.fromOffset(22, 22), LayoutOrder = 0, Parent = barBg })
	help.Activated:Connect(HintController.toggleControls)
	local bar = UITheme.label({
		Name = "Text",
		Body = true,
		RichText = true,
		TextScaled = false,
		TextSize = 15,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = UITheme.Colors.White,
		Stroke = 1.5,
		LayoutOrder = 1,
		Parent = barBg,
	})
	local barScale = UITheme.new("UIScale", { Parent = barBg })
	local function rescale()
		local cam = workspace.CurrentCamera
		local w = cam and tonumber(cam.ViewportSize.X) or 1200
		barScale.Scale = math.clamp(w / 1100, 0.6, 1.2)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- carte des contrôles
	buildCard(player.PlayerGui)
	local lastDev = HintController.device()
	local function checkDevice()
		local dev = HintController.device()
		if dev == lastDev then
			return
		end
		lastDev = dev
		if cardRoot.Visible then
			fillCard(dev)
		else
			cardDevice = nil -- reconstruite à la prochaine ouverture
		end
		for _, fn in ipairs(deviceListeners) do
			task.spawn(fn, dev)
		end
	end
	pcall(function()
		UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(checkDevice)
	end)
	UserInputService.LastInputTypeChanged:Connect(checkDevice)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local k = input.KeyCode
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		if k == Enum.KeyCode.H or k == Enum.KeyCode.Question or (k == Enum.KeyCode.Slash and shift) or k == Enum.KeyCode.DPadUp then
			HintController.toggleControls()
		end
	end)
	-- première apparition de la session : carte affichée (sauf tutoriel déjà terminé ; attribut posé par TutorialService)
	task.spawn(function()
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		local t0 = os.clock()
		while player:GetAttribute("TutorialDone") == nil and os.clock() - t0 < 8 do
			task.wait(0.25)
		end
		task.wait(1)
		if player:GetAttribute("TutorialDone") ~= true then
			HintController.showControls()
		end
	end)

	local lastBest
	task.spawn(function()
		while true do
			task.wait(0.15)
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local held = c and c:GetAttribute("HeldItem")
			local dev = HintController.device()
			local touch = dev == "Touch"
			local pad = dev == "Gamepad"
			-- combat ABA : rappels contextuels (combo subi -> EVASIVE ; guard break ; sinon les commandes de base)
			local sn = workspace:GetServerTimeNow()
			local stunned = c ~= nil and sn < (c:GetAttribute("StunUntil") or 0)
			local broken = c ~= nil and sn < (c:GetAttribute("GuardBrokenUntil") or 0)
			local evasiveReady = stunned and not broken and sn >= (c:GetAttribute("CDEvasive") or 0)
				and sn >= (c:GetAttribute("KnockdownUntil") or 0) and not c:GetAttribute("PendingKO")
			if broken then
				bar.Text = chips({ { "GUARD BROKEN!", "you can't block for a moment" } })
			elseif evasiveReady then
				bar.Text = touch and chips({ { "DASH", "EVASIVE: break free!" } })
					or pad and chips({ { "B", "EVASIVE: break free!" } })
					or chips({ { "Q", "EVASIVE: break free!" } })
			elseif held then
				bar.Text = touch and chips({ { "HIT", "swing" }, { "THROW", "throw it" }, { "GRAB", "drop" } })
					or pad and chips({ { "R2", "swing" }, { "Y", "throw" }, { "X", "drop" } })
					or chips({ { "CLICK", "swing" }, { "R", "throw" }, { "E", "drop" } })
			else
				bar.Text = touch and chips({ { "HIT x5", "combo" }, { "JUMP + 5th HIT", "uppercut" }, { "BLOCK", "guard" }, { "DASH", "dash" }, { "GRAB", "pick up" } })
					or pad and chips({ { "R2 x5", "combo" }, { "A + 5th", "uppercut" }, { "L2", "block" }, { "B", "dash" }, { "X", "pick up" } })
					or chips({ { "CLICK x5", "combo" }, { "SPACE + 5th", "uppercut" }, { "F", "block (timed = perfect)" }, { "Q + WASD", "dash" }, { "E", "pick up" }, { "H", "controls" } })
			end
			-- objet le plus proche
			local best, bestDist = nil, CombatConfig.PickupRange
			if root and not held then
				for _, m in ipairs(workspace.ActiveItems:GetChildren()) do
					local h = m.PrimaryPart
					if h then
						local d = (h.Position - root.Position).Magnitude
						if d < bestDist then
							best, bestDist = m, d
						end
					end
				end
			end
			if best then
				local cfg = ItemsConfig[best:GetAttribute("ItemId") or ""]
				tag.Adornee = best.PrimaryPart
				keyLabel.Text = touch and "+" or pad and "X" or "E"
				tagLabel.Text = (touch and "GRAB " or "PICK UP ") .. string.upper(cfg and cfg.DisplayName or best.Name) .. "!"
				if best ~= lastBest then
					lastBest = best
					tagScale.Scale = 0.5
					UITheme.tween(tagScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
				end
				tag.Enabled = true
			else
				tag.Enabled = false
				lastBest = nil
			end
		end
	end)
end

return HintController
