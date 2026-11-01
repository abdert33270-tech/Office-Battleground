--[[
	CodesController — panneau CODES (bouton du dock) : champ de saisie + REDEEM.
	Remote "RedeemCode" : envoie le texte ; reçoit { ok, message, code, reward } (voir CodeService).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIKit = require(script.Parent.UIKit)
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Net"))

local Codes = {}
Codes.Priority = 56

local PURPLE = Color3.fromRGB(165, 95, 255)
local GREEN = Color3.fromRGB(110, 235, 120)
local RED = Color3.fromRGB(255, 110, 90)

local panel, box, result, redeemBtn
local remote
local pending = false

local function send()
	if pending or not remote then
		return
	end
	local text = string.gsub(box.Text, "%s+", "")
	if text == "" then
		result.Text = "Type a code first!"
		result.TextColor3 = RED
		return
	end
	pending = true
	redeemBtn.Label.Text = "..."
	result.Text = "Checking..."
	result.TextColor3 = UIKit.Colors.Muted
	remote:FireServer(text)
	task.delay(5, function()
		if pending then
			pending = false
			redeemBtn.Label.Text = "REDEEM"
			result.Text = "No answer, try again."
			result.TextColor3 = RED
		end
	end)
end

local function onResult(ctx, r)
	if type(r) ~= "table" then
		return
	end
	pending = false
	redeemBtn.Label.Text = "REDEEM"
	result.Text = tostring(r.message or (r.ok and "Code redeemed!" or "Invalid code"))
	result.TextColor3 = r.ok and GREEN or RED
	UIKit.pop(result, 1.12)
	if r.ok then
		box.Text = ""
		local hud = ctx.HUDController
		if hud and hud.toast then
			pcall(hud.toast, result.Text, GREEN)
		end
	else
		UIKit.Theme.wobble(box, 4)
	end
end

function Codes.init(ctx)
	local dock = ctx.MetaDockController
	if not dock then
		warn("[Codes] MetaDockController manquant")
		return
	end
	local p, body = dock.panel("CodesPanel", "CODES", PURPLE, Vector2.new(470, 270), "glyph:#")
	panel = p
	local hint = UIKit.label({ Text = "Got a code? Type it below for free Cash & cases!", Font = UIKit.Body, Size = UDim2.new(1, 0, 0, 16), TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, ZIndex = 22 })
	hint.Parent = body
	local field = UIKit.new("Frame", { Name = "Field", BackgroundColor3 = UIKit.Colors.Paper, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 52), ZIndex = 22, Parent = body })
	UIKit.corner(field, UDim.new(0, 6))
	UIKit.stroke(field, 3, UIKit.Black, true)
	box = UIKit.new("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = Color3.fromRGB(160, 150, 140),
		Text = "",
		FontFace = UIKit.Theme.Display,
		TextColor3 = UIKit.Colors.Ink,
		TextScaled = true,
		Position = UDim2.new(0, 12, 0.22, 0),
		Size = UDim2.new(1, -24, 0.56, 0),
		ZIndex = 23,
		Parent = field,
	})
	UIKit.Theme.sizeLimit(box, 26, 8)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > 30 then
			box.Text = string.sub(box.Text, 1, 30)
		end
	end)
	redeemBtn = UIKit.button({ Name = "Redeem", Text = "REDEEM", Color = Color3.fromRGB(70, 200, 90), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(200, 48), ZIndex = 22, Parent = body })
	result = UIKit.label({ Name = "Result", Text = "", Font = UIKit.Body, Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 18), Stroke = 1.5, ZIndex = 22 })
	result.Parent = body

	redeemBtn.Activated:Connect(function()
		send()
	end)
	box.FocusLost:Connect(function(enter)
		if enter then
			send()
		end
	end)

	dock.addButton("Codes", "CODES", PURPLE, "glyph:#", function()
		dock.toggle(panel)
		if panel.Visible then
			result.Text = ""
		end
	end, 20)

	task.spawn(function()
		remote = Net.get("RedeemCode")
		remote.OnClientEvent:Connect(function(r)
			onResult(ctx, r)
		end)
	end)
end

return Codes
