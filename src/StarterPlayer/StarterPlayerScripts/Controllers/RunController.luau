--[[
	RunController — courir.
	PC : appuyer deux fois sur W (ou Z sur clavier AZERTY : c'est la même touche physique) -> on court
	tant qu'on avance ; on s'arrête en lâchant les touches de déplacement, en bloquant ou si on est étourdi.
	Manette : clic du stick gauche (L3) = basculer. Mobile : bouton « RUN » (bascule).
	La vitesse est appliquée par le serveur (modificateur "Run", Config/Combat.Run) ; l'animation de course est
	une pose dynamique de ProcAnim (attribut Running). Ici : entrées + petits nuages de poussière aux pieds.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.Combat)
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)
local CartoonFX = require(Shared.Modules.CartoonFX)
local UITheme = require(Shared.Modules.UITheme)

local RunController = {}
RunController.Priority = 20

local player = Players.LocalPlayer
local wanted = false
local lastTap = -10
local stillSince = nil
local button

local function character()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return c, hum
	end
end

function RunController.set(on: boolean)
	if wanted == on then
		return
	end
	wanted = on
	Net.get("Run"):FireServer(on)
	if button then
		button.BackgroundColor3 = on and Color3.fromRGB(80, 200, 255) or Color3.fromRGB(45, 50, 70)
	end
	local c = character()
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if on and root then
		CartoonFX.puff(root.Position - Vector3.new(0, 2.6, 0), 0.7)
		CartoonFX.speedLines(0.2)
	end
end

function RunController.toggle()
	RunController.set(not wanted)
end

function RunController.init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.Up then
			local t = os.clock()
			if t - lastTap <= CombatConfig.Run.DoubleTapWindow then
				RunController.set(true)
				lastTap = -10
			else
				lastTap = t
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
			RunController.toggle()
		end
	end)

	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local gui = Instance.new("ScreenGui")
		gui.Name = "RunButton"
		gui.ResetOnSpawn = false
		gui.Parent = player:WaitForChild("PlayerGui")
		button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = UDim2.new(1, -14, 0.36, 48)
		button.Size = UDim2.fromOffset(64, 40)
		button.FontFace = UITheme.Display
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundColor3 = Color3.fromRGB(45, 50, 70)
		button.Parent = gui
		UITheme.corner(button, 6)
		UITheme.stroke(button, 3, UITheme.Colors.Ink, true)
		UITheme.bevel(button)
		UITheme.shine(button)
		UITheme.label({ Name = "Label", Text = "RUN", Size = UDim2.fromScale(0.8, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Stroke = 2, ZIndex = 2, Parent = button })
		button.Activated:Connect(function()
			UITheme.click()
			RunController.toggle()
		end)
	end

	-- arrêt automatique (PC/manette : quand on n'avance plus ; tout le monde : block, étourdi, refus du serveur)
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	RunService.Heartbeat:Connect(function()
		local c, hum = character()
		if not wanted then
			return
		end
		if not c then
			wanted = false
			return
		end
		local stunned = workspace:GetServerTimeNow() < (c:GetAttribute("StunUntil") or 0)
		if stunned or c:GetAttribute("Blocking") then
			RunController.set(false)
			return
		end
		if not touchOnly then
			if hum.MoveDirection.Magnitude < 0.1 then
				stillSince = stillSince or os.clock()
				if os.clock() - stillSince > 0.2 then
					RunController.set(false)
				end
			else
				stillSince = nil
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		wanted = false
		if button then
			button.BackgroundColor3 = Color3.fromRGB(45, 50, 70)
		end
	end)

	-- nuages de poussière aux pieds de tous ceux qui courent
	task.spawn(function()
		while true do
			task.wait(0.13)
			for _, c in ipairs(Hitbox.characters()) do
				if c:GetAttribute("Running") then
					local hum = c:FindFirstChildOfClass("Humanoid")
					local root = c:FindFirstChild("HumanoidRootPart")
					if hum and root and hum.MoveDirection.Magnitude > 0.1 and hum.FloorMaterial ~= Enum.Material.Air then
						CartoonFX.puff(root.Position - Vector3.new(0, 2.7, 0) - hum.MoveDirection * 1.2, 0.35)
					end
				end
			end
		end
	end)
end

return RunController
