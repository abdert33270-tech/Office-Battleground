--[[
	LoadingScreen — écran de chargement aux couleurs d'Office Battlegrounds (ReplicatedFirst, s'exécute en premier).
	UITheme n'est pas encore répliqué ici : les quelques couleurs / polices du thème sont recopiées en dur
	(src/ReplicatedStorage/Shared/Modules/UITheme.luau : Ink, PanelDark, Panel, Yellow, Orange, Muted ;
	Display = Press Start 2P, Body = Silkscreen).
	Barre animée : ContentProvider:PreloadAsync sur les polices + quelques sons de Config/Sounds (IDs recopiés),
	puis game:IsLoaded() et l'arrivée du ScreenGui « HUD » dans le PlayerGui. Fondu dès que tout est prêt
	(au plus tard après TIMEOUT s). Astuces de bureau tirées au hasard.
]]
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local TIMEOUT = 15
local MIN_SHOW = 1.5

local INK = Color3.fromRGB(18, 14, 30)
local PANEL_DARK = Color3.fromRGB(24, 21, 44)
local PANEL = Color3.fromRGB(36, 32, 62)
local YELLOW = Color3.fromRGB(255, 214, 50)
local ORANGE = Color3.fromRGB(255, 138, 30)
local MUTED = Color3.fromRGB(170, 165, 205)
local WHITE = Color3.new(1, 1, 1)

local DISPLAY = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local BODY = Font.fromId(12187371840, Enum.FontWeight.Bold, Enum.FontStyle.Normal) -- Silkscreen

-- copiés de Config/Sounds (Punch, Whoosh, Ding, Pickup, Throw, Block, Dash, LevelUp)
local SOUND_IDS = {
	"rbxassetid://139795256698131",
	"rbxassetid://137081214744553",
	"rbxassetid://9126073001",
	"rbxassetid://9113263454",
	"rbxassetid://120706760824134",
	"rbxassetid://80809123525734",
	"rbxassetid://136934236721060",
	"rbxassetid://112485797063762",
}

local TIPS = {
	"Tip: the stapler is mightier than the sword.",
	"Tip: hold F to block. Tap it right before a hit for a PERFECT block!",
	"Tip: caught in a combo? Press Q to EVASIVE out of it.",
	"Tip: chairs make great projectiles. Press E, then R.",
	"Tip: 5 clicks = full combo. Hold SPACE on the 5th for an uppercut.",
	"Tip: never trust a printer that says it's ready.",
	"Tip: claim your DAILY reward every day to keep your streak.",
	"Tip: the coffee machine is load-bearing. Do not break it.",
	"Tip: the floor collapses. Keep moving, keep climbing.",
	"Tip: reply-all is not an attack. Yet.",
	"Tip: Q + WASD dashes in any direction.",
	"Tip: press H any time to see the controls.",
}

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

------------------------------------------------------------------------ interface
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local canvas = Instance.new("CanvasGroup")
canvas.Name = "Root"
canvas.Size = UDim2.fromScale(1, 1)
canvas.BackgroundColor3 = PANEL_DARK
canvas.BorderSizePixel = 0
canvas.Parent = gui

local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Color = ColorSequence.new(PANEL, INK)
grad.Parent = canvas

local function stroke(parent, thickness, color, border)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or INK
	s.ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Miter
	s.Parent = parent
	return s
end

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.TextColor3 = WHITE
	l.FontFace = DISPLAY
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

-- colonne centrale (largeur bornée : téléphone comme PC)
local col = Instance.new("Frame")
col.Name = "Column"
col.AnchorPoint = Vector2.new(0.5, 0.5)
col.Position = UDim2.fromScale(0.5, 0.5)
col.Size = UDim2.fromScale(0.86, 0.7)
col.BackgroundTransparency = 1
col.Parent = canvas
local lim = Instance.new("UISizeConstraint")
lim.MaxSize = Vector2.new(760, 420)
lim.Parent = col

local title = label({
	Name = "Title",
	Text = "OFFICE\nBATTLEGROUNDS",
	TextColor3 = YELLOW,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.04),
	Size = UDim2.fromScale(1, 0.42),
	LineHeight = 1.15,
	Parent = col,
})
stroke(title, 4, INK)
local tl = Instance.new("UITextSizeConstraint")
tl.MaxTextSize = 54
tl.MinTextSize = 14
tl.Parent = title
-- ombre portée orange (style pixel)
local shadow = label({
	Name = "Shadow",
	Text = title.Text,
	TextColor3 = ORANGE,
	AnchorPoint = title.AnchorPoint,
	Position = UDim2.new(0.5, 4, 0.04, 4),
	Size = title.Size,
	LineHeight = 1.15,
	ZIndex = 0,
	Parent = col,
})
stroke(shadow, 4, INK)
tl:Clone().Parent = shadow

local sub = label({
	Name = "Sub",
	Text = "CLOCKING IN...",
	FontFace = BODY,
	TextColor3 = MUTED,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 0.07),
	Parent = col,
})
stroke(sub, 1.5, INK)
local sl = Instance.new("UITextSizeConstraint")
sl.MaxTextSize = 18
sl.MinTextSize = 10
sl.Parent = sub

-- barre de progression
local barBg = Instance.new("Frame")
barBg.Name = "Bar"
barBg.AnchorPoint = Vector2.new(0.5, 0)
barBg.Position = UDim2.fromScale(0.5, 0.62)
barBg.Size = UDim2.new(0.9, 0, 0, 26)
barBg.BackgroundColor3 = INK
barBg.BorderSizePixel = 0
barBg.Parent = col
stroke(barBg, 3, INK, true)
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 4)
bc.Parent = barBg
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = YELLOW
fill.BorderSizePixel = 0
fill.Parent = barBg
local fc = Instance.new("UICorner")
fc.CornerRadius = UDim.new(0, 4)
fc.Parent = fill
local fg = Instance.new("UIGradient")
fg.Rotation = 90
fg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 170, 60))
fg.Parent = fill
local pct = label({
	Name = "Percent",
	Text = "0%",
	TextColor3 = WHITE,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 0, 0, 12),
	ZIndex = 3,
	Parent = barBg,
})
stroke(pct, 2, INK)

local tip = label({
	Name = "Tip",
	Text = TIPS[math.random(1, #TIPS)],
	FontFace = BODY,
	TextColor3 = WHITE,
	TextWrapped = true,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.8),
	Size = UDim2.fromScale(1, 0.14),
	Parent = col,
})
stroke(tip, 1.5, INK)
local tpl = Instance.new("UITextSizeConstraint")
tpl.MaxTextSize = 20
tpl.MinTextSize = 10
tpl.Parent = tip

gui.Parent = pg
ReplicatedFirst:RemoveDefaultLoadingScreen()

------------------------------------------------------------------------ chargement
local start = os.clock()
local total, loaded = 0, 0
local preloadDone = false

task.spawn(function()
	local list = { title, sub } -- polices Press Start 2P + Silkscreen (via les TextLabels)
	for _, id in ipairs(SOUND_IDS) do
		local s = Instance.new("Sound")
		s.SoundId = id
		table.insert(list, s)
	end
	total = #list
	for _, item in ipairs(list) do
		pcall(function()
			ContentProvider:PreloadAsync({ item })
		end)
		loaded += 1
	end
	preloadDone = true
end)

local function hudReady()
	return pg:FindFirstChild("HUD") ~= nil
end

local function targetProgress()
	local p = (total > 0 and loaded / total or 0) * 0.7
	if game:IsLoaded() then
		p += 0.15
	end
	if hudReady() then
		p += 0.15
	end
	return math.min(p, 1)
end

-- astuces qui tournent
task.spawn(function()
	local last = tip.Text
	while gui.Parent do
		task.wait(3.5)
		local nextTip = TIPS[math.random(1, #TIPS)]
		if nextTip == last then
			nextTip = TIPS[(table.find(TIPS, nextTip) or 0) % #TIPS + 1]
		end
		last = nextTip
		tip.Text = nextTip
	end
end)

local shown = 0
local dots = 0
local finishing = false
local conn = RunService.RenderStepped:Connect(function(dt)
	shown += ((finishing and 1 or targetProgress()) - shown) * math.min(1, dt * 6)
	fill.Size = UDim2.fromScale(math.clamp(shown, 0.02, 1), 1)
	pct.Text = math.floor(shown * 100 + 0.5) .. "%"
	dots = (dots + dt * 2.5) % 4
	local d = string.rep(".", math.floor(dots))
	if not game:IsLoaded() or not preloadDone then
		sub.Text = "CLOCKING IN" .. d
	elseif not hudReady() then
		sub.Text = "SETTING UP YOUR DESK" .. d
	else
		sub.Text = "READY!"
	end
	title.Rotation = math.sin(os.clock() * 2) * 1.2
	shadow.Rotation = title.Rotation
end)

while os.clock() - start < TIMEOUT do
	if game:IsLoaded() and preloadDone and hudReady() and os.clock() - start >= MIN_SHOW then
		break
	end
	task.wait(0.1)
end

finishing = true
task.wait(0.35)
local tw = TweenService:Create(canvas, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 1 })
tw:Play()
tw.Completed:Wait()
conn:Disconnect()
gui:Destroy()
