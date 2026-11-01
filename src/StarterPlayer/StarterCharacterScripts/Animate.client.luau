--[[
	Animate — remplace le script « Animate » par défaut de Roblox (même nom dans StarterCharacterScripts).
	Détails : docs/Animation-v2.md

	- Repos, marche et course : PROCÉDURAUX (ProcAnim v2 : garde de combat par archétype, foulée phasée par la vitesse),
	  calculés par chaque client pour chaque personnage visible.
	- Saut, chute, escalade, nage, assis, outil en main : pistes Animator avec les animations R6 standard de Roblox
	  (jouées par le propriétaire du personnage -> répliquées automatiquement aux autres joueurs).
	- Une action ProcAnim (coup, dash, réaction…) en l'air : la piste saut / chute est atténuée (l'action domine).
	Pas d'émotes « /e » (le jeu n'en a pas besoin).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local character = script.Parent
local hum = character:WaitForChild("Humanoid")
local ProcAnim = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("ProcAnim"))

-- animations R6 standard de Roblox (script Animate R6 d'origine)
local IDS = {
	jump = 125750702,
	fall = 180436148,
	climb = 180436334,
	sit = 178130996,
	swim = 180426354, -- (pas d'anim de nage en R6 : la marche, au ralenti)
	toolnone = 182393478,
}
local FADE = 0.1
local JUMP_TIME = 0.31 -- durée de l'anim de saut avant de passer à la chute

local animator = hum:FindFirstChildOfClass("Animator")
if not animator then
	animator = Instance.new("Animator")
	animator.Parent = hum
end

local tracks = {}
local function track(name)
	local t = tracks[name]
	if t then
		return t
	end
	local a = Instance.new("Animation")
	a.Name = name
	a.AnimationId = "rbxassetid://" .. IDS[name]
	local ok, loaded = pcall(animator.LoadAnimation, animator, a)
	if not ok or not loaded then
		return nil
	end
	loaded.Priority = Enum.AnimationPriority.Core
	tracks[name] = loaded
	return loaded
end

local current = nil -- piste de mouvement en cours (jump / fall / climb / sit / swim) ; nil = locomotion procédurale
local jumpAt = -10

local function stopMove(fade)
	for name, t in pairs(tracks) do
		if name ~= "toolnone" and t.IsPlaying then
			t:Stop(fade or FADE)
		end
	end
	current = nil
end

local function playMove(name, fade, speed)
	if current == name then
		local t = tracks[name]
		if t and speed then
			t:AdjustSpeed(speed)
		end
		return
	end
	stopMove(fade)
	local t = track(name)
	if t then
		t:Play(fade or FADE)
		if speed then
			t:AdjustSpeed(speed)
		end
		current = name
	end
end

local ST = Enum.HumanoidStateType
local function onState(_, new)
	if new == ST.Jumping then
		jumpAt = os.clock()
		playMove("jump", FADE)
	elseif new == ST.Freefall then
		local wait = JUMP_TIME - (os.clock() - jumpAt)
		if current == "jump" and wait > 0 then
			task.delay(wait, function()
				if hum:GetState() == ST.Freefall and current == "jump" then
					playMove("fall", 0.2)
				end
			end)
		else
			playMove("fall", 0.2)
		end
	elseif new == ST.Climbing then
		playMove("climb", FADE, 0)
	elseif new == ST.Seated then
		playMove("sit", 0.5)
	elseif new == ST.Swimming then
		playMove("swim", 0.3, 0.6)
	elseif new == ST.Dead then
		stopMove(0.2)
	else
		-- au sol (Running, Landed, GettingUp…) ou état physique (ragdoll, PlatformStanding) : rien d'imposé
		stopMove(new == ST.Landed and 0.08 or FADE)
	end
end
hum.StateChanged:Connect(onState)
hum.Climbing:Connect(function(speed)
	if current == "climb" then
		local t = tracks.climb
		if t then
			t:AdjustSpeed(speed / 5) -- comme le script d'origine (12 studs/s -> vitesse 2,4)
		end
	end
end)
hum.Swimming:Connect(function(speed)
	if current == "swim" then
		local t = tracks.swim
		if t then
			t:AdjustSpeed(math.clamp(speed / 12, 0.3, 1.2))
		end
	end
end)
onState(nil, hum:GetState())

-- outil (Tool) en main : bras tendu (les objets du jeu passent par HoldPose / ProcAnim, pas par des Tools)
local function refreshTool()
	local hasTool = character:FindFirstChildOfClass("Tool") ~= nil
	local t = track("toolnone")
	if not t then
		return
	end
	if hasTool and not t.IsPlaying then
		t.Priority = Enum.AnimationPriority.Idle
		t:Play(FADE)
	elseif not hasTool and t.IsPlaying then
		t:Stop(FADE)
	end
end
character.ChildAdded:Connect(function(ch)
	if ch:IsA("Tool") then
		refreshTool()
	end
end)
character.ChildRemoved:Connect(function(ch)
	if ch:IsA("Tool") then
		refreshTool()
	end
end)

-- enregistrement ProcAnim (locomotion procédurale) dès que le rig est complet
task.spawn(function()
	-- (FXController ré-enregistre aussi tous les personnages 4 fois par seconde : rig reconstruit, skin…)
	character:WaitForChild("Torso", 10)
	character:WaitForChild("HumanoidRootPart", 10)
	ProcAnim.register(character)
end)

-- action ProcAnim en l'air : la piste saut / chute s'efface pour laisser lire le coup
local dampened = false
RunService.Heartbeat:Connect(function()
	if not character.Parent then
		return
	end
	local airTrack = (current == "jump" or current == "fall") and tracks[current] or nil
	local want = airTrack ~= nil and ProcAnim.isPlaying(character)
	if want ~= dampened then
		dampened = want
		for _, name in ipairs({ "jump", "fall" }) do
			local t = tracks[name]
			if t and t.IsPlaying then
				t:AdjustWeight(want and 0.15 or 1, 0.08)
			end
		end
	elseif dampened and airTrack and airTrack.WeightTarget > 0.2 then
		airTrack:AdjustWeight(0.15, 0.08) -- nouvelle piste (saut -> chute) pendant l'action
	end
end)
