--[[
	FXController — reçoit les effets du serveur (remote « FX ») et les joue via CartoonFX.
	- "Hit" : sauté si ce client l'a déjà prédit (évite les doublons chez l'attaquant).
	- "Anim" : animations procédurales des AUTRES personnages.
	- « UltFX » : on suit seulement les ultimes en cours (lanceur / cibles) pour le filtre des onomatopées.
	- Boucle d'état : vertige (DizzyUntil), sueur (PV bas), poses de maintien d'objet.

	Chaque handler est appelé dans CartoonFX.withContext(attaquant, victime, …) : les mots / chiffres créés
	n'apparaissent que si MON personnage est l'attaquant ou la victime (voir CartoonFX.isRelevant).

	PAYLOADS (le type se lit dans data.k OU data.type) — champs optionnels entre crochets :
		{ k="Hit", a, v, p, c, pw, d, [w, m, ko, r, fin, seq] }          coup complet (CartoonFX.hit)
		{ k="Block", p, v, [a, d, dir|n] }                               coup bloqué (étincelles orientées + chip)
		{ type="BlockHit", p, [dir], [character|v], [a], [d] }           idem, nouvelle forme ; dir = normale de rebond
		                                                                 (du bloqueur vers l'attaquant), déduite si absente
		{ type="GuardBreak", character, [a], [p] }                       garde brisée (aussi { k="GuardBreak", p, v, a })
		{ type="PerfectBlock", character, [a], [p] }                     parade parfaite (character = celui qui bloque)
		{ type="DashFX", character, [dir], [skipSelf] }                  dash (skipSelf = le dasheur l'a déjà joué en local)
		{ type="Knockdown", character|v, [p] }                           retombée au sol (poussière + thud)
		{ k="Parry", p, v, a }, { k="Pinned", p, v, a }, { k="WallSplat", p, v, a, [n, d] }, { k="Slam", p, [a, v, small] }
		{ k="Breaker", p, a }, { k="Slip", p, v }, { k="Heal", p, v, d, [eat] }, { k="Burn", p, v, d }
		{ k="ComboName", a, name, [v] }  (v conseillé : sinon le nom n'est visible que pour l'adversaire récent de a)
		{ k="Dash", a }, { k="Disarm", p, v }, { k="Splash", p }, { k="Spray", p, [a] }, { k="ItemFX", p, [w, s, c, r, a, v] }
		{ k="Break", p, m }, { k="Pickup", p }, { k="Throw", p }
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.Combat)
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)
local ProcAnim = require(Shared.Modules.ProcAnim)
local CartoonFX = require(Shared.Modules.CartoonFX)
local UITheme = require(Shared.Modules.UITheme)

local FXController = {}
local player = Players.LocalPlayer

local handlers = {}

local function isModel(x)
	return typeof(x) == "Instance" and x:IsA("Model")
end

function handlers.Hit(data, combat)
	if data.a and data.a == player.Character and data.seq and combat and type(combat.predicted) == "table" then
		local set = combat.predicted[data.seq]
		if type(set) == "table" and set[data.v] then
			-- déjà joué en prédiction
			return
		end
	end
	CartoonFX.hit(data)
end

function handlers.Burn(data)
	if typeof(data.p) ~= "Vector3" then
		return
	end
	local ctx = { v = data.v, avoid = { data.v } }
	CartoonFX.word(data.p, "HOT!", 0.2, "Light", ctx)
	if type(data.d) == "number" then
		CartoonFX.damageNumber(data.p, data.d, 0.5, ctx)
	end
	CartoonFX.flash(data.v, 0.05, Color3.fromRGB(255, 160, 60))
end

function handlers.Break(data)
	if typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.breakItem(data.p, data.m)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - data.p).Magnitude < 40 then
		CartoonFX.shake(0.15)
	end
end

for k, fn in pairs({
	Parry = CartoonFX.parry, Block = CartoonFX.block, WallSplat = CartoonFX.wallSplat,
	Slam = CartoonFX.slam, Breaker = CartoonFX.breaker, Pinned = CartoonFX.pinned, Slip = CartoonFX.slip, Heal = CartoonFX.heal,
}) do
	handlers[k] = fn
end

-- garde brisée : nouvelle forme { character, a } ou ancienne { p, v, a }
function handlers.GuardBreak(data)
	if isModel(data.character) then
		CartoonFX.guardBreak(data.character, data.a)
	else
		CartoonFX.guardBreak(data)
	end
end

function handlers.PerfectBlock(data)
	local c = data.character or data.v
	if isModel(c) then
		CartoonFX.perfectBlock({ character = c, a = data.a, p = data.p })
	end
end

function handlers.BlockHit(data)
	local c = data.character or data.v
	local p = data.p
	if typeof(p) ~= "Vector3" then
		local r = isModel(c) and c:FindFirstChild("HumanoidRootPart")
		p = r and (r.Position + Vector3.new(0, 1, 0)) or nil
	end
	if typeof(p) ~= "Vector3" then
		return
	end
	CartoonFX.noteEngage(data.a, c)
	CartoonFX.blockHit(p, data.dir or data.n, { a = data.a, v = c })
	if type(data.d) == "number" and data.d > 0 then
		CartoonFX.damageNumber(p, data.d, 0.2, { a = data.a, v = c })
	end
end

function handlers.DashFX(data)
	local c = data.character or data.a
	if not isModel(c) then
		return
	end
	if data.skipSelf and c == player.Character then
		return
	end
	CartoonFX.dashFX(c, data.dir)
end

function handlers.Knockdown(data)
	local c = data.character or data.v
	if isModel(c) then
		CartoonFX.knockdown(c)
	elseif typeof(data.p) == "Vector3" then
		CartoonFX.knockdown(data.p)
	end
end

function handlers.ComboName(data)
	local root = isModel(data.a) and data.a:FindFirstChild("HumanoidRootPart")
	if root then
		CartoonFX.word(root.Position + Vector3.new(0, 4, 0), data.name, 1.25, "Heavy", { a = data.a, v = data.v, prefer = "up", avoid = { data.a, data.v } })
		CartoonFX.sound("Combo", root.Position, data.a == player.Character and 1 or 0.6)
		if data.a == player.Character then
			CartoonFX.speedLines(0.35)
			CartoonFX.fovKick(6)
		end
	end
end

function handlers.Dash(data)
	if isModel(data.a) and data.a ~= player.Character then
		CartoonFX.dash(data.a)
	end
end

function handlers.Disarm(data)
	if typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.word(data.p + Vector3.new(0, 2, 0), "DISARMED!", 0.7, "Parry", { v = data.v, avoid = { data.v } })
	CartoonFX.sound("Clang", data.p, 0.9)
	CartoonFX.sparks(data.p + Vector3.new(0, 1, 0), 10, Color3.fromRGB(220, 220, 230))
end

function handlers.Splash(data)
	if typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.word(data.p, "SPLASH!", 0.6, "Splat")
	CartoonFX.sound("Water", data.p, 1)
	CartoonFX.shards(data.p, 14, { Color3.fromRGB(90, 180, 255), Color3.fromRGB(200, 235, 255) })
end

function handlers.Spray(data)
	if typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.sound("Spray", data.p, 1)
	CartoonFX.puff(data.p, 1.4)
end

-- spéciaux des objets (ItemService) : mot + son + éclats colorés + anneau optionnel
function handlers.ItemFX(data)
	if typeof(data.p) ~= "Vector3" then
		return
	end
	if data.w then
		CartoonFX.word(data.p, data.w, 0.7, "Funny")
	end
	if data.s then
		CartoonFX.sound(data.s, data.p, 1)
	end
	CartoonFX.shards(data.p, 12, data.c and { data.c, Color3.new(1, 1, 1) } or nil)
	if data.r then
		CartoonFX.shockwave(data.p, data.r, data.c)
	end
end

function handlers.Pickup(data)
	if typeof(data.p) == "Vector3" then
		CartoonFX.sound("Pickup", data.p, 0.5)
	end
end

function handlers.Throw(data)
	if typeof(data.p) == "Vector3" then
		CartoonFX.sound("Throw", data.p, 0.6)
		CartoonFX.sound("Whoosh", data.p, 0.4, 1.2)
	end
end

FXController.handlers = handlers

local blindGui
function FXController.setBlind(on: boolean)
	if not blindGui or not blindGui.Parent or not blindGui:FindFirstChild("Dark") then
		if blindGui then
			blindGui:Destroy()
		end
		blindGui = Instance.new("ScreenGui")
		blindGui.Name = "Blind"
		blindGui.ResetOnSpawn = false
		blindGui.IgnoreGuiInset = true
		blindGui.DisplayOrder = 4
		local f = Instance.new("Frame")
		f.Name = "Dark"
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 1
		f.Parent = blindGui
		local l = Instance.new("TextLabel")
		l.Name = "Text"
		l.Size = UDim2.fromScale(0.8, 0.09)
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.48)
		l.Rotation = -3
		l.BackgroundTransparency = 1
		l.FontFace = UITheme.Display
		l.TextScaled = true
		l.TextColor3 = UITheme.Colors.Yellow
		l.TextTransparency = 1
		l.Text = "CAN'T SEE!"
		l.Parent = f
		UITheme.sizeLimit(l, 54, 18)
		local ls = UITheme.stroke(l, 4)
		ls.Name = "TextStroke"
		ls.Transparency = 1
		local sub = Instance.new("TextLabel")
		sub.Name = "Sub"
		sub.Size = UDim2.fromScale(0.6, 0.035)
		sub.AnchorPoint = Vector2.new(0.5, 0)
		sub.Position = UDim2.fromScale(0.5, 0.54)
		sub.BackgroundTransparency = 1
		sub.FontFace = UITheme.Body
		sub.TextScaled = true
		sub.TextColor3 = UITheme.Colors.Muted
		sub.TextTransparency = 1
		sub.Text = "*cough* *cough*"
		sub.Parent = f
		UITheme.sizeLimit(sub, 22, 10)
		blindGui.Parent = player:WaitForChild("PlayerGui")
	end
	local f = blindGui.Dark
	local target = on and 0.08 or 1
	if math.abs(f.BackgroundTransparency - target) > 0.01 then
		game:GetService("TweenService"):Create(f, TweenInfo.new(0.15), { BackgroundTransparency = target }):Play()
		game:GetService("TweenService"):Create(f.Text, TweenInfo.new(0.15), { TextTransparency = on and 0 or 1 }):Play()
		local ts = f.Text:FindFirstChild("TextStroke")
		if ts then
			game:GetService("TweenService"):Create(ts, TweenInfo.new(0.15), { Transparency = on and 0 or 1 }):Play()
		end
		if f:FindFirstChild("Sub") then
			game:GetService("TweenService"):Create(f.Sub, TweenInfo.new(0.15), { TextTransparency = on and 0.1 or 1 }):Play()
		end
		if on then
			UITheme.wobble(f.Text, 4, -3)
		end
	end
end

function FXController.init(ctx)
	local combat = ctx.CombatController
	Net.get("FX").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		local h = handlers[data.k or data.type or ""]
		if h then
			-- contexte (attaquant, victime) pour le filtre des onomatopées
			local a = data.a
			local v = data.v
			if a == nil and v == nil then
				a = data.character
			end
			CartoonFX.withContext(a, v, h, data, combat)
		end
	end)
	-- ultimes : on suit lanceur / cibles (les mots d'une ulti qui ne me concerne pas sont masqués)
	task.spawn(function()
		local ult = Net.get("UltFX")
		ult.OnClientEvent:Connect(function(data)
			CartoonFX.noteUlt(data)
		end)
	end)
	Net.get("Anim").OnClientEvent:Connect(function(character, name)
		if character and character ~= player.Character then
			ProcAnim.play(character, name)
		end
	end)

	-- boucle d'état visuel (4 fois par seconde suffit)
	task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			local chars = Hitbox.characters()
			for _, c in ipairs(chars) do
				ProcAnim.register(c)
				local hum = c:FindFirstChildOfClass("Humanoid")
				CartoonFX.setSweat(c, hum and hum.Health > 0 and hum.Health <= CombatConfig.LowHealth)
				local dizzy = (c:GetAttribute("DizzyUntil") or 0) - now
				if dizzy > 0.05 then
					CartoonFX.dizzy(c, dizzy)
				end
			end
			local me = player.Character
			if me then
				FXController.setBlind((me:GetAttribute("BlindUntil") or 0) - now > 0)
			end
			task.wait(0.15)
		end
	end)
end

return FXController
