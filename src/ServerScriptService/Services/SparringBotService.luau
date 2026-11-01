--[[
	SparringBotService — bot d'entraînement R6 (RigBuilder) qui se bat comme un joueur (voir docs/Entrainement.md).
	Apparition :
		- /bot <easy|normal|hard>  (admins : AdminService.isAdmin, lu en lecture seule) ; /bot clear = tout retirer
		- borne « SPAR » (ProximityPrompt "SparPrompt") posée près des mannequins de l'étage : menu TrainingController ->
		  remote "Training" op "Spar" (difficulté) / "DismissBot", validés ici (distance à la borne, limite).
	Limites : MAX_BOTS par serveur, 1 bot par joueur via la borne ; disparaît après IDLE_TIME s sans combat, à sa mort,
	si son joueur quitte, s'il tombe hors de la carte.
	IA : s'approche, chaîne de M1, réagit aux coups adverses (début d'attaque vu côté serveur : nextAttack / délai
	global des attaques = windup du M1, télégraphe des attaques de perso) en bloquant ou en dashant, avec un délai de
	réaction et une probabilité par difficulté ; attaque de perso générique toutes les ~8 s ; EVASIVE (Normal / Hard).
	Combat via TrainingService.npc (CombatService.performM1 / performBlock / performDash si présents, sinon repli).
	Pas de récompense : le bot porte IsDummy = true (+ IsBot) et vit dans workspace.Dummies, comme le mannequin
	(DataService / TaskService / KillFeedService ignorent IsDummy ; FloorService / EventService le traitent comme un
	mannequin pendant les effondrements).
]]
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Shared = game.ReplicatedStorage.Shared
local Attacks = require(Shared.Config.Attacks)
local CombatConfig = require(Shared.Config.Combat)
local Net = require(Shared.Modules.Net)
local AbilityService = require(script.Parent.AbilityService)
local CharacterState = require(script.Parent.CharacterState)
local CombatService = require(script.Parent.CombatService)
local Ragdoll = require(script.Parent.Ragdoll)
local RigBuilder = require(script.Parent.RigBuilder)
local Signals = require(script.Parent.Signals)
local TrainingService = require(script.Parent.TrainingService)
local World = require(script.Parent.World)

local SparringBotService = {}
SparringBotService.Priority = 88

local Npc = TrainingService.npc
local MAX_BOTS = 2
local IDLE_TIME = 180
local STATION_RANGE = 14
local TICK = 0.05

-- réglages par difficulté
local DIFFICULTY = {
	Easy = {
		Reaction = 0.42, ReactChance = 0.3, BlockChance = 0.75, Chain = { 2, 3 }, Pause = 1.1, Gap = 0.18,
		Ability = 10, EvasiveAt = nil, Speed = 0.8, Color = Color3.fromRGB(110, 220, 120), Tie = Color3.fromRGB(40, 120, 50),
	},
	Normal = {
		Reaction = 0.24, ReactChance = 0.55, BlockChance = 0.6, Chain = { 3, 5 }, Pause = 0.8, Gap = 0.06,
		Ability = 8, EvasiveAt = 5, HoldBlock = true, Speed = 0.95, Color = Color3.fromRGB(255, 190, 70), Tie = Color3.fromRGB(150, 80, 20),
	},
	Hard = {
		Reaction = 0.11, ReactChance = 0.85, BlockChance = 0.55, Chain = { 5, 5 }, Pause = 0.5, Gap = 0,
		Ability = 7, EvasiveAt = 3, HoldBlock = true, Speed = 1, Color = Color3.fromRGB(235, 70, 70), Tie = Color3.fromRGB(25, 20, 30),
	},
}
SparringBotService.DIFFICULTY = DIFFICULTY

-- attaques de perso génériques (Config/Attacks) : une tirée au sort par bot
local ABILITIES = { "StickySlap", "MopSweep", "WhistleBlast", "FryingPanSmash" }
local FALLBACK_ABILITY = {
	Name = "Haymaker", Kind = "Melee", Windup = 0.35, HitboxOffset = 3, HitboxSize = Vector3.new(6, 6, 6),
	Damage = 8, Knockback = 30, KnockUp = 10, Stun = 0.8, Category = "Heavy", Power = 0.8, Words = { "HAYMAKER!" },
}

local bots = {} -- [bot] = data
local station   -- borne SPAR
local rng = Random.new()

local function count(): number
	local n = 0
	for _ in pairs(bots) do
		n += 1
	end
	return n
end

local function normDifficulty(s): string?
	if type(s) ~= "string" then
		return nil
	end
	s = string.lower(s)
	for name in pairs(DIFFICULTY) do
		if string.lower(name) == s then
			return name
		end
	end
	return nil
end

function SparringBotService.despawn(bot: Model)
	local d = bots[bot]
	if not d then
		return
	end
	bots[bot] = nil
	d.alive = false
	bot:Destroy()
end

function SparringBotService.clear()
	for bot in pairs(bots) do
		SparringBotService.despawn(bot)
	end
end

------------------------------------------------------------------------
-- IA
------------------------------------------------------------------------
local function validTarget(c: Model?): boolean
	return c ~= nil and c.Parent ~= nil and CharacterState.isAlive(c) and c:FindFirstChild("HumanoidRootPart") ~= nil
		and c:GetAttribute("SafeZone") ~= true
end

local function pickTarget(bot: Model, d): Model?
	local root = bot.HumanoidRootPart
	local owner = d.owner and d.owner.Parent and d.owner.Character
	if validTarget(owner) and (owner.HumanoidRootPart.Position - root.Position).Magnitude < 120 then
		return owner
	end
	local best, bestD = nil, 60
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if validTarget(c) then
			local dist = (c.HumanoidRootPart.Position - root.Position).Magnitude
			if dist < bestD then
				best, bestD = c, dist
			end
		end
	end
	return best
end

-- attaque de perso générique (mêmes effets que AbilityService : anim, FX « Ability », télégraphe du Kind)
local function castAbility(bot: Model, d)
	local s = CharacterState.get(bot)
	local t = os.clock()
	local cfg = Attacks[d.ability]
	local kinds = AbilityService.api and AbilityService.api.Kinds
	local fn = cfg and kinds and kinds[cfg.Kind]
	s.nextAttack = math.max(s.nextAttack, t + 0.35)
	s.gcdUntil = t + (CombatConfig.AbilityGCD or 0.6)
	CharacterState.setSpeedMod(bot, "Attack", 0.55, 0.35)
	local FX, Anim = Net.get("FX"), Net.get("Anim")
	if fn then
		if cfg.Anim then
			Anim:FireAllClients(bot, cfg.Anim)
		end
		FX:FireAllClients({ k = "Ability", a = bot, id = d.ability, name = cfg.Name, snd = cfg.Sound, kind = cfg.Kind, prop = cfg.Prop, dur = 0.75 })
		task.spawn(function()
			local ok, err = pcall(fn, bot, cfg, nil)
			if not ok then
				warn("[SparringBotService]", d.ability, err)
			end
		end)
		return
	end
	-- repli : gros coup lourd télégraphié
	local A = FALLBACK_ABILITY
	FX:FireAllClients({ k = "Telegraph", shape = "Box", a = bot, size = A.HitboxSize, offset = A.HitboxOffset, dur = A.Windup })
	Anim:FireAllClients(bot, "Punch5")
	task.delay(A.Windup, function()
		if CharacterState.isAlive(bot) and not CharacterState.isStunned(bot) then
			pcall(CombatService.swing, bot, {
				HitboxOffset = A.HitboxOffset, HitboxSize = A.HitboxSize, MaxTargets = 3, Damage = A.Damage,
				Knockback = A.Knockback, KnockUp = A.KnockUp, Stun = A.Stun, Category = A.Category, Power = A.Power,
				Words = A.Words, Weapon = A.Name, Heavy = true,
			}, nil)
		end
	end)
end

-- réaction à un coup adverse (après le délai de réaction) : block ou dash
local function react(bot: Model, d, target: Model)
	d.reacting = false
	if not d.alive or not CharacterState.isAlive(bot) or CharacterState.isStunned(bot) or not validTarget(target) then
		return
	end
	local root, tr = bot.HumanoidRootPart, target.HumanoidRootPart
	if (tr.Position - root.Position).Magnitude > 13 then
		return
	end
	local cfg = d.cfg
	if rng:NextNumber() < cfg.BlockChance and not CharacterState.isGuardBroken(bot) then
		Npc.face(bot, tr.Position)
		Npc.block(bot, true, true)
		d.blockUntil = os.clock() + 0.55
	else
		local kinds = { "L", "R", "B" }
		Npc.face(bot, tr.Position)
		Npc.dash(bot, kinds[rng:NextInteger(1, #kinds)])
	end
end

local function think(bot: Model, d)
	local hum = bot:FindFirstChildOfClass("Humanoid")
	local root = bot:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return
	end
	local t = os.clock()
	if t - d.lastActive > IDLE_TIME or (d.owner and not d.owner.Parent) then
		SparringBotService.despawn(bot)
		return
	end
	if not World.collapsing and root.Position.Y < World.getFloorY() - 80 then
		SparringBotService.despawn(bot)
		return
	end
	if World.collapsing then
		hum:Move(Vector3.zero)
		return
	end
	local s = CharacterState.get(bot)
	local cfg = d.cfg

	-- cible
	if t >= d.nextRetarget or not validTarget(d.target) then
		d.nextRetarget = t + 0.5
		local nt = pickTarget(bot, d)
		if nt ~= d.target then
			d.target = nt
			if nt then
				local ts = CharacterState.get(nt)
				d.seenNA, d.seenGCD = ts.nextAttack or 0, ts.gcdUntil or 0
			end
		end
	end
	local target = d.target
	if not target then
		hum:Move(Vector3.zero)
		if s.blocking then
			Npc.block(bot, false)
		end
		return
	end
	local tr = target.HumanoidRootPart
	local dist = (tr.Position - root.Position).Magnitude

	-- étourdi : EVASIVE si le combo subi est trop long (Normal / Hard)
	if CharacterState.isStunned(bot) then
		if cfg.EvasiveAt and d.comboTaken >= cfg.EvasiveAt and not d.evading and t >= (s.nextBreak or 0) then
			d.evading = true
			task.delay(cfg.Reaction, function()
				d.evading = false
				if d.alive and Npc.evasive(bot) then
					d.comboTaken = 0
				end
			end)
		end
		return
	end

	-- début d'attaque de la cible (windup du M1 / télégraphe d'attaque de perso) -> réaction différée
	local ts = CharacterState.get(target)
	local na, gcd = ts.nextAttack or 0, ts.gcdUntil or 0
	if na > d.seenNA + 0.01 or gcd > d.seenGCD + 0.01 then
		d.seenNA, d.seenGCD = na, gcd
		if dist < 13 and not d.reacting and rng:NextNumber() < cfg.ReactChance then
			d.reacting = true
			task.delay(cfg.Reaction * rng:NextNumber(0.8, 1.25), react, bot, d, target)
		end
	end

	-- en garde : on reste face à la cible ; garde prolongée tant que la chaîne adverse continue
	if s.blocking then
		Npc.face(bot, tr.Position)
		if t < d.blockUntil or (cfg.HoldBlock and os.clock() < (ts.nextAttack or 0) + 0.15 and dist < 9) then
			hum:Move(Vector3.zero)
			return
		end
		Npc.block(bot, false)
	end

	-- déplacement
	if dist > 4.2 then
		CharacterState.setRunning(bot, dist > 18)
		hum:MoveTo(tr.Position - (tr.Position - root.Position).Unit * 3)
	else
		CharacterState.setRunning(bot, false)
		hum:Move(Vector3.zero)
		Npc.face(bot, tr.Position)
	end

	-- attaques
	if dist <= 6 then
		local look = root.CFrame.LookVector
		local to = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
		local facing = to.Magnitude < 0.5 or look:Dot(to.Unit) > 0.5
		if not facing then
			Npc.face(bot, tr.Position)
			return
		end
		if t >= d.nextAbility and Npc.canM1(bot) then
			d.nextAbility = t + cfg.Ability + rng:NextNumber(-1.5, 1.5)
			castAbility(bot, d)
			return
		end
		if t >= d.nextSwing and Npc.canM1(bot) then
			local M1 = CombatConfig.M1
			local idx = d.chain + 1
			if t - d.lastSwing > (M1.ComboReset or 1) * 0.9 then
				idx = 1
			end
			if Npc.m1(bot, idx) then
				d.chain, d.lastSwing = idx, t
				if idx >= d.chainLen or idx >= M1.Hits then
					d.chain = 0
					d.chainLen = rng:NextInteger(cfg.Chain[1], cfg.Chain[2])
					d.nextSwing = t + (idx >= M1.Hits and 0 or cfg.Pause)
				else
					d.nextSwing = t + cfg.Gap
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- Apparition
------------------------------------------------------------------------
function SparringBotService.spawn(difficulty: string, owner: Player?, cf: CFrame?): (Model?, string?)
	difficulty = normDifficulty(difficulty) or "Normal"
	if count() >= MAX_BOTS then
		return nil, "Max " .. MAX_BOTS .. " sparring bots per server"
	end
	local cfg = DIFFICULTY[difficulty]
	if not cf then
		local c = owner and owner.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r then
			local p = r.Position + r.CFrame.LookVector * 10 + Vector3.new(0, 1, 0)
			cf = CFrame.lookAt(p, Vector3.new(r.Position.X, p.Y, r.Position.Z))
		else
			cf = World.getDummySpawn() or World.getPlayerSpawn()
		end
	end
	local bot = RigBuilder.r6("Spar Bot (" .. difficulty .. ")", { Shirt = cfg.Color, Tie = cfg.Tie })
	bot:PivotTo(cf)
	bot.Parent = workspace.Dummies
	CharacterState.setup(bot)
	bot:SetAttribute("IsDummy", true) -- pas de récompense (DataService / TaskService / KillFeedService)
	bot:SetAttribute("IsBot", true)
	bot:SetAttribute("BotDifficulty", difficulty)
	bot:SetAttribute("BotOwner", owner and owner.UserId or 0)
	for _, p in ipairs(bot:GetChildren()) do
		if p:IsA("BasePart") then
			p:SetNetworkOwner(nil)
		end
	end
	if cfg.Speed ~= 1 then
		CharacterState.setSpeedMod(bot, "Bot", cfg.Speed)
	end
	RigBuilder.tag(bot, "SPAR BOT · " .. string.upper(difficulty), cfg.Color)
	local d = {
		cfg = cfg, owner = owner, alive = true, target = nil, nextRetarget = 0, seenNA = 0, seenGCD = 0,
		reacting = false, evading = false, blockUntil = 0, comboTaken = 0,
		chain = 0, chainLen = rng:NextInteger(cfg.Chain[1], cfg.Chain[2]), lastSwing = -10, nextSwing = os.clock() + 1,
		nextAbility = os.clock() + cfg.Ability * 0.6, ability = ABILITIES[rng:NextInteger(1, #ABILITIES)],
		lastActive = os.clock(),
	}
	bots[bot] = d
	local hum = bot:FindFirstChildOfClass("Humanoid")
	hum.Died:Connect(function()
		d.alive = false
		Ragdoll.apply(bot, bot:GetAttribute("KOLaunch"))
		task.delay(3, function()
			SparringBotService.despawn(bot)
		end)
	end)
	task.spawn(function()
		while d.alive and bot.Parent do
			local ok, err = pcall(think, bot, d)
			if not ok then
				warn("[SparringBotService]", err)
			end
			task.wait(TICK)
		end
	end)
	return bot, nil
end

------------------------------------------------------------------------
-- Borne SPAR (près des mannequins de l'étage)
------------------------------------------------------------------------
local function buildStation()
	local m = Instance.new("Model")
	m.Name = "SparStation"
	local pole = Instance.new("Part")
	pole.Name = "Pole"
	pole.Anchored = true
	pole.CanCollide = true
	pole.CanQuery = false
	pole.CanTouch = false
	pole.Size = Vector3.new(0.6, 6, 0.6)
	pole.Color = Color3.fromRGB(40, 36, 60)
	pole.Material = Enum.Material.SmoothPlastic
	pole.Parent = m
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanQuery = false
	sign.CanTouch = false
	sign.Size = Vector3.new(4, 1.6, 0.3)
	sign.Color = Color3.fromRGB(255, 214, 50)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Parent = m
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.LightInfluence = 0
		sg.CanvasSize = Vector2.new(250, 100)
		sg.Parent = sign
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Text = "SPAR"
		l.TextScaled = true
		l.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold)
		l.TextColor3 = Color3.fromRGB(18, 14, 30)
		l.Parent = sg
	end
	m.PrimaryPart = pole
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SparPrompt"
	prompt.ActionText = "Spar"
	prompt.ObjectText = "Sparring Bot"
	prompt.KeyboardKeyCode = Enum.KeyCode.V
	prompt.GamepadKeyCode = Enum.KeyCode.DPadUp
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pole
	return m
end

local function placeStation()
	if not station then
		station = buildStation()
	end
	local base = World.getDummySpawn()
	local cf = base and (base * CFrame.new(7, 0, 0)) or (World.getPlayerSpawn() * CFrame.new(10, 0, -14))
	-- au sol (rayon vers le bas, sans personnages / mannequins)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { workspace:FindFirstChild("Dummies"), workspace:FindFirstChild("FX"), station }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(cf.Position + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
	local groundY = hit and hit.Position.Y or (cf.Position.Y - 3)
	local rot = cf - cf.Position
	local pos = Vector3.new(cf.Position.X, groundY, cf.Position.Z)
	station.Pole.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) * rot
	station.Sign.CFrame = CFrame.new(pos + Vector3.new(0, 5.6, 0)) * rot
	station.Parent = workspace
end

local function nearStation(player: Player): boolean
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return r ~= nil and station ~= nil and station.Parent ~= nil
		and (station.Pole.Position - r.Position).Magnitude <= STATION_RANGE + 4
end

local function ownedBy(player: Player): { Model }
	local list = {}
	for bot, d in pairs(bots) do
		if d.owner == player then
			table.insert(list, bot)
		end
	end
	return list
end

------------------------------------------------------------------------
-- Commande admin /bot (écoute du chat ; AdminService appartient à un autre module : lecture seule de isAdmin)
------------------------------------------------------------------------
local adminService
local function isAdmin(player: Player): boolean
	if adminService == nil then
		local m = script.Parent:FindFirstChild("AdminService")
		local ok, mod = false, nil
		if m then
			ok, mod = pcall(require, m)
		end
		adminService = (ok and type(mod) == "table") and mod or false
	end
	if adminService and type(adminService.isAdmin) == "function" then
		local ok, res = pcall(adminService.isAdmin, player)
		return ok and res == true
	end
	return false
end

local recent = {}
local function onChat(player: Player, text: string)
	if type(text) ~= "string" then
		return
	end
	text = string.sub(text, 1, 60)
	local arg = string.match(string.lower(text), "^/bot%s*(%S*)")
	if arg == nil then
		return
	end
	if string.match(string.lower(text), "^/bot%S") then
		return -- autre commande (/bots...)
	end
	local stamp = player.UserId .. text
	if recent[stamp] and os.clock() - recent[stamp] < 0.4 then
		return
	end
	recent[stamp] = os.clock()
	if not isAdmin(player) then
		return
	end
	if arg == "clear" or arg == "off" then
		SparringBotService.clear()
		TrainingService.toast(player, "Sparring bots removed")
		return
	end
	local diff = normDifficulty(arg ~= "" and arg or "normal")
	if not diff then
		TrainingService.toast(player, "Usage: /bot <easy|normal|hard|clear>", true)
		return
	end
	local bot, err = SparringBotService.spawn(diff, player)
	TrainingService.toast(player, bot and ("Sparring bot spawned (" .. diff .. ")") or err or "Could not spawn bot", bot == nil)
end

------------------------------------------------------------------------
function SparringBotService.init()
	TrainingService.handlers.Spar = function(player: Player, difficulty)
		local diff = normDifficulty(difficulty)
		if not diff then
			return
		end
		if not nearStation(player) or not CharacterState.isAlive(player.Character) then
			TrainingService.toast(player, "Use the SPAR station", true)
			return
		end
		-- un bot par joueur : le précédent est remplacé
		for _, b in ipairs(ownedBy(player)) do
			SparringBotService.despawn(b)
		end
		local bot, err = SparringBotService.spawn(diff, player) -- devant le joueur, tourné vers lui
		TrainingService.toast(player, bot and ("Sparring partner ready: " .. diff) or err or "Could not spawn bot", bot == nil)
	end
	TrainingService.handlers.DismissBot = function(player: Player)
		local list = ownedBy(player)
		for _, b in ipairs(list) do
			SparringBotService.despawn(b)
		end
		if #list > 0 then
			TrainingService.toast(player, "Sparring bot dismissed")
		end
	end

	-- activité (pour la disparition après IDLE_TIME) + combo subi (EVASIVE)
	Signals.Hit:Connect(function(attacker, victim)
		local t = os.clock()
		local dv = bots[victim]
		if dv then
			-- (synchrone, avant l'étourdissement de ce coup)
			dv.comboTaken = CharacterState.isStunned(victim) and dv.comboTaken + 1 or 1
			dv.lastActive = t
			if dv.blockUntil > t then
				dv.blockUntil = 0
			end
		end
		local da = attacker and bots[attacker]
		if da then
			da.lastActive = t
		end
	end)
	for _, name in ipairs({ "Blocked", "Parried", "GuardBroken" }) do
		Signals[name]:Connect(function(a, b)
			local t = os.clock()
			for _, m in ipairs({ a, b }) do
				if m and bots[m] then
					bots[m].lastActive = t
				end
			end
		end)
	end

	-- chat : /bot <difficulté>
	local function onPlayer(player: Player)
		player.Chatted:Connect(function(msg)
			onChat(player, msg)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		for _, b in ipairs(ownedBy(p)) do
			SparringBotService.despawn(b)
		end
	end)
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local folder = TextChatService:FindFirstChild("TextChatCommands") or Instance.new("Folder")
		folder.Name = "TextChatCommands"
		folder.Parent = TextChatService
		if not folder:FindFirstChild("OB_bot") then
			local c = Instance.new("TextChatCommand")
			c.Name = "OB_bot"
			c.PrimaryAlias = "/bot"
			c.Parent = folder
			c.Triggered:Connect(function(source, text)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					onChat(player, text)
				end
			end)
		end
	end

	-- borne SPAR : posée sur l'étage chargé, retirée pendant l'effondrement, reposée sur le nouvel étage
	Signals.CollapseWarning:Connect(function()
		if station then
			station.Parent = nil
		end
	end)
	Signals.FloorChanged:Connect(function()
		task.delay(0.5, placeStation)
	end)
	task.defer(function()
		local t0 = os.clock()
		while not World.floorModel and os.clock() - t0 < 15 do
			task.wait(0.2)
		end
		task.wait(0.5)
		if not station or not station.Parent then
			placeStation()
		end
	end)
end

-- (pour les autres modules / tests)
function SparringBotService.list(): { Model }
	local list = {}
	for bot in pairs(bots) do
		table.insert(list, bot)
	end
	return list
end


return SparringBotService
