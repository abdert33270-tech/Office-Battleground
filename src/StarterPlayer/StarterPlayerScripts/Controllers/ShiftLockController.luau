--[[
	ShiftLockController — shift lock maison (marche même si l'option Roblox est désactivée chez le joueur).
	PC : Shift (gauche ou droite) active / désactive. Mobile : bouton « LOCK » en haut à droite de la zone des boutons.
	Quand il est actif : souris bloquée au centre, caméra décalée sur l'épaule droite, le personnage
	regarde toujours dans la direction de la caméra (idéal pour viser les coups et les lancers).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local UITheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UITheme"))

local ShiftLockController = {}
ShiftLockController.Priority = 15

local player = Players.LocalPlayer
local enabled = false
local OFFSET = Vector3.new(1.75, 0.25, 0)
local icon, mobileButton

local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

-- menus du jeu ouverts (on rend alors la souris pour pouvoir cliquer)
local MENUS = {
	{ "HUD", "Tasks" }, { "HUD", "Shop" }, { "HUD", "Combos" },
	{ "CharacterSelect", "Root" }, { "CharacterSelect", "CrateShop" }, { "Admin", "Panel" },
	{ "Meta", "DailyPanel" }, { "Meta", "CodesPanel" }, { "Meta", "SettingsPanel" },
}
local GuiService = game:GetService("GuiService")
local function menuOpen()
	if GuiService.MenuIsOpen then
		return true
	end
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return false
	end
	for _, m in ipairs(MENUS) do
		local g = pg:FindFirstChild(m[1])
		local f = g and g.Enabled and g:FindFirstChild(m[2])
		if f and f:IsA("GuiObject") and f.Visible then
			return true
		end
	end
	return false
end

local function refreshVisuals()
	if icon then
		icon.Visible = enabled and not menuOpen() and not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
	end
	if mobileButton then
		mobileButton.BackgroundColor3 = enabled and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(45, 50, 70)
	end
end

function ShiftLockController.set(on: boolean)
	enabled = on
	local hum = humanoid()
	if hum then
		hum.AutoRotate = not on
		hum.CameraOffset = on and OFFSET or Vector3.zero
	end
	if not on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
	refreshVisuals()
end

function ShiftLockController.toggle()
	ShiftLockController.set(not enabled)
end

function ShiftLockController.isEnabled()
	return enabled
end

function ShiftLockController.init()
	game:GetService("StarterPlayer").EnableMouseLockOption = false

	-- petite cible au centre de l'écran
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShiftLock"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")
	icon = Instance.new("Frame")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(8, 8)
	icon.BackgroundColor3 = Color3.new(1, 1, 1)
	icon.BorderSizePixel = 0
	icon.Rotation = 45
	icon.Visible = false
	icon.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = UITheme.Colors.Ink
	stroke.LineJoinMode = Enum.LineJoinMode.Miter
	stroke.Parent = icon
	-- petits crochets pixel autour du viseur
	for i = 0, 3 do
		local tick = Instance.new("Frame")
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		local dx, dy = (i == 0 and -1 or i == 1 and 1 or 0), (i == 2 and -1 or i == 3 and 1 or 0)
		tick.Position = UDim2.new(0.5, dx * 12, 0.5, dy * 12)
		tick.Size = UDim2.fromOffset(dx ~= 0 and 6 or 2, dy ~= 0 and 6 or 2)
		tick.BackgroundColor3 = Color3.new(1, 1, 1)
		tick.BorderSizePixel = 0
		tick.Parent = icon
	end

	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		mobileButton = Instance.new("TextButton")
		mobileButton.AnchorPoint = Vector2.new(1, 0)
		mobileButton.Position = UDim2.new(1, -14, 0.36, 0)
		mobileButton.Size = UDim2.fromOffset(64, 40)
		mobileButton.FontFace = UITheme.Display
		mobileButton.Text = ""
		mobileButton.AutoButtonColor = false
		mobileButton.Parent = gui
		UITheme.corner(mobileButton, 6)
		UITheme.stroke(mobileButton, 3, UITheme.Colors.Ink, true)
		UITheme.bevel(mobileButton)
		UITheme.shine(mobileButton)
		UITheme.label({ Name = "Label", Text = "LOCK", Size = UDim2.fromScale(0.8, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Stroke = 2, ZIndex = 2, Parent = mobileButton })
		mobileButton.Activated:Connect(function()
			UITheme.click()
			ShiftLockController.toggle()
		end)
	end
	refreshVisuals()

	ContextActionService:BindActionAtPriority("OB_ShiftLock", function(_, state)
		if state == Enum.UserInputState.Begin then
			ShiftLockController.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)

	-- chaque image : souris au centre + le perso suit la caméra
	RunService:BindToRenderStep("OB_ShiftLock", Enum.RenderPriority.Camera.Value + 3, function()
		if not enabled then
			return
		end
		-- menu ouvert : souris libre et visible, pas de viseur
		if menuOpen() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			if icon then
				icon.Visible = false
			end
			return
		end
		-- en jeu : souris cachée, seul le viseur reste au centre
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		if icon then
			icon.Visible = not (UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
		end
		local hum, root = humanoid()
		local cam = workspace.CurrentCamera
		if hum and root and cam and hum.Health > 0 and not root.Anchored and not hum.PlatformStand then
			hum.AutoRotate = false
			hum.CameraOffset = OFFSET
			local look = cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.05 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		task.wait()
		ShiftLockController.set(enabled)
	end)
end

return ShiftLockController
