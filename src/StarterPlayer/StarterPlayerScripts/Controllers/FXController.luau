--[[
	FXController — reçoit les effets du serveur et les joue via CartoonFX.
	- "Hit" : sauté si ce client l'a déjà prédit (évite les doublons chez l'attaquant).
	- "Anim" : animations procédurales des AUTRES personnages.
	- Boucle d'état : vertige (DizzyUntil), sueur (PV bas), poses de maintien d'objet.
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

function handlers.Hit(data, combat)
	if data.a and data.a == player.Character and data.seq then
		local set = combat.predicted[data.seq]
		if set and set[data.v] then
			-- déjà joué en prédiction ; on ajoute seulement le K.O. si la prédiction l'a raté
			return
		end
	end
	CartoonFX.hit(data)
end

function handlers.Burn(data)
	CartoonFX.word(data.p, "HOT!", 0.2, "Light")
	CartoonFX.damageNumber(data.p, data.d, 0.8)
	CartoonFX.flash(data.v, 0.05)
end

function handlers.Break(data)
	CartoonFX.breakItem(data.p, data.m)
	CartoonFX.shake(0.15)
end

for k, fn in pairs({
	Parry = CartoonFX.parry, Block = CartoonFX.block, GuardBreak = CartoonFX.guardBreak, WallSplat = CartoonFX.wallSplat,
	Slam = CartoonFX.slam, Breaker = CartoonFX.breaker, Pinned = CartoonFX.pinned, Slip = CartoonFX.slip, Heal = CartoonFX.heal,
}) do
	handlers[k] = fn
end

function handlers.ComboName(data)
	local root = data.a and data.a:FindFirstChild("HumanoidRootPart")
	if root then
		CartoonFX.word(root.Position + Vector3.new(0, 5, 0), data.name, 1.25, "Heavy")
		CartoonFX.sound("Combo", root.Position, 1)
		if data.a == player.Character then
			CartoonFX.speedLines(0.35)
			CartoonFX.fovKick(6)
		end
	end
end

function handlers.Dash(data)
	if data.a and data.a ~= player.Character then
		CartoonFX.dash(data.a)
	end
end

function handlers.Disarm(data)
	CartoonFX.word(data.p + Vector3.new(0, 2, 0), "DISARMED!", 0.7, "Parry")
	CartoonFX.sound("Clang", data.p, 0.9)
end

function handlers.Splash(data)
	CartoonFX.word(data.p, "SPLASH!", 0.6, "Splat")
	CartoonFX.sound("Water", data.p, 1)
	CartoonFX.shards(data.p, 14, { Color3.fromRGB(90, 180, 255), Color3.fromRGB(200, 235, 255) })
end

function handlers.Spray(data)
	CartoonFX.sound("Spray", data.p, 1)
	CartoonFX.puff(data.p, 1.4)
end

-- spéciaux des objets (ItemService) : mot + son + éclats colorés + anneau optionnel
function handlers.ItemFX(data)
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
	CartoonFX.sound("Pickup", data.p, 0.5)
end

function handlers.Throw(data)
	CartoonFX.sound("Throw", data.p, 0.6)
end

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
		local h = type(data) == "table" and handlers[data.k]
		if h then
			h(data, combat)
		end
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
