--[[
	MobileController — boutons tactiles (uniquement sur écran tactile), placés pour le pouce droit.
	M1 (gros, devient USE avec un objet), attaques 1/2/3 (icône du type d'attaque), OT (transformation, jauge en %),
	ULT (apparaît quand l'attribut UltReady du perso est vrai : même action que G -> CombatController.transform()),
	DASH (direction = joystick ; pendant un combo subi : EVASIVE, le bouton affiche « EVADE! »), BLOCK (maintenu ;
	appui juste avant le coup = PERFECT BLOCK), et UN bouton contextuel : PICK UP (objet proche) / THROW (objet en main) ;
	appui long = DROP. Combat ABA : HIT x5 ; maintenir SAUT + 5e HIT = UPPERCUT ; DASH avant + HIT = DASH STRIKE.
	Appelle ctx.CombatController : attack, pickup, throw, dash, setBlock, ability, transform.
	Les boutons n'existent que si l'appareil est tactile (test PC : ReplicatedStorage.DebugTouch = true).
	Taille : échelle bornée pour que le plus petit bouton fasse toujours >= 44 px à l'écran.
	Disposition (passe mobile) : arc du pouce droit centré sur le bouton SAUT de Roblox (lu dans
	PlayerGui.TouchGui...JumpButton, sinon règle de Roblox : petit écran (côté min <= 500) 70 px à (-95,-90) du coin,
	sinon 120 px à (-170,-210)). Positions = centre du saut + décalage en « unités design » x échelle k.
	  arc intérieur : HIT (gros) à gauche du saut, attaques 1 / 2 / 3 en quart de cercle autour ;
	  arc extérieur : PICK UP, BLOCK, OT (ULT prend la place d'OT quand l'ultime est prêt) ; DASH juste au-dessus du saut.
	Zones laissées libres (vérifié à 667x375 et 844x390, k = 0,7) : tout le bord gauche jusqu'à 330 px du bord droit
	(joystick dynamique = 40 % gauche, dock fusionné = 260x140 en bas à gauche), la colonne RUN / LOCK
	(x 14-78 px du bord droit, ~150-250 px du bas), et ~90 px en haut (HUD). Pas d'échelle utilisateur (UIScale)
	ici : les boutons sont placés au pixel près autour des commandes Roblox (ScreenGui ignoré par SettingsController).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)
local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
-- icônes d'attaque illustrées (Modules/AttackIcon) ; repli = icônes génériques
local AttackIcon
do
	local m = ReplicatedStorage.Shared.Modules:FindFirstChild("AttackIcon")
	local ok, mod = false, nil
	if m then
		ok, mod = pcall(require, m)
	end
	AttackIcon = ok and type(mod) == "table" and mod or nil
end

local Mobile = {}
Mobile.Priority = 55

local player = Players.LocalPlayer
local combat, hud
local buttons = {}

local function call(fnName, ...)
	if combat and type(combat[fnName]) == "function" then
		local ok, err = pcall(combat[fnName], ...)
		if not ok then
			warn("[Mobile] " .. fnName .. ": " .. tostring(err))
		end
	end
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

-- bouton rond ; pos = décalage depuis le coin bas-droit (centre du bouton) ; icon = type d'icône (optionnel)
local function round(parent, name, text, size, pos, color, icon)
	local b = UIKit.button({
		Name = name,
		Text = text,
		Color = color,
		Round = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, pos.X, 1, pos.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 0.08,
		Parent = parent,
	})
	if icon then
		local holder = UIKit.new("Frame", { Name = "IconHolder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(0.44, 0.44), BackgroundTransparency = 1, ZIndex = b.ZIndex + 1, Parent = b })
		holder:SetAttribute("Kind", icon)
		UIKit.icon(icon, holder, Color3.new(1, 1, 1), b.ZIndex + 1)
		b.Label.Position = UDim2.fromScale(0.5, 0.74)
		b.Label.Size = UDim2.fromScale(0.78, 0.2)
	end
	buttons[name] = b
	return b
end

local function setIcon(b, kind)
	local holder = b:FindFirstChild("IconHolder")
	if not holder or holder:GetAttribute("Kind") == kind then
		return
	end
	holder:SetAttribute("Kind", kind)
	holder:ClearAllChildren()
	UIKit.icon(kind, holder, Color3.new(1, 1, 1), b.ZIndex + 1)
end

-- icône illustrée (key = id d'attaque, "Ult:<CharId>", "Dash", "Block", "Transform", "Hit") ; repli = icône générique
local function setAttack(b, key, color, fallback)
	local holder = b:FindFirstChild("IconHolder")
	if not holder then
		return
	end
	local tag = tostring(key) .. "|" .. (color and color:ToHex() or "")
	if holder:GetAttribute("Kind") == tag then
		return
	end
	holder:SetAttribute("Kind", tag)
	holder:ClearAllChildren()
	if AttackIcon and pcall(AttackIcon.build, key, holder, { Color = color, ZIndex = b.ZIndex + 1 }) then
		return
	end
	holder:ClearAllChildren()
	UIKit.icon(fallback or "Melee", holder, Color3.new(1, 1, 1), b.ZIndex + 1)
end

-- grande icône (60 % du bouton), libellé réduit en dessous : lisible au pouce
local function bigIcon(b)
	local h = b:FindFirstChild("IconHolder")
	if not h or not AttackIcon then
		return
	end
	h.Position = UDim2.fromScale(0.5, 0.43)
	h.Size = UDim2.fromScale(0.6, 0.6)
	b.Label.Position = UDim2.fromScale(0.5, 0.85)
	b.Label.Size = UDim2.fromScale(0.7, 0.15)
end

local function nearbyItem()
	local c = player.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local items = workspace:FindFirstChild("ActiveItems")
	if not root or not items then
		return false
	end
	for _, m in ipairs(items:GetChildren()) do
		local h = m.PrimaryPart
		if h and (h.Position - root.Position).Magnitude < CombatConfig.PickupRange then
			return true
		end
	end
	return false
end

local attacksCfg
local function attackKind(id)
	if attacksCfg == nil then
		local ok, mod = pcall(require, ReplicatedStorage.Shared.Config.Attacks)
		attacksCfg = ok and mod or false
	end
	local a = attacksCfg and id and attacksCfg[id]
	return type(a) == "table" and a.Kind or "Melee"
end

function Mobile.init(ctx)
	combat = ctx.CombatController
	hud = ctx.HUDController
	if not UIKit.isTouch() then
		return
	end
	local gui = UIKit.screen("MobileControls", 4)
	local holder = UIKit.new("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(600, 600),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	-- échelle : plus petit bouton (70) * 0.7 = 49 px minimum à l'écran. Le holder est ancré au coin bas-droit :
	-- un enfant à (x, y) du coin apparaît à (x, y) * k du coin de l'écran.
	local scale = UIKit.new("UIScale", { Name = "AutoScale", Parent = holder })

	-- décalages (unités design) depuis le CENTRE du bouton saut ; tailles en unités design
	local LAYOUT = {
		M1 = { -143, -10, 118 },
		A1 = { -234, -63, 80 },
		A2 = { -171, -171, 80 },
		A3 = { -83, -229, 80 },
		Dash = { -3, -100, 70 },
		Grab = { -347, -49, 78 },
		Block = { -303, -174, 70 },
		OT = { -221, -281, 78 },
		ULT = { -221, -281, 98 }, -- même place qu'OT (OT caché quand l'ultime est prêt)
	}
	local C_ATT = Color3.fromRGB(90, 140, 255)
	local m1 = round(holder, "M1", "HIT", LAYOUT.M1[3], Vector2.zero, Color3.fromRGB(240, 70, 60), "Melee")
	local a1 = round(holder, "A1", "1", LAYOUT.A1[3], Vector2.zero, C_ATT, "Melee")
	local a2 = round(holder, "A2", "2", LAYOUT.A2[3], Vector2.zero, C_ATT, "Melee")
	local a3 = round(holder, "A3", "3", LAYOUT.A3[3], Vector2.zero, C_ATT, "Melee")
	local dash = round(holder, "Dash", "DASH", LAYOUT.Dash[3], Vector2.zero, Color3.fromRGB(120, 210, 255), "Dash")
	local block = round(holder, "Block", "BLOCK", LAYOUT.Block[3], Vector2.zero, Color3.fromRGB(160, 160, 175), "Guard")
	local grab = round(holder, "Grab", "PICK UP", LAYOUT.Grab[3], Vector2.zero, Color3.fromRGB(255, 200, 40), "Grab")
	local ot = round(holder, "OT", "OT", LAYOUT.OT[3], Vector2.zero, Color3.fromRGB(255, 140, 30), "Bolt")
	local ult = round(holder, "ULT", "ULT!", LAYOUT.ULT[3], Vector2.zero, Color3.fromRGB(255, 80, 40), "Ult")
	ult.Visible = false

	-- centre du bouton saut, en px depuis le coin bas-droit (négatif)
	local function jumpCenter(vp)
		local pg = player:FindFirstChild("PlayerGui")
		local tg = pg and pg:FindFirstChild("TouchGui")
		local jb = tg and tg:FindFirstChild("JumpButton", true)
		if jb and jb:IsA("GuiObject") and jb.AbsoluteSize.X > 0 then
			local c = jb.AbsolutePosition + jb.AbsoluteSize / 2
			-- AbsolutePosition est relative au ScreenGui ; son coin bas-droit = celui de l'écran
			local root = tg:IsA("ScreenGui") and tg.AbsoluteSize or vp
			local d = Vector2.new(c.X - root.X, c.Y - root.Y)
			if d.X < 0 and d.Y < 0 and d.X > -260 and d.Y > -320 then -- valeur plausible (sinon : règle de Roblox)
				return d, jb.AbsoluteSize.X
			end
		end
		local small = math.min(vp.X, vp.Y) <= 500
		if small then
			return Vector2.new(-60, -55), 70
		end
		return Vector2.new(-110, -150), 120
	end
	local halo
	local function rescale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(844, 390)
		local k = math.clamp(math.min(vp.Y / 560, vp.X / 1000), 0.7, 1.2)
		scale:SetAttribute("Base", k)
		scale.Scale = k
		local j = jumpCenter(vp)
		for name, l in pairs(LAYOUT) do
			local b = buttons[name]
			if b then
				-- position dans le holder (unités design) = (centre du saut en px) / k + décalage design
				b.Position = UDim2.new(1, j.X / k + l[1], 1, j.Y / k + l[2])
			end
		end
		if halo then
			halo.Position = ult.Position
		end
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	task.delay(2, rescale) -- TouchGui (bouton saut) créé par Roblox après nous
	grab.Label.TextColor3 = Color3.new(1, 1, 1)
	for _, b in ipairs({ m1, a1, a2, a3, dash, block, ot, ult }) do
		bigIcon(b)
	end
	setAttack(m1, "Hit", nil, "Melee")
	setAttack(dash, "Dash", nil, "Dash")
	setAttack(block, "Block", nil, "Guard")
	setAttack(ot, "Transform", nil, "Bolt")
	-- pastilles numérotées sur les attaques
	for i, b in ipairs({ a1, a2, a3 }) do
		UIKit.Theme.keycap({ Name = "Key", Text = tostring(i), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.16, 0.16), Size = UDim2.fromOffset(24, 22), ZIndex = b.ZIndex + 6, Parent = b })
	end
	local otStroke = ot:FindFirstChildOfClass("UIStroke")
	local ultStroke = ult:FindFirstChildOfClass("UIStroke")
	local ultScale = UIKit.new("UIScale", { Name = "Pulse", Parent = ult:FindFirstChild("Label") })
	-- halo derrière le bouton ULT (frère : dessiné dessous)
	halo = UIKit.new("Frame", { Name = "UltHalo", AnchorPoint = Vector2.new(0.5, 0.5), Position = ult.Position, Size = UDim2.fromOffset(124, 124), BackgroundColor3 = Color3.fromRGB(255, 200, 60), BackgroundTransparency = 1, Visible = false, ZIndex = 0, Parent = holder })
	UIKit.corner(halo, UDim.new(0.5, 0))

	if hud then
		hud.bindCooldown(a1, "1")
		hud.bindCooldown(a2, "2")
		hud.bindCooldown(a3, "3")
		hud.bindCooldown(dash, "Dash")
	end

	-- M1 : maintenir = enchaîner (le contrôleur de combat gère la cadence)
	local holdingM1 = false
	m1.InputBegan:Connect(function(input)
		if isPress(input) then
			holdingM1 = true
			call("attack")
		end
	end)
	m1.InputEnded:Connect(function(input)
		if isPress(input) then
			holdingM1 = false
		end
	end)
	RunService.Heartbeat:Connect(function()
		if holdingM1 then
			call("attack")
		end
	end)

	for i, b in ipairs({ a1, a2, a3 }) do
		b.Activated:Connect(function()
			call("ability", i)
		end)
	end
	dash.Activated:Connect(function()
		call("dash")
	end)
	ot.Activated:Connect(function()
		call("transform")
	end)
	-- ULT = même chose que G (le contrôleur de combat lance l'ultime si UltReady, sinon transforme)
	ult.Activated:Connect(function()
		call("transform")
	end)
	block.InputBegan:Connect(function(input)
		if isPress(input) then
			call("setBlock", true)
		end
	end)
	block.InputEnded:Connect(function(input)
		if isPress(input) then
			call("setBlock", false)
		end
	end)

	-- Bouton contextuel : tap = ramasser / lancer ; appui long (objet en main) = lâcher
	local pressT, longDone = nil, false
	grab.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end
		pressT, longDone = os.clock(), false
		local my = pressT
		task.delay(0.5, function()
			local c = player.Character
			if pressT == my and c and c:GetAttribute("HeldItem") then
				longDone = true
				call("pickup") -- avec un objet en main, pickup = lâcher
				if hud then
					hud.toast("Dropped!", Color3.fromRGB(255, 220, 90), 1.2)
				end
			end
		end)
	end)
	grab.InputEnded:Connect(function(input)
		if not isPress(input) or not pressT then
			return
		end
		pressT = nil
		if longDone then
			return
		end
		local c = player.Character
		if c and c:GetAttribute("HeldItem") then
			call("throw")
		else
			call("pickup")
		end
	end)

	-- animation continue (pulsation ULT / OT prêt)
	local ultWas = false
	RunService.RenderStepped:Connect(function()
		local c = player.Character
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 8)
		local ready = c and c:GetAttribute("Transformed") == true and c:GetAttribute("UltReady") == true
		if ready ~= ultWas then
			ultWas = ready
			ult.Visible = ready
			halo.Visible = ready
			ot.Visible = not ready -- l'ULT prend la place du bouton OT
			local ps = ult:FindFirstChild("PressScale")
			if ready and ps then
				ps.Scale = 0.3
				UIKit.tween(ps, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		if ready then
			ultScale.Scale = 1 + 0.08 * pulse
			ultStroke.Color = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 220, 60), pulse)
			halo.BackgroundTransparency = 0.35 + 0.45 * (1 - pulse)
			halo.Size = UDim2.fromOffset(112 + 18 * pulse, 112 + 18 * pulse)
		end
		local otv = c and c:GetAttribute("Overtime") or 0
		local transformed = c and c:GetAttribute("Transformed")
		otStroke.Color = (otv >= 100 and not transformed) and Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 220, 60), pulse) or UIKit.Black
	end)

	-- mise à jour des libellés
	task.spawn(function()
		while gui.Parent do
			local c = player.Character
			local held = c and c:GetAttribute("HeldItem")
			if held then
				grab.Label.Text = "THROW"
				grab.BackgroundColor3 = Color3.fromRGB(255, 120, 40)
				grab.BackgroundTransparency = 0.08
				m1.Label.Text = "USE"
			else
				local near = nearbyItem()
				grab.Label.Text = "PICK UP"
				grab.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
				grab.BackgroundTransparency = near and 0.08 or 0.5
				m1.Label.Text = "HIT"
			end
			local kit, cname = nil, nil
			if hud then
				kit, cname = hud.currentKit()
			end
			if cname then
				setAttack(ult, "Ult:" .. cname, kit and kit.Color, "Ult")
			end
			local transformed = c and c:GetAttribute("Transformed")
			local list = kit and (transformed and kit.TransAttacks or kit.Attacks) or {}
			for i, b in ipairs({ a1, a2, a3 }) do
				local id = list[i]
				if id then
					local nm = hud and hud.attackName(id) or UIKit.pretty(id)
					b.Label.Text = string.upper(string.split(nm, " ")[1])
				else
					b.Label.Text = tostring(i)
				end
				setAttack(b, id or "Hit", kit and kit.Color, attackKind(id))
				b.BackgroundColor3 = transformed and Color3.fromRGB(255, 80, 40) or (kit and kit.Color or Color3.fromRGB(90, 140, 255))
			end
			local otv = c and c:GetAttribute("Overtime") or 0
			ot.BackgroundTransparency = (otv >= 100 or transformed) and 0.05 or 0.55
			ot.Label.Text = transformed and "ON!" or (otv >= 100 and "OT!" or (math.floor(otv) .. "%"))
			local blocking = c and c:GetAttribute("Blocking")
			block.BackgroundColor3 = blocking and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(160, 160, 175)
			-- pendant un combo subi, DASH = EVASIVE (si rechargée, pas en guard break ni au sol)
			local sn = workspace:GetServerTimeNow()
			local evade = c ~= nil and sn < (c:GetAttribute("StunUntil") or 0) and sn >= (c:GetAttribute("CDEvasive") or 0)
				and sn >= (c:GetAttribute("GuardBrokenUntil") or 0) and sn >= (c:GetAttribute("KnockdownUntil") or 0)
				and not c:GetAttribute("PendingKO")
			dash.Label.Text = evade and "EVADE!" or "DASH"
			dash.BackgroundColor3 = evade and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(120, 210, 255)
			task.wait(0.15)
		end
	end)
end

return Mobile
