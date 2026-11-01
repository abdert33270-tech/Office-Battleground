--[[
	TutorialController — liste d'étapes du premier match (Config/Tutorial), NON bloquante, en haut au centre.
	Le serveur (TutorialService) valide les étapes et envoie l'état par le remote « Tutorial » ; ici on ne fait qu'afficher :
		- panneau « TRAINING » : cases à cocher, compteur (3/5), consigne de l'étape en cours selon l'appareil
		  (ctx.HintController.device() : "KBM" | "Touch" | "Gamepad"), bouton SKIP (deux appuis : SKIP -> SURE?)
		- flèches : au-dessus du mannequin / de l'objet le plus proche (BillboardGui), ou au-dessus du bouton concerné
		  (HUD Slot1 / SlotQ, MobileControls A1 / Dash / Block / Grab, MetaDock Daily) en suivant sa position à l'écran
		- étape optionnelle DAILY : signalée au serveur ("Daily") quand le panneau Meta.DailyPanel s'ouvre
		- fin : « TRAINING COMPLETE! » + récompense, puis le panneau disparaît. Profil terminé : rien n'est affiché.
	Petit écran (téléphone) : seulement l'en-tête et l'étape en cours.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local UIKit = require(script.Parent.UIKit)
local UITheme = UIKit.Theme
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TutorialCfg = require(Shared:WaitForChild("Config"):WaitForChild("Tutorial"))
local Net = require(Shared:WaitForChild("Modules"):WaitForChild("Net"))

local TutorialController = {}
TutorialController.Priority = 60

local player = Players.LocalPlayer
local C = UITheme.Colors

local ctxRef
local remote
local state = nil -- dernier état reçu du serveur
local gui, root, rows, headerTitle, skipBtn
local worldArrow, worldLabel, screenArrow, screenLabel
local dailySent = false
local hideToken = 0

local function device()
	local H = ctxRef and ctxRef.HintController
	if H and type(H.device) == "function" then
		local ok, d = pcall(H.device)
		if ok and type(d) == "string" then
			return d
		end
	end
	return UIKit.isTouch() and "Touch" or "KBM"
end

local function small()
	return UITheme.isSmallScreen()
end

---------------------------------------------------------------- construction
local function pointer(parent, z)
	-- pointeur vers le bas : pastille + losange (pointe) dessous
	local holder = UIKit.new("Frame", { Name = "Arrow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = parent })
	local tip = UIKit.new("Frame", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = C.Yellow,
		ZIndex = z,
		Parent = holder,
	})
	UITheme.stroke(tip, 3, C.Ink, true)
	local pill = UIKit.new("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0, 0, 0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Yellow,
		ZIndex = z + 1,
		Parent = holder,
	})
	UITheme.corner(pill, 4)
	UITheme.stroke(pill, 3, C.Ink, true)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = pill })
	local label = UITheme.label({
		Name = "Text",
		Text = "",
		TextScaled = false,
		TextSize = 12,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		TextColor3 = C.Ink,
		Stroke = false,
		ZIndex = z + 2,
		Parent = pill,
	})
	return holder, label
end

local function build()
	gui = UIKit.screen("Tutorial", 6)
	gui.Enabled = false
	root = UIKit.panel({
		Name = "Checklist",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Accent = C.Yellow,
		Parent = gui,
	})
	local sc = UIKit.new("UIScale", { Name = "AutoScale", Parent = root })
	local function rescale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize
		local h = vp and tonumber(vp.Y) or 900
		local w = vp and tonumber(vp.X) or 1600
		local v = math.clamp(math.min(h / 760, w / 900), 0.72, 1.1)
		sc:SetAttribute("Base", v)
		sc.Scale = v
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = root })
	UIKit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = root })

	local header = UIKit.new("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 0, Parent = root })
	headerTitle = UITheme.label({ Name = "Title", Text = "TRAINING", TextColor3 = C.Yellow, Size = UDim2.new(1, -78, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2.5, Parent = header })
	local R = TutorialCfg.Reward
	UITheme.label({
		Name = "Reward",
		Text = string.format("Reward: $%d + %d Mystery Briefcase", R.Cash, R.Crates),
		Body = true,
		TextScaled = false,
		TextSize = 13,
		TextColor3 = C.Cash,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, -78, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = 1.5,
		Parent = header,
	})
	skipBtn = UIKit.button({ Name = "Skip", Text = "SKIP", Color = C.Slot, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(70, 28), Parent = header })
	local armed = 0
	skipBtn.Activated:Connect(function()
		local lbl = skipBtn:FindFirstChild("Label")
		if os.clock() - armed > 3 then
			armed = os.clock()
			if lbl then
				lbl.Text = "SURE?"
			end
			skipBtn.BackgroundColor3 = C.Red
			task.delay(3, function()
				if os.clock() - armed >= 2.9 and skipBtn.Parent then
					if lbl then
						lbl.Text = "SKIP"
					end
					skipBtn.BackgroundColor3 = C.Slot
				end
			end)
			return
		end
		armed = 0
		if remote then
			remote:FireServer("Skip")
		end
		gui.Enabled = false
	end)

	rows = {}
	for i, s in ipairs(TutorialCfg.Steps) do
		local row = UIKit.new("Frame", { Name = s.Id, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = root })
		local box = UIKit.new("Frame", { Name = "Box", Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.PanelDark, Parent = row })
		UITheme.corner(box, 3)
		UITheme.stroke(box, 2, C.Ink, true)
		local check = UIKit.new("Frame", { Name = "Check", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = box })
		UITheme.icon("Check", check, C.White)
		local title = UITheme.label({
			Name = "Title",
			Text = s.Title,
			Body = true,
			TextScaled = false,
			TextSize = 15,
			Position = UDim2.fromOffset(26, 0),
			Size = UDim2.new(1, -26, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Stroke = 1.5,
			Parent = row,
		})
		local sub = UITheme.label({
			Name = "Sub",
			Text = "",
			Body = true,
			TextScaled = false,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = C.Paper,
			Position = UDim2.fromOffset(26, 22),
			Size = UDim2.new(1, -26, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = false,
			Stroke = 1.5,
			Parent = row,
		})
		rows[s.Id] = { row = row, box = box, check = check, title = title, sub = sub }
	end

	-- flèche dans le monde (mannequin, objet)
	worldArrow = UIKit.new("BillboardGui", {
		Name = "TutorialArrow",
		Size = UDim2.fromOffset(180, 60),
		StudsOffsetWorldSpace = Vector3.new(0, 4, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Enabled = false,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local _, wl = pointer(worldArrow, 1)
	worldLabel = wl
	-- flèche à l'écran (au-dessus d'un bouton)
	screenArrow = UIKit.new("Frame", { Name = "ScreenArrow", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(180, 60), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = gui })
	local _, sl = pointer(screenArrow, 30)
	screenLabel = sl
end

---------------------------------------------------------------- affichage
local function stepText(s)
	local t = s.Text or {}
	return t[device()] or t.KBM or ""
end

local function refresh()
	if not root or not state then
		return
	end
	local steps = state.steps or {}
	local compact = small()
	for _, s in ipairs(TutorialCfg.Steps) do
		local r = rows[s.Id]
		local n = math.min(s.Goal, tonumber(steps[s.Id]) or 0)
		local done = n >= s.Goal or (state.finished and not s.Optional)
		local cur = (state.current == s.Id) or (s.Optional and state.finished and not done)
		r.check.Visible = done
		r.box.BackgroundColor3 = done and C.Green or (cur and C.Yellow or C.PanelDark)
		local label = s.Title .. (s.Optional and "  (OPTIONAL)" or "")
		if s.Goal > 1 and not done then
			label ..= "  " .. n .. "/" .. s.Goal
		end
		r.title.Text = label
		r.title.TextColor3 = done and C.Muted or (cur and C.Yellow or C.White)
		r.sub.Text = stepText(s)
		r.sub.Visible = cur and not done
		r.row.Visible = not compact or cur or (s.Optional and not done and not state.current)
	end
	if state.finished then
		headerTitle.Text = "TRAINING COMPLETE!"
		headerTitle.TextColor3 = C.Green
		skipBtn.Visible = false
	else
		headerTitle.Text = "TRAINING"
		headerTitle.TextColor3 = C.Yellow
		skipBtn.Visible = true
	end
end

local function toast(text, color)
	local H = ctxRef and ctxRef.HUDController
	if H and type(H.toast) == "function" then
		pcall(H.toast, text, color, 4)
	end
end

local function applyState(st)
	if type(st) ~= "table" then
		return
	end
	local prev = state
	state = st
	if st.finished then
		hideToken += 1
		local my = hideToken
		gui.Enabled = true
		refresh()
		UITheme.pop(root, 1.08)
		local R = st.reward or TutorialCfg.Reward
		toast(string.format("TRAINING COMPLETE!  +$%d  +%d MYSTERY BRIEFCASE", R.Cash or 0, R.Crates or 0), C.Gold)
		task.delay(8, function()
			if hideToken == my then
				gui.Enabled = false
			end
		end)
		return
	end
	if not st.active then
		hideToken += 1
		gui.Enabled = false
		return
	end
	local wasHidden = not gui.Enabled
	gui.Enabled = true
	refresh()
	if wasHidden then
		UITheme.pop(root, 1.05)
	elseif prev and prev.current ~= st.current and rows[st.current] then
		UITheme.pop(rows[st.current].box, 1.4)
	end
end

---------------------------------------------------------------- flèches
local function findIn(guiName, objName)
	local pg = player:FindFirstChild("PlayerGui")
	local g = pg and pg:FindFirstChild(guiName)
	if not g or (g:IsA("ScreenGui") and not g.Enabled) then
		return nil
	end
	local o = g:FindFirstChild(objName, true)
	if o and o:IsA("GuiObject") and o.Visible and o.AbsoluteSize.X > 0 then
		return o, g
	end
	return nil
end

local function nearestItem(root)
	local folder = workspace:FindFirstChild("ActiveItems")
	if not folder or not root then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, m in ipairs(folder:GetChildren()) do
		local h = m:IsA("Model") and m.PrimaryPart
		if h and not m:GetAttribute("HeldBy") then
			local d = (h.Position - root.Position).Magnitude
			if d < bestD then
				best, bestD = h, d
			end
		end
	end
	return best
end

local function dummyPart()
	local folder = workspace:FindFirstChild("Dummies")
	for _, d in ipairs(folder and folder:GetChildren() or {}) do
		local hum = d:FindFirstChildOfClass("Humanoid")
		local head = d:FindFirstChild("Head") or d.PrimaryPart
		if hum and hum.Health > 0 and head then
			return head
		end
	end
	return nil
end

-- cible de l'étape en cours : ("world", part, texte) | ("screen", guiObject, texte, screenGui) | nil
local function target()
	if not state or not gui.Enabled then
		return nil
	end
	local id = state.current
	if not id then
		local daily = TutorialCfg.ById.Daily
		if state.finished and daily and (tonumber((state.steps or {}).Daily) or 0) < daily.Goal then
			id = "Daily"
		else
			return nil
		end
	end
	local dev = device()
	local touch = dev == "Touch"
	local c = player.Character
	if id == "HitDummy" then
		local p = dummyPart()
		return p and "world" or nil, p, "HIT ME!"
	elseif id == "Block" then
		if touch then
			local o, g = findIn("MobileControls", "Block")
			return o and "screen" or nil, o, "HOLD!", g
		end
	elseif id == "Dash" then
		local o, g
		if touch then
			o, g = findIn("MobileControls", "Dash")
		else
			o, g = findIn("HUD", "SlotQ")
		end
		return o and "screen" or nil, o, dev == "Gamepad" and "B" or touch and "TAP!" or "Q", g
	elseif id == "Ability" then
		local o, g
		if touch then
			o, g = findIn("MobileControls", "A1")
		else
			o, g = findIn("HUD", "Slot1")
		end
		return o and "screen" or nil, o, touch and "TAP!" or "PRESS 1", g
	elseif id == "Throw" then
		if c and c:GetAttribute("HeldItem") then
			if touch then
				local o, g = findIn("MobileControls", "Grab")
				return o and "screen" or nil, o, "THROW!", g
			end
			return nil
		end
		local p = nearestItem(c and c:FindFirstChild("HumanoidRootPart"))
		return p and "world" or nil, p, "PICK ME UP!"
	elseif id == "Daily" then
		local o, g = findIn("MetaDock", "Daily")
		return o and "screen" or nil, o, "DAILY!", g
	end
	return nil
end

local function stepArrows()
	local kind, obj, text, ownerGui = target()
	local bob = math.sin(os.clock() * 5) * 0.35
	if kind == "world" then
		worldArrow.Adornee = obj
		worldArrow.StudsOffsetWorldSpace = Vector3.new(0, 3.6 + bob, 0)
		worldLabel.Text = text
		worldArrow.Enabled = true
	else
		worldArrow.Enabled = false
		worldArrow.Adornee = nil
	end
	if kind == "screen" then
		local pos = obj.AbsolutePosition
		-- repère de notre ScreenGui (IgnoreGuiInset = true) : on ajoute l'encart si l'autre ne l'ignore pas
		if ownerGui and ownerGui:IsA("ScreenGui") and not ownerGui.IgnoreGuiInset then
			pos += (GuiService:GetGuiInset())
		end
		local x = pos.X + obj.AbsoluteSize.X / 2
		local y = pos.Y - 4 + bob * 12
		screenArrow.Position = UDim2.fromOffset(x, y)
		screenLabel.Text = text
		screenArrow.Visible = true
	else
		screenArrow.Visible = false
	end
end

---------------------------------------------------------------- init
function TutorialController.init(ctx)
	ctxRef = ctx
	build()
	local H = ctx.HintController
	if H and type(H.onDeviceChanged) == "function" then
		H.onDeviceChanged(refresh)
	end
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	task.spawn(function()
		remote = Net.get("Tutorial")
		remote.OnClientEvent:Connect(applyState)
		remote:FireServer("State")
	end)
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(stepArrows)
		if not ok and not TutorialController._warned then
			TutorialController._warned = true
			warn("[TutorialController] " .. tostring(err))
		end
	end)
	-- étape optionnelle : ouverture du panneau DAILY (MetaDock « Meta » / « DailyPanel »)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if remote and state and state.active and not dailySent then
				local pg = player:FindFirstChild("PlayerGui")
				local meta = pg and pg:FindFirstChild("Meta")
				local panel = meta and meta:FindFirstChild("DailyPanel", true)
				if panel and panel:IsA("GuiObject") and panel.Visible then
					dailySent = true
					remote:FireServer("Daily")
				end
			end
		end
	end)
end

return TutorialController
