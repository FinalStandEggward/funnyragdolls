-- FR_PORTAL_QOL_R5 | rainbow white bubbles, unobstructed spawning, terminal spin
-- FunnyRagdolls Portal - faithful standalone-core module (register-safe).
-- Derived from the last working RainbowEveryPortal_10SecondLinger standalone.
-- The loader provides settings during module initialization. Regular portal
-- mechanics and their lexical scopes stay unchanged.
local portalBootstrapEnv = (type(getgenv) == "function" and getgenv()) or _G
local portalSettings = portalBootstrapEnv.__FunnyRagdollsPortalSettings
assert(type(portalSettings) == "table", "[FunnyRagdolls/Portal] Launch this through the updated FunnyRagdolls loader")
local H = {} -- Internal helpers live here, avoiding Luau's 200-local register limit.
local C = {} -- Internal defaults with a small external override set.
local function portalSetting(name, fallback)
    local configured = portalSettings[name]
    if configured == nil then return fallback end
    return configured
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local RAGDOLLS_FOLDER = Workspace:WaitForChild("Ragdolls")

C.PORTAL_FILE = portalSetting("PORTAL_FILE", "Portal.rbxm")
C.AUDIO = portalSetting("AUDIO", {
 Open = {File="open.mp3", ID="rbxassetid://86019142812328"},
 Enter = {File="enter.mp3", ID="rbxassetid://108037385078143"},
 Close = {File="close.mp3", ID="rbxassetid://111603938108285"}
})
C.SETTLE_TIME, C.GROW_TIME, C.SHRINK_TIME = portalSetting("SETTLE_TIME", 0.3), portalSetting("GROW_TIME", 0.22), portalSetting("SHRINK_TIME", 0.16)
C.START_SCALE, C.FINAL_SCALE, C.END_SCALE = portalSetting("START_SCALE", 0.05), portalSetting("FINAL_SCALE", 1), portalSetting("END_SCALE", 0.05)
C.TRAVEL_TIME, C.LINGER_TIME = portalSetting("TRAVEL_TIME", 0), portalSetting("LINGER_TIME", 0.35)
C.ROTATION_SPEED, C.PORTAL_OFFSET = portalSetting("ROTATION_SPEED", 180), portalSetting("PORTAL_OFFSET", 0.08)
C.MAX_PORTAL_HOPS, C.EXIT_SEARCH_RADIUS = portalSetting("MAX_PORTAL_HOPS", 20), portalSetting("EXIT_SEARCH_RADIUS", 22)
C.EXIT_LAUNCH_SPEED, C.NEXT_PORTAL_DELAY = portalSetting("EXIT_LAUNCH_SPEED", 65), portalSetting("NEXT_PORTAL_DELAY", 0.12)
C.ENTRY_TIMEOUT = portalSetting("ENTRY_TIMEOUT", 5) -- legacy unused entry helper
C.ABOVE_BOUNCE_AFTER = portalSetting("ABOVE_BOUNCE_AFTER", 0.3)
C.GROUND_BOUNCE_AFTER = portalSetting("GROUND_BOUNCE_AFTER", 0.55)
C.BOUNCE_SPEED = portalSetting("BOUNCE_SPEED", 48)
C.ABOVE_PORTAL_CHANCE = portalSetting("ABOVE_PORTAL_CHANCE", 0.25) -- 25% above-ragdoll portal; 75% ground portal
C.ABOVE_PORTAL_HEIGHT_MIN, C.ABOVE_PORTAL_HEIGHT_MAX = portalSetting("ABOVE_PORTAL_HEIGHT_MIN", 5), portalSetting("ABOVE_PORTAL_HEIGHT_MAX", 8)
C.GROUND_RAY_START_HEIGHT, C.GROUND_RAY_DISTANCE = portalSetting("GROUND_RAY_START_HEIGHT", 4), portalSetting("GROUND_RAY_DISTANCE", 32)
C.MAX_GROUND_DROP = portalSetting("MAX_GROUND_DROP", 12) -- Reject floors far below the ragdoll.
C.GROUND_CLEARANCE_BELOW_BODY = portalSetting("GROUND_CLEARANCE_BELOW_BODY", 2)
C.SURFACE_CLEARANCE = portalSetting("SURFACE_CLEARANCE", 0.6)
C.SOUND_MAX_DISTANCE = portalSetting("SOUND_MAX_DISTANCE", 85)
C.SOUND_MIN_DISTANCE = portalSetting("SOUND_MIN_DISTANCE", 8)
C.ENABLE_CLOSING_FLUID = portalSetting("ENABLE_CLOSING_FLUID", true)
C.CLOSING_FLUID_DROPS = portalSetting("CLOSING_FLUID_DROPS", 6)
C.MAX_SURFACE_ADJUSTMENTS = portalSetting("MAX_SURFACE_ADJUSTMENTS", 12)
C.SURFACE_ADJUST_STEP = portalSetting("SURFACE_ADJUST_STEP", 0.12)
C.EXIT_CANDIDATE_ATTEMPTS = portalSetting("EXIT_CANDIDATE_ATTEMPTS", 16)
-- Camera-aware exits. Keep entrance portals near their ragdolls.
C.CAMERA_AWARE_EXITS = portalSetting("CAMERA_AWARE_EXITS", true)
C.CAMERA_VIEW_MARGIN = portalSetting("CAMERA_VIEW_MARGIN", 0.14) -- reserve 14% of screen edges
C.CAMERA_MAX_EXIT_DISTANCE = portalSetting("CAMERA_MAX_EXIT_DISTANCE", 90) -- studs from camera
C.CAMERA_VISIBLE_ATTEMPTS = portalSetting("CAMERA_VISIBLE_ATTEMPTS", 50)
C.CAMERA_RAY_LENGTH = portalSetting("CAMERA_RAY_LENGTH", 140)
-- Chain duplication and clone cleanup
-- Experimental airborne portal-to-portal ballistic transfer
C.MIDAIR_CHAIN_CHANCE = portalSetting("MIDAIR_CHAIN_CHANCE", 0.35) -- existing chance in normal chains
C.AIR_ONLY_LIFETIME_CHANCE = portalSetting("AIR_ONLY_LIFETIME_CHANCE", 0.20) -- a ragdoll has a 20% chance to use ONLY midair portals
C.AIR_ONLY_MAX_SPAWN_ATTEMPTS = portalSetting("AIR_ONLY_MAX_SPAWN_ATTEMPTS", 24) -- find a camera-visible floating corridor
C.AIR_ONLY_RETRY_INTERVAL = portalSetting("AIR_ONLY_RETRY_INTERVAL", 0.10) -- retry if the current camera view is obstructed
-- ONLY midair-to-midair travel is deliberately controlled.
-- All ordinary exits and floor landings retain their random physics.
C.MIDAIR_FLIGHT_TIME = portalSetting("MIDAIR_FLIGHT_TIME", 0.20) -- 3.5x faster midair flight; change only this for speed tuning
C.MIDAIR_SPACING_MIN, C.MIDAIR_SPACING_MAX = portalSetting("MIDAIR_SPACING_MIN", 12), portalSetting("MIDAIR_SPACING_MAX", 34)
C.MIDAIR_WALL_ATTACH_CHANCE = portalSetting("MIDAIR_WALL_ATTACH_CHANCE", 0.60) -- wall mounting is attempted on 60% of pairs
C.MIDAIR_WALL_SEARCH_DISTANCE = portalSetting("MIDAIR_WALL_SEARCH_DISTANCE", 9) -- look for a suitable wall near either endpoint
C.MIDAIR_DIRECTION_VERTICALITY = portalSetting("MIDAIR_DIRECTION_VERTICALITY", 0.75) -- allow diagonal and vertical changes
C.MIDAIR_DIRECTION_DEPTH = portalSetting("MIDAIR_DIRECTION_DEPTH", 0.60) -- vary depth relative to camera
C.MIDAIR_HEIGHT = portalSetting("MIDAIR_HEIGHT", 9)
C.MIDAIR_ARRIVAL_RADIUS = portalSetting("MIDAIR_ARRIVAL_RADIUS", 5)
C.MIDAIR_MAX_WAIT = portalSetting("MIDAIR_MAX_WAIT", 0.75) -- recovery guard, NOT the normal flight duration
C.MIDAIR_STRAIGHT_STEERING = portalSetting("MIDAIR_STRAIGHT_STEERING", 14) -- stronger lateral stability at high speed
C.MIDAIR_MAX_STEERING_SPEED = portalSetting("MIDAIR_MAX_STEERING_SPEED", 34)
-- Prediction lookahead is a search DISTANCE in time, not an entry timer.
-- Portals trigger only when the actual ragdoll reaches their plane.
C.PREDICTION_LOOKAHEAD = portalSetting("PREDICTION_LOOKAHEAD", 2.8)
C.PREDICTION_STEP = portalSetting("PREDICTION_STEP", 0.12)
C.ENTRY_CAPTURE_RADIUS = portalSetting("ENTRY_CAPTURE_RADIUS", 4.1)
C.ENTRY_CAPTURE_MARGIN = portalSetting("ENTRY_CAPTURE_MARGIN", 0.20)
-- Limit how far and how often a predicted landing portal can move.
-- Small changes in the prediction are ignored; the final approach is locked.
C.ENTRY_REPOSITION_EPSILON = portalSetting("ENTRY_REPOSITION_EPSILON", 1.5)
C.PREDICTION_MAX_REPOSITIONS = portalSetting("PREDICTION_MAX_REPOSITIONS", 7)
C.PREDICTION_MAX_TOTAL_MOVE = portalSetting("PREDICTION_MAX_TOTAL_MOVE", 18)
C.PREDICTION_MAX_STEP = portalSetting("PREDICTION_MAX_STEP", 3.5)
C.PREDICTION_REPOSITION_COOLDOWN = portalSetting("PREDICTION_REPOSITION_COOLDOWN", 0.10)
C.PREDICTION_FREEZE_HEIGHT = portalSetting("PREDICTION_FREEZE_HEIGHT", 3.2)
C.PREDICTION_REPLAN_DISTANCE = portalSetting("PREDICTION_REPLAN_DISTANCE", 7) -- discard outdated entrance when the actual landing floor changes
C.PREDICTION_EARLY_ASSIST_TIME = portalSetting("PREDICTION_EARLY_ASSIST_TIME", 1.65) -- earlier correction if entry becomes unlikely
C.PREDICTION_SWEEP_RADIUS = portalSetting("PREDICTION_SWEEP_RADIUS", 0.75) -- account for wide ragdoll bodies near walls
C.PREDICTION_LANDING_CLEARANCE = portalSetting("PREDICTION_LANDING_CLEARANCE", 3.2) -- don't spawn a portal inside blocking parts
-- Only ignore collisions with fully opaque (Transparency == 0) nearby BaseParts.
C.PASS_THROUGH_OPAQUE = portalSetting("PASS_THROUGH_OPAQUE", true)
C.OPAQUE_SCAN_RADIUS = portalSetting("OPAQUE_SCAN_RADIUS", 19)
C.OPAQUE_SCAN_INTERVAL = portalSetting("OPAQUE_SCAN_INTERVAL", 0.12)
C.OPAQUE_MAX_NEARBY_PARTS = portalSetting("OPAQUE_MAX_NEARBY_PARTS", 90)
C.FORCE_GROUND_ENTRANCES = portalSetting("FORCE_GROUND_ENTRANCES", true)
C.GROUND_ENTRY_SEARCH_RADIUS = portalSetting("GROUND_ENTRY_SEARCH_RADIUS", 8)
-- Stuck ragdoll watchdog: after 2.5 seconds without an entrance teleport,
-- temporarily disable ragdoll collisions and force it into its CURRENT portal.
C.STUCK_TELEPORT_TIMEOUT = portalSetting("STUCK_TELEPORT_TIMEOUT", 2.5)
C.STUCK_PULL_SPEED = portalSetting("STUCK_PULL_SPEED", 115) -- studs per second, rescue only
C.STUCK_PORTAL_OVERSHOOT = portalSetting("STUCK_PORTAL_OVERSHOOT", 2) -- aim through the plane, not just at the surface
C.STUCK_CAPTURE_EXTRA_RADIUS = portalSetting("STUCK_CAPTURE_EXTRA_RADIUS", 1.5)
-- Final one-way 'blender dimension' portal. This counts time since the last
-- COMPLETED teleport, not time since a portal was created or approached.
C.FINAL_PORTAL_STALL_TIME = portalSetting("FINAL_PORTAL_STALL_TIME", 5.0)
C.FINAL_SUCTION_MAX_SPEED = portalSetting("FINAL_SUCTION_MAX_SPEED", 130)
C.FINAL_SUCTION_RESPONSE = portalSetting("FINAL_SUCTION_RESPONSE", 15)
C.FINAL_SUCTION_CAPTURE_RADIUS = portalSetting("FINAL_SUCTION_CAPTURE_RADIUS", 4.1)
C.FINAL_SUCTION_MAX_DURATION = portalSetting("FINAL_SUCTION_MAX_DURATION", 2.8) -- fail-safe only; entry itself is plane-driven
-- Terminal endings: slower than regular portal hops.
C.FINAL_PORTAL_SHAKE_DURATION = portalSetting("FINAL_PORTAL_SHAKE_DURATION", 5.0) -- blender holds/shakes for a full five seconds
C.TERMINAL_BOMB_CHANCE = portalSetting("TERMINAL_BOMB_CHANCE", 0.40) -- 40% bomb, 60% blender
C.FINAL_PORTAL_OPEN_WAIT = portalSetting("FINAL_PORTAL_OPEN_WAIT", 0.56) -- preserve the normal elastic opening speed
C.FINAL_RAGDOLL_CLEANUP_DELAY = portalSetting("FINAL_RAGDOLL_CLEANUP_DELAY", 12) -- after ejecting, no additional chains
C.BOMB_OVERHEAD_HEIGHT = portalSetting("BOMB_OVERHEAD_HEIGHT", 5)
C.BOMB_DROP_SETTLE = portalSetting("BOMB_DROP_SETTLE", 0.65) -- let the bomb physically drop before arming
C.BOMB_ARM_TIME = portalSetting("BOMB_ARM_TIME", 2.75)
-- Cartoon bomb shockwave: affects EVERY nearby ragdoll and ends its portal chain.
C.BOMB_BLAST_RADIUS = portalSetting("BOMB_BLAST_RADIUS", 42) -- studs from explosion center
C.BOMB_SHOCKWAVE_SPEED = portalSetting("BOMB_SHOCKWAVE_SPEED", 145) -- horizontal/radial launch strength
C.BOMB_SHOCKWAVE_LIFT = portalSetting("BOMB_SHOCKWAVE_LIFT", 72) -- upward impulse
C.BOMB_CHAR_COLOR = portalSetting("BOMB_CHAR_COLOR", Color3.fromRGB(7, 7, 7))
C.BOMB_CHAR_MATERIAL = portalSetting("BOMB_CHAR_MATERIAL", Enum.Material.SmoothPlastic) -- plain black, no charred/slate surface
C.BOMB_CHARRED_CLEANUP_DELAY = portalSetting("BOMB_CHARRED_CLEANUP_DELAY", 14)
C.BOMB_PART_SEPARATION_CHANCE = portalSetting("BOMB_PART_SEPARATION_CHANCE", 0.35) -- independent chance for each blast-affected ragdoll
C.BOMB_SEPARATION_FLUID_DURATION = portalSetting("BOMB_SEPARATION_FLUID_DURATION", 4.5) -- stylized red droplets from released attachment points
C.BOMB_VISUAL_COLOR = portalSetting("BOMB_VISUAL_COLOR", Color3.fromRGB(255,25,160))
-- Positional bomb sounds. Optionally supply PrimeBombTick.mp3 and
-- PrimeBombExplosion.mp3 next to the Lua file for getcustomasset().
C.BOMB_TICK_FILE = portalSetting("BOMB_TICK_FILE", "ticking.mp3")
C.BOMB_EXPLOSION_SOUND_FILE = portalSetting("BOMB_EXPLOSION_SOUND_FILE", "neutrinobomb.mp3")
C.BOMB_TICK_SOUND_ID = portalSetting("BOMB_TICK_SOUND_ID", "") -- no unrelated fallback; provide ticking.mp3
C.BOMB_EXPLOSION_SOUND_ID = portalSetting("BOMB_EXPLOSION_SOUND_ID", "") -- no unrelated fallback; provide neutrinobomb.mp3
C.BOMB_BEEP_INTERVAL = portalSetting("BOMB_BEEP_INTERVAL", 0.36)
C.BOMB_SOUND_MAX_DISTANCE = portalSetting("BOMB_SOUND_MAX_DISTANCE", 180)
C.PRIME_BOMB_EXPLOSION_FILE = portalSetting("PRIME_BOMB_EXPLOSION_FILE", "PrimeBombExplosion.rbxmx")
C.PRIME_BOMB_DEATH_AURA_FILE = portalSetting("PRIME_BOMB_DEATH_AURA_FILE", "PrimeBombDeathAura.rbxmx")
C.FINAL_PORTAL_DISTANCE = portalSetting("FINAL_PORTAL_DISTANCE", 8)
C.FINAL_BLOOD_COLOR = portalSetting("FINAL_BLOOD_COLOR", Color3.fromRGB(185, 0, 0))
C.FINAL_SHAKE_BLOOD_INTERVAL = portalSetting("FINAL_SHAKE_BLOOD_INTERVAL", 0.15) -- 5 seconds of fluid, but cap the particle budget
C.FINAL_EJECT_SPEED = portalSetting("FINAL_EJECT_SPEED", 82)
C.FINAL_TEAROFF_MIN = portalSetting("FINAL_TEAROFF_MIN", 1)
C.FINAL_TEAROFF_MAX = portalSetting("FINAL_TEAROFF_MAX", 3)
C.CLONE_CHANCE = portalSetting("CLONE_CHANCE", 0.20) -- each completed teleport may produce one clone
C.CLONE_LIFETIME = portalSetting("CLONE_LIFETIME", 20) -- seconds, measured from clone creation
-- Prototype blue portals: a limited infinite-falling sequence, then sideways launch.
C.BLUE_LOOP_CHANCE = portalSetting("BLUE_LOOP_CHANCE", 0.15) -- roll after each successful ordinary teleport
C.BLUE_LOOP_MIN_FALLS = portalSetting("BLUE_LOOP_MIN_FALLS", 3)
C.BLUE_LOOP_MAX_FALLS = portalSetting("BLUE_LOOP_MAX_FALLS", 5)
C.BLUE_LOOP_HEIGHT = portalSetting("BLUE_LOOP_HEIGHT", 16)
C.BLUE_LOOP_START_SPEED = portalSetting("BLUE_LOOP_START_SPEED", 45)
C.BLUE_LOOP_SPEED_GAIN = portalSetting("BLUE_LOOP_SPEED_GAIN", 18)
C.BLUE_LOOP_MAX_SPEED = portalSetting("BLUE_LOOP_MAX_SPEED", 140)
C.BLUE_LOOP_CAPTURE_RADIUS = portalSetting("BLUE_LOOP_CAPTURE_RADIUS", 5.0)
C.BLUE_LOOP_STEERING = portalSetting("BLUE_LOOP_STEERING", 9)
C.BLUE_LOOP_MAX_PASS_TIME = portalSetting("BLUE_LOOP_MAX_PASS_TIME", 1.2) -- missed-crossing safety only
C.BLUE_LOOP_SIDE_LAUNCH = portalSetting("BLUE_LOOP_SIDE_LAUNCH", 125)
C.BLUE_RETURN_DISTANCE = portalSetting("BLUE_RETURN_DISTANCE", 28) -- green portal opens early ahead of the blue sideways launch
C.BLUE_RETURN_TIMEOUT = portalSetting("BLUE_RETURN_TIMEOUT", 2.25)
C.BLUE_RETURN_CAPTURE_RADIUS = portalSetting("BLUE_RETURN_CAPTURE_RADIUS", 5.5)
C.BLUE_PORTAL_COLOR = portalSetting("BLUE_PORTAL_COLOR", Color3.fromRGB(40, 170, 255))
C.BLUE_PORTAL_GLOW = portalSetting("BLUE_PORTAL_GLOW", Color3.fromRGB(45, 210, 255))
-- Every newly created portal independently rolls for a rainbow override,
-- including entrances, air pairs, blue-loop portals, return catches and terminals.
C.RAINBOW_PORTAL_DENOMINATOR = math.max(1, math.floor(tonumber(portalSetting("RAINBOW_PORTAL_DENOMINATOR", 250)) or 250))
C.RAINBOW_PORTAL_COOLDOWN = math.max(0, tonumber(portalSetting("RAINBOW_PORTAL_COOLDOWN", 30)) or 30) -- global time between rainbow appearances
C.RAINBOW_PORTAL_LINGER = portalSetting("RAINBOW_PORTAL_LINGER", 10.0) -- seconds AFTER this portal would normally close
C.RAINBOW_PORTAL_HUE_SPEED = portalSetting("RAINBOW_PORTAL_HUE_SPEED", 0.30)
C.RAINBOW_RAGDOLL_HUE_SPEED = portalSetting("RAINBOW_RAGDOLL_HUE_SPEED", 0.20)
C.RAINBOW_COLOR_UPDATE = portalSetting("RAINBOW_COLOR_UPDATE", 0.10)
-- Stylized red portal fluid ONLY from the remaining attachment points after
-- a Blender Dimension ejection (never from ordinary portal travel).
C.BLENDER_EXIT_FLUID = portalSetting("BLENDER_EXIT_FLUID", true)
C.BLENDER_EXIT_FLUID_COLOR = portalSetting("BLENDER_EXIT_FLUID_COLOR", Color3.fromRGB(185, 18, 26))
C.BLENDER_EXIT_FLUID_DURATION = portalSetting("BLENDER_EXIT_FLUID_DURATION", 4.5)
C.BLENDER_EXIT_FLUID_INTERVAL = portalSetting("BLENDER_EXIT_FLUID_INTERVAL", 0.40)
C.MAX_ACTIVE_CLONES = portalSetting("MAX_ACTIVE_CLONES", 8) -- prevents runaway exponential cloning
C.MAX_TOTAL_CLONES = portalSetting("MAX_TOTAL_CLONES", 24) -- total spawned by this script
C.BANISH_DISTANCE = portalSetting("BANISH_DISTANCE", 3000) -- off-map teleport before deletion
C.CLONE_FAILSAFE_TIME = portalSetting("CLONE_FAILSAFE_TIME", 45) -- clean up if it cannot reach another portal

function H.LoadAudio(fileName, fallbackId)
 if getcustomasset then
  local ok, asset = pcall(function() return getcustomasset(fileName) end)
  if ok and asset then print("[Portal Audio] Local:", fileName); return asset end
 end
 print("[Portal Audio] Roblox ID:", fallbackId)
 return fallbackId
end

-- Standalone MintBlood-inspired effect: no game-specific modules or folders needed.
C.FLUID_SPEED = portalSetting("FLUID_SPEED", 28)
C.FLUID_SPREAD_DEGREES = portalSetting("FLUID_SPREAD_DEGREES", 28)
C.FLUID_LIFETIME = portalSetting("FLUID_LIFETIME", 3.5)
C.FLUID_SPLASH_DURATION = portalSetting("FLUID_SPLASH_DURATION", 3.5)
C.FLUID_MAX_CAMERA_DISTANCE = portalSetting("FLUID_MAX_CAMERA_DISTANCE", 200)
local fluidRandom = Random.new()
local fluidFolder = Instance.new("Folder")
fluidFolder.Name = "LocalPortalFluid"
fluidFolder.Parent = Workspace

function H.SpawnFluidDrop(origin, direction, color)
 local drop = Instance.new("Part")
 drop.Name = "PortalFluidDrop"
 drop.Shape = Enum.PartType.Ball
 drop.Size = Vector3.new(0.5, 0.5, 0.5)
 drop.Material = Enum.Material.SmoothPlastic
 drop.Color = color
 drop.Anchored = true
 drop.CanCollide = false
 drop.CanTouch = false
 drop.CanQuery = false
 drop.CFrame = CFrame.new(origin)
 drop.Parent = fluidFolder
 local a0 = Instance.new("Attachment")
 a0.Position = Vector3.new(0, 0.2, 0)
 a0.Parent = drop
 local a1 = Instance.new("Attachment")
 a1.Position = Vector3.new(0, -0.2, 0)
 a1.Parent = drop
 local trail = Instance.new("Trail")
 trail.Attachment0 = a0
 trail.Attachment1 = a1
 trail.Color = ColorSequence.new(color)
 trail.Lifetime = 0.22
 trail.MinLength = 0.03
 trail.FaceCamera = true
 trail.Parent = drop
 local spread = math.rad(C.FLUID_SPREAD_DEGREES)
 local velocity = (direction + Vector3.new(fluidRandom:NextNumber(-spread, spread), fluidRandom:NextNumber(-spread, spread), fluidRandom:NextNumber(-spread, spread))).Unit * (C.FLUID_SPEED + fluidRandom:NextNumber(-5, 5))
 local start = os.clock()
 local connection
 connection = RunService.Heartbeat:Connect(function(dt)
  if not drop.Parent or os.clock() - start > C.FLUID_LIFETIME then
   connection:Disconnect()
   if drop.Parent then drop:Destroy() end
   return
  end
  velocity = (velocity + Vector3.new(0, -Workspace.Gravity, 0)*dt) * math.max(0, 1 - 0.1*dt)
  local delta = velocity*dt
  local hit = Workspace:Raycast(drop.Position, delta, (function()
   local params = RaycastParams.new()
   params.FilterType = Enum.RaycastFilterType.Exclude
   params.FilterDescendantsInstances = {fluidFolder}
   return params
  end)())
  if hit then
   connection:Disconnect()
   trail.Enabled = false
   drop.Shape = Enum.PartType.Block
   drop.Size = Vector3.new(0.15, 0.015, 0.15)
   -- Align the puddle's thin Y axis with the surface normal, then spin in-plane.
   local normal = hit.Normal.Unit
   local tangent = normal:Cross(Vector3.new(0, 1, 0))
   if tangent.Magnitude < 0.01 then tangent = normal:Cross(Vector3.new(1, 0, 0)) end
   tangent = tangent.Unit
   local spin = fluidRandom:NextNumber(0, math.pi*2)
   local xAxis = tangent*math.cos(spin) + normal:Cross(tangent)*math.sin(spin)
   local zAxis = xAxis:Cross(normal)
   drop.CFrame = CFrame.fromMatrix(hit.Position + normal*0.025, xAxis, normal, zAxis)
   local scale = fluidRandom:NextNumber(0.4, 1.5)
   TweenService:Create(drop, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(scale, 0.015, scale)}):Play()
   task.delay(C.FLUID_SPLASH_DURATION, function()
    if drop.Parent then
     local tween = TweenService:Create(drop, TweenInfo.new(0.7), {Transparency = 1, Size = Vector3.new(0.01, 0.015, 0.01)})
     tween:Play()
     tween.Completed:Once(function() if drop.Parent then drop:Destroy() end end)
    end
   end)
  else
   drop.Position += delta
  end
 end)
end

function H.PlayPortalSound(info, portal)
 if not portal or not portal.Parent then return end
 local root = portal:IsA("BasePart") and portal or portal.PrimaryPart or portal:FindFirstChildWhichIsA("BasePart", true)
 if not root then return end
 local emitter = Instance.new("Part")
 emitter.Name = "LocalPortalSoundEmitter"
 emitter.Size = Vector3.new(0.1, 0.1, 0.1)
 emitter.Transparency = 1
 emitter.Anchored = true
 emitter.CanCollide = false
 emitter.CanTouch = false
 emitter.CanQuery = false
 emitter.CFrame = root.CFrame
 emitter.Parent = Workspace
 local sound = Instance.new("Sound")
 sound.Name = "PortalSound"
 sound.SoundId = H.LoadAudio(info.File, info.ID)
 sound.Volume = .7
 sound.RollOffMode = Enum.RollOffMode.InverseTapered
 sound.RollOffMinDistance = C.SOUND_MIN_DISTANCE
 sound.RollOffMaxDistance = C.SOUND_MAX_DISTANCE
 sound.Parent = emitter
 sound:Play()
 Debris:AddItem(emitter, 20)
 sound.Ended:Once(function()
  if emitter.Parent then emitter:Destroy() end
 end)
end

-- Detached local 3D sound emitters continue playing after bomb/portal cleanup.
-- Use the original game's sound assets when known, otherwise local files or
-- configurable fallbacks. This changes audio only; no damaging explosion.
-- Prefer the user's local audio files over unrelated sounds in ReplicatedStorage.
function H.ResolveTerminalSound(name, fileName, fallback)
 if type(getcustomasset) == "function" then
  local ok, asset = pcall(getcustomasset, fileName)
  if ok and type(asset) == "string" and asset ~= "" then return asset end
  warn("[PrimeBomb] Local audio unavailable:", fileName, asset)
 end
 return fallback
end

function H.PlayTerminalBombSound(position, isExplosion, playbackSpeed)
 local holder=Instance.new("Part")
 holder.Name=isExplosion and "PrimeBombExplosionAudio" or "PrimeBombTickAudio"
 holder.Size=Vector3.new(0.1,0.1,0.1)
 holder.Transparency=1
 holder.Anchored=true
 holder.CanCollide=false
 holder.CanTouch=false
 holder.CanQuery=false
 holder.CFrame=CFrame.new(position)
 holder.Parent=Workspace
 local sound=Instance.new("Sound")
 sound.Name=holder.Name
 sound.SoundId=isExplosion
  and H.ResolveTerminalSound("PrimeBombExplosion",C.BOMB_EXPLOSION_SOUND_FILE,C.BOMB_EXPLOSION_SOUND_ID)
  or H.ResolveTerminalSound("PrimeBombTick",C.BOMB_TICK_FILE,C.BOMB_TICK_SOUND_ID)
 sound.Volume=isExplosion and 10 or 3.5
 sound.PlaybackSpeed=playbackSpeed or 1
 sound.RollOffMode=Enum.RollOffMode.InverseTapered
 sound.RollOffMinDistance=8
 sound.RollOffMaxDistance=C.BOMB_SOUND_MAX_DISTANCE
 sound.Parent=holder
 sound:Play()
 Debris:AddItem(holder,isExplosion and 20 or 12)
 sound.Ended:Once(function() if holder.Parent then holder:Destroy() end end)
 return sound
end

function H.EmitPortalClosingFluid(frame, size, color)
 if not C.ENABLE_CLOSING_FLUID then return end
 local camera = Workspace.CurrentCamera
 if camera and (camera.CFrame.Position - frame.Position).Magnitude > C.FLUID_MAX_CAMERA_DISTANCE then return end
 local rx, ry = math.max(size.X * 0.36, 0.5), math.max(size.Y * 0.36, 0.5)
 for _ = 1, C.CLOSING_FLUID_DROPS do
  local theta = fluidRandom:NextNumber(0, math.pi * 2)
  local radius = math.sqrt(fluidRandom:NextNumber())
  local origin = (frame * CFrame.new(math.cos(theta)*rx*radius, math.sin(theta)*ry*radius, -0.18)).Position
  H.SpawnFluidDrop(origin, frame.LookVector, color)
 end
end

function H.LoadPortal()
 if not getcustomasset then warn("[Portal] getcustomasset unavailable"); return nil end
 local ok, assetId = pcall(function() return getcustomasset(C.PORTAL_FILE) end)
 if not ok or not assetId then warn("[Portal] Could not load Portal.rbxm:", assetId); return nil end
 local ok2, objects = pcall(function() return game:GetObjects(assetId) end)
 if not ok2 or not objects or not objects[1] then warn("[Portal] GetObjects failed:", objects); return nil end
 local template = objects[1]
 template.Name, template.Parent = "PortalTemplate", ReplicatedStorage
 return template
end
local PortalTemplate = H.LoadPortal()
assert(PortalTemplate, "[FunnyRagdolls/Portal] Portal.rbxm could not be loaded")

function H.GetBodyPart(model)
 for _, name in ipairs({"HumanoidRootPart","UpperTorso","LowerTorso","Torso"}) do
  local p = model:FindFirstChild(name, true)
  if p and p:IsA("BasePart") then return p end
 end
 for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then return p end end
end

-- Each ragdoll keeps its own NoCollisionConstraints against nearby opaque
-- world parts. This does NOT disable those parts globally, so other players
-- and transparent/invisible platforms retain their ordinary collisions.
-- PhysicsService collision groups are deliberately avoided because changing
-- existing map groups could break unrelated game systems.
function H.StartOpaquePassThrough(model)
 if not C.PASS_THROUGH_OPAQUE then return function() end end
 local holder = Instance.new("Folder")
 holder.Name = "PortalOpaquePassThrough"
 holder.Parent = model
 local pairsByWorldPart = {}
 local running = true
 local timer = 0
 local scanParams = OverlapParams.new()
 scanParams.FilterType = Enum.RaycastFilterType.Exclude
 scanParams.FilterDescendantsInstances = {RAGDOLLS_FOLDER, fluidFolder}
 scanParams.MaxParts = C.OPAQUE_MAX_NEARBY_PARTS
 local function update()
  local body = H.GetBodyPart(model)
  if not body then return end
  local ragdollParts = {}
  for _, p in ipairs(model:GetDescendants()) do
   if p:IsA("BasePart") and p.CanCollide then
    table.insert(ragdollParts, p)
   end
  end
  local nearby = {}
  for _, worldPart in ipairs(Workspace:GetPartBoundsInRadius(body.Position, C.OPAQUE_SCAN_RADIUS, scanParams)) do
   if worldPart:IsA("BasePart") and worldPart.CanCollide and worldPart.Transparency == 0
    and not worldPart:IsDescendantOf(model) and not worldPart:FindFirstAncestor("RagdollPortal") then
    nearby[worldPart] = true
    local existing = pairsByWorldPart[worldPart]
    if not existing then existing = {}; pairsByWorldPart[worldPart] = existing end
    for _, ragdollPart in ipairs(ragdollParts) do
     if not existing[ragdollPart] then
      local constraint = Instance.new("NoCollisionConstraint")
      constraint.Part0 = ragdollPart
      constraint.Part1 = worldPart
      constraint.Parent = holder
      existing[ragdollPart] = constraint
     end
    end
   end
  end
  for worldPart, existing in pairs(pairsByWorldPart) do
   if not nearby[worldPart] or not worldPart.Parent then
    for _, constraint in pairs(existing) do constraint:Destroy() end
    pairsByWorldPart[worldPart] = nil
   else
    for ragdollPart, constraint in pairs(existing) do
     if not ragdollPart.Parent or not ragdollPart.CanCollide then
      constraint:Destroy()
      existing[ragdollPart] = nil
     end
    end
   end
  end
 end
 update()
 local connection = RunService.Heartbeat:Connect(function(dt)
  if not running or not model.Parent then return end
  timer += dt
  if timer >= C.OPAQUE_SCAN_INTERVAL then
   timer = 0
   update()
  end
 end)
 return function()
  if not running then return end
  running = false
  connection:Disconnect()
  holder:Destroy()
 end
end

-- Multi-point, obstruction-aware floor predictor. A narrow ray handles the actual
-- center-of-mass flight, while an occasional spherecast detects walls a ragdoll
-- body would graze. Never predict through a solid wall into a hidden floor.
function H.PredictGroundImpact(model, body)
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {model, fluidFolder, RAGDOLLS_FOLDER}
 params.IgnoreWater = true
 params.RespectCanCollide = true

 local function clearLanding(hit)
  if not hit or hit.Normal.Y < 0.65 then return nil end
  -- Check for collidable obstructions in the landing aperture. Offset a small
  -- amount only when necessary; prefer the actual predicted hit every time.
  local overlap = OverlapParams.new()
  overlap.FilterType = Enum.RaycastFilterType.Exclude
  overlap.MaxParts = 20
  local offsets = {Vector3.zero, Vector3.new(2.2,0,0),Vector3.new(-2.2,0,0),
   Vector3.new(0,0,2.2),Vector3.new(0,0,-2.2),
   Vector3.new(3.5,0,0),Vector3.new(-3.5,0,0),
   Vector3.new(0,0,3.5),Vector3.new(0,0,-3.5)}
  for _, offset in ipairs(offsets) do
   local floor = hit
   if offset.Magnitude > 0 then
    floor = Workspace:Raycast(hit.Position + offset + Vector3.yAxis*2.5,
     Vector3.new(0,-5.5,0), params)
   end
   if floor and floor.Normal.Y >= 0.65
    and math.abs(floor.Position.Y-hit.Position.Y) < 1.4 then
    local exclusions = {model, RAGDOLLS_FOLDER,fluidFolder,floor.Instance}
    overlap.FilterDescendantsInstances = exclusions
    local blocked = false
    for _, obstacle in ipairs(Workspace:GetPartBoundsInBox(
     CFrame.new(floor.Position+Vector3.yAxis*(C.PREDICTION_LANDING_CLEARANCE*0.5+0.15)),
     Vector3.new(4.4,C.PREDICTION_LANDING_CLEARANCE,4.4),overlap)) do
     if obstacle.CanCollide and not obstacle:IsDescendantOf(model) then
      blocked=true
      break
     end
    end
    if not blocked then return floor end
   end
  end
  return hit -- fall back to the real hit, never fabricate a floor surface
 end

 local origin = body.Position-Vector3.yAxis*(body.Size.Y*0.30)
 local velocity = body.AssemblyLinearVelocity
 local gravity = Vector3.new(0,-Workspace.Gravity,0)
 local previous = origin
 local segmentIndex = 0
 for t = C.PREDICTION_STEP,C.PREDICTION_LOOKAHEAD,C.PREDICTION_STEP do
  local future = origin+velocity*t+gravity*(0.5*t*t)
  local segment=future-previous
  segmentIndex += 1
  if segment.Magnitude>0.0001 then
   local hit=Workspace:Raycast(previous,segment,params)
   -- Sweep a little body volume every third segment without running expensive
   -- volumetric checks on every single physics frame.
   if not hit and velocity.Magnitude>22 and segmentIndex%3==0 then
    local ok,swept=pcall(function()
     return Workspace:Spherecast(previous,C.PREDICTION_SWEEP_RADIUS,segment,params)
    end)
    if ok then hit=swept end
   end
   if hit then
    if hit.Normal.Y>=0.65 and segment:Dot(hit.Normal)<0 then
     return clearLanding(hit)
    end
    -- First solid collision was a wall/object, not a ground impact. Predict a
    -- plausible landing on THIS side of it, rather than passing through it.
    local beforeWall=hit.Position-segment.Unit*1.2
    local floor=Workspace:Raycast(beforeWall+Vector3.yAxis*0.35,
     -Vector3.yAxis*25,params)
    if floor and floor.Normal.Y>=0.65 then return clearLanding(floor) end
    return nil
   end
  end
  previous=future
 end
 return nil
end

function H.GetGround(model, body)
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {model,RAGDOLLS_FOLDER,fluidFolder}
 params.IgnoreWater = true
 params.RespectCanCollide = true
 -- Only look for a nearby floor. A long ray can hit a lower level of the map
 -- and make the portal appear far beneath the ragdoll.
 local result = Workspace:Raycast(
  body.Position + Vector3.new(0, C.GROUND_RAY_START_HEIGHT, 0),
  Vector3.new(0, -C.GROUND_RAY_DISTANCE, 0),
  params
 )
 if result and body.Position.Y - result.Position.Y <= C.MAX_GROUND_DROP then
  return result
 end
 return nil
end

function H.GetRoot(portal)
 if portal:IsA("BasePart") then return portal end
 if portal:IsA("Model") then
  if portal.PrimaryPart then return portal.PrimaryPart end
  for _, obj in ipairs(portal:GetDescendants()) do
   if obj:IsA("BasePart") then portal.PrimaryPart = obj; return obj end
  end
 end
end

-- MAIN portal image: preserve the existing green style by default.
-- The two physical bubble-model ImageLabels are a separate cosmetic layer.
C.PORTAL_IMAGE_ID = portalSetting("PORTAL_IMAGE_ID", "rbxassetid://90420443390752")
C.PORTAL_IMAGE_COLOR = portalSetting("PORTAL_IMAGE_COLOR", Color3.fromRGB(43, 200, 0))
C.PORTAL_BUBBLE_IMAGE_ID = portalSetting("PORTAL_BUBBLE_IMAGE_ID", "rbxassetid://99217935145970")

-- Gold/yellow Evil Morty-inspired palette for players flagged by the leaderboard.
C.EVIL_MORTY_IMAGE_COLOR = portalSetting("EVIL_MORTY_IMAGE_COLOR", Color3.fromRGB(255, 208, 25))
C.EVIL_MORTY_ACCENT = portalSetting("EVIL_MORTY_ACCENT", Color3.fromRGB(255, 221, 48))
C.EVIL_MORTY_GLOW = portalSetting("EVIL_MORTY_GLOW", Color3.fromRGB(255, 185, 15))

function H.IsBubbleSubtree(item, portal)
 local current = item
 while current and current ~= portal do
  local cleaned = string.lower(current.Name):gsub("[%s_%-]", "")
  if cleaned == "backbubbles" or cleaned == "frontbubbles" then return true end
  current = current.Parent
 end
 return false
end

-- Match exactly the leaderboard's rules, not its other highlight categories:
-- (KillerWins - KillerLosses >= 7) OR (SurvivorWins - SurvivorLosses >= 15).
function H.PlayerIsSuspicious(player)
 if not player then return false end
 local data = player:FindFirstChild("PlayerData")
 local stats = data and data:FindFirstChild("Stats")
 local killer = stats and stats:FindFirstChild("KillerStats")
 local survivor = stats and stats:FindFirstChild("SurvivorStats")
 if not killer or not survivor then return false end
 local kw = killer:FindFirstChild("KillerWins")
 local kl = killer:FindFirstChild("KillerLosses")
 local sw = survivor:FindFirstChild("SurvivorWins")
 local sl = survivor:FindFirstChild("SurvivorLosses")
 if not (kw and kl and sw and sl) then return false end
 return ((tonumber(kw.Value) or 0) - (tonumber(kl.Value) or 0) >= 7)
  or ((tonumber(sw.Value) or 0) - (tonumber(sl.Value) or 0) >= 15)
end

function H.GetRagdollOwner(model)
 if not model then return nil end
 local candidates = {}
 local username = model:GetAttribute("Username")
 if username ~= nil then table.insert(candidates, tostring(username)) end
 -- Each recursive clone adds "_PortalClone_N" to the name; strip all suffixes.
 local modelName = model.Name:gsub("_PortalClone_%d+", "")
 table.insert(candidates, modelName)
 for _, candidate in ipairs(candidates) do
  local lower = string.lower(candidate)
  for _, player in ipairs(Players:GetPlayers()) do
   if player.Name:lower() == lower then return player end
  end
 end
 return nil
end

function H.ApplyPortalImageAppearance(portal, model)
 local suspicious = H.PlayerIsSuspicious(H.GetRagdollOwner(model))
 portal:SetAttribute("EvilMortyTheme", suspicious)
 for _, item in ipairs(portal:GetDescendants()) do
  local isBubble = H.IsBubbleSubtree(item, portal)
  if item:IsA("ImageLabel") or item:IsA("ImageButton") then
   if isBubble then
    -- Keep the bubble tint/geometry as supplied in Portal.rbxm.
    item.Image = C.PORTAL_BUBBLE_IMAGE_ID
   elseif item:FindFirstAncestorWhichIsA("SurfaceGui") then
    item.Image = C.PORTAL_IMAGE_ID
    item.ImageColor3 = suspicious and C.EVIL_MORTY_IMAGE_COLOR or C.PORTAL_IMAGE_COLOR
   end
  end
  if suspicious and not isBubble then
   if item:IsA("BasePart") then
    item.Color = C.EVIL_MORTY_ACCENT
   elseif item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
    item.Color = C.EVIL_MORTY_GLOW
   elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then
    item.Color = ColorSequence.new({
     ColorSequenceKeypoint.new(0, C.EVIL_MORTY_ACCENT),
     ColorSequenceKeypoint.new(1, C.EVIL_MORTY_GLOW)
    })
   elseif item:IsA("UIStroke") then
    item.Color = C.EVIL_MORTY_ACCENT
   elseif item:IsA("UIGradient") then
    item.Color = ColorSequence.new(C.EVIL_MORTY_IMAGE_COLOR)
   elseif item:IsA("Decal") then
    item.Color3 = C.EVIL_MORTY_ACCENT
   elseif item:IsA("GuiObject") then
    item.BackgroundColor3 = C.EVIL_MORTY_ACCENT
    if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
     item.TextColor3 = C.EVIL_MORTY_IMAGE_COLOR
    end
   elseif item:IsA("Highlight") then
    item.FillColor = C.EVIL_MORTY_ACCENT
    item.OutlineColor = C.EVIL_MORTY_GLOW
   elseif item:IsA("Fire") then
    item.Color = C.EVIL_MORTY_ACCENT
    item.SecondaryColor = C.EVIL_MORTY_GLOW
   elseif item:IsA("Smoke") then
    item.Color = C.EVIL_MORTY_GLOW
   elseif item:IsA("Sparkles") then
    item.SparkleColor = C.EVIL_MORTY_ACCENT
   end
  end
 end
end

-- Rainbow rolls are shared by every portal type. 20 hops can spawn 40+ portals,
-- so a 1-in-50 roll PER portal was much more frequent than it appeared.
-- Keep a single cooldown across this loader instance, including clone chains.
H.LastRainbowSpawnAt = -math.huge
H.StartRainbowPortal = nil
function H.CreatePortal(model)
 local clone = PortalTemplate:Clone()
 local portal
 if clone:IsA("Model") then portal = clone else portal = Instance.new("Model"); clone.Parent = portal end
 portal.Name = "RagdollPortal"
 H.ApplyPortalImageAppearance(portal, model)
 local root = H.GetRoot(portal)
 if not root then portal:Destroy(); warn("[Portal] Asset contains no BasePart"); return end
 for _, obj in ipairs(portal:GetDescendants()) do
  if (obj:IsA("Script") or obj:IsA("LocalScript")) and obj.Name == "Rotate" then obj.Enabled = false end
 end
 portal.Parent = Workspace
 -- Rare global rainbow roll: any portal type can be selected, but even
 -- multi-ragdoll clone storms cannot produce several rainbow portals at once.
 -- This is a per-portal chance, with a separate cooldown for successful rolls.
 local now = os.clock()
 if now - H.LastRainbowSpawnAt >= C.RAINBOW_PORTAL_COOLDOWN
  and math.random(1, C.RAINBOW_PORTAL_DENOMINATOR) == 1 then
  H.LastRainbowSpawnAt = now
  H.StartRainbowPortal(portal)
 end
 return portal, root
end

function H.GetVisibleFace(root)
 for _, obj in ipairs(root:GetDescendants()) do
  if obj:IsA("SurfaceGui") or obj:IsA("Decal") or obj:IsA("Texture") then return obj.Face end
 end
 return Enum.NormalId.Front
end
function H.FaceDirection(root, face)
 if face == Enum.NormalId.Front then return root.CFrame.LookVector end
 if face == Enum.NormalId.Back then return -root.CFrame.LookVector end
 if face == Enum.NormalId.Top then return root.CFrame.UpVector end
 if face == Enum.NormalId.Bottom then return -root.CFrame.UpVector end
 if face == Enum.NormalId.Right then return root.CFrame.RightVector end
 return -root.CFrame.RightVector
end
function H.RotationBetween(a,b)
 a,b = a.Unit,b.Unit
 local dot = math.clamp(a:Dot(b),-1,1)
 if dot > 0.9999 then return CFrame.new() end
 if dot < -0.9999 then
  local axis = a:Cross(Vector3.new(0,1,0))
  if axis.Magnitude < 0.001 then axis = a:Cross(Vector3.new(1,0,0)) end
  return CFrame.fromAxisAngle(axis.Unit, math.pi)
 end
 return CFrame.fromAxisAngle(a:Cross(b).Unit, math.acos(dot))
end

-- Anchor using the visible portal panel (PortalA), NOT the full model bounds.
-- This asset's FloorPortalTrigger is a large invisible box positioned above the
-- panel; using GetBoundingBox() for the entire model incorrectly drags the
-- visible panel below the floor. Project the panel's own oriented thickness
-- onto the surface normal and keep its visible face slightly above the floor.
function H.AnchorPortalToSurface(portal, root, surfacePosition, normal, clearance)
 normal = normal.Unit
 if portal:GetAttribute("GroundLocked") then
  clearance = 0.035 -- visible panel almost flush with the real floor
 else
  clearance = clearance or C.SURFACE_CLEARANCE
 end
 if not root or not root.Parent then return portal:GetPivot() end

 local rootCF = root.CFrame
 local extent =
  math.abs(rootCF.RightVector:Dot(normal))*root.Size.X/2
  + math.abs(rootCF.UpVector:Dot(normal))*root.Size.Y/2
  + math.abs(rootCF.LookVector:Dot(normal))*root.Size.Z/2

 local targetProjection = surfacePosition:Dot(normal) + clearance
 local currentLowestProjection = root.Position:Dot(normal) - extent
 local correction = targetProjection - currentLowestProjection
 portal:PivotTo(portal:GetPivot() + normal*correction)
 return portal:GetPivot()
end

function H.PlacePortal(portal, root, position, normal)
 normal = normal.Unit
 local alignment = H.RotationBetween(H.FaceDirection(root, H.GetVisibleFace(root)), normal)
 local rotation = root.CFrame - root.CFrame.Position
 portal:PivotTo(CFrame.new(position) * alignment * rotation)
 return H.AnchorPortalToSurface(portal, root, position, normal, C.SURFACE_CLEARANCE)
end

-- Reject portals embedded in nearby geometry. The contacted surface is excluded
-- because the portal is intentionally placed directly against that surface.
-- Geometry validation uses the actual 9x9 portal *panel*, not the huge
-- invisible FloorPortalTrigger. The full opening must be free of visible or
-- physically solid obstructions, including partial coverage near the rim.
function H.IsPortalBlocker(part)
 return part:IsA("BasePart") and (part.CanCollide or part.Transparency < 0.98)
end

function H.PortalHasObstruction(portal, ragdoll, surfacePart)
 local root = H.GetRoot(portal)
 if not root or not root.Parent then return true end
 local normal = H.FaceDirection(root, H.GetVisibleFace(root)).Unit
 local right = root.CFrame.RightVector
 right = right - normal * right:Dot(normal)
 if right.Magnitude < 0.05 then
  right = root.CFrame.UpVector - normal * root.CFrame.UpVector:Dot(normal)
 end
 if right.Magnitude < 0.05 then return true end
 right = right.Unit
 local up = normal:Cross(right).Unit
 -- Keep a little breathing room around the outermost visible rim.
 local halfSize = math.max(2.4, math.min(4.55, math.max(root.Size.X, root.Size.Y)*0.47))
 local sampleFrame = CFrame.fromMatrix(root.Position + normal*0.65, right, up, normal)
 local overlap = OverlapParams.new()
 overlap.FilterType = Enum.RaycastFilterType.Exclude
 local exclusions = {portal, RAGDOLLS_FOLDER, fluidFolder}
 if ragdoll then table.insert(exclusions, ragdoll) end
 -- A floor or wall supporting the portal belongs BEHIND the surface.
 -- Exclude that single part, but never exclude its neighboring geometry.
 if surfacePart then table.insert(exclusions, surfacePart) end
 overlap.FilterDescendantsInstances = exclusions
 overlap.MaxParts = 80
 -- Validate at both 0 and 45 degrees. Spinning a square portal frame can
 -- sweep its corners into an object even if the original angle was clear.
 for _, roll in ipairs({0, math.pi/4}) do
  local sweptFrame = sampleFrame * CFrame.Angles(0,0,roll)
  for _, part in ipairs(Workspace:GetPartBoundsInBox(sweptFrame,
   Vector3.new(halfSize*2, halfSize*2, 2.1), overlap)) do
   if H.IsPortalBlocker(part) then return true end
  end
 end
 -- Thin parts can cover only a corner and slip through a coarse box check.
 -- Nine short rays scan the face from in front to just behind the panel.
 local ray = RaycastParams.new()
 ray.FilterType = Enum.RaycastFilterType.Exclude
 ray.FilterDescendantsInstances = exclusions
 ray.RespectCanCollide = false
 ray.IgnoreWater = true
 for _, offset in ipairs({Vector2.new(0,0),Vector2.new(1,0),Vector2.new(-1,0),
  Vector2.new(0,1),Vector2.new(0,-1),Vector2.new(0.75,0.75),
  Vector2.new(-0.75,0.75),Vector2.new(0.75,-0.75),Vector2.new(-0.75,-0.75)}) do
  local point = root.Position + right*offset.X*halfSize + up*offset.Y*halfSize
  local hit = Workspace:Raycast(point + normal*1.75, -normal*2.05, ray)
  if hit and H.IsPortalBlocker(hit.Instance) then return true end
 end
 return false
end

function H.NudgePortalOutOfObstruction(portal, ragdoll, surfacePosition, normal, surfacePart)
 -- The portal must stay on its selected surface: moving it forward along
 -- the normal creates a floating portal in front of the obstructing part.
 return not H.PortalHasObstruction(portal, ragdoll, surfacePart)
end

-- Search a small patch of the same surface without moving a ground portal
-- far from the ragdoll it needs to catch. Never keep a blocked placement.
function H.TryPlacePortal(portal, root, position, normal, ragdoll, surfacePart)
 local tangent = normal:Cross(Vector3.yAxis)
 if tangent.Magnitude < 0.05 then tangent = normal:Cross(Vector3.xAxis) end
 tangent = tangent.Unit
 local other = normal:Cross(tangent).Unit
 local offsets = {Vector2.zero,Vector2.new(2.2,0),Vector2.new(-2.2,0),
  Vector2.new(0,2.2),Vector2.new(0,-2.2),Vector2.new(2.2,2.2),
  Vector2.new(-2.2,2.2),Vector2.new(2.2,-2.2),Vector2.new(-2.2,-2.2)}
 local rp = RaycastParams.new()
 rp.FilterType = Enum.RaycastFilterType.Exclude
 rp.FilterDescendantsInstances = {portal,ragdoll,RAGDOLLS_FOLDER,fluidFolder}
 rp.RespectCanCollide = true
 for _, offset in ipairs(offsets) do
  local candidate = position + tangent*offset.X + other*offset.Y
  if surfacePart then
   local hit = Workspace:Raycast(candidate + normal*1.5, -normal*3, rp)
   if not hit or hit.Instance ~= surfacePart or hit.Normal:Dot(normal) < 0.85 then
    continue
   end
   candidate = hit.Position
  end
  H.PlacePortal(portal, root, candidate, normal)
  if not H.PortalHasObstruction(portal, ragdoll, surfacePart) then
   return true, candidate
  end
 end
 return false, position
end

-- Clear, visibly open corridor between a ragdoll and the Blender portal.
-- Unlike general placement, this rejects even non-collidable opaque decor.
function H.BlenderCorridorClear(model, portalCenter, portal)
 local body = H.GetBodyPart(model)
 if not body then return false end
 local from = body.Position + Vector3.yAxis*0.55
 local to = portalCenter + Vector3.yAxis*0.15
 local distance = (to-from).Magnitude
 if distance < 2 then return false end
 local exclusions = {model,RAGDOLLS_FOLDER,fluidFolder}
 if portal then table.insert(exclusions,portal) end
 local overlap = OverlapParams.new()
 overlap.FilterType = Enum.RaycastFilterType.Exclude
 overlap.FilterDescendantsInstances = exclusions
 overlap.MaxParts = 80
 local corridor = CFrame.lookAt((from+to)*0.5,to)
 for _, part in ipairs(Workspace:GetPartBoundsInBox(corridor,
  Vector3.new(2.5,2.6,math.max(0.3,distance-2.1)),overlap)) do
  if part:IsA("BasePart") and part.Transparency < 0.98 then return false end
 end
 local ray = RaycastParams.new()
 ray.FilterType = Enum.RaycastFilterType.Exclude
 ray.FilterDescendantsInstances = exclusions
 ray.RespectCanCollide = false
 ray.IgnoreWater = true
 local delta=to-from
 for _, side in ipairs({Vector3.zero,Vector3.yAxis*0.75,Vector3.yAxis*-0.45}) do
  local hit = Workspace:Raycast(from+side,delta,ray)
  if hit and hit.Instance.Transparency < 0.98 then return false end
 end
 return true
end

function H.ScalePortal(portal, from, to, duration, surfacePosition, surfaceNormal, surfacePart, ragdoll)
 if not portal or not portal.Parent then return end
 local start = os.clock()
 while portal.Parent do
  local alpha = math.clamp((os.clock()-start)/math.max(duration,0.01),0,1)
  local eased = alpha*alpha*(3-2*alpha)
  pcall(function() portal:ScaleTo(from+(to-from)*eased) end)
  if surfacePosition and surfaceNormal then
   pcall(function()
    H.AnchorPortalToSurface(portal, H.GetRoot(portal), surfacePosition, surfaceNormal, C.SURFACE_CLEARANCE)
    H.NudgePortalOutOfObstruction(portal, ragdoll, surfacePosition, surfaceNormal, surfacePart)
   end)
  end
  if alpha >= 1 then break end
  RunService.Heartbeat:Wait()
 end
end

-- Opening animation modeled on RoundPortalVisuals.openingScale/apply.
-- Two Elastic-Out stages scale EVERY BasePart and its offset from the portal
-- root, rather than stretching only the visible panel. Original geometry is
-- snapshotted once so repeated frames never compound the scale.
C.OPEN_STAGE_ONE, C.OPEN_STAGE_TWO = portalSetting("OPEN_STAGE_ONE", 0.23), portalSetting("OPEN_STAGE_TWO", 0.30)
C.OPEN_TINY = portalSetting("OPEN_TINY", Vector3.new(0.131578952, 0.123839005, 1))
C.OPEN_STRETCH = portalSetting("OPEN_STRETCH", Vector3.new(0.275000005, 1.176470637, 1))
C.OPEN_FULL = portalSetting("OPEN_FULL", Vector3.new(1, 1, 1))

function H.ElasticPortalIntro(portal, root, surfacePosition, surfaceNormal, surfacePart, ragdoll, dynamicTarget)
 if not portal or not portal.Parent or not root or not root.Parent then return end
 local reference = root.CFrame
 local referenceSurface = surfacePosition
 local original = {}
 for _, part in ipairs(portal:GetDescendants()) do
  if part:IsA("BasePart") then
   table.insert(original, {
    part = part,
    size = part.Size,
    relative = reference:ToObjectSpace(part.CFrame)
   })
  end
 end

 local function apply(scale)
  if not portal.Parent or not root.Parent then return end
  -- While the portal opens, let its actual position follow the most recently
  -- predicted landing point instead of resetting it to its first location.
  if dynamicTarget and referenceSurface then
   local target = dynamicTarget()
   if target then
    reference = reference + (target - referenceSurface)
    referenceSurface = target
   end
  end
  -- The root is the animation frame, just like the source module's frame.
  -- It stays fixed in world space, so the ground clearance is not lost.
  for _, record in ipairs(original) do
   local part, relative, size = record.part, record.relative, record.size
   if part.Parent then
    local right, up, look = relative.RightVector, relative.UpVector, relative.LookVector
    local function stretchedLength(axis, length)
     return math.max(0.001, length * Vector3.new(
      axis.X * scale.X, axis.Y * scale.Y, axis.Z * scale.Z
     ).Magnitude)
    end
    part.Size = Vector3.new(
     stretchedLength(right, size.X),
     stretchedLength(up, size.Y),
     stretchedLength(look, size.Z)
    )
    local offset = relative.Position
    part.CFrame = reference * CFrame.new(
     offset.X * scale.X, offset.Y * scale.Y, offset.Z * scale.Z
    ) * relative.Rotation
   end
  end
 end

 local function stage(fromScale, toScale, duration)
  local started = os.clock()
  while portal.Parent and root.Parent do
   local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
   local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
   apply(fromScale:Lerp(toScale, eased))
   if alpha >= 1 then break end
   RunService.Heartbeat:Wait()
  end
 end

 apply(C.OPEN_TINY)
 stage(C.OPEN_TINY, C.OPEN_STRETCH, C.OPEN_STAGE_ONE)
 stage(C.OPEN_STRETCH, C.OPEN_FULL, C.OPEN_STAGE_TWO)
 apply(C.OPEN_FULL)
end

function H.StartRotation(portal, base, normal)
 local angle, connection = 0, nil
 connection = RunService.Heartbeat:Connect(function(dt)
  if not portal.Parent then if connection then connection:Disconnect() end; return end
  angle += math.rad(C.ROTATION_SPEED)*dt
  -- Use the current pivot so surface anchoring during growth is not undone.
  local pos = portal:GetPivot().Position
  portal:PivotTo(CFrame.new(pos)*CFrame.fromAxisAngle(normal.Unit,angle)*(base-base.Position))
 end)
 return function() if connection then connection:Disconnect(); connection=nil end end
end

function H.GetTrigger(portal)
 local trigger = portal:FindFirstChild("FloorPortalTrigger", true)
 if trigger and trigger:IsA("BasePart") then trigger.CanTouch=true; trigger.CanQuery=true; return trigger end
 return H.GetRoot(portal)
end

function H.BounceRagdollTowardPortal(model, trigger, body)
 if not model.Parent or not trigger.Parent or not body or not body.Parent then return end
 -- Give the ragdoll a visible hop toward the portal if it hasn't entered naturally.
 local offset = trigger.Position - body.Position
 local direction = offset.Magnitude > 0.01 and offset.Unit or Vector3.new(0, 1, 0)
 local velocity = direction * C.BOUNCE_SPEED + Vector3.new(0, 18, 0)
 local seen = {}
 for _, part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") and not part.Anchored then
   local assembly = part.AssemblyRootPart or part
   if not seen[assembly] then
    seen[assembly] = true
    assembly.AssemblyLinearVelocity = velocity
   end
  end
 end
end

function H.WaitForEntry(model, trigger, portal, body, bounceAfter)
 local entered = false
 local bounced = false
 local connection = trigger.Touched:Connect(function(hit) if hit and hit:IsDescendantOf(model) then entered=true end end)
 local params = OverlapParams.new()
 params.FilterType = Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances = {model}
 local start = os.clock()
 while model.Parent and portal.Parent and not entered and os.clock()-start < C.ENTRY_TIMEOUT do
  if #Workspace:GetPartBoundsInBox(trigger.CFrame, trigger.Size, params) > 0 then entered=true; break end
  if bounceAfter and not bounced and os.clock()-start >= bounceAfter then
   bounced = true
   H.BounceRagdollTowardPortal(model, trigger, body)
  end
  RunService.Heartbeat:Wait()
 end
 if connection then connection:Disconnect() end
 return entered
end

function H.SetRagdollVelocity(model, velocity)
 local seen = {}
 for _, part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") and not part.Anchored then
   local assembly = part.AssemblyRootPart or part
   if not seen[assembly] then
    seen[assembly] = true
    assembly.AssemblyLinearVelocity = velocity
   end
  end
 end
end

-- Every heartbeat: update the predicted floor impact, then detect entry.
-- If no portal entry has occurred for 2.5 seconds, switch to an aggressive
-- collision-free rescue until we actually cross the CURRENT portal.
function H.DisableCollision(model)
 local old = {}
 local function apply(obj)
  if obj:IsA("BasePart") and old[obj] == nil then old[obj]=obj.CanCollide; obj.CanCollide=false end
 end
 for _, obj in ipairs(model:GetDescendants()) do apply(obj) end
 local conn = model.DescendantAdded:Connect(apply)
 return function()
  if conn then conn:Disconnect(); conn=nil end
  for part,value in pairs(old) do if part.Parent then part.CanCollide=value end end
 end
end


function H.WaitForPredictedImpact(model, portal, root, tracking)
 local previousPosition = nil
 local recoveryRestore = nil
 local recovering = false
 local function finish(result)
  if recoveryRestore then
   recoveryRestore()
   recoveryRestore = nil
  end
  return result
 end
 while model.Parent and portal.Parent do
  if tracking.flow and tracking.flow.finalizing then return finish(false) end
  local body = H.GetBodyPart(model)
  if not body then return finish(false) end

  -- The recovery clock carries across every portal hop for this ragdoll.
  -- Only real portal entry resets it, not portal creation or prediction updates.
  if not recovering and os.clock() - tracking.lastTeleportAt >= C.STUCK_TELEPORT_TIMEOUT then
   recovering = true
   recoveryRestore = H.DisableCollision(model)
  end

  if not recovering then
   local hit = H.PredictGroundImpact(model, body)
   if hit and hit.Normal.Y >= 0.65 then
    local moved = (hit.Position - tracking.position).Magnitude
    local distanceToPlane = (body.Position - tracking.position):Dot(tracking.normal)
    -- Tiles with matching heights and normals count as the same floor even
    -- when they are separate Instances. A new raised/lowered surface requires
    -- a new portal rather than an old portal hovering inside geometry.
    local sameSurface = hit.Normal:Dot(tracking.normal) >= 0.97
     and math.abs((hit.Position-tracking.position):Dot(tracking.normal)) < 1.3
    if not sameSurface and moved > C.PREDICTION_REPLAN_DISTANCE
     and distanceToPlane > 3.5 and not tracking.opening then
     return finish(false) -- outer loop will re-predict / place a fresh entrance
    end
    local canAdjust = sameSurface
     and moved > C.ENTRY_REPOSITION_EPSILON
     and distanceToPlane > C.PREDICTION_FREEZE_HEIGHT
     and tracking.moves < C.PREDICTION_MAX_REPOSITIONS
     and os.clock() - tracking.lastMoveAt >= C.PREDICTION_REPOSITION_COOLDOWN
    if canAdjust then
     local shift = hit.Position - tracking.position
     local available = C.PREDICTION_MAX_TOTAL_MOVE
      - (tracking.position-tracking.initialPosition).Magnitude
     local amount = math.min(shift.Magnitude, C.PREDICTION_MAX_STEP, available)
     if amount > 0 then
      local correction = shift.Unit * amount
      -- Reject corrected landing predictions that would embed the portal.
      local oldPivot = portal:GetPivot()
      portal:PivotTo(oldPivot + correction)
      local safeMove = not H.PortalHasObstruction(portal,model,tracking.surface)
      portal:PivotTo(oldPivot)
      if safeMove then
       tracking.position += correction
       tracking.moves += 1
       tracking.lastMoveAt = os.clock()
       if not tracking.opening then
        portal:PivotTo(portal:GetPivot() + correction)
       end
      end
     end
    end
   end
  end

  local normal = tracking.normal
  local current = body.Position
  local relative = current - tracking.position
  local signed = relative:Dot(normal)
  local radialVector = relative - normal*signed
  local radial = radialVector.Magnitude
  local normalSpeed = body.AssemblyLinearVelocity:Dot(normal)
  local captureHeight = math.max(0.6, body.Size.Y*0.50 + C.ENTRY_CAPTURE_MARGIN)
  local captureRadius = C.ENTRY_CAPTURE_RADIUS + (recovering and C.STUCK_CAPTURE_EXTRA_RADIUS or 0)

  -- Test intersection of the actual last-frame path with the entry plane.
  -- This is robust even at rescue speeds above 100 studs/second.
  if previousPosition then
   local previousSigned = (previousPosition - tracking.position):Dot(normal)
   if previousSigned > captureHeight and signed <= captureHeight then
    local denom = previousSigned - signed
    if denom > 0.0001 then
     local fraction = math.clamp((previousSigned - captureHeight) / denom, 0, 1)
     local intersection = previousPosition:Lerp(current, fraction)
     local planar = intersection - tracking.position - normal*captureHeight
     if planar.Magnitude <= captureRadius then
      return finish(true)
     end
    end
   end
  end

  if radial <= captureRadius and normalSpeed < -0.8
   and signed <= captureHeight and signed >= -1.5 then
   return finish(true)
  end
  -- During rescue, accept a near-plane contact even if the ragdoll's torso
  -- approached from below after a previous missed physics step.
  if recovering and radial <= captureRadius and math.abs(signed) <= 2.2 then
   return finish(true)
  end

   -- If the ragdoll has drifted well outside the portal's reach, begin
   -- controlled recovery earlier than the hard 2.5s timeout. This protects
   -- trajectories deflected by other parts without snapping the model.
   if not recovering and os.clock()-tracking.lastTeleportAt>=C.PREDICTION_EARLY_ASSIST_TIME
    and not tracking.opening and radial>captureRadius+2.0 then
    recovering=true
    recoveryRestore=H.DisableCollision(model)
   end
  if recovering then
   -- Strong velocity-based pull toward a point BEYOND the portal plane.
   -- Not a snap/teleport: the ragdoll travels through the intervening space.
   local target = tracking.position - normal*C.STUCK_PORTAL_OVERSHOOT
   local displacement = target - current
   if displacement.Magnitude > 0.05 then
    H.SetRagdollVelocity(model, displacement.Unit * C.STUCK_PULL_SPEED)
   end
  end
  previousPosition = current
  RunService.Heartbeat:Wait()
 end
 return finish(false)
end

-- Pick a surface from the visible part of the camera's screen.
-- A clear line of sight is required, so the portal cannot be hidden behind a wall.
function H.CameraVisibleExit(model, body, minimumY)
 local camera = Workspace.CurrentCamera
 if not camera then return nil end
 local viewport = camera.ViewportSize
 if viewport.X < 2 or viewport.Y < 2 then return nil end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {model, fluidFolder}
 params.IgnoreWater = true
 params.RespectCanCollide = true
 local bestHit, bestScore
 for _ = 1, C.CAMERA_VISIBLE_ATTEMPTS do
  local x = fluidRandom:NextNumber(C.CAMERA_VIEW_MARGIN, 1-C.CAMERA_VIEW_MARGIN) * viewport.X
  local y = fluidRandom:NextNumber(C.CAMERA_VIEW_MARGIN, 1-C.CAMERA_VIEW_MARGIN) * viewport.Y
  local ray = camera:ViewportPointToRay(x, y)
  local hit = Workspace:Raycast(ray.Origin, ray.Direction * C.CAMERA_RAY_LENGTH, params)
  if hit and hit.Instance and hit.Instance:IsA("BasePart") and hit.Position.Y >= minimumY then
   local distanceToBody = (hit.Position-body.Position).Magnitude
   local distanceToCamera = (hit.Position-camera.CFrame.Position).Magnitude
   -- Keep exits near enough to the ragdoll to preserve the recursive sequence.
   if distanceToBody <= C.EXIT_SEARCH_RADIUS * 2.5 and distanceToCamera <= C.CAMERA_MAX_EXIT_DISTANCE then
    -- Prefer nearby visible surfaces, with a slight preference for screen center.
    local centerPenalty = ((x/viewport.X-0.5)^2+(y/viewport.Y-0.5)^2)*12
    local score = distanceToBody + centerPenalty
    if not bestScore or score < bestScore then
     bestHit, bestScore = hit, score
    end
   end
  end
 end
 if bestHit then return bestHit.Position, bestHit.Normal, bestHit.Instance end
 return nil
end

function H.RandomExit(model, body, minimumY)
 if C.CAMERA_AWARE_EXITS then
  local pos, normal, part = H.CameraVisibleExit(model, body, minimumY)
  if pos then return pos, normal, part end
 end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {model}
 params.IgnoreWater = true
 local dirs = {Vector3.new(0,-1,0),Vector3.new(0,1,0),Vector3.new(1,0,0),Vector3.new(-1,0,0),Vector3.new(0,0,1),Vector3.new(0,0,-1)}
 for _ = 1, C.EXIT_CANDIDATE_ATTEMPTS do
  local dir = dirs[math.random(1,#dirs)]
  local offset = Vector3.new(math.random(-C.EXIT_SEARCH_RADIUS,C.EXIT_SEARCH_RADIUS),math.random(-4,12),math.random(-C.EXIT_SEARCH_RADIUS,C.EXIT_SEARCH_RADIUS))
  local origin = body.Position + offset + dir*14
  local hit = Workspace:Raycast(origin,-dir*28,params)
  if hit and hit.Position.Y >= minimumY then
   return hit.Position, hit.Normal, hit.Instance
  end
 end
 -- Safe fallback: above and beside the ragdoll, never below the original ground.
 local fallback = body.Position + Vector3.new(math.random(-8,8),math.max(5, minimumY-body.Position.Y+5),math.random(-8,8))
 return fallback, Vector3.new(0,1,0), nil
end

function H.ActuallyClosePortal(portal)
 if not portal or not portal.Parent then return end
 H.PlayPortalSound(C.AUDIO.Close, portal)
 local fluidRoot = H.GetRoot(portal)
 local fluidFrame = fluidRoot and fluidRoot.CFrame
 local fluidSize = fluidRoot and fluidRoot.Size
 local fluidLight = portal:FindFirstChildWhichIsA("PointLight", true)
 local fluidColor = fluidLight and fluidLight.Color or Color3.fromRGB(26,255,0)
 H.ScalePortal(portal,C.FINAL_SCALE,C.END_SCALE,C.SHRINK_TIME)
 if fluidFrame and fluidSize then
  H.EmitPortalClosingFluid(fluidFrame, fluidSize, fluidColor)
 end
 if portal.Parent then portal:Destroy() end
end

function H.ClosePortal(portal, stop)
 -- Stop rotation/tracking immediately; the next hop must not be delayed.
 if stop then stop() end
 if not portal or not portal.Parent then return end
 if portal:GetAttribute("RainbowPortal") then
  -- The normal stop callback above stops the active spin. Start a fresh
  -- independent spin for the entire decorative linger, including portals that
  -- were never given a stop callback (certain blue and terminal portals).
  if portal:GetAttribute("RainbowClosingScheduled") then return end
  portal:SetAttribute("RainbowClosingScheduled", true)
  local root = H.GetRoot(portal)
  local normal = root and H.FaceDirection(root, H.GetVisibleFace(root)) or Vector3.yAxis
  local stopLingerSpin = H.StartRotation(portal, portal:GetPivot(), normal)
  -- Retain visuals, but remove collision/query/touch so old portal hitboxes
  -- cannot obstruct the ragdoll or the smart portal-ground predictor.
  for _, item in ipairs(portal:GetDescendants()) do
   if item:IsA("BasePart") then
    item.CanCollide = false
    item.CanTouch = false
    item.CanQuery = false
   end
  end
  task.delay(C.RAINBOW_PORTAL_LINGER, function()
   stopLingerSpin()
   if portal.Parent then H.ActuallyClosePortal(portal) end
  end)
  return
 end
 H.ActuallyClosePortal(portal)
end

function H.SpawnExit(model, body, minimumY)
 local portal,root = H.CreatePortal(model)
 if not portal then return end
 local pos,normal,surfacePart
 local placed = false
 for _ = 1, 6 do
  local attemptPos, attemptNormal, attemptSupport = H.RandomExit(model,body,minimumY)
  local ok,safePos = H.TryPlacePortal(portal,root,attemptPos,attemptNormal,model,attemptSupport)
  if ok then
   pos,normal,surfacePart = safePos,attemptNormal,attemptSupport
   placed = true
   break
  end
 end
 if not placed then portal:Destroy(); return nil end
 H.PlayPortalSound(C.AUDIO.Open, portal)
 task.spawn(function()
  H.ElasticPortalIntro(portal,root, surfacePart and pos or nil, surfacePart and normal or nil, surfacePart, model)
 end)
 local stop = H.StartRotation(portal,portal:GetPivot(),normal)
 return portal,stop,pos,normal,surfacePart
end

-- Each air pair can vary in distance and direction, with optional wall mounts.
-- Portals still face the direction of travel, so straight flight stays valid.
function H.SpawnAirPair(model, body, airOnly)
 local cam = Workspace.CurrentCamera
 if not cam then return end
 local right, forward, up = cam.CFrame.RightVector, cam.CFrame.LookVector, cam.CFrame.UpVector
 local viewport = cam.ViewportSize
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 local ignore = {model, RAGDOLLS_FOLDER, fluidFolder}
 for _, obj in ipairs(Workspace:GetChildren()) do
  if obj.Name == "RagdollPortal" then table.insert(ignore, obj) end
 end
 params.FilterDescendantsInstances = ignore
 params.IgnoreWater = true
 params.RespectCanCollide = true

 local function onScreen(worldPos)
  local screen, visible = cam:WorldToViewportPoint(worldPos)
  return visible and screen.Z > 0
   and screen.X > viewport.X*0.09 and screen.X < viewport.X*0.91
   and screen.Y > viewport.Y*0.09 and screen.Y < viewport.Y*0.91
 end

 local function visibleToCamera(worldPos)
  local path = worldPos - cam.CFrame.Position
  if path.Magnitude < 0.01 then return false end
  -- Slightly before the portal surface so an attached wall isn't an obstruction.
  local hit = Workspace:Raycast(cam.CFrame.Position, path.Unit * math.max(0, path.Magnitude - 0.7), params)
  return hit == nil
 end

 local tries = airOnly and C.AIR_ONLY_MAX_SPAWN_ATTEMPTS or 12
 local chosen
 for _ = 1, tries do
  local separation = fluidRandom:NextNumber(C.MIDAIR_SPACING_MIN, C.MIDAIR_SPACING_MAX)
  local direction = right * fluidRandom:NextNumber(-1, 1)
   + up * fluidRandom:NextNumber(-C.MIDAIR_DIRECTION_VERTICALITY, C.MIDAIR_DIRECTION_VERTICALITY)
   + forward * fluidRandom:NextNumber(-C.MIDAIR_DIRECTION_DEPTH, C.MIDAIR_DIRECTION_DEPTH)
  if direction.Magnitude < 0.20 then direction = right end
  direction = direction.Unit
  local center
  if airOnly then
   center = cam.CFrame.Position + forward * fluidRandom:NextNumber(28, 46)
    + up * fluidRandom:NextNumber(-6, 6)
    + right * fluidRandom:NextNumber(-5, 5)
  else
   center = body.Position + forward * fluidRandom:NextNumber(6, 13)
    + up * fluidRandom:NextNumber(5, 12)
  end
  local p1 = center - direction * separation*0.5
  local p2 = center + direction * separation*0.5
  local normal1, normal2 = direction, -direction
  local wall1, wall2 = nil, nil
  if fluidRandom:NextNumber() < C.MIDAIR_WALL_ATTACH_CHANCE then
   -- Search BEHIND the first portal (outward normal must face the flight).
   local hit1 = Workspace:Raycast(p1, -direction * C.MIDAIR_WALL_SEARCH_DISTANCE, params)
   if hit1 and hit1.Instance:IsA("BasePart")
    and math.abs(hit1.Normal.Y) < 0.45 and hit1.Normal:Dot(direction) > 0.68 then
    p1, normal1, wall1 = hit1.Position, hit1.Normal, hit1.Instance
   end
   -- Search AHEAD of the destination. Its normal faces the incoming ragdoll.
   local hit2 = Workspace:Raycast(p2, direction * C.MIDAIR_WALL_SEARCH_DISTANCE, params)
   if hit2 and hit2.Instance:IsA("BasePart")
    and math.abs(hit2.Normal.Y) < 0.45 and hit2.Normal:Dot(-direction) > 0.68 then
    p2, normal2, wall2 = hit2.Position, hit2.Normal, hit2.Instance
   end
  end
  local newTravel = p2-p1
  local flightDistance = newTravel.Magnitude
  if flightDistance >= C.MIDAIR_SPACING_MIN and flightDistance <= C.MIDAIR_SPACING_MAX + C.MIDAIR_WALL_SEARCH_DISTANCE*2
   and onScreen(p1) and onScreen(p2)
   and visibleToCamera(p1 + normal1 * 0.5)
   and visibleToCamera(p2 + normal2 * 0.5) then
   -- Ray stops short of the wall surface(s); wall-backed portals are intended.
   local travelDir = newTravel.Unit
   local from = p1 + travelDir * (wall1 and 1 or 0.12)
   local to = p2 - travelDir * (wall2 and 1 or 0.12)
   if not Workspace:Raycast(from, to-from, params) then
    chosen = {p1, p2, normal1, normal2, wall1, wall2}
    break
   end
  end
 end
 if not chosen then return end
 local p1, p2, normal1, normal2, wall1, wall2 = table.unpack(chosen, 1, 6)
 local first, firstRoot = H.CreatePortal(model)
 if not first then return end
 local second, secondRoot = H.CreatePortal(model)
 if not second then first:Destroy(); return end
 if wall1 then first:SetAttribute("WallMounted", true) end
 if wall2 then second:SetAttribute("WallMounted", true) end
 H.PlacePortal(first, firstRoot, p1, normal1)
 H.PlacePortal(second, secondRoot, p2, normal2)
 if H.PortalHasObstruction(first,model,wall1)
  or H.PortalHasObstruction(second,model,wall2) then
  first:Destroy()
  second:Destroy()
  return nil
 end
 for _, entry in ipairs({{first,firstRoot},{second,secondRoot}}) do
  task.spawn(function()
   if not entry[1].Parent then return end
   H.PlayPortalSound(C.AUDIO.Open, entry[1])
   H.ElasticPortalIntro(entry[1], entry[2])
  end)
 end
 return first, second, p1, p2
end

-- Special exception to free-flight ragdoll physics: guide ONLY the segment
-- between a paired set of airborne portals along a straight line.
-- Setting velocity on Heartbeat counteracts gravity without anchoring limbs;
-- rotations and joint movement remain free, and normal physics resumes on exit.
function H.FlyBetweenAirPortals(model, firstPos, secondPos, flow)
 if not model.Parent then return false end
 local body = H.GetBodyPart(model)
 if not body then return false end
 local travel = secondPos - firstPos
 local length = travel.Magnitude
 if length < 0.01 then return false end
 local forward = travel / length
 local speed = length / C.MIDAIR_FLIGHT_TIME

 -- Teleport from the ground entrance INTO the first airborne opening.
 -- Align the torso rather than the model pivot (which can be offset by limbs).
 model:PivotTo(model:GetPivot() + (firstPos - body.Position))
 H.SetRagdollVelocity(model, forward * speed)

 local previousPosition = body.Position
 local previousAlong = (previousPosition-secondPos):Dot(forward)
 local started = os.clock()
 while model.Parent and body.Parent and (not flow or not flow.finalizing)
  and os.clock()-started < C.MIDAIR_MAX_WAIT do
  RunService.Heartbeat:Wait()
  if not model.Parent or not body.Parent or (flow and flow.finalizing) then break end
  local position = body.Position
  local fromTarget = position - secondPos
  local along = fromTarget:Dot(forward)
  -- At very high speeds a torso can cross the entire opening in one physics
  -- step. Intersect its previous-to-current segment with the target plane,
  -- rather than checking only its position AFTER crossing.
  if previousAlong < 0 and along >= 0 then
   local fraction = math.clamp(-previousAlong / math.max(along-previousAlong, 0.0001), 0, 1)
   local crossedAt = previousPosition:Lerp(position, fraction)
   local offset = crossedAt - secondPos
   local lateralAtCrossing = (offset-forward*offset:Dot(forward)).Magnitude
   if lateralAtCrossing <= C.MIDAIR_ARRIVAL_RADIUS then
    return true
   end
  end
  previousAlong = along
  previousPosition = position

  -- Project current body position onto the straight flight corridor.
  -- Correct ONLY sideways drift, not forward speed or limb rotation.
  local progress = math.clamp((position-firstPos):Dot(forward), 0, length)
  local closest = firstPos + forward*progress
  local correction = (closest-position)*C.MIDAIR_STRAIGHT_STEERING
  if correction.Magnitude > C.MIDAIR_MAX_STEERING_SPEED then
   correction = correction.Unit * C.MIDAIR_MAX_STEERING_SPEED
  end
  H.SetRagdollVelocity(model, forward*speed + correction)
 end
 return false
end

-- BLUE PROTOTYPE INFINITE-FALLING LOOP --------------------------------------
-- Two stationary portals: the lower catches the fall, the upper sends the
-- ragdoll downward again. Crossing is physics-frame driven, not a loop timer.
function H.TintBluePortal(portal)
 -- A rolled rainbow portal can replace even one of the blue prototype portals.
 if portal:GetAttribute("RainbowPortal") then return end
 portal:SetAttribute("BluePrototypePortal", true)
 portal:SetAttribute("EvilMortyTheme", false)
 for _, item in ipairs(portal:GetDescendants()) do
  if not H.IsBubbleSubtree(item, portal) then
   if item:IsA("ImageLabel") or item:IsA("ImageButton") then
    item.ImageColor3 = C.BLUE_PORTAL_COLOR
   elseif item:IsA("BasePart") then
    item.Color = C.BLUE_PORTAL_COLOR
   elseif item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
    item.Color = C.BLUE_PORTAL_GLOW
   elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then
    item.Color = ColorSequence.new(C.BLUE_PORTAL_COLOR)
   elseif item:IsA("Decal") then
    item.Color3 = C.BLUE_PORTAL_COLOR
   elseif item:IsA("UIStroke") then
    item.Color = C.BLUE_PORTAL_GLOW
   elseif item:IsA("UIGradient") then
    item.Color = ColorSequence.new(C.BLUE_PORTAL_COLOR)
   elseif item:IsA("GuiObject") then
    item.BackgroundColor3 = C.BLUE_PORTAL_COLOR
   elseif item:IsA("Fire") then
    item.Color, item.SecondaryColor = C.BLUE_PORTAL_COLOR, C.BLUE_PORTAL_GLOW
   elseif item:IsA("Smoke") then
    item.Color = C.BLUE_PORTAL_COLOR
   elseif item:IsA("Sparkles") then
    item.SparkleColor = C.BLUE_PORTAL_COLOR
   end
  end
 end
end

-- RAINBOW PORTALS ---------------------------------------------------------
-- Apply a multi-hued cycle, retaining the supplied portal geometry and the
-- original bubble imagery. The coroutine ends on portal destruction.
H.StartRainbowPortal = function(portal)
 if not portal or not portal.Parent or portal:GetAttribute("RainbowPortal") then return end
 portal:SetAttribute("RainbowPortal", true)
 portal:SetAttribute("EvilMortyTheme", false)
 portal:SetAttribute("BluePrototypePortal", false)
 local colored, gradients = {}, {}
 for _, item in ipairs(portal:GetDescendants()) do
  -- All visible layers (including the original bubble textures) receive a
  -- coordinated saturated hue. Independent complementary hues on overlapping
  -- transparent layers used to average into washed-out gray.
  local supported = item:IsA("BasePart") or item:IsA("ImageLabel")
   or item:IsA("ImageButton") or item:IsA("PointLight")
   or item:IsA("SpotLight") or item:IsA("SurfaceLight")
   or item:IsA("ParticleEmitter") or item:IsA("Beam")
   or item:IsA("Trail") or item:IsA("Decal")
   or item:IsA("UIStroke") or item:IsA("Highlight")
   or item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles")
  -- Bubble imagery is intentionally neutral white, not rainbow-tinted.
  if H.IsBubbleSubtree(item, portal) then
   if item:IsA("ImageLabel") or item:IsA("ImageButton") then
    item.Image = C.PORTAL_BUBBLE_IMAGE_ID
    item.ImageColor3 = Color3.new(1, 1, 1)
    local oldRainbow = item:FindFirstChild("RainbowColorGradient")
    if oldRainbow then oldRainbow:Destroy() end
   end
  elseif supported then
   table.insert(colored, item)
   if item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
    item.Brightness = math.max(item.Brightness, 2.8)
    if item:IsA("PointLight") then item.Range = math.max(item.Range, 15) end
   end
   -- A true 6-color ribbon WITHIN each portal image, rather than separate
   -- differently-tinted transparent images layered on each other. The same
   -- gradient is applied across overlapping ImageLabels to avoid gray mixing.
   if (item:IsA("ImageLabel") or item:IsA("ImageButton"))
    and item:FindFirstAncestorWhichIsA("SurfaceGui")
    and not H.IsBubbleSubtree(item, portal) then
    local gradient = item:FindFirstChild("RainbowColorGradient")
    if not gradient then
     gradient = Instance.new("UIGradient")
     gradient.Name = "RainbowColorGradient"
     gradient.Parent = item
    end
    gradient.Rotation = 0
    table.insert(gradients, {image=item, gradient=gradient})
   end
  end
 end
 task.spawn(function()
  while portal.Parent and portal:GetAttribute("RainbowPortal") do
   local hue = (os.clock()*C.RAINBOW_PORTAL_HUE_SPEED)%1
   local mainColor = Color3.fromHSV(hue, 1, 1)
   local vividRibbon = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromHSV(hue, 1, 1)),
    ColorSequenceKeypoint.new(0.20, Color3.fromHSV((hue+0.2)%1, 1, 1)),
    ColorSequenceKeypoint.new(0.40, Color3.fromHSV((hue+0.4)%1, 1, 1)),
    ColorSequenceKeypoint.new(0.60, Color3.fromHSV((hue+0.6)%1, 1, 1)),
    ColorSequenceKeypoint.new(0.80, Color3.fromHSV((hue+0.8)%1, 1, 1)),
    ColorSequenceKeypoint.new(1.00, Color3.fromHSV(hue, 1, 1)),
   })
   for _, item in ipairs(colored) do
    if item.Parent then
     if item:IsA("ImageLabel") or item:IsA("ImageButton") then
      -- Keep image brightness at white when a rainbow gradient is attached;
      -- multiplying two unrelated colors would darken/desaturate it.
      item.ImageColor3 = item:FindFirstChild("RainbowColorGradient")
       and Color3.new(1, 1, 1) or mainColor
     elseif item:IsA("BasePart") then
      item.Color = mainColor
     elseif item:IsA("PointLight") or item:IsA("SpotLight")
      or item:IsA("SurfaceLight") then
      item.Color = mainColor
     elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then
      item.Color = ColorSequence.new(mainColor)
     elseif item:IsA("Decal") then
      item.Color3 = mainColor
     elseif item:IsA("UIStroke") then
      item.Color = mainColor
     elseif item:IsA("Highlight") then
      item.FillColor = mainColor
      item.OutlineColor = mainColor
     elseif item:IsA("Fire") then
      item.Color = mainColor
      item.SecondaryColor = mainColor
     elseif item:IsA("Smoke") then
      item.Color = mainColor
     elseif item:IsA("Sparkles") then
      item.SparkleColor = mainColor
     end
    end
   end
   for _, entry in ipairs(gradients) do
    if entry.image.Parent and entry.gradient.Parent then
     entry.gradient.Color = vividRibbon
    end
   end
   task.wait(C.RAINBOW_COLOR_UPDATE)
  end
 end)
end

-- Color only rendered ragdoll geometry; don't expose invisible physics parts.
-- Bomb charring terminates the cycle, allowing permanent black recoloring.
local rainbowRagdollRunning=setmetatable({},{__mode="k"})
function H.StartRainbowRagdoll(model)
 if not model or not model.Parent or model:GetAttribute("BombCharred") then return end
 model:SetAttribute("RainbowRagdoll",true)
 if rainbowRagdollRunning[model] then return end
 rainbowRagdollRunning[model]=true
 task.spawn(function()
  local colored={}
  local nextRefresh=0
  while model.Parent and model:GetAttribute("RainbowRagdoll")
   and not model:GetAttribute("BombCharred") do
   local now=os.clock()
   if now>=nextRefresh then
    table.clear(colored)
    for _,part in ipairs(model:GetDescendants()) do
     if part:IsA("BasePart") and part.Transparency<0.95 then
      table.insert(colored,part)
     elseif part:IsA("Decal") and part.Transparency<0.95 then
      table.insert(colored,part)
     end
    end
    nextRefresh=now+1.3
   end
   local hue=(now*C.RAINBOW_RAGDOLL_HUE_SPEED)%1
   for i,part in ipairs(colored) do
    if part.Parent and not model:GetAttribute("BombCharred") then
     local color=Color3.fromHSV((hue+(i-1)*0.115)%1,1,1)
     if part:IsA("BasePart") then part.Color=color
     elseif part:IsA("Decal") then part.Color3=color end
    end
   end
   task.wait(C.RAINBOW_COLOR_UPDATE)
  end
  rainbowRagdollRunning[model]=nil
 end)
end

function H.RollBlueLoopForExit(model,flow)
 return model and model.Parent and not flow.finalizing
  and not model:GetAttribute("BombCharred")
  and not model:GetAttribute("BlueLoopUsed")
  and math.random()<C.BLUE_LOOP_CHANCE
end
-- END RAINBOW PORTALS -----------------------------------------------------

function H.SpawnBlueFallPortals(model)
 local body = H.GetBodyPart(model)
 if not body then return end
 local cam = Workspace.CurrentCamera
 local offsets = {Vector3.zero}
 if cam then
  local r = cam.CFrame.RightVector
  local f = cam.CFrame.LookVector
  table.insert(offsets, r*6)
  table.insert(offsets, -r*6)
  table.insert(offsets, f*6)
  table.insert(offsets, -f*6)
  table.insert(offsets, r*10+f*3)
  table.insert(offsets, -r*10+f*3)
 end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 local ignored = {model, RAGDOLLS_FOLDER, fluidFolder}
 for _, obj in ipairs(Workspace:GetChildren()) do
  if obj:IsA("Model") and (obj.Name == "RagdollPortal" or obj:GetAttribute("FinalDimensionPortal")) then
   table.insert(ignored, obj)
  end
 end
 params.FilterDescendantsInstances = ignored
 params.RespectCanCollide = true
 params.IgnoreWater = true

 local bestPos, bestFloor, bestScore
 for _, offset in ipairs(offsets) do
  local p = body.Position + Vector3.new(offset.X,0,offset.Z)
  local floor = Workspace:Raycast(p+Vector3.yAxis*6,-Vector3.yAxis*50,params)
  local lowerPos = floor and floor.Normal.Y > 0.8 and floor.Position or p-Vector3.yAxis*3
  local upperPos = lowerPos+Vector3.yAxis*C.BLUE_LOOP_HEIGHT
  local corridorHit = Workspace:Raycast(lowerPos+Vector3.yAxis*0.8,
   Vector3.yAxis*(C.BLUE_LOOP_HEIGHT-1.6),params)
  if not corridorHit then
   local score = 0
   if cam then
    for _, point in ipairs({lowerPos,upperPos}) do
     local screen, visible = cam:WorldToViewportPoint(point)
     if not visible or screen.Z < 0 then score += 100 end
     local view = cam.ViewportSize
     if screen.X < view.X*0.07 or screen.X > view.X*0.93 or
      screen.Y < view.Y*0.07 or screen.Y > view.Y*0.93 then
      score += 15
     end
    end
   end
   score += (lowerPos-body.Position).Magnitude*0.05
   if not bestScore or score < bestScore then
    bestScore, bestPos, bestFloor = score, lowerPos, floor
   end
  end
 end
 if not bestPos then return end
 local low, lowRoot = H.CreatePortal(model)
 if not low then return end
 local high, highRoot = H.CreatePortal(model)
 if not high then low:Destroy(); return end
 low.Name, high.Name = "BlueFallLowerPortal", "BlueFallUpperPortal"
 H.TintBluePortal(low)
 H.TintBluePortal(high)
 if bestFloor and bestFloor.Normal.Y > 0.8 then
  low:SetAttribute("GroundLocked", true)
 end
 H.PlacePortal(low,lowRoot,bestPos,Vector3.yAxis)
 H.PlacePortal(high,highRoot,bestPos+Vector3.yAxis*C.BLUE_LOOP_HEIGHT,-Vector3.yAxis)
 if H.PortalHasObstruction(low,model,bestFloor and bestFloor.Instance)
  or H.PortalHasObstruction(high,model,nil) then
  low:Destroy()
  high:Destroy()
  return nil
 end
 for _, entry in ipairs({{low,lowRoot},{high,highRoot}}) do
  task.spawn(function()
   H.PlayPortalSound(C.AUDIO.Open,entry[1])
   H.ElasticPortalIntro(entry[1],entry[2])
  end)
 end
 return low,high,bestPos,bestPos+Vector3.yAxis*C.BLUE_LOOP_HEIGHT,highRoot
end

-- Guaranteed visual continuation after the blue prototype's final sideways
-- launch. A green (or leaderboard-yellow) catcher is placed directly ahead,
-- detects real plane crossing, then uses the usual camera-aware exit portal.
function H.SpawnBlueReturnEntrance(model,side,startPosition)
 local forward=side.Unit
 local desired=startPosition+forward*C.BLUE_RETURN_DISTANCE+Vector3.yAxis*0.4
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 local ignore={model,RAGDOLLS_FOLDER,fluidFolder}
 for _, object in ipairs(Workspace:GetChildren()) do
  if object:IsA("Model") and (object.Name:find("Portal") or object:GetAttribute("FinalDimensionPortal")) then
   table.insert(ignore,object)
  end
 end
 params.FilterDescendantsInstances=ignore
 params.RespectCanCollide=true
 local obstacle=Workspace:Raycast(startPosition,desired-startPosition,params)
 if obstacle then
  local gap=(obstacle.Position-startPosition).Magnitude
  desired=startPosition+forward*math.max(4,math.min(C.BLUE_RETURN_DISTANCE,gap-2))
 end
 local portal,root=H.CreatePortal(model)
 if not portal then return nil end
 portal.Name="BlueLoopReturnEntrance"
 local placed, safePos = H.TryPlacePortal(portal,root,desired,-forward,model,nil)
 if not placed then portal:Destroy(); return nil end
 desired = safePos
 H.PlayPortalSound(C.AUDIO.Open,portal)
 task.spawn(H.ElasticPortalIntro,portal,root)
 return portal,desired
end

function H.RunBlueReturnPortal(model,flow,side,preOpened,prePosition)
 if not model.Parent or flow.finalizing or model:GetAttribute("BombCharred") then
  if preOpened and preOpened.Parent then task.spawn(H.ClosePortal,preOpened,nil) end
  return false
 end
 local body=H.GetBodyPart(model)
 if not body then
  if preOpened and preOpened.Parent then task.spawn(H.ClosePortal,preOpened,nil) end
  return false
 end
 local forward=side.Unit
 local entrance,desired=preOpened,prePosition
 if not entrance or not entrance.Parent or not desired then
  entrance,desired=H.SpawnBlueReturnEntrance(model,side,body.Position)
 end
 if not entrance then return false end
 local restore=H.DisableCollision(model)
 local started=os.clock()
 local previous=body.Position
 local caught=false
 while model.Parent and entrance.Parent and not flow.finalizing
  and not model:GetAttribute("BombCharred") and os.clock()-started<C.BLUE_RETURN_TIMEOUT do
  RunService.Heartbeat:Wait()
  body=H.GetBodyPart(model)
  if not body then break end
  local current=body.Position
  local before=(previous-desired):Dot(-forward)
  local after=(current-desired):Dot(-forward)
  local crossing=before>0 and after<=0
  local hitPoint=current
  if crossing then
   local alpha=math.clamp(before/math.max(before-after,0.001),0,1)
   hitPoint=previous:Lerp(current,alpha)
  end
  local localOffset=hitPoint-desired
  local radial=(localOffset-forward*localOffset:Dot(forward)).Magnitude
  if radial<=C.BLUE_RETURN_CAPTURE_RADIUS and (crossing or after<=0.7) then
   caught=true
   break
  end
  -- Keep the flight aligned with the opening even if the ragdoll clips a
  -- nearby object. This is the controlled blue-to-green transition only.
  local target=desired+forward*2
  local lateral=target-current-forward*(target-current):Dot(forward)
  local assist=lateral*8
  if assist.Magnitude>38 then assist=assist.Unit*38 end
  H.SetRagdollVelocity(model,forward*math.max(C.BLUE_LOOP_SIDE_LAUNCH,105)+assist)
  previous=current
 end
 restore()
 if caught and model.Parent and not flow.finalizing then
  H.PlayPortalSound(C.AUDIO.Enter,entrance)
  local bodyNow=H.GetBodyPart(model) or body
  local exit,stopExit,exitPos,exitNormal=H.SpawnExit(model,bodyNow,-math.huge)
  local rainbowReturn = entrance:GetAttribute("RainbowPortal")
   or (exit and exit:GetAttribute("RainbowPortal"))
  if exit and exitPos and exitNormal and model.Parent and not flow.finalizing then
   local noCollision=H.DisableCollision(model)
   local pivot=model:GetPivot()
   model:PivotTo(CFrame.new(exitPos+exitNormal*3)*(pivot-pivot.Position))
   H.SetRagdollVelocity(model,exitNormal*math.random(40,68)
    +Vector3.new(math.random(-16,16),math.random(8,25),math.random(-16,16)))
   noCollision()
   H.PlayPortalSound(C.AUDIO.Enter,exit)
   if rainbowReturn then H.StartRainbowRagdoll(model) end
   flow.lastTeleportAt=os.clock()
   task.delay(C.LINGER_TIME,function()
    if exit.Parent then H.ClosePortal(exit,stopExit) end
   end)
   task.spawn(H.ClosePortal,entrance,nil)
   return true
  end
  if exit then task.spawn(H.ClosePortal,exit,stopExit) end
 end
 if entrance.Parent then task.spawn(H.ClosePortal,entrance,nil) end
 return false
end

function H.RunBlueFallingLoop(model,flow)
 if not model.Parent or flow.finalizing or model:GetAttribute("BombCharred") then return false end
 local low,high,lowPos,highPos,highRoot = H.SpawnBlueFallPortals(model)
 if not low or not high then return false end
 model:SetAttribute("BlueLoopActive",true)
 local function active()
  return model.Parent and low.Parent and high.Parent and not flow.finalizing
   and not model:GetAttribute("BombCharred")
 end
 local restoreCollision
 local function cleanup()
  if restoreCollision then restoreCollision(); restoreCollision=nil end
  model:SetAttribute("BlueLoopActive",false)
  if low.Parent then task.spawn(H.ClosePortal,low,nil) end
  if high.Parent then task.spawn(H.ClosePortal,high,nil) end
 end
 -- Allow both portals to finish their original two-stage elastic opening.
 local openedAt=os.clock()
 while active() and os.clock()-openedAt < C.OPEN_STAGE_ONE+C.OPEN_STAGE_TWO do
  RunService.Heartbeat:Wait()
 end
 if not active() then cleanup(); return false end
 restoreCollision=H.DisableCollision(model)
 local count=math.random(C.BLUE_LOOP_MIN_FALLS,C.BLUE_LOOP_MAX_FALLS)
 local initialBody=H.GetBodyPart(model)
 if not initialBody then cleanup(); return false end
 model:PivotTo(model:GetPivot()+(highPos-Vector3.yAxis*2-initialBody.Position))
 local downSpeed=C.BLUE_LOOP_START_SPEED
 H.SetRagdollVelocity(model,-Vector3.yAxis*downSpeed)
 local completed=0
 local finalSide,finalReturnPortal,finalReturnPosition
 for pass=1,count do
  if not active() then break end
  local body=H.GetBodyPart(model)
  if not body then break end
  local previous=body.Position
  local reached=false
  local passStarted=os.clock()
  while active() and body.Parent and os.clock()-passStarted < C.BLUE_LOOP_MAX_PASS_TIME do
   RunService.Heartbeat:Wait()
   if not active() then break end
   local current=body.Position
   local planeY=lowPos.Y+0.3
   local horizontal=(Vector3.new(current.X,0,current.Z)-Vector3.new(lowPos.X,0,lowPos.Z)).Magnitude
   if previous.Y > planeY and current.Y <= planeY then
    local alpha=math.clamp((previous.Y-planeY)/math.max(previous.Y-current.Y,0.001),0,1)
    local point=previous:Lerp(current,alpha)
    horizontal=(Vector3.new(point.X,0,point.Z)-Vector3.new(lowPos.X,0,lowPos.Z)).Magnitude
    if horizontal <= C.BLUE_LOOP_CAPTURE_RADIUS then reached=true; break end
   end
   -- A predictable X/Z corridor, with real gravity acting on the Y velocity.
   local planar=Vector3.new(lowPos.X-current.X,0,lowPos.Z-current.Z)
   if planar.Magnitude>0.06 then
    local velocity=body.AssemblyLinearVelocity
    local steer=planar*C.BLUE_LOOP_STEERING
    if steer.Magnitude > 38 then steer=steer.Unit*38 end
    H.SetRagdollVelocity(model,Vector3.new(steer.X,velocity.Y,steer.Z))
   end
   previous=current
  end
  if not reached or not active() then break end
  completed += 1
  flow.lastTeleportAt=os.clock() -- a genuine crossing resets the 5s watchdog
  H.PlayPortalSound(C.AUDIO.Enter,low)
  if low:GetAttribute("RainbowPortal") or high:GetAttribute("RainbowPortal") then
   H.StartRainbowRagdoll(model)
  end
  downSpeed=math.min(C.BLUE_LOOP_MAX_SPEED,downSpeed+C.BLUE_LOOP_SPEED_GAIN)
  if pass < count then
   local torso=H.GetBodyPart(model)
   if not torso then break end
   model:PivotTo(model:GetPivot()+(highPos-Vector3.yAxis*2-torso.Position))
   H.SetRagdollVelocity(model,-Vector3.yAxis*downSpeed)
   H.PlayPortalSound(C.AUDIO.Enter,high)
  else
   -- Final pass: upper opening visibly turns sideways, then ejects horizontally.
   local camera=Workspace.CurrentCamera
   local forward=camera and camera.CFrame.RightVector or Vector3.xAxis
   if math.random(1,2)==1 then forward=-forward end
   local side=Vector3.new(forward.X,0,forward.Z)
   if side.Magnitude<0.01 then side=Vector3.xAxis end
   side=side.Unit
   -- Prepare the ordinary entrance WHILE the upper blue portal is rotating.
   -- Its normal opening animation therefore starts before the ragdoll launches.
   finalReturnPortal,finalReturnPosition=H.SpawnBlueReturnEntrance(
    model,side,highPos+side*2.4)
   local oldPivot=high:GetPivot()
   H.PlacePortal(high,highRoot,highPos,side)
   local endPivot=high:GetPivot()
   high:PivotTo(oldPivot)
   local rotateAt=os.clock()
   while active() and os.clock()-rotateAt < 0.16 do
    high:PivotTo(oldPivot:Lerp(endPivot,math.clamp((os.clock()-rotateAt)/0.16,0,1)))
    RunService.Heartbeat:Wait()
   end
   if not active() then break end
   high:PivotTo(endPivot)
   local torso=H.GetBodyPart(model)
   if not torso then break end
   model:PivotTo(model:GetPivot()+(highPos+side*2.4-torso.Position))
   H.SetRagdollVelocity(model,side*math.max(C.BLUE_LOOP_SIDE_LAUNCH,downSpeed*1.1)+Vector3.yAxis*14)
   H.PlayPortalSound(C.AUDIO.Enter,high)
   flow.lastTeleportAt=os.clock()
   finalSide=side
  end
 end
 cleanup()
 if completed==count and finalSide and not flow.finalizing
  and model.Parent and not model:GetAttribute("BombCharred") then
  -- This return portal makes the next hop visible and physically reachable.
  return H.RunBlueReturnPortal(model,flow,finalSide,finalReturnPortal,finalReturnPosition)
 end
 if finalReturnPortal and finalReturnPortal.Parent then
  task.spawn(H.ClosePortal,finalReturnPortal,nil)
 end
 return false
end

function H.MaybeRunBlueFallingLoop(model,flow,wasSelected)
 if not model.Parent or flow.finalizing or model:GetAttribute("BombCharred")
  or model:GetAttribute("BlueLoopUsed") or not wasSelected then
  return
 end
 if H.RunBlueFallingLoop(model,flow) then
  model:SetAttribute("BlueLoopUsed",true)
 end
end
-- END BLUE PROTOTYPE LOOP ----------------------------------------------------

-- FINAL ONE-WAY PORTAL -------------------------------------------------------
-- A self-contained visual adaptation of portalOpenBlood, falsePortalLegBlood,
-- and falsePortalExitShake. No game MintBlood module is required.
function H.FinalPortalFluidColor(portal)
 local lamp = portal and portal:FindFirstChildWhichIsA("PointLight", true)
 return lamp and lamp.Color or Color3.fromRGB(26, 255, 0)
end

function H.EmitFinalLegSpray(model, color)
 -- Respect the original attachment names when they exist. Emit simple colored
 -- portal droplets; the effect works even on ragdolls without attachments.
 for _, name in ipairs({"Left Leg", "Right Leg", "LeftLowerLeg", "RightLowerLeg"}) do
  local part = model:FindFirstChild(name, true)
  if part and part:IsA("BasePart") then
   local origin = part:FindFirstChild("FalsePortalLegBloodOrigin")
   local start = (origin and origin:IsA("Attachment")) and origin.WorldPosition or part.Position
   local velocity = part.AssemblyLinearVelocity
   local outward = velocity.Magnitude > 1 and velocity.Unit or part.CFrame.LookVector
   local direction = (outward*0.78 + part.CFrame.UpVector*0.22).Unit
   for _ = 1, 3 do H.SpawnFluidDrop(start, direction, color) end
   task.delay(0.08, function()
    if part.Parent then
     local second = outward*0.35 - Vector3.new(0, 0.65, 0)
     if second.Magnitude > 0.001 then
      for _ = 1, 2 do H.SpawnFluidDrop(start, second.Unit, color) end
     end
    end
   end)
  end
 end
end


function H.EmitPortalBloodBurst(frame, size, direction, color, count)
 color = color or C.FINAL_BLOOD_COLOR
 direction = (typeof(direction) == "Vector3" and direction.Magnitude > 0.001) and direction.Unit or Vector3.new(0, 0, 1)
 size = typeof(size) == "Vector3" and size or Vector3.new(8, 8.5, 0.1)
 local rx = math.max(size.X * 0.36, 0.5)
 local ry = math.max(size.Y * 0.36, 0.5)
 for _ = 1, (count or 6) do
  local theta = math.random() * math.pi * 2
  local radius = math.sqrt(math.random())
  local origin = frame * CFrame.new(math.cos(theta) * rx * radius, math.sin(theta) * ry * radius, -0.18)
  H.SpawnFluidDrop(origin.Position, direction, color)
 end
end

function H.SpillPortalBloodDuringShake(portal, duration)
 local root = H.GetRoot(portal)
 if not root then return end
 local started = os.clock()
 while portal.Parent and os.clock() - started < duration do
  root = H.GetRoot(portal)
  if not root then break end
  H.EmitPortalBloodBurst(root.CFrame, root.Size, root.CFrame.LookVector, C.FINAL_BLOOD_COLOR, 4)
  task.wait(C.FINAL_SHAKE_BLOOD_INTERVAL)
 end
end

-- Find the point on the remaining ragdoll where a released Roblox limb
-- was connected. Prefer actual ragdoll constraints/rig joints when available.
function H.FindLimbConnection(model, releasedPart)
 for _, item in ipairs(model:GetDescendants()) do
  if item:IsA("BallSocketConstraint") or item:IsA("HingeConstraint") then
   local a, b = item.Attachment0, item.Attachment1
   if a and b then
    local connected, other
    if a.Parent == releasedPart then connected, other = a, b
    elseif b.Parent == releasedPart then connected, other = b, a end
    if other and other.Parent and other.Parent:IsA("BasePart") then
     return other.Parent, other.WorldPosition
    end
   end
  elseif item:IsA("Motor6D") or item:IsA("Weld") then
   local other, worldPoint
   if item.Part1 == releasedPart and item.Part0 then
    other = item.Part0
    worldPoint = other.CFrame * item.C0
   elseif item.Part0 == releasedPart and item.Part1 then
    other = item.Part1
    worldPoint = other.CFrame * item.C1
   end
   if other and other:IsDescendantOf(model) then
    return other, worldPoint.Position
   end
  end
 end
 -- Fallback for physics-only ragdolls without surviving rig connectors.
 local closest, distance
 for _, part in ipairs(model:GetDescendants()) do
  if part:IsA("BasePart") and part ~= releasedPart
   and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
   local d = (part.Position - releasedPart.Position).Magnitude
   if not distance or d < distance then closest, distance = part, d end
  end
 end
 if closest then
  return closest, releasedPart.Position:Lerp(closest.Position, 0.35)
 end
end

function H.StartBlenderExitFluid(model, sites, allowCharred, duration)
 if not C.BLENDER_EXIT_FLUID or #sites == 0 then return end
 task.spawn(function()
  local began = os.clock()
  while model.Parent and (allowCharred or not model:GetAttribute("BombCharred"))
   and os.clock() - began < (duration or C.BLENDER_EXIT_FLUID_DURATION) do
   for _, site in ipairs(sites) do
    if site.Parent and site:IsDescendantOf(model) then
     local parent = site.Parent
     local velocity = parent.AssemblyLinearVelocity
     local direction = Vector3.new(math.random(-6,6)*0.12, 0.65, math.random(-6,6)*0.12)
     if velocity.Magnitude > 1 then direction += velocity.Unit*0.30 end
     H.SpawnFluidDrop(site.WorldPosition, direction.Unit, C.BLENDER_EXIT_FLUID_COLOR)
    end
   end
   task.wait(C.BLENDER_EXIT_FLUID_INTERVAL)
  end
  for _, site in ipairs(sites) do
   if site.Parent then site:Destroy() end
  end
 end)
end

-- Separate a few simple Roblox limb parts as before, remembering their
-- former attachment locations for the brief, post-ejection fluid effect.
function H.TearOffRandomLimbs(model, color, outward)
 local limbCandidates, seen = {}, {}
 for _, name in ipairs({
  "Left Arm","Right Arm","Left Leg","Right Leg",
  "LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftHand","RightHand",
  "LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot"
 }) do
  local part = model:FindFirstChild(name, true)
  if part and part:IsA("BasePart") and not seen[part] then
   seen[part] = true
   table.insert(limbCandidates, part)
  end
 end
 if #limbCandidates == 0 then return {} end
 local count = math.min(#limbCandidates, math.random(C.FINAL_TEAROFF_MIN,C.FINAL_TEAROFF_MAX))
 outward = outward and outward.Magnitude > 0.01 and outward.Unit or Vector3.new(1,0,0)
 local connectionRecords = {}
 for _ = 1, count do
  local chosen = table.remove(limbCandidates, math.random(1,#limbCandidates))
  if chosen and chosen.Parent then
   local connectedPart, point = H.FindLimbConnection(model, chosen)
   if connectedPart and point then
    table.insert(connectionRecords, {part = connectedPart, point = point})
   end
   local oldArchive = chosen.Archivable
   chosen.Archivable = true
   local ok, piece = pcall(function() return chosen:Clone() end)
   chosen.Archivable = oldArchive
   if ok and piece then
    piece.Name = "Ejected" .. chosen.Name
    for _, desc in ipairs(piece:GetDescendants()) do
     if desc:IsA("Constraint") or desc:IsA("JointInstance")
      or desc:IsA("Script") or desc:IsA("LocalScript") then
      desc:Destroy()
     end
    end
    piece.Anchored = false
    piece.CanCollide = true
    piece.CanTouch = true
    piece.CanQuery = true
    piece.Massless = false
    pcall(function() piece.CollisionGroup="Default" end)
    piece.Parent = Workspace
    piece.AssemblyLinearVelocity = outward * math.random(45,88)
      + Vector3.new(math.random(-30,30),math.random(16,42),math.random(-30,30))
    piece.AssemblyAngularVelocity = Vector3.new(math.random(-25,25),math.random(-25,25),math.random(-25,25))
    Debris:AddItem(piece, C.FINAL_RAGDOLL_CLEANUP_DELAY)
   end
   chosen:Destroy()
  end
 end
 local sites = {}
 for _, record in ipairs(connectionRecords) do
  local target = record.part
  if target and target.Parent and target:IsDescendantOf(model) then
   local attachment = Instance.new("Attachment")
   attachment.Name = "BlenderExitFluidOrigin"
   attachment.Position = target.CFrame:PointToObjectSpace(record.point)
   attachment.Parent = target
   table.insert(sites, attachment)
  end
 end
 return sites
end

function H.ShakeFinalPortal(portal, duration, owner)
 if not portal or not portal.Parent then return end
 -- Duplicate JUST the visuals, like falsePortalExitShake. Hide the original
 -- locally and restore it before the existing ClosePortal implementation.
 local visual = portal:Clone()
 visual.Name = "FinalPortalShakeVisual"
 local originalHidden = {}
 for _, object in ipairs(portal:GetDescendants()) do
  if object:IsA("BasePart") then
   table.insert(originalHidden, {object, "LocalTransparencyModifier", object.LocalTransparencyModifier})
   object.LocalTransparencyModifier = 1
  elseif object:IsA("SurfaceGui") or object:IsA("BillboardGui") then
   table.insert(originalHidden, {object, "Enabled", object.Enabled})
   object.Enabled = false
  end
 end
 for _, object in ipairs(visual:GetDescendants()) do
  if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("Sound")
   or object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
   object:Destroy()
  elseif object:IsA("BasePart") then
   object.Anchored = true
   object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
   object.CastShadow = false
   object.LocalTransparencyModifier = 0
  end
 end
 visual.Parent = Workspace:FindFirstChild("VFXLive") or Workspace
 local frame = portal:GetPivot()
 local began = os.clock()
 while visual.Parent and os.clock()-began < duration do
  if owner and (not owner.Parent or owner:GetAttribute("BombCharred")) then break end
  local t = os.clock()-began
  local stretchX = math.clamp(1 + math.sin(t*31)*0.16 + math.sin(t*57+0.7)*0.05,0.78,1.23)
  local stretchY = math.clamp(1 - math.sin(t*31)*0.13 + math.sin(t*83+1.9)*0.04,0.81,1.20)
  -- Scale uniformly for the template's welded geometry; tiny position/roll
  -- jitter conveys the wobbly false-portal look without breaking its parts.
  pcall(function() visual:ScaleTo(math.max(0.1,(stretchX+stretchY)*0.5)) end)
  visual:PivotTo(frame * CFrame.new(math.sin(t*57)*0.11, math.cos(t*43)*0.13, 0)
   * CFrame.Angles(0,0,math.sin(t*31)*0.035))
  RunService.RenderStepped:Wait()
 end
 if visual.Parent then visual:Destroy() end
 for _, record in ipairs(originalHidden) do
  local object, property, value = record[1],record[2],record[3]
  if object.Parent then pcall(function() object[property] = value end) end
 end
end

-- All terminal portals override the yellow suspicious-player theme.
-- The front/back bubble image tints are intentionally left alone.
C.TERMINAL_GREEN = portalSetting("TERMINAL_GREEN", Color3.fromRGB(26,255,0))
C.TERMINAL_GREEN_DIM = portalSetting("TERMINAL_GREEN_DIM", Color3.fromRGB(43,200,0))
function H.MakeTerminalPortalGreen(portal)
 -- The one-in-fifty rainbow roll also applies to either terminal portal.
 if portal:GetAttribute("RainbowPortal") then return end
 portal:SetAttribute("EvilMortyTheme", false)
 portal:SetAttribute("TerminalGreen", true)
 for _, item in ipairs(portal:GetDescendants()) do
  if not H.IsBubbleSubtree(item,portal) then
   if item:IsA("ImageLabel") or item:IsA("ImageButton") then
    item.ImageColor3 = C.TERMINAL_GREEN_DIM
   elseif item:IsA("BasePart") then item.Color = C.TERMINAL_GREEN_DIM
   elseif item:IsA("PointLight") or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
    item.Color = C.TERMINAL_GREEN
   elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then
    item.Color = ColorSequence.new(C.TERMINAL_GREEN)
   elseif item:IsA("UIStroke") then item.Color = C.TERMINAL_GREEN
   elseif item:IsA("UIGradient") then item.Color = ColorSequence.new(C.TERMINAL_GREEN_DIM)
   elseif item:IsA("Decal") then item.Color3 = C.TERMINAL_GREEN_DIM
   elseif item:IsA("GuiObject") then item.BackgroundColor3 = C.TERMINAL_GREEN_DIM
   elseif item:IsA("Highlight") then
    item.FillColor, item.OutlineColor = C.TERMINAL_GREEN_DIM, C.TERMINAL_GREEN
   elseif item:IsA("Fire") then
    item.Color, item.SecondaryColor = C.TERMINAL_GREEN_DIM, C.TERMINAL_GREEN
   elseif item:IsA("Smoke") then item.Color = C.TERMINAL_GREEN_DIM
   elseif item:IsA("Sparkles") then item.SparkleColor = C.TERMINAL_GREEN
   end
  end
 end
end

-- Try the actual game's VFX first. If it is absent, load the supplied RBXMX
-- from the executor's local files. This is visual-only; no server damage.
function H.LoadEffectModel(name, fileName)
 local assets = ReplicatedStorage:FindFirstChild("Assets")
 local vfx = assets and assets:FindFirstChild("VFX")
 local existing = vfx and vfx:FindFirstChild(name)
 if existing then return existing end
 if not getcustomasset then return nil end
 local ok, result = pcall(function()
  return game:GetObjects(getcustomasset(fileName))
 end)
 if ok and result and result[1] then
  return result[1]
 end
 return nil
end

-- Property-dump hydration for local RBXMX exports. Roblox's XML export
-- preserved the ParticleEmitter textures and NumberSequences but DID NOT
-- serialize these per-emitter VFX attributes. Restore the numeric settings
-- from the user's dump without overwriting existing attributes from the game.
-- Binary *_Curve buffers were not recoverable reliably from the text dump;
-- gameVfxDispatcher still takes priority whenever its originals are present.
local explosionEmitterSpecs = {
 {name="Bright Glare 1",texture="rbxassetid://87561602489912",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=0,Size_Envelope=2,Size_Start=50,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Chromatic Heat Haze Lens Flare",texture="rbxassetid://81904109714928",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=0,Size_Envelope=2,Size_Start=50,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Flare111New",texture="rbxassetid://3060556198",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=0,Size_Envelope=2,Size_Start=50,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="glare",texture="rbxassetid://88200687714438",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=10,Size_Envelope=2,Size_Start=10,Squash_End=1,Squash_Envelope=0.5,Squash_Start=0,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Chromatic Star",texture="rbxassetid://138578711337491",attrs={EmitCount=1,EmitDelay=0,EmitDuration=0,Size_End=0,Size_Envelope=2,Size_Start=50,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Impact346",texture="rbxassetid://15264848485",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=25,Size_Envelope=2,Size_Start=0,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Smooth Chromatic Sun Ray Lens Flare",texture="rbxassetid://85455873620937",attrs={EmitCount=1,EmitDelay=0,EmitDuration=0,Size_End=25,Size_Envelope=2,Size_Start=0,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Realistic 3D Smoke",texture="rbxassetid://11799788138",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=4,Size_Envelope=1,Size_Start=2,TimeScale_Duration=0.1774841777241046,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.5}},
 {name="Billowing",texture="rbxassetid://15415212938",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=3,Size_Envelope=1,Size_Start=2,TimeScale_Duration=0.1774841777241046,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.5}},
 {name="Darkening realism",texture="rbxassetid://11866794293",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=8,Size_Envelope=2,TimeScale_Duration=0.1774841777241046,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.5}},
 {name="Realistic 3D Smoke",texture="rbxassetid://11799788138",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=5,Size_Envelope=2,Size_Start=2,TimeScale_Duration=0.1774841777241046,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.5}},
 {name="Impact285",texture="rbxassetid://10358014393",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=30,Size_Envelope=2,Size_Start=0,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.5}},
 {name="Impact296",texture="rbxassetid://12389942991",attrs={EmitCount=3,EmitDelay=0,EmitDuration=0,Size_End=30,Size_Envelope=2,Size_Start=0,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.5}},
 {name="Impact332",texture="rbxassetid://13877774093",attrs={EmitCount=3,EmitDelay=0,EmitDuration=0,Size_End=30,Size_Envelope=2,Size_Start=0,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0}},
 {name="Billowing",texture="rbxassetid://15415212938",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=2,Size_Envelope=0.5,Size_Start=2.5,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.2}},
 {name="Realistic 3D Smoke",texture="rbxassetid://11799788138",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=2,Size_Envelope=0.5,Size_Start=2.5,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.2}},
 {name="Cartoon AOE",texture="rbxassetid://120553932796626",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=2,Size_Envelope=0.5,Size_Start=2.5,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.2}},
 {name="fog debris 2",texture="rbxassetid://91576474072579",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=2,Size_Envelope=0.5,Size_Start=2.5,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.2}},
 {name="Impact351",texture="rbxassetid://15846202888",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=8,Size_Envelope=2,Size_Start=0,Squash_End=0,Squash_Envelope=0.5,Squash_Start=1,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Envelope=0,Transparency_Start=0}},
 {name="Impact347",texture="rbxassetid://12937922496",attrs={EmitCount=1,EmitDelay=0,EmitDuration=0,Size_End=8,Size_Envelope=1,Size_Start=0,Squash_End=0,Squash_Envelope=0.5,Squash_Start=1,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Envelope=0,Transparency_Start=0.2}},
 {name="Ground9",texture="rbxassetid://99257520037104",attrs={EmitCount=1,EmitDelay=0,EmitDuration=0,Size_End=7,Size_Envelope=1,Size_Start=0,Squash_End=0,Squash_Envelope=0.5,Squash_Start=1,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Envelope=0,Transparency_Start=0.5}},
 {name="Circle73",texture="rbxassetid://15206623459",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=8,Size_Envelope=2,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Impact347",texture="rbxassetid://12937922496",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=8,Size_Envelope=1,Size_Start=0,Squash_End=0,Squash_Envelope=0.5,Squash_Start=1,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Envelope=0,Transparency_Start=0.5}},
 {name="Impact15",texture="rbxassetid://16892231149",attrs={EmitCount=1,EmitDelay=0,EmitDuration=0,Size_End=7,Size_Envelope=1,Size_Start=0,Squash_End=0,Squash_Envelope=0.5,Squash_Start=1,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Envelope=0,Transparency_Start=0.2}},
 {name="Ground29",texture="rbxassetid://125314922601956",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=25,Size_Envelope=1,Size_Start=3,Squash_End=0,Squash_Envelope=0.5,Squash_Start=1,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Envelope=0,Transparency_Start=0}},
 {name="Impact553",texture="rbxassetid://18230541777",attrs={EmitCount=1,EmitDelay=0,EmitDuration=0,Size_End=25,Size_Envelope=1,Size_Start=3,Squash_End=0,Squash_Envelope=0.5,Squash_Start=1,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Envelope=0,Transparency_Start=0}},
 {name="Impact487",texture="rbxassetid://129551943516119",attrs={EmitCount=1,EmitDelay=0,EmitDuration=0,Size_End=25,Size_Envelope=1,Size_Start=3,Squash_End=0,Squash_Envelope=0.5,Squash_Start=1,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Envelope=0,Transparency_Start=0}},
 {name="Realistic Fire Kit",texture="rbxassetid://18369727963",attrs={EmitCount=1,EmitDelay=0,EmitDuration=0,Size_End=12,Size_Envelope=2,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Fire36",texture="rbxassetid://16860267787",attrs={EmitCount=1,EmitDelay=0,EmitDuration=0,Size_End=13,Size_Envelope=2,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Fire2",texture="rbxassetid://16843151641",attrs={EmitCount=6,EmitDelay=0,EmitDuration=0,Size_End=10,Size_Envelope=2,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Fire23",texture="rbxassetid://16848303531",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=8,Size_Envelope=2,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Low Res Burst",texture="rbxassetid://13486412595",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=6,Size_Envelope=1,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Fire1",texture="rbxassetid://16841991986",attrs={EmitCount=10,EmitDelay=0,EmitDuration=0,Size_End=5,Size_Envelope=1,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Fire8",texture="rbxassetid://16845391847",attrs={EmitCount=2,EmitDelay=0,EmitDuration=0,Size_End=12,Size_Envelope=5,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Darkening realism",texture="rbxassetid://11866794293",attrs={EmitCount=6,EmitDelay=0,EmitDuration=0,Size_End=5,Size_Envelope=2,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Fire23",texture="rbxassetid://16848303531",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=5,Size_Envelope=2,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Fire3",texture="rbxassetid://16843373901",attrs={EmitCount=10,EmitDelay=0,EmitDuration=0,Size_End=10,Size_Envelope=2,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1}},
 {name="Stylized Smoke71 fading",texture="rbxassetid://16334792296",attrs={EmitCount=5,EmitDelay=0,EmitDuration=0,Size_End=4,Size_Envelope=1,Size_Start=2,TimeScale_Duration=0.1,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.5}},
 {name="Darkening realism",texture="rbxassetid://11866794293",attrs={EmitCount=0,EmitDelay=0,EmitDuration=1.2,Size_End=8,Size_Envelope=2,TimeScale_Duration=0.13209574987787004,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.5}},
 {name="Realistic 3D Smoke",texture="rbxassetid://11799788138",attrs={EmitCount=0,EmitDelay=0,EmitDuration=1.2,Size_End=5,Size_Envelope=2,Size_Start=2,TimeScale_Duration=0.13209574987787004,TimeScale_End=1,TimeScale_Start=1,Transparency_Start=0.5}},
}
local deathAuraEmitterSpecs = {
 {name="Fire19",texture="rbxassetid://16847032740",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire6",texture="rbxassetid://16845227778",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="OffCentered Spec 57",texture="rbxassetid://15419161283",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire6",texture="rbxassetid://16845227778",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire19",texture="rbxassetid://16847032740",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="OffCentered Spec 57",texture="rbxassetid://15419161283",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire19",texture="rbxassetid://16847032740",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire6",texture="rbxassetid://16845227778",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="OffCentered Spec 57",texture="rbxassetid://15419161283",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire19",texture="rbxassetid://16847032740",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire6",texture="rbxassetid://16845227778",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="OffCentered Spec 57",texture="rbxassetid://15419161283",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire19",texture="rbxassetid://16847032740",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire6",texture="rbxassetid://16845227778",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="OffCentered Spec 57",texture="rbxassetid://15419161283",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire6",texture="rbxassetid://16845227778",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="Fire19",texture="rbxassetid://16847032740",attrs={Size_End=1,Size_Envelope=0.5}},
 {name="OffCentered Spec 57",texture="rbxassetid://15419161283",attrs={Size_End=1,Size_Envelope=0.5}},
}

function H.HydrateEmitterAttributes(template,specs)
 if not template then return end
 local groups={}
 for _,spec in ipairs(specs) do
  local key=spec.name.."|"..tostring(spec.texture)
  if not groups[key] then groups[key]={} end
  table.insert(groups[key],spec)
 end
 local hydrated=0
 for _,obj in ipairs(template:GetDescendants()) do
  if obj:IsA("ParticleEmitter") then
   local key=obj.Name.."|"..tostring(obj.Texture)
   local entries=groups[key]
   local matched=entries and table.remove(entries,1)
   -- If texture is inaccessible/sanitized, use a name-only match only when
   -- unambiguous within the same remaining metadata records.
   if not matched then
    local candidateKey
    for k,v in pairs(groups) do
     if #v>0 and v[1].name==obj.Name then
      if candidateKey then candidateKey=nil; break end
      candidateKey=k
     end
    end
    if candidateKey then matched=table.remove(groups[candidateKey],1) end
   end
   if matched then
    -- A missing/blank texture in an exported model must be restored explicitly.
    -- Roblox may still refuse private textures; this cannot bypass asset access.
    if matched.texture and matched.texture ~= "" and obj.Texture ~= matched.texture then
     local ok,err=pcall(function() obj.Texture=matched.texture end)
     if not ok then warn("[PrimeBomb] Texture assignment failed:",obj.Name,err) end
    end
    for attr,value in pairs(matched.attrs) do
     if obj:GetAttribute(attr)==nil then obj:SetAttribute(attr,value) end
    end
    hydrated+=1
   end
  end
 end
 print("[PrimeBomb] Restored VFX emitter metadata/textures:", hydrated, "/",#specs)
 for _,obj in ipairs(template:GetDescendants()) do
  if obj:IsA("ParticleEmitter") and (obj.Texture=="" or obj.Texture=="rbxasset://textures/particles/sparkles_main.dds") then
   warn("[PrimeBomb] Emitter may have missing/default texture:",obj:GetFullName(),obj.Texture)
  end
 end
end

-- Full emitter property restoration generated from PrimeBomb_FullDump(2).txt
local PrimeBombDumpProperties = {
 {root="PrimeBombExplosion",path="Anchor.Explosion.Pact.Bright Glare 1",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.806158,0.113725,0.964706)),ColorSequenceKeypoint.new(1,Color3.new(0.806158,0.113725,0.964706))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.075,0.075),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityParallel,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,132.479,0),NumberSequenceKeypoint.new(0.0737787,105.155,0),NumberSequenceKeypoint.new(0.17348,78.6596,0),NumberSequenceKeypoint.new(0.445663,36.4318,0),NumberSequenceKeypoint.new(0.740778,9.93595,0),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(0.0070405,0.0070405),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0)}),["Texture"]="rbxassetid://87561602489912",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Pact.Chromatic Heat Haze Lens Flare",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=1,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.806158,0.113725,0.964706)),ColorSequenceKeypoint.new(1,Color3.new(0.806158,0.113725,0.964706))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.075,0.075),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityParallel,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,120.436,0),NumberSequenceKeypoint.new(0.0737787,95.5959,0),NumberSequenceKeypoint.new(0.17348,71.5087,0),NumberSequenceKeypoint.new(0.445663,33.1198,0),NumberSequenceKeypoint.new(0.740778,9.03268,0),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(0.00640045,0.00640045),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://81904109714928",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Pact.Flare111New",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.806158,0.113725,0.964706)),ColorSequenceKeypoint.new(1,Color3.new(0.806158,0.113725,0.964706))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.075,0.075),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityParallel,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,132.479,0),NumberSequenceKeypoint.new(0.0737787,105.155,0),NumberSequenceKeypoint.new(0.17348,78.6596,0),NumberSequenceKeypoint.new(0.445663,36.4318,0),NumberSequenceKeypoint.new(0.740778,9.93595,0),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(0.0070405,0.0070405),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(1,1,0)}),["Texture"]="rbxassetid://3060556198",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Pact.glare",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.806158,0.113725,0.964706)),ColorSequenceKeypoint.new(1,Color3.new(0.806158,0.113725,0.964706))}),["Drag"]=15,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.1,0.15),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.VelocityParallel,["Rate"]=10,["RotSpeed"]=NumberRange.new(-1000,1000),["Rotation"]=NumberRange.new(-1000,1000),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,68.6695,13.7339),NumberSequenceKeypoint.new(1,68.6695,13.7339)}),["Speed"]=NumberRange.new(0.00364938,0.00364938),["SpreadAngle"]=Vector2.new(-360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(0.528846,-0.0967741,0),NumberSequenceKeypoint.new(1,1.41935,0)}),["Texture"]="rbxassetid://88200687714438",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Pact.Chromatic Star",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.806158,0.113725,0.964706)),ColorSequenceKeypoint.new(1,Color3.new(0.806158,0.113725,0.964706))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.075,0.075),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,120.436,0),NumberSequenceKeypoint.new(0.0737787,95.5959,0),NumberSequenceKeypoint.new(0.17348,71.5087,0),NumberSequenceKeypoint.new(0.445663,33.1198,0),NumberSequenceKeypoint.new(0.740778,9.03268,0),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(0.00640045,0.00640045),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(0.274725,2.4,0),NumberSequenceKeypoint.new(0.631258,-2.55,0),NumberSequenceKeypoint.new(1,-3,0)}),["Texture"]="rbxassetid://138578711337491",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Pact.Impact346",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=1,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.806158,0.113725,0.964706)),ColorSequenceKeypoint.new(1,Color3.new(0.806158,0.113725,0.964706))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.075,0.075),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityParallel,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,5.84488),NumberSequenceKeypoint.new(0.0617071,12.6505,5.84488),NumberSequenceKeypoint.new(0.12693,25.1252,5.84488),NumberSequenceKeypoint.new(0.162264,31.2152,5.84488),NumberSequenceKeypoint.new(0.200324,37.1411,5.84488),NumberSequenceKeypoint.new(0.241846,42.8332,5.84488),NumberSequenceKeypoint.new(0.287501,48.2042,5.84488),NumberSequenceKeypoint.new(0.337754,53.1543,5.84488),NumberSequenceKeypoint.new(0.392709,57.5852,5.84488),NumberSequenceKeypoint.new(0.452035,61.4218,5.84488),NumberSequenceKeypoint.new(0.515043,64.6305,5.84488),NumberSequenceKeypoint.new(0.58088,67.2229,5.84488),NumberSequenceKeypoint.new(0.648722,69.2454,5.84488),NumberSequenceKeypoint.new(0.717898,70.7626,5.84488),NumberSequenceKeypoint.new(0.787908,71.8428,5.84488),NumberSequenceKeypoint.new(0.858403,72.5499,5.84488),NumberSequenceKeypoint.new(0.929151,72.9402,5.84488),NumberSequenceKeypoint.new(1,73.0611,5.84488)}),["Speed"]=NumberRange.new(0.00529268,0.00529268),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://15264848485",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Pact.Smooth Chromatic Sun Ray Lens Flare",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=1,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.806158,0.113725,0.964706)),ColorSequenceKeypoint.new(1,Color3.new(0.806158,0.113725,0.964706))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.075,0.075),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityParallel,["Rate"]=20,["RotSpeed"]=NumberRange.new(-500,500),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,7.06823),NumberSequenceKeypoint.new(0.0617071,15.2983,7.06823),NumberSequenceKeypoint.new(0.12693,30.3839,7.06823),NumberSequenceKeypoint.new(0.162264,37.7487,7.06823),NumberSequenceKeypoint.new(0.200324,44.9148,7.06823),NumberSequenceKeypoint.new(0.241846,51.7983,7.06823),NumberSequenceKeypoint.new(0.287501,58.2935,7.06823),NumberSequenceKeypoint.new(0.337754,64.2796,7.06823),NumberSequenceKeypoint.new(0.392709,69.6379,7.06823),NumberSequenceKeypoint.new(0.452035,74.2775,7.06823),NumberSequenceKeypoint.new(0.515043,78.1578,7.06823),NumberSequenceKeypoint.new(0.58088,81.2928,7.06823),NumberSequenceKeypoint.new(0.648722,83.7387,7.06823),NumberSequenceKeypoint.new(0.717898,85.5734,7.06823),NumberSequenceKeypoint.new(0.787908,86.8796,7.06823),NumberSequenceKeypoint.new(0.858403,87.7348,7.06823),NumberSequenceKeypoint.new(0.929151,88.2067,7.06823),NumberSequenceKeypoint.new(1,88.3529,7.06823)}),["Speed"]=NumberRange.new(0.00920065,0.00920065),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://85455873620937",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Realistic 3D Smoke",occurrence=1,properties={["Acceleration"]=Vector3.new(0,-6.3444108963012695,0),["Brightness"]=1,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.619608,0.619608,0.619608)),ColorSequenceKeypoint.new(1,Color3.new(0.619608,0.619608,0.619608))}),["Drag"]=1.6902918815612793,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(30,30),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid8x8,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(2.66226,5.32452),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=42.257286071777344,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,24.1822,12.0911),NumberSequenceKeypoint.new(0.0105052,26.5788,12.0911),NumberSequenceKeypoint.new(0.0243512,28.9568,12.0911),NumberSequenceKeypoint.new(0.0427394,31.3012,12.0911),NumberSequenceKeypoint.new(0.0668089,33.5893,12.0911),NumberSequenceKeypoint.new(0.0975439,35.7893,12.0911),NumberSequenceKeypoint.new(0.13559,37.8623,12.0911),NumberSequenceKeypoint.new(0.181059,39.7672,12.0911),NumberSequenceKeypoint.new(0.233449,41.4699,12.0911),NumberSequenceKeypoint.new(0.29176,42.9511,12.0911),NumberSequenceKeypoint.new(0.354767,44.2087,12.0911),NumberSequenceKeypoint.new(0.421282,45.2545,12.0911),NumberSequenceKeypoint.new(0.490308,46.1078,12.0911),NumberSequenceKeypoint.new(0.561076,46.791,12.0911),NumberSequenceKeypoint.new(0.633026,47.3255,12.0911),NumberSequenceKeypoint.new(0.705756,47.7309,12.0911),NumberSequenceKeypoint.new(0.778988,48.0241,12.0911),NumberSequenceKeypoint.new(0.852522,48.2197,12.0911),NumberSequenceKeypoint.new(0.926223,48.3297,12.0911),NumberSequenceKeypoint.new(1,48.3644,12.0911)}),["Speed"]=NumberRange.new(56.3016,168.905),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1125,0.1125),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://11799788138",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3,0),NumberSequenceKeypoint.new(0.0846497,0.399409,0),NumberSequenceKeypoint.new(0.172384,0.496372,0),NumberSequenceKeypoint.new(0.263711,0.59029,0),NumberSequenceKeypoint.new(0.310915,0.635857,0),NumberSequenceKeypoint.new(0.408885,0.723514,0),NumberSequenceKeypoint.new(0.459877,0.765233,0),NumberSequenceKeypoint.new(0.512381,0.805222,0),NumberSequenceKeypoint.new(0.566542,0.843162,0),NumberSequenceKeypoint.new(0.622515,0.878647,0),NumberSequenceKeypoint.new(0.680449,0.911163,0),NumberSequenceKeypoint.new(0.74047,0.940049,0),NumberSequenceKeypoint.new(0.802643,0.964474,0),NumberSequenceKeypoint.new(0.866893,0.98341,0),NumberSequenceKeypoint.new(0.932906,0.995665,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=-1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Billowing",occurrence=1,properties={["Acceleration"]=Vector3.new(0,-12.688821792602539,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.219608,0.219608,0.219608)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=1.6902918815612793,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(30,30),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(2.66226,5.32452),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=42.257286071777344,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,19.9853,9.99265),NumberSequenceKeypoint.new(0.0105052,20.9756,9.99265),NumberSequenceKeypoint.new(0.0243512,21.9583,9.99265),NumberSequenceKeypoint.new(0.0427394,22.9271,9.99265),NumberSequenceKeypoint.new(0.0668089,23.8725,9.99265),NumberSequenceKeypoint.new(0.0975439,24.7816,9.99265),NumberSequenceKeypoint.new(0.13559,25.6382,9.99265),NumberSequenceKeypoint.new(0.181059,26.4254,9.99265),NumberSequenceKeypoint.new(0.233449,27.1289,9.99265),NumberSequenceKeypoint.new(0.29176,27.741,9.99265),NumberSequenceKeypoint.new(0.354767,28.2607,9.99265),NumberSequenceKeypoint.new(0.421282,28.6929,9.99265),NumberSequenceKeypoint.new(0.490308,29.0455,9.99265),NumberSequenceKeypoint.new(0.561076,29.3278,9.99265),NumberSequenceKeypoint.new(0.633026,29.5486,9.99265),NumberSequenceKeypoint.new(0.705756,29.7161,9.99265),NumberSequenceKeypoint.new(0.778988,29.8373,9.99265),NumberSequenceKeypoint.new(0.852522,29.9181,9.99265),NumberSequenceKeypoint.new(0.926223,29.9636,9.99265),NumberSequenceKeypoint.new(1,29.9779,9.99265)}),["Speed"]=NumberRange.new(56.3016,197.056),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.6375,0.2625),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://15415212938",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5,0),NumberSequenceKeypoint.new(0.0844572,0.570849,0),NumberSequenceKeypoint.new(0.172009,0.639979,0),NumberSequenceKeypoint.new(0.263168,0.706967,0),NumberSequenceKeypoint.new(0.310297,0.739481,0),NumberSequenceKeypoint.new(0.408139,0.80206,0),NumberSequenceKeypoint.new(0.459084,0.831861,0),NumberSequenceKeypoint.new(0.511554,0.86044,0),NumberSequenceKeypoint.new(0.5657,0.88757,0),NumberSequenceKeypoint.new(0.621679,0.912962,0),NumberSequenceKeypoint.new(0.679649,0.936246,0),NumberSequenceKeypoint.new(0.739743,0.95695,0),NumberSequenceKeypoint.new(0.802031,0.974473,0),NumberSequenceKeypoint.new(0.866443,0.988072,0),NumberSequenceKeypoint.new(0.932665,0.996882,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=-1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Darkening realism",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.219608,0.219608,0.219608)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=3.3805837631225586,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(30,30),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(1.06491,1.77484),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=42.257286071777344,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,18.8158),NumberSequenceKeypoint.new(0.0081561,7.43777,18.8158),NumberSequenceKeypoint.new(0.0218356,14.79,18.8158),NumberSequenceKeypoint.new(0.0416248,21.9952,18.8158),NumberSequenceKeypoint.new(0.0680281,28.9751,18.8158),NumberSequenceKeypoint.new(0.101359,35.6379,18.8158),NumberSequenceKeypoint.new(0.141647,41.8865,18.8158),NumberSequenceKeypoint.new(0.188576,47.6313,18.8158),NumberSequenceKeypoint.new(0.241499,52.8043,18.8158),NumberSequenceKeypoint.new(0.29955,57.3681,18.8158),NumberSequenceKeypoint.new(0.361775,61.3176,18.8158),NumberSequenceKeypoint.new(0.427263,64.6732,18.8158),NumberSequenceKeypoint.new(0.495216,67.4724,18.8158),NumberSequenceKeypoint.new(0.56498,69.7611,18.8158),NumberSequenceKeypoint.new(0.636043,71.5873,18.8158),NumberSequenceKeypoint.new(0.70801,72.9975,18.8158),NumberSequenceKeypoint.new(0.780585,74.0343,18.8158),NumberSequenceKeypoint.new(0.853545,74.7359,18.8158),NumberSequenceKeypoint.new(0.926724,75.1356,18.8158),NumberSequenceKeypoint.new(1,75.263,18.8158)}),["Speed"]=NumberRange.new(131.652,230.392),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://11866794293",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5,0),NumberSequenceKeypoint.new(0.0844572,0.570849,0),NumberSequenceKeypoint.new(0.172009,0.639979,0),NumberSequenceKeypoint.new(0.263168,0.706967,0),NumberSequenceKeypoint.new(0.310297,0.739481,0),NumberSequenceKeypoint.new(0.408139,0.80206,0),NumberSequenceKeypoint.new(0.459084,0.831861,0),NumberSequenceKeypoint.new(0.511554,0.86044,0),NumberSequenceKeypoint.new(0.5657,0.88757,0),NumberSequenceKeypoint.new(0.621679,0.912962,0),NumberSequenceKeypoint.new(0.679649,0.936246,0),NumberSequenceKeypoint.new(0.739743,0.95695,0),NumberSequenceKeypoint.new(0.802031,0.974473,0),NumberSequenceKeypoint.new(0.866443,0.988072,0),NumberSequenceKeypoint.new(0.932665,0.996882,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=-1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Realistic 3D Smoke",occurrence=2,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.219608,0.219608,0.219608)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=1.6902918815612793,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(30,30),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid8x8,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(2.66226,5.32452),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=42.257286071777344,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,19.9853,19.9853),NumberSequenceKeypoint.new(0.0105052,22.9562,19.9853),NumberSequenceKeypoint.new(0.0243512,25.9042,19.9853),NumberSequenceKeypoint.new(0.0427394,28.8105,19.9853),NumberSequenceKeypoint.new(0.0668089,31.647,19.9853),NumberSequenceKeypoint.new(0.0975439,34.3743,19.9853),NumberSequenceKeypoint.new(0.13559,36.9441,19.9853),NumberSequenceKeypoint.new(0.181059,39.3055,19.9853),NumberSequenceKeypoint.new(0.233449,41.4163,19.9853),NumberSequenceKeypoint.new(0.29176,43.2525,19.9853),NumberSequenceKeypoint.new(0.354767,44.8116,19.9853),NumberSequenceKeypoint.new(0.421282,46.108,19.9853),NumberSequenceKeypoint.new(0.490308,47.1659,19.9853),NumberSequenceKeypoint.new(0.561076,48.0127,19.9853),NumberSequenceKeypoint.new(0.633026,48.6753,19.9853),NumberSequenceKeypoint.new(0.705756,49.1778,19.9853),NumberSequenceKeypoint.new(0.778988,49.5414,19.9853),NumberSequenceKeypoint.new(0.852522,49.7839,19.9853),NumberSequenceKeypoint.new(0.926223,49.9202,19.9853),NumberSequenceKeypoint.new(1,49.9632,19.9853)}),["Speed"]=NumberRange.new(16.4566,98.7392),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://11799788138",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3,0),NumberSequenceKeypoint.new(0.0846497,0.399409,0),NumberSequenceKeypoint.new(0.172384,0.496372,0),NumberSequenceKeypoint.new(0.263711,0.59029,0),NumberSequenceKeypoint.new(0.310915,0.635857,0),NumberSequenceKeypoint.new(0.408885,0.723514,0),NumberSequenceKeypoint.new(0.459877,0.765233,0),NumberSequenceKeypoint.new(0.512381,0.805222,0),NumberSequenceKeypoint.new(0.566542,0.843162,0),NumberSequenceKeypoint.new(0.622515,0.878647,0),NumberSequenceKeypoint.new(0.680449,0.911163,0),NumberSequenceKeypoint.new(0.74047,0.940049,0),NumberSequenceKeypoint.new(0.802643,0.964474,0),NumberSequenceKeypoint.new(0.866893,0.98341,0),NumberSequenceKeypoint.new(0.932906,0.995665,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=-1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Impact285",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.690196,0.690196,0.690196)),ColorSequenceKeypoint.new(1,Color3.new(0.690196,0.690196,0.690196))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(1,2),["LightEmission"]=0.6000000238418579,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=20,["RotSpeed"]=NumberRange.new(-50,50),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,6.29184),NumberSequenceKeypoint.new(0.0388407,18.9292,6.29184),NumberSequenceKeypoint.new(0.080949,37.7425,6.29184),NumberSequenceKeypoint.new(0.104748,47.0412,6.29184),NumberSequenceKeypoint.new(0.131918,56.1861,6.29184),NumberSequenceKeypoint.new(0.164457,65.0361,6.29184),NumberSequenceKeypoint.new(0.20527,73.2974,6.29184),NumberSequenceKeypoint.new(0.257325,80.4342,6.29184),NumberSequenceKeypoint.new(0.320765,85.8474,6.29184),NumberSequenceKeypoint.new(0.391742,89.4322,6.29184),NumberSequenceKeypoint.new(0.466166,91.6207,6.29184),NumberSequenceKeypoint.new(0.541887,92.909,6.29184),NumberSequenceKeypoint.new(0.618068,93.6467,6.29184),NumberSequenceKeypoint.new(0.694404,94.051,6.29184),NumberSequenceKeypoint.new(0.770791,94.2559,6.29184),NumberSequenceKeypoint.new(0.847191,94.3454,6.29184),NumberSequenceKeypoint.new(0.923594,94.374,6.29184),NumberSequenceKeypoint.new(1,94.3775,6.29184)}),["Speed"]=NumberRange.new(0.00299811,0.00299811),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://10358014393",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5,0),NumberSequenceKeypoint.new(0.0506233,0.590008,0),NumberSequenceKeypoint.new(0.0793971,0.634066,0),NumberSequenceKeypoint.new(0.111148,0.677189,0),NumberSequenceKeypoint.new(0.146363,0.719077,0),NumberSequenceKeypoint.new(0.185493,0.759364,0),NumberSequenceKeypoint.new(0.228895,0.797619,0),NumberSequenceKeypoint.new(0.276791,0.833369,0),NumberSequenceKeypoint.new(0.329195,0.866134,0),NumberSequenceKeypoint.new(0.385894,0.895491,0),NumberSequenceKeypoint.new(0.446458,0.921129,0),NumberSequenceKeypoint.new(0.51029,0.942893,0),NumberSequenceKeypoint.new(0.576731,0.960795,0),NumberSequenceKeypoint.new(0.645131,0.974986,0),NumberSequenceKeypoint.new(0.714918,0.98571,0),NumberSequenceKeypoint.new(0.785621,0.993268,0),NumberSequenceKeypoint.new(0.856874,0.99797,0),NumberSequenceKeypoint.new(0.928399,1,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Impact296",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.690196,0.690196,0.690196)),ColorSequenceKeypoint.new(1,Color3.new(0.690196,0.690196,0.690196))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(1.5,2.5),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,6.29184),NumberSequenceKeypoint.new(0.0388407,18.9292,6.29184),NumberSequenceKeypoint.new(0.080949,37.7425,6.29184),NumberSequenceKeypoint.new(0.104748,47.0412,6.29184),NumberSequenceKeypoint.new(0.131918,56.1861,6.29184),NumberSequenceKeypoint.new(0.164457,65.0361,6.29184),NumberSequenceKeypoint.new(0.20527,73.2974,6.29184),NumberSequenceKeypoint.new(0.257325,80.4342,6.29184),NumberSequenceKeypoint.new(0.320765,85.8474,6.29184),NumberSequenceKeypoint.new(0.391742,89.4322,6.29184),NumberSequenceKeypoint.new(0.466166,91.6207,6.29184),NumberSequenceKeypoint.new(0.541887,92.909,6.29184),NumberSequenceKeypoint.new(0.618068,93.6467,6.29184),NumberSequenceKeypoint.new(0.694404,94.051,6.29184),NumberSequenceKeypoint.new(0.770791,94.2559,6.29184),NumberSequenceKeypoint.new(0.847191,94.3454,6.29184),NumberSequenceKeypoint.new(0.923594,94.374,6.29184),NumberSequenceKeypoint.new(1,94.3775,6.29184)}),["Speed"]=NumberRange.new(0.00299811,0.00299811),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://12389942991",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5,0),NumberSequenceKeypoint.new(0.0506233,0.590008,0),NumberSequenceKeypoint.new(0.0793971,0.634066,0),NumberSequenceKeypoint.new(0.111148,0.677189,0),NumberSequenceKeypoint.new(0.146363,0.719077,0),NumberSequenceKeypoint.new(0.185493,0.759364,0),NumberSequenceKeypoint.new(0.228895,0.797619,0),NumberSequenceKeypoint.new(0.276791,0.833369,0),NumberSequenceKeypoint.new(0.329195,0.866134,0),NumberSequenceKeypoint.new(0.385894,0.895491,0),NumberSequenceKeypoint.new(0.446458,0.921129,0),NumberSequenceKeypoint.new(0.51029,0.942893,0),NumberSequenceKeypoint.new(0.576731,0.960795,0),NumberSequenceKeypoint.new(0.645131,0.974986,0),NumberSequenceKeypoint.new(0.714918,0.98571,0),NumberSequenceKeypoint.new(0.785621,0.993268,0),NumberSequenceKeypoint.new(0.856874,0.99797,0),NumberSequenceKeypoint.new(0.928399,1,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Impact332",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.05000000074505806,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.690196,0.690196,0.690196)),ColorSequenceKeypoint.new(1,Color3.new(0.690196,0.690196,0.690196))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.8,1.5),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=20,["RotSpeed"]=NumberRange.new(-50,50),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,8.13704),NumberSequenceKeypoint.new(0.0388407,24.4806,8.13704),NumberSequenceKeypoint.new(0.080949,48.8113,8.13704),NumberSequenceKeypoint.new(0.104748,60.8369,8.13704),NumberSequenceKeypoint.new(0.131918,72.6637,8.13704),NumberSequenceKeypoint.new(0.164457,84.1091,8.13704),NumberSequenceKeypoint.new(0.20527,94.7933,8.13704),NumberSequenceKeypoint.new(0.257325,104.023,8.13704),NumberSequenceKeypoint.new(0.320765,111.024,8.13704),NumberSequenceKeypoint.new(0.391742,115.66,8.13704),NumberSequenceKeypoint.new(0.466166,118.49,8.13704),NumberSequenceKeypoint.new(0.541887,120.156,8.13704),NumberSequenceKeypoint.new(0.618068,121.11,8.13704),NumberSequenceKeypoint.new(0.694404,121.633,8.13704),NumberSequenceKeypoint.new(0.770791,121.898,8.13704),NumberSequenceKeypoint.new(0.847191,122.014,8.13704),NumberSequenceKeypoint.new(0.923594,122.051,8.13704),NumberSequenceKeypoint.new(1,122.056,8.13704)}),["Speed"]=NumberRange.new(0.00387737,0.00387737),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://13877774093",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(0.0844572,0.141698,0),NumberSequenceKeypoint.new(0.172009,0.279958,0),NumberSequenceKeypoint.new(0.263168,0.413934,0),NumberSequenceKeypoint.new(0.310297,0.478963,0),NumberSequenceKeypoint.new(0.358584,0.542436,0),NumberSequenceKeypoint.new(0.408139,0.60412,0),NumberSequenceKeypoint.new(0.459084,0.663722,0),NumberSequenceKeypoint.new(0.511554,0.720881,0),NumberSequenceKeypoint.new(0.5657,0.775141,0),NumberSequenceKeypoint.new(0.621679,0.825924,0),NumberSequenceKeypoint.new(0.679649,0.872492,0),NumberSequenceKeypoint.new(0.739743,0.913899,0),NumberSequenceKeypoint.new(0.802031,0.948945,0),NumberSequenceKeypoint.new(0.866443,0.976145,0),NumberSequenceKeypoint.new(0.932665,0.993763,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Smoke.Billowing",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.800000011920929,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.443137,0.443137,0.443137)),ColorSequenceKeypoint.new(1,Color3.new(0.443137,0.443137,0.443137))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Back,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(2,3),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,31.1649,6.23298),NumberSequenceKeypoint.new(0.0459003,29.9604,6.23298),NumberSequenceKeypoint.new(0.0961229,28.7684,6.23298),NumberSequenceKeypoint.new(0.124088,28.1815,6.23298),NumberSequenceKeypoint.new(0.155079,27.6057,6.23298),NumberSequenceKeypoint.new(0.190419,27.0482,6.23298),NumberSequenceKeypoint.new(0.231914,26.5221,6.23298),NumberSequenceKeypoint.new(0.281563,26.0497,6.23298),NumberSequenceKeypoint.new(0.340388,25.6604,6.23298),NumberSequenceKeypoint.new(0.406988,25.3743,6.23298),NumberSequenceKeypoint.new(0.478301,25.185,6.23298),NumberSequenceKeypoint.new(0.551797,25.0685,6.23298),NumberSequenceKeypoint.new(0.626155,25.0003,6.23298),NumberSequenceKeypoint.new(0.700822,24.9625,6.23298),NumberSequenceKeypoint.new(1,24.9319,6.23298)}),["Speed"]=NumberRange.new(38.7019,270.913),["SpreadAngle"]=Vector2.new(0,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.8625,0),NumberSequenceKeypoint.new(0.169719,0.2625,0.238558),NumberSequenceKeypoint.new(0.410256,-0.0375001,0.224667),NumberSequenceKeypoint.new(1,-0.15,0)}),["Texture"]="rbxassetid://15415212938",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2,0),NumberSequenceKeypoint.new(0.0233633,0.270425,0),NumberSequenceKeypoint.new(0.0534873,0.337775,0),NumberSequenceKeypoint.new(0.0887987,0.402096,0),NumberSequenceKeypoint.new(0.128267,0.463509,0),NumberSequenceKeypoint.new(0.171199,0.522122,0),NumberSequenceKeypoint.new(0.217117,0.578008,0),NumberSequenceKeypoint.new(0.265677,0.631194,0),NumberSequenceKeypoint.new(0.316638,0.681666,0),NumberSequenceKeypoint.new(0.36982,0.729361,0),NumberSequenceKeypoint.new(0.425088,0.774172,0),NumberSequenceKeypoint.new(0.482344,0.815939,0),NumberSequenceKeypoint.new(0.541503,0.854449,0),NumberSequenceKeypoint.new(0.602495,0.889425,0),NumberSequenceKeypoint.new(0.665242,0.920523,0),NumberSequenceKeypoint.new(0.729649,0.947319,0),NumberSequenceKeypoint.new(0.795582,0.9693,0),NumberSequenceKeypoint.new(0.862841,0.985869,0),NumberSequenceKeypoint.new(0.931127,0.996345,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Smoke.Realistic 3D Smoke",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.800000011920929,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.443137,0.443137,0.443137)),ColorSequenceKeypoint.new(1,Color3.new(0.443137,0.443137,0.443137))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Back,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid8x8,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(2,3),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,31.1649,6.23298),NumberSequenceKeypoint.new(0.0459003,29.9604,6.23298),NumberSequenceKeypoint.new(0.0961229,28.7684,6.23298),NumberSequenceKeypoint.new(0.124088,28.1815,6.23298),NumberSequenceKeypoint.new(0.155079,27.6057,6.23298),NumberSequenceKeypoint.new(0.190419,27.0482,6.23298),NumberSequenceKeypoint.new(0.231914,26.5221,6.23298),NumberSequenceKeypoint.new(0.281563,26.0497,6.23298),NumberSequenceKeypoint.new(0.340388,25.6604,6.23298),NumberSequenceKeypoint.new(0.406988,25.3743,6.23298),NumberSequenceKeypoint.new(0.478301,25.185,6.23298),NumberSequenceKeypoint.new(0.551797,25.0685,6.23298),NumberSequenceKeypoint.new(0.626155,25.0003,6.23298),NumberSequenceKeypoint.new(0.700822,24.9625,6.23298),NumberSequenceKeypoint.new(1,24.9319,6.23298)}),["Speed"]=NumberRange.new(38.7019,270.913),["SpreadAngle"]=Vector2.new(0,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.8625,0),NumberSequenceKeypoint.new(0.169719,0.2625,0.238558),NumberSequenceKeypoint.new(0.410256,-0.0375001,0.224667),NumberSequenceKeypoint.new(1,-0.15,0)}),["Texture"]="rbxassetid://11799788138",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2,0),NumberSequenceKeypoint.new(0.0233633,0.270425,0),NumberSequenceKeypoint.new(0.0534873,0.337775,0),NumberSequenceKeypoint.new(0.0887987,0.402096,0),NumberSequenceKeypoint.new(0.128267,0.463509,0),NumberSequenceKeypoint.new(0.171199,0.522122,0),NumberSequenceKeypoint.new(0.217117,0.578008,0),NumberSequenceKeypoint.new(0.265677,0.631194,0),NumberSequenceKeypoint.new(0.316638,0.681666,0),NumberSequenceKeypoint.new(0.36982,0.729361,0),NumberSequenceKeypoint.new(0.425088,0.774172,0),NumberSequenceKeypoint.new(0.482344,0.815939,0),NumberSequenceKeypoint.new(0.541503,0.854449,0),NumberSequenceKeypoint.new(0.602495,0.889425,0),NumberSequenceKeypoint.new(0.665242,0.920523,0),NumberSequenceKeypoint.new(0.729649,0.947319,0),NumberSequenceKeypoint.new(0.795582,0.9693,0),NumberSequenceKeypoint.new(0.862841,0.985869,0),NumberSequenceKeypoint.new(0.931127,0.996345,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.sPECSS.Cartoon AOE",occurrence=1,properties={["Acceleration"]=Vector3.new(0,-25.000003814697266,0),["Brightness"]=1,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.0980392,0.0980392,0.0980392)),ColorSequenceKeypoint.new(1,Color3.new(0.0980392,0.0980392,0.0980392))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Back,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(2,3),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,8.52564,4.87179),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(100,275),["SpreadAngle"]=Vector2.new(80,80),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://120553932796626",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2,0),NumberSequenceKeypoint.new(0.0233633,0.270425,0),NumberSequenceKeypoint.new(0.0534873,0.337775,0),NumberSequenceKeypoint.new(0.0887987,0.402096,0),NumberSequenceKeypoint.new(0.128267,0.463509,0),NumberSequenceKeypoint.new(0.171199,0.522122,0),NumberSequenceKeypoint.new(0.217117,0.578008,0),NumberSequenceKeypoint.new(0.265677,0.631194,0),NumberSequenceKeypoint.new(0.316638,0.681666,0),NumberSequenceKeypoint.new(0.36982,0.729361,0),NumberSequenceKeypoint.new(0.425088,0.774172,0),NumberSequenceKeypoint.new(0.482344,0.815939,0),NumberSequenceKeypoint.new(0.541503,0.854449,0),NumberSequenceKeypoint.new(0.602495,0.889425,0),NumberSequenceKeypoint.new(0.665242,0.920523,0),NumberSequenceKeypoint.new(0.729649,0.947319,0),NumberSequenceKeypoint.new(0.795582,0.9693,0),NumberSequenceKeypoint.new(0.862841,0.985869,0),NumberSequenceKeypoint.new(0.931127,0.996345,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.sPECSS.fog debris 2",occurrence=1,properties={["Acceleration"]=Vector3.new(0,-25.000003814697266,0),["Brightness"]=0.10000000149011612,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Back,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(2,3),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,8.52564,4.87179),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(100,275),["SpreadAngle"]=Vector2.new(80,80),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://91576474072579",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2,0),NumberSequenceKeypoint.new(0.0233633,0.270425,0),NumberSequenceKeypoint.new(0.0534873,0.337775,0),NumberSequenceKeypoint.new(0.0887987,0.402096,0),NumberSequenceKeypoint.new(0.128267,0.463509,0),NumberSequenceKeypoint.new(0.171199,0.522122,0),NumberSequenceKeypoint.new(0.217117,0.578008,0),NumberSequenceKeypoint.new(0.265677,0.631194,0),NumberSequenceKeypoint.new(0.316638,0.681666,0),NumberSequenceKeypoint.new(0.36982,0.729361,0),NumberSequenceKeypoint.new(0.425088,0.774172,0),NumberSequenceKeypoint.new(0.482344,0.815939,0),NumberSequenceKeypoint.new(0.541503,0.854449,0),NumberSequenceKeypoint.new(0.602495,0.889425,0),NumberSequenceKeypoint.new(0.665242,0.920523,0),NumberSequenceKeypoint.new(0.729649,0.947319,0),NumberSequenceKeypoint.new(0.795582,0.9693,0),NumberSequenceKeypoint.new(0.862841,0.985869,0),NumberSequenceKeypoint.new(0.931127,0.996345,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Attachment.Impact351",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.10000000149011612,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.6,0.6),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,21.2798),NumberSequenceKeypoint.new(0.0103585,8.08057,21.2798),NumberSequenceKeypoint.new(0.0239955,16.0969,21.2798),NumberSequenceKeypoint.new(0.0416386,24.0097,21.2798),NumberSequenceKeypoint.new(0.0641421,31.7588,21.2798),NumberSequenceKeypoint.new(0.0924373,39.2542,21.2798),NumberSequenceKeypoint.new(0.127384,46.3714,21.2798),NumberSequenceKeypoint.new(0.169508,52.9592,21.2798),NumberSequenceKeypoint.new(0.218713,58.8691,21.2798),NumberSequenceKeypoint.new(0.274195,64.0008,21.2798),NumberSequenceKeypoint.new(0.334671,68.3337,21.2798),NumberSequenceKeypoint.new(0.398782,71.9205,21.2798),NumberSequenceKeypoint.new(0.465386,74.8564,21.2798),NumberSequenceKeypoint.new(0.533639,77.2481,21.2798),NumberSequenceKeypoint.new(0.602968,79.195,21.2798),NumberSequenceKeypoint.new(0.672997,80.7822,21.2798),NumberSequenceKeypoint.new(0.743483,82.0794,21.2798),NumberSequenceKeypoint.new(0.814268,83.1428,21.2798),NumberSequenceKeypoint.new(0.885251,84.0175,21.2798),NumberSequenceKeypoint.new(1,84.7394,21.2798)}),["Speed"]=NumberRange.new(0.00451236,0.00451236),["SpreadAngle"]=Vector2.new(10,10),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://15846202888",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(0.00510143,0.0960832,0),NumberSequenceKeypoint.new(0.0155656,0.191372,0),NumberSequenceKeypoint.new(0.0320647,0.285099,0),NumberSequenceKeypoint.new(0.0552105,0.376242,0),NumberSequenceKeypoint.new(0.0854385,0.463551,0),NumberSequenceKeypoint.new(0.122876,0.545652,0),NumberSequenceKeypoint.new(0.167247,0.621253,0),NumberSequenceKeypoint.new(0.217893,0.689366,0),NumberSequenceKeypoint.new(0.273875,0.749472,0),NumberSequenceKeypoint.new(0.334162,0.801534,0),NumberSequenceKeypoint.new(0.397772,0.845898,0),NumberSequenceKeypoint.new(0.463866,0.883142,0),NumberSequenceKeypoint.new(0.531776,0.91395,0),NumberSequenceKeypoint.new(0.600985,0.939011,0),NumberSequenceKeypoint.new(0.671109,0.958974,0),NumberSequenceKeypoint.new(0.741861,0.974426,0),NumberSequenceKeypoint.new(0.813036,0.98588,0),NumberSequenceKeypoint.new(0.884477,0.993782,0),NumberSequenceKeypoint.new(1,0.998518,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Attachment.Impact347",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.10000000149011612,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(1.2,1.4),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,7.99391),NumberSequenceKeypoint.new(0.0103585,6.07105,7.99391),NumberSequenceKeypoint.new(0.0239955,12.0938,7.99391),NumberSequenceKeypoint.new(0.0416386,18.0389,7.99391),NumberSequenceKeypoint.new(0.0641421,23.8609,7.99391),NumberSequenceKeypoint.new(0.0924373,29.4922,7.99391),NumberSequenceKeypoint.new(0.127384,34.8395,7.99391),NumberSequenceKeypoint.new(0.169508,39.789,7.99391),NumberSequenceKeypoint.new(0.218713,44.2292,7.99391),NumberSequenceKeypoint.new(0.274195,48.0848,7.99391),NumberSequenceKeypoint.new(0.334671,51.3401,7.99391),NumberSequenceKeypoint.new(0.398782,54.0349,7.99391),NumberSequenceKeypoint.new(0.465386,56.2407,7.99391),NumberSequenceKeypoint.new(0.533639,58.0376,7.99391),NumberSequenceKeypoint.new(0.602968,59.5004,7.99391),NumberSequenceKeypoint.new(0.672997,60.6928,7.99391),NumberSequenceKeypoint.new(0.743483,61.6675,7.99391),NumberSequenceKeypoint.new(0.814268,62.4664,7.99391),NumberSequenceKeypoint.new(0.885251,63.1235,7.99391),NumberSequenceKeypoint.new(1,63.6659,7.99391)}),["Speed"]=NumberRange.new(0.00451236,0.00451236),["SpreadAngle"]=Vector2.new(10,10),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://12937922496",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2,0),NumberSequenceKeypoint.new(0.0459003,0.354597,0),NumberSequenceKeypoint.new(0.0961229,0.507593,0),NumberSequenceKeypoint.new(0.124088,0.582916,0),NumberSequenceKeypoint.new(0.155079,0.656825,0),NumberSequenceKeypoint.new(0.190419,0.728383,0),NumberSequenceKeypoint.new(0.231914,0.795906,0),NumberSequenceKeypoint.new(0.281563,0.856536,0),NumberSequenceKeypoint.new(0.340388,0.906499,0),NumberSequenceKeypoint.new(0.406988,0.943223,0),NumberSequenceKeypoint.new(0.478301,0.967518,0),NumberSequenceKeypoint.new(0.551797,0.982477,0),NumberSequenceKeypoint.new(0.626155,0.991229,0),NumberSequenceKeypoint.new(0.700822,0.996072,0),NumberSequenceKeypoint.new(0.850389,0.999613,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Attachment.Ground9",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=15,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.85098,0.14902,0.901961)),ColorSequenceKeypoint.new(1,Color3.new(0.85098,0.14902,0.901961))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(2,2),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,8.6857),NumberSequenceKeypoint.new(0.0125563,6.01247,8.6857),NumberSequenceKeypoint.new(0.0282318,11.9747,8.6857),NumberSequenceKeypoint.new(0.0477373,17.8591,8.6857),NumberSequenceKeypoint.new(0.0719154,23.6237,8.6857),NumberSequenceKeypoint.new(0.101694,29.2063,8.6857),NumberSequenceKeypoint.new(0.137969,34.5198,8.6857),NumberSequenceKeypoint.new(0.181381,39.4544,8.6857),NumberSequenceKeypoint.new(0.232015,43.8949,8.6857),NumberSequenceKeypoint.new(0.289257,47.7507,8.6857),NumberSequenceKeypoint.new(0.351913,50.9839,8.6857),NumberSequenceKeypoint.new(0.418594,53.6145,8.6857),NumberSequenceKeypoint.new(0.48805,55.702,8.6857),NumberSequenceKeypoint.new(0.559322,57.3227,8.6857),NumberSequenceKeypoint.new(0.631739,58.5518,8.6857),NumberSequenceKeypoint.new(0.70486,59.4561,8.6857),NumberSequenceKeypoint.new(0.778397,60.0916,8.6857),NumberSequenceKeypoint.new(0.852169,60.504,8.6857),NumberSequenceKeypoint.new(0.92606,60.7301,8.6857),NumberSequenceKeypoint.new(1,60.7998,8.6857)}),["Speed"]=NumberRange.new(0.00490285,0.00490285),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://99257520037104",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5,0),NumberSequenceKeypoint.new(0.0105052,0.549552,0),NumberSequenceKeypoint.new(0.0243512,0.598721,0),NumberSequenceKeypoint.new(0.0427394,0.647196,0),NumberSequenceKeypoint.new(0.0668089,0.694504,0),NumberSequenceKeypoint.new(0.0975439,0.739993,0),NumberSequenceKeypoint.new(0.13559,0.782854,0),NumberSequenceKeypoint.new(0.181059,0.82224,0),NumberSequenceKeypoint.new(0.233449,0.857446,0),NumberSequenceKeypoint.new(0.29176,0.888072,0),NumberSequenceKeypoint.new(0.354767,0.914076,0),NumberSequenceKeypoint.new(0.421282,0.935699,0),NumberSequenceKeypoint.new(0.490308,0.953343,0),NumberSequenceKeypoint.new(0.561076,0.967467,0),NumberSequenceKeypoint.new(0.633026,0.978518,0),NumberSequenceKeypoint.new(0.705756,0.986901,0),NumberSequenceKeypoint.new(0.778988,0.992965,0),NumberSequenceKeypoint.new(0.852522,0.997008,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Attachment.Circle73",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=1,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.412794,0.412794,0.412794)),ColorSequenceKeypoint.new(1,Color3.new(0.412794,0.412794,0.412794))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(1,2),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-500,500),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,22.2419),NumberSequenceKeypoint.new(0.00969257,8.34384,22.2419),NumberSequenceKeypoint.new(0.023054,16.6143,22.2419),NumberSequenceKeypoint.new(0.0411518,24.7541,22.2419),NumberSequenceKeypoint.new(0.0651052,32.6735,22.2419),NumberSequenceKeypoint.new(0.0958768,40.2472,22.2419),NumberSequenceKeypoint.new(0.13398,47.3271,22.2419),NumberSequenceKeypoint.new(0.179243,53.7761,22.2419),NumberSequenceKeypoint.new(0.230817,59.5084,22.2419),NumberSequenceKeypoint.new(0.28748,64.5089,22.2419),NumberSequenceKeypoint.new(0.347982,68.8205,22.2419),NumberSequenceKeypoint.new(0.411271,72.5181,22.2419),NumberSequenceKeypoint.new(0.476546,75.6854,22.2419),NumberSequenceKeypoint.new(0.543234,78.4011,22.2419),NumberSequenceKeypoint.new(0.61093,80.7341,22.2419),NumberSequenceKeypoint.new(0.679351,82.7424,22.2419),NumberSequenceKeypoint.new(0.748301,84.4737,22.2419),NumberSequenceKeypoint.new(0.817639,85.9675,22.2419),NumberSequenceKeypoint.new(0.887266,87.2559,22.2419),NumberSequenceKeypoint.new(1,88.3658,22.2419)}),["Speed"]=NumberRange.new(0.00545102,0.00545102),["SpreadAngle"]=Vector2.new(15,15),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://15206623459",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5875,0),NumberSequenceKeypoint.new(0.229523,0.75625,0),NumberSequenceKeypoint.new(0.60036,0.925,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Attachment.Impact347",occurrence=2,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(1,2),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=2,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,7.99391),NumberSequenceKeypoint.new(0.0103585,6.07105,7.99391),NumberSequenceKeypoint.new(0.0239955,12.0938,7.99391),NumberSequenceKeypoint.new(0.0416386,18.0389,7.99391),NumberSequenceKeypoint.new(0.0641421,23.8609,7.99391),NumberSequenceKeypoint.new(0.0924373,29.4922,7.99391),NumberSequenceKeypoint.new(0.127384,34.8395,7.99391),NumberSequenceKeypoint.new(0.169508,39.789,7.99391),NumberSequenceKeypoint.new(0.218713,44.2292,7.99391),NumberSequenceKeypoint.new(0.274195,48.0848,7.99391),NumberSequenceKeypoint.new(0.334671,51.3401,7.99391),NumberSequenceKeypoint.new(0.398782,54.0349,7.99391),NumberSequenceKeypoint.new(0.465386,56.2407,7.99391),NumberSequenceKeypoint.new(0.533639,58.0376,7.99391),NumberSequenceKeypoint.new(0.602968,59.5004,7.99391),NumberSequenceKeypoint.new(0.672997,60.6928,7.99391),NumberSequenceKeypoint.new(0.743483,61.6675,7.99391),NumberSequenceKeypoint.new(0.814268,62.4664,7.99391),NumberSequenceKeypoint.new(0.885251,63.1235,7.99391),NumberSequenceKeypoint.new(1,63.6659,7.99391)}),["Speed"]=NumberRange.new(0.00451236,0.00451236),["SpreadAngle"]=Vector2.new(10,10),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://12937922496",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5,0),NumberSequenceKeypoint.new(0.0459003,0.596623,0),NumberSequenceKeypoint.new(0.0961229,0.692245,0),NumberSequenceKeypoint.new(0.124088,0.739322,0),NumberSequenceKeypoint.new(0.155079,0.785515,0),NumberSequenceKeypoint.new(0.190419,0.830239,0),NumberSequenceKeypoint.new(0.231914,0.872441,0),NumberSequenceKeypoint.new(0.281563,0.910335,0),NumberSequenceKeypoint.new(0.340388,0.941562,0),NumberSequenceKeypoint.new(0.406988,0.964514,0),NumberSequenceKeypoint.new(0.478301,0.979699,0),NumberSequenceKeypoint.new(0.551797,0.989048,0),NumberSequenceKeypoint.new(0.626155,0.994518,0),NumberSequenceKeypoint.new(0.700822,0.997545,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Attachment.Impact15",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.10000000149011612,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.8,1),["LightEmission"]=1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,7.99391),NumberSequenceKeypoint.new(0.0125563,5.5336,7.99391),NumberSequenceKeypoint.new(0.0282318,11.0209,7.99391),NumberSequenceKeypoint.new(0.0477373,16.4367,7.99391),NumberSequenceKeypoint.new(0.0719154,21.7422,7.99391),NumberSequenceKeypoint.new(0.101694,26.8802,7.99391),NumberSequenceKeypoint.new(0.137969,31.7704,7.99391),NumberSequenceKeypoint.new(0.181381,36.312,7.99391),NumberSequenceKeypoint.new(0.232015,40.3988,7.99391),NumberSequenceKeypoint.new(0.289257,43.9475,7.99391),NumberSequenceKeypoint.new(0.351913,46.9232,7.99391),NumberSequenceKeypoint.new(0.418594,49.3443,7.99391),NumberSequenceKeypoint.new(0.48805,51.2656,7.99391),NumberSequenceKeypoint.new(0.559322,52.7572,7.99391),NumberSequenceKeypoint.new(0.631739,53.8884,7.99391),NumberSequenceKeypoint.new(0.70486,54.7206,7.99391),NumberSequenceKeypoint.new(0.778397,55.3055,7.99391),NumberSequenceKeypoint.new(0.852169,55.6851,7.99391),NumberSequenceKeypoint.new(0.92606,55.8932,7.99391),NumberSequenceKeypoint.new(1,55.9574,7.99391)}),["Speed"]=NumberRange.new(0.00451236,0.00451236),["SpreadAngle"]=Vector2.new(10,10),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16892231149",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2,0),NumberSequenceKeypoint.new(0.0195398,0.273943,0),NumberSequenceKeypoint.new(0.0436436,0.34628,0),NumberSequenceKeypoint.new(0.0723284,0.416618,0),NumberSequenceKeypoint.new(0.105581,0.484544,0),NumberSequenceKeypoint.new(0.143344,0.54963,0),NumberSequenceKeypoint.new(0.185514,0.611442,0),NumberSequenceKeypoint.new(0.231927,0.669559,0),NumberSequenceKeypoint.new(0.282361,0.723583,0),NumberSequenceKeypoint.new(0.336529,0.773163,0),NumberSequenceKeypoint.new(0.394091,0.818008,0),NumberSequenceKeypoint.new(0.454663,0.857908,0),NumberSequenceKeypoint.new(0.517836,0.892734,0),NumberSequenceKeypoint.new(0.583188,0.922449,0),NumberSequenceKeypoint.new(0.650305,0.947095,0),NumberSequenceKeypoint.new(0.718799,0.966786,0),NumberSequenceKeypoint.new(0.78831,0.981696,0),NumberSequenceKeypoint.new(0.858523,0.992037,0),NumberSequenceKeypoint.new(0.929164,0.998053,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Attachment.Ground29",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.152941,0.152941,0.152941)),ColorSequenceKeypoint.new(1,Color3.new(0.152941,0.152941,0.152941))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(5,5),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,8.25721,2.7524),NumberSequenceKeypoint.new(0.0211807,20.7597,2.7524),NumberSequenceKeypoint.new(0.0345414,26.9751,2.7524),NumberSequenceKeypoint.new(0.051142,33.137,2.7524),NumberSequenceKeypoint.new(0.0726168,39.1954,2.7524),NumberSequenceKeypoint.new(0.101207,45.0497,2.7524),NumberSequenceKeypoint.new(0.139512,50.5125,2.7524),NumberSequenceKeypoint.new(0.189279,55.3064,2.7524),NumberSequenceKeypoint.new(0.249699,59.1866,2.7524),NumberSequenceKeypoint.new(0.317658,62.1131,2.7524),NumberSequenceKeypoint.new(0.389947,64.2347,2.7524),NumberSequenceKeypoint.new(0.464485,65.7499,2.7524),NumberSequenceKeypoint.new(0.540157,66.8251,2.7524),NumberSequenceKeypoint.new(0.616405,67.5813,2.7524),NumberSequenceKeypoint.new(0.692945,68.1031,2.7524),NumberSequenceKeypoint.new(0.769634,68.45,2.7524),NumberSequenceKeypoint.new(0.846395,68.6643,2.7524),NumberSequenceKeypoint.new(0.923189,68.7767,2.7524),NumberSequenceKeypoint.new(1,68.8101,2.7524)}),["Speed"]=NumberRange.new(0.00347025,0.00347025),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://125314922601956",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Attachment.Impact553",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=15,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(0.0398671,Color3.new(0.899073,0.278188,0.846329)),ColorSequenceKeypoint.new(0.134551,Color3.new(0.34902,0.105882,0.329412)),ColorSequenceKeypoint.new(0.596345,Color3.new(0,0,0)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(4,4),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,8.25721,2.7524),NumberSequenceKeypoint.new(0.0211807,20.7597,2.7524),NumberSequenceKeypoint.new(0.0345414,26.9751,2.7524),NumberSequenceKeypoint.new(0.051142,33.137,2.7524),NumberSequenceKeypoint.new(0.0726168,39.1954,2.7524),NumberSequenceKeypoint.new(0.101207,45.0497,2.7524),NumberSequenceKeypoint.new(0.139512,50.5125,2.7524),NumberSequenceKeypoint.new(0.189279,55.3064,2.7524),NumberSequenceKeypoint.new(0.249699,59.1866,2.7524),NumberSequenceKeypoint.new(0.317658,62.1131,2.7524),NumberSequenceKeypoint.new(0.389947,64.2347,2.7524),NumberSequenceKeypoint.new(0.464485,65.7499,2.7524),NumberSequenceKeypoint.new(0.540157,66.8251,2.7524),NumberSequenceKeypoint.new(0.616405,67.5813,2.7524),NumberSequenceKeypoint.new(0.692945,68.1031,2.7524),NumberSequenceKeypoint.new(0.769634,68.45,2.7524),NumberSequenceKeypoint.new(0.846395,68.6643,2.7524),NumberSequenceKeypoint.new(0.923189,68.7767,2.7524),NumberSequenceKeypoint.new(1,68.8101,2.7524)}),["Speed"]=NumberRange.new(0.00347025,0.00347025),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://18230541777",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Ground.Attachment.Impact487",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=0.5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.152941,0.152941,0.152941)),ColorSequenceKeypoint.new(1,Color3.new(0.152941,0.152941,0.152941))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(5,5),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.VelocityPerpendicular,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,8.25721,2.7524),NumberSequenceKeypoint.new(0.0211807,20.7597,2.7524),NumberSequenceKeypoint.new(0.0345414,26.9751,2.7524),NumberSequenceKeypoint.new(0.051142,33.137,2.7524),NumberSequenceKeypoint.new(0.0726168,39.1954,2.7524),NumberSequenceKeypoint.new(0.101207,45.0497,2.7524),NumberSequenceKeypoint.new(0.139512,50.5125,2.7524),NumberSequenceKeypoint.new(0.189279,55.3064,2.7524),NumberSequenceKeypoint.new(0.249699,59.1866,2.7524),NumberSequenceKeypoint.new(0.317658,62.1131,2.7524),NumberSequenceKeypoint.new(0.389947,64.2347,2.7524),NumberSequenceKeypoint.new(0.464485,65.7499,2.7524),NumberSequenceKeypoint.new(0.540157,66.8251,2.7524),NumberSequenceKeypoint.new(0.616405,67.5813,2.7524),NumberSequenceKeypoint.new(0.692945,68.1031,2.7524),NumberSequenceKeypoint.new(0.769634,68.45,2.7524),NumberSequenceKeypoint.new(0.846395,68.6643,2.7524),NumberSequenceKeypoint.new(0.923189,68.7767,2.7524),NumberSequenceKeypoint.new(1,68.8101,2.7524)}),["Speed"]=NumberRange.new(0.00347025,0.00347025),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://129551943516119",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Realistic Fire Kit",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.239203,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.576412,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.858804,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=2,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(1.4,1.4),["LightEmission"]=0.699999988079071,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=75,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,11.5206),NumberSequenceKeypoint.new(0.024324,4.17093,11.5206),NumberSequenceKeypoint.new(0.0506233,8.2955,11.5206),NumberSequenceKeypoint.new(0.0793971,12.3561,11.5206),NumberSequenceKeypoint.new(0.111148,16.3305,11.5206),NumberSequenceKeypoint.new(0.146363,20.1911,11.5206),NumberSequenceKeypoint.new(0.185493,23.9041,11.5206),NumberSequenceKeypoint.new(0.228895,27.4299,11.5206),NumberSequenceKeypoint.new(0.276791,30.7248,11.5206),NumberSequenceKeypoint.new(0.329195,33.7446,11.5206),NumberSequenceKeypoint.new(0.385894,36.4502,11.5206),NumberSequenceKeypoint.new(0.446458,38.8131,11.5206),NumberSequenceKeypoint.new(0.51029,40.819,11.5206),NumberSequenceKeypoint.new(0.576731,42.469,11.5206),NumberSequenceKeypoint.new(0.645131,43.7768,11.5206),NumberSequenceKeypoint.new(0.714918,44.7653,11.5206),NumberSequenceKeypoint.new(0.785621,45.4618,11.5206),NumberSequenceKeypoint.new(0.856874,45.8951,11.5206),NumberSequenceKeypoint.new(0.928399,46.0933,11.5206),NumberSequenceKeypoint.new(1,46.0823,11.5206)}),["Speed"]=NumberRange.new(0.00722599,0.00722599),["SpreadAngle"]=Vector2.new(0,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0.6375,0)}),["Texture"]="rbxassetid://18369727963",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Fire36",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.167774,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.436877,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.719269,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=2,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.6,1),["LightEmission"]=0.699999988079071,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=75,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,7.68038),NumberSequenceKeypoint.new(0.024324,4.5185,7.68038),NumberSequenceKeypoint.new(0.0506233,8.98679,7.68038),NumberSequenceKeypoint.new(0.0793971,13.3858,7.68038),NumberSequenceKeypoint.new(0.111148,17.6914,7.68038),NumberSequenceKeypoint.new(0.146363,21.8737,7.68038),NumberSequenceKeypoint.new(0.185493,25.8961,7.68038),NumberSequenceKeypoint.new(0.228895,29.7157,7.68038),NumberSequenceKeypoint.new(0.276791,33.2851,7.68038),NumberSequenceKeypoint.new(0.329195,36.5566,7.68038),NumberSequenceKeypoint.new(0.385894,39.4877,7.68038),NumberSequenceKeypoint.new(0.446458,42.0475,7.68038),NumberSequenceKeypoint.new(0.51029,44.2206,7.68038),NumberSequenceKeypoint.new(0.576731,46.0081,7.68038),NumberSequenceKeypoint.new(0.645131,47.4249,7.68038),NumberSequenceKeypoint.new(0.714918,48.4957,7.68038),NumberSequenceKeypoint.new(0.785621,49.2503,7.68038),NumberSequenceKeypoint.new(0.856874,49.7198,7.68038),NumberSequenceKeypoint.new(0.928399,49.9345,7.68038),NumberSequenceKeypoint.new(1,49.9225,7.68038)}),["Speed"]=NumberRange.new(0.0722599,0.0722599),["SpreadAngle"]=Vector2.new(0,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0.6,0)}),["Texture"]="rbxassetid://16860267787",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Fire2",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=3,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.167774,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.436877,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.719269,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.8,1.3),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=75,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,7.68038),NumberSequenceKeypoint.new(0.0729477,5.94435,7.68038),NumberSequenceKeypoint.new(0.111544,8.84447,7.68038),NumberSequenceKeypoint.new(0.151855,11.6817,7.68038),NumberSequenceKeypoint.new(0.19406,14.4445,7.68038),NumberSequenceKeypoint.new(0.23831,17.1207,7.68038),NumberSequenceKeypoint.new(0.284725,19.6973,7.68038),NumberSequenceKeypoint.new(0.333389,22.1608,7.68038),NumberSequenceKeypoint.new(0.384352,24.4971,7.68038),NumberSequenceKeypoint.new(0.437619,26.6921,7.68038),NumberSequenceKeypoint.new(0.493151,28.7321,7.68038),NumberSequenceKeypoint.new(0.550859,30.6043,7.68038),NumberSequenceKeypoint.new(0.610604,32.2977,7.68038),NumberSequenceKeypoint.new(0.672208,33.8031,7.68038),NumberSequenceKeypoint.new(0.735456,35.1147,7.68038),NumberSequenceKeypoint.new(0.800107,36.229,7.68038),NumberSequenceKeypoint.new(0.865913,37.1461,7.68038),NumberSequenceKeypoint.new(0.932621,37.8687,7.68038),NumberSequenceKeypoint.new(1,38.4019,7.68038)}),["Speed"]=NumberRange.new(153.608,153.608),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16843151641",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(0.0844572,0.141698,0),NumberSequenceKeypoint.new(0.172009,0.279958,0),NumberSequenceKeypoint.new(0.263168,0.413934,0),NumberSequenceKeypoint.new(0.310297,0.478963,0),NumberSequenceKeypoint.new(0.358584,0.542436,0),NumberSequenceKeypoint.new(0.408139,0.60412,0),NumberSequenceKeypoint.new(0.459084,0.663722,0),NumberSequenceKeypoint.new(0.511554,0.720881,0),NumberSequenceKeypoint.new(0.5657,0.775141,0),NumberSequenceKeypoint.new(0.621679,0.825924,0),NumberSequenceKeypoint.new(0.679649,0.872492,0),NumberSequenceKeypoint.new(0.739743,0.913899,0),NumberSequenceKeypoint.new(0.802031,0.948945,0),NumberSequenceKeypoint.new(0.866443,0.976145,0),NumberSequenceKeypoint.new(0.932665,0.993763,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Fire23",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.167774,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.436877,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.719269,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.6,1),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,7.68038),NumberSequenceKeypoint.new(0.0614576,5.29834,7.68038),NumberSequenceKeypoint.new(0.1264,10.5248,7.68038),NumberSequenceKeypoint.new(0.161572,13.0779,7.68038),NumberSequenceKeypoint.new(0.199453,15.5638,7.68038),NumberSequenceKeypoint.new(0.240783,17.9539,7.68038),NumberSequenceKeypoint.new(0.286244,20.2122,7.68038),NumberSequenceKeypoint.new(0.336322,22.297,7.68038),NumberSequenceKeypoint.new(0.391151,24.1665,7.68038),NumberSequenceKeypoint.new(0.450425,25.7883,7.68038),NumberSequenceKeypoint.new(0.513466,27.1467,7.68038),NumberSequenceKeypoint.new(0.579414,28.2454,7.68038),NumberSequenceKeypoint.new(0.647433,29.1031,7.68038),NumberSequenceKeypoint.new(0.71683,29.7467,7.68038),NumberSequenceKeypoint.new(0.787089,30.2049,7.68038),NumberSequenceKeypoint.new(0.857849,30.5048,7.68038),NumberSequenceKeypoint.new(0.928872,30.6703,7.68038),NumberSequenceKeypoint.new(1,30.7215,7.68038)}),["Speed"]=NumberRange.new(19.2009,192.009),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16848303531",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(0.0844572,0.141698,0),NumberSequenceKeypoint.new(0.172009,0.279958,0),NumberSequenceKeypoint.new(0.263168,0.413934,0),NumberSequenceKeypoint.new(0.310297,0.478963,0),NumberSequenceKeypoint.new(0.358584,0.542436,0),NumberSequenceKeypoint.new(0.408139,0.60412,0),NumberSequenceKeypoint.new(0.459084,0.663722,0),NumberSequenceKeypoint.new(0.511554,0.720881,0),NumberSequenceKeypoint.new(0.5657,0.775141,0),NumberSequenceKeypoint.new(0.621679,0.825924,0),NumberSequenceKeypoint.new(0.679649,0.872492,0),NumberSequenceKeypoint.new(0.739743,0.913899,0),NumberSequenceKeypoint.new(0.802031,0.948945,0),NumberSequenceKeypoint.new(0.866443,0.976145,0),NumberSequenceKeypoint.new(0.932665,0.993763,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Low Res Burst",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.167774,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.436877,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.719269,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Back,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.6,1),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=100,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,4.89255),NumberSequenceKeypoint.new(0.0456776,5.64634,4.89255),NumberSequenceKeypoint.new(0.0956305,11.2357,4.89255),NumberSequenceKeypoint.new(0.123426,13.9887,4.89255),NumberSequenceKeypoint.new(0.154206,16.6916,4.89255),NumberSequenceKeypoint.new(0.189278,19.3114,4.89255),NumberSequenceKeypoint.new(0.230438,21.7885,4.89255),NumberSequenceKeypoint.new(0.27972,24.0209,4.89255),NumberSequenceKeypoint.new(0.338262,25.8702,4.89255),NumberSequenceKeypoint.new(0.404789,27.2367,4.89255),NumberSequenceKeypoint.new(0.476231,28.1434,4.89255),NumberSequenceKeypoint.new(0.549968,28.7019,4.89255),NumberSequenceKeypoint.new(0.624613,29.0285,4.89255),NumberSequenceKeypoint.new(0.699584,29.209,4.89255),NumberSequenceKeypoint.new(0.77466,29.3008,4.89255),NumberSequenceKeypoint.new(0.849767,29.3409,4.89255),NumberSequenceKeypoint.new(0.924881,29.3537,4.89255),NumberSequenceKeypoint.new(1,29.3553,4.89255)}),["Speed"]=NumberRange.new(244.627,244.627),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1125,0.15),NumberSequenceKeypoint.new(1,0.1875,0.1125)}),["Texture"]="rbxassetid://13486412595",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(0.419954,0,0),NumberSequenceKeypoint.new(0.605761,0.94375,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Fire1",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=2,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.167774,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.436877,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.719269,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Back,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.8,1.3),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=100,["RotSpeed"]=NumberRange.new(-50,50),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,3.84019),NumberSequenceKeypoint.new(0.0456776,3.6932,3.84019),NumberSequenceKeypoint.new(0.0956305,7.34912,3.84019),NumberSequenceKeypoint.new(0.123426,9.14984,3.84019),NumberSequenceKeypoint.new(0.154206,10.9178,3.84019),NumberSequenceKeypoint.new(0.189278,12.6314,3.84019),NumberSequenceKeypoint.new(0.230438,14.2516,3.84019),NumberSequenceKeypoint.new(0.27972,15.7118,3.84019),NumberSequenceKeypoint.new(0.338262,16.9214,3.84019),NumberSequenceKeypoint.new(0.404789,17.8152,3.84019),NumberSequenceKeypoint.new(0.476231,18.4082,3.84019),NumberSequenceKeypoint.new(0.549968,18.7736,3.84019),NumberSequenceKeypoint.new(0.624613,18.9872,3.84019),NumberSequenceKeypoint.new(0.699584,19.1053,3.84019),NumberSequenceKeypoint.new(0.77466,19.1653,3.84019),NumberSequenceKeypoint.new(0.849767,19.1915,3.84019),NumberSequenceKeypoint.new(1,19.2009,3.84019)}),["Speed"]=NumberRange.new(38.4019,268.813),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16841991986",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(0.419954,0,0),NumberSequenceKeypoint.new(0.608461,0.9375,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Fire8",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.167774,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.436877,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.719269,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=2,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.5,1.2),["LightEmission"]=0.699999988079071,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=75,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,23.0781),NumberSequenceKeypoint.new(0.0614576,9.55229,23.0781),NumberSequenceKeypoint.new(0.1264,18.9751,23.0781),NumberSequenceKeypoint.new(0.161572,23.5779,23.0781),NumberSequenceKeypoint.new(0.199453,28.0597,23.0781),NumberSequenceKeypoint.new(0.240783,32.3688,23.0781),NumberSequenceKeypoint.new(0.286244,36.4403,23.0781),NumberSequenceKeypoint.new(0.336322,40.1988,23.0781),NumberSequenceKeypoint.new(0.391151,43.5694,23.0781),NumberSequenceKeypoint.new(0.450425,46.4933,23.0781),NumberSequenceKeypoint.new(0.513466,48.9424,23.0781),NumberSequenceKeypoint.new(0.579414,50.9232,23.0781),NumberSequenceKeypoint.new(0.647433,52.4696,23.0781),NumberSequenceKeypoint.new(0.71683,53.6299,23.0781),NumberSequenceKeypoint.new(0.787089,54.4559,23.0781),NumberSequenceKeypoint.new(0.857849,54.9966,23.0781),NumberSequenceKeypoint.new(0.928872,55.2949,23.0781),NumberSequenceKeypoint.new(1,55.3873,23.0781)}),["Speed"]=NumberRange.new(0,184.624),["SpreadAngle"]=Vector2.new(0,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,1.67742,0)}),["Texture"]="rbxassetid://16845391847",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Darkening realism",occurrence=2,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.167774,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.436877,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.719269,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=3,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(30,30),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.5,1.2),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=75,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,7.68038),NumberSequenceKeypoint.new(0.0614576,3.31146,7.68038),NumberSequenceKeypoint.new(0.1264,6.57802,7.68038),NumberSequenceKeypoint.new(0.161572,8.17367,7.68038),NumberSequenceKeypoint.new(0.199453,9.72735,7.68038),NumberSequenceKeypoint.new(0.240783,11.2212,7.68038),NumberSequenceKeypoint.new(0.286244,12.6326,7.68038),NumberSequenceKeypoint.new(0.336322,13.9356,7.68038),NumberSequenceKeypoint.new(0.391151,15.1041,7.68038),NumberSequenceKeypoint.new(0.450425,16.1177,7.68038),NumberSequenceKeypoint.new(0.513466,16.9667,7.68038),NumberSequenceKeypoint.new(0.579414,17.6534,7.68038),NumberSequenceKeypoint.new(0.647433,18.1895,7.68038),NumberSequenceKeypoint.new(0.71683,18.5917,7.68038),NumberSequenceKeypoint.new(0.787089,18.878,7.68038),NumberSequenceKeypoint.new(0.857849,19.0655,7.68038),NumberSequenceKeypoint.new(0.928872,19.1689,7.68038),NumberSequenceKeypoint.new(1,19.2009,7.68038)}),["Speed"]=NumberRange.new(38.4019,153.608),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://11866794293",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Fire23",occurrence=2,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=3,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.167774,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.436877,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.719269,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.8,1.3),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=75,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,7.68038),NumberSequenceKeypoint.new(0.0844572,2.72073,7.68038),NumberSequenceKeypoint.new(0.172009,5.37545,7.68038),NumberSequenceKeypoint.new(0.263168,7.94793,7.68038),NumberSequenceKeypoint.new(0.310297,9.19653,7.68038),NumberSequenceKeypoint.new(0.358584,10.4153,7.68038),NumberSequenceKeypoint.new(0.408139,11.5997,7.68038),NumberSequenceKeypoint.new(0.459084,12.7441,7.68038),NumberSequenceKeypoint.new(0.511554,13.8416,7.68038),NumberSequenceKeypoint.new(0.5657,14.8834,7.68038),NumberSequenceKeypoint.new(0.621679,15.8585,7.68038),NumberSequenceKeypoint.new(0.679649,16.7527,7.68038),NumberSequenceKeypoint.new(0.739743,17.5477,7.68038),NumberSequenceKeypoint.new(0.802031,18.2206,7.68038),NumberSequenceKeypoint.new(0.866443,18.7429,7.68038),NumberSequenceKeypoint.new(0.932665,19.0812,7.68038),NumberSequenceKeypoint.new(1,19.2009,7.68038)}),["Speed"]=NumberRange.new(153.608,153.608),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16848303531",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(0.0844572,0.141698,0),NumberSequenceKeypoint.new(0.172009,0.279958,0),NumberSequenceKeypoint.new(0.263168,0.413934,0),NumberSequenceKeypoint.new(0.310297,0.478963,0),NumberSequenceKeypoint.new(0.358584,0.542436,0),NumberSequenceKeypoint.new(0.408139,0.60412,0),NumberSequenceKeypoint.new(0.459084,0.663722,0),NumberSequenceKeypoint.new(0.511554,0.720881,0),NumberSequenceKeypoint.new(0.5657,0.775141,0),NumberSequenceKeypoint.new(0.621679,0.825924,0),NumberSequenceKeypoint.new(0.679649,0.872492,0),NumberSequenceKeypoint.new(0.739743,0.913899,0),NumberSequenceKeypoint.new(0.802031,0.948945,0),NumberSequenceKeypoint.new(0.866443,0.976145,0),NumberSequenceKeypoint.new(0.932665,0.993763,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Fire3",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.167774,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.436877,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.719269,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=5,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(1,1),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.8,1.3),["LightEmission"]=0.5,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=75,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,7.68038),NumberSequenceKeypoint.new(0.0729477,5.94435,7.68038),NumberSequenceKeypoint.new(0.111544,8.84447,7.68038),NumberSequenceKeypoint.new(0.151855,11.6817,7.68038),NumberSequenceKeypoint.new(0.19406,14.4445,7.68038),NumberSequenceKeypoint.new(0.23831,17.1207,7.68038),NumberSequenceKeypoint.new(0.284725,19.6973,7.68038),NumberSequenceKeypoint.new(0.333389,22.1608,7.68038),NumberSequenceKeypoint.new(0.384352,24.4971,7.68038),NumberSequenceKeypoint.new(0.437619,26.6921,7.68038),NumberSequenceKeypoint.new(0.493151,28.7321,7.68038),NumberSequenceKeypoint.new(0.550859,30.6043,7.68038),NumberSequenceKeypoint.new(0.610604,32.2977,7.68038),NumberSequenceKeypoint.new(0.672208,33.8031,7.68038),NumberSequenceKeypoint.new(0.735456,35.1147,7.68038),NumberSequenceKeypoint.new(0.800107,36.229,7.68038),NumberSequenceKeypoint.new(0.865913,37.1461,7.68038),NumberSequenceKeypoint.new(0.932621,37.8687,7.68038),NumberSequenceKeypoint.new(1,38.4019,7.68038)}),["Speed"]=NumberRange.new(153.608,153.608),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16843373901",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(0.168317,1,0),NumberSequenceKeypoint.new(0.374437,0,0),NumberSequenceKeypoint.new(0.705671,0.75,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Attachment.Stylized Smoke71 fading",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=25,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.321569,0.988235)),ColorSequenceKeypoint.new(0.167774,Color3.new(0.913725,0.254902,1)),ColorSequenceKeypoint.new(0.38206,Color3.new(0.509804,0.145098,0.541176)),ColorSequenceKeypoint.new(0.644518,Color3.new(0.0257732,0.00851989,0.00521952)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=3,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(1,1.5),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=75,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,19.0931,9.54655),NumberSequenceKeypoint.new(0.0105052,20.9853,9.54655),NumberSequenceKeypoint.new(0.0243512,22.8629,9.54655),NumberSequenceKeypoint.new(0.0427394,24.714,9.54655),NumberSequenceKeypoint.new(0.0668089,26.5205,9.54655),NumberSequenceKeypoint.new(0.0975439,28.2575,9.54655),NumberSequenceKeypoint.new(0.13559,29.8943,9.54655),NumberSequenceKeypoint.new(0.181059,31.3982,9.54655),NumberSequenceKeypoint.new(0.233449,32.7426,9.54655),NumberSequenceKeypoint.new(0.29176,33.9121,9.54655),NumberSequenceKeypoint.new(0.354767,34.9051,9.54655),NumberSequenceKeypoint.new(0.421282,35.7308,9.54655),NumberSequenceKeypoint.new(0.490308,36.4045,9.54655),NumberSequenceKeypoint.new(0.561076,36.9439,9.54655),NumberSequenceKeypoint.new(0.633026,37.3659,9.54655),NumberSequenceKeypoint.new(0.705756,37.686,9.54655),NumberSequenceKeypoint.new(0.778988,37.9176,9.54655),NumberSequenceKeypoint.new(0.852522,38.0719,9.54655),NumberSequenceKeypoint.new(0.926223,38.1588,9.54655),NumberSequenceKeypoint.new(1,38.1862,9.54655)}),["Speed"]=NumberRange.new(50.9646,127.412),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1125,0.1125),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16334792296",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(0.730713,0.3125,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=-1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Debris.Debris.Part.Darkening realism",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.219608,0.219608,0.219608)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=4.542159557342529,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(30,30),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid4x4,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(2,4),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,2.75611),NumberSequenceKeypoint.new(0.0081561,1.08948,2.75611),NumberSequenceKeypoint.new(0.0218356,2.16643,2.75611),NumberSequenceKeypoint.new(0.0416248,3.22183,2.75611),NumberSequenceKeypoint.new(0.0680281,4.24424,2.75611),NumberSequenceKeypoint.new(0.101359,5.2202,2.75611),NumberSequenceKeypoint.new(0.141647,6.13549,2.75611),NumberSequenceKeypoint.new(0.188576,6.97698,2.75611),NumberSequenceKeypoint.new(0.241499,7.73471,2.75611),NumberSequenceKeypoint.new(0.29955,8.40322,2.75611),NumberSequenceKeypoint.new(0.361775,8.98174,2.75611),NumberSequenceKeypoint.new(0.427263,9.47325,2.75611),NumberSequenceKeypoint.new(0.495216,9.88328,2.75611),NumberSequenceKeypoint.new(0.56498,10.2185,2.75611),NumberSequenceKeypoint.new(0.636043,10.486,2.75611),NumberSequenceKeypoint.new(0.70801,10.6926,2.75611),NumberSequenceKeypoint.new(0.780585,10.8445,2.75611),NumberSequenceKeypoint.new(0.853545,10.9472,2.75611),NumberSequenceKeypoint.new(0.926724,11.0058,2.75611),NumberSequenceKeypoint.new(1,11.0244,2.75611)}),["Speed"]=NumberRange.new(25.9104,45.3432),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://11866794293",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5,0),NumberSequenceKeypoint.new(0.0844572,0.570849,0),NumberSequenceKeypoint.new(0.172009,0.639979,0),NumberSequenceKeypoint.new(0.263168,0.706967,0),NumberSequenceKeypoint.new(0.310297,0.739481,0),NumberSequenceKeypoint.new(0.408139,0.80206,0),NumberSequenceKeypoint.new(0.459084,0.831861,0),NumberSequenceKeypoint.new(0.511554,0.86044,0),NumberSequenceKeypoint.new(0.5657,0.88757,0),NumberSequenceKeypoint.new(0.621679,0.912962,0),NumberSequenceKeypoint.new(0.679649,0.936246,0),NumberSequenceKeypoint.new(0.739743,0.95695,0),NumberSequenceKeypoint.new(0.802031,0.974473,0),NumberSequenceKeypoint.new(0.866443,0.988072,0),NumberSequenceKeypoint.new(0.932665,0.996882,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=-1}},
 {root="PrimeBombExplosion",path="Anchor.Explosion.Debris.Debris.Part.Realistic 3D Smoke",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=5,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(0.219608,0.219608,0.219608)),ColorSequenceKeypoint.new(1,Color3.new(0,0,0))}),["Drag"]=2.2710797786712646,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(30,30),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Grid8x8,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(2,4),["LightEmission"]=0,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=20,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,2.92742,2.92742),NumberSequenceKeypoint.new(0.0105052,3.3626,2.92742),NumberSequenceKeypoint.new(0.0243512,3.79442,2.92742),NumberSequenceKeypoint.new(0.0427394,4.22013,2.92742),NumberSequenceKeypoint.new(0.0668089,4.63561,2.92742),NumberSequenceKeypoint.new(0.0975439,5.03511,2.92742),NumberSequenceKeypoint.new(0.13559,5.41153,2.92742),NumberSequenceKeypoint.new(0.181059,5.75743,2.92742),NumberSequenceKeypoint.new(0.233449,6.06661,2.92742),NumberSequenceKeypoint.new(0.29176,6.33558,2.92742),NumberSequenceKeypoint.new(0.354767,6.56395,2.92742),NumberSequenceKeypoint.new(0.421282,6.75385,2.92742),NumberSequenceKeypoint.new(0.490308,6.9088,2.92742),NumberSequenceKeypoint.new(0.561076,7.03284,2.92742),NumberSequenceKeypoint.new(0.633026,7.1299,2.92742),NumberSequenceKeypoint.new(0.705756,7.20352,2.92742),NumberSequenceKeypoint.new(0.778988,7.25677,2.92742),NumberSequenceKeypoint.new(0.852522,7.29229,2.92742),NumberSequenceKeypoint.new(0.926223,7.31226,2.92742),NumberSequenceKeypoint.new(1,7.31856,2.92742)}),["Speed"]=NumberRange.new(3.2388,19.4328),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://11799788138",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3,0),NumberSequenceKeypoint.new(0.0846497,0.399409,0),NumberSequenceKeypoint.new(0.172384,0.496372,0),NumberSequenceKeypoint.new(0.263711,0.59029,0),NumberSequenceKeypoint.new(0.310915,0.635857,0),NumberSequenceKeypoint.new(0.408885,0.723514,0),NumberSequenceKeypoint.new(0.459877,0.765233,0),NumberSequenceKeypoint.new(0.512381,0.805222,0),NumberSequenceKeypoint.new(0.566542,0.843162,0),NumberSequenceKeypoint.new(0.622515,0.878647,0),NumberSequenceKeypoint.new(0.680449,0.911163,0),NumberSequenceKeypoint.new(0.74047,0.940049,0),NumberSequenceKeypoint.new(0.802643,0.964474,0),NumberSequenceKeypoint.new(0.866893,0.98341,0),NumberSequenceKeypoint.new(0.932906,0.995665,0),NumberSequenceKeypoint.new(1,1,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=-1}},
 {root="PrimeBombDeathAura",path="Head.Fire19",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.5),NumberSequenceKeypoint.new(0.0617071,0.17315,0.5),NumberSequenceKeypoint.new(0.12693,0.343893,0.5),NumberSequenceKeypoint.new(0.162264,0.427249,0.5),NumberSequenceKeypoint.new(0.200324,0.508357,0.5),NumberSequenceKeypoint.new(0.241846,0.586266,0.5),NumberSequenceKeypoint.new(0.287501,0.65978,0.5),NumberSequenceKeypoint.new(0.337754,0.727533,0.5),NumberSequenceKeypoint.new(0.392709,0.788179,0.5),NumberSequenceKeypoint.new(0.452035,0.840691,0.5),NumberSequenceKeypoint.new(0.515043,0.884609,0.5),NumberSequenceKeypoint.new(0.58088,0.920092,0.5),NumberSequenceKeypoint.new(0.648722,0.947775,0.5),NumberSequenceKeypoint.new(0.717898,0.968541,0.5),NumberSequenceKeypoint.new(0.787908,0.983325,0.5),NumberSequenceKeypoint.new(0.858403,0.993004,0.5),NumberSequenceKeypoint.new(0.929151,0.998345,0.5),NumberSequenceKeypoint.new(1,1,0.5)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16847032740",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Head.Fire6",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.579327),NumberSequenceKeypoint.new(0.0617071,0.200621,0.579327),NumberSequenceKeypoint.new(0.12693,0.398453,0.579327),NumberSequenceKeypoint.new(0.162264,0.495033,0.579327),NumberSequenceKeypoint.new(0.200324,0.58901,0.579327),NumberSequenceKeypoint.new(0.241846,0.679279,0.579327),NumberSequenceKeypoint.new(0.287501,0.764457,0.579327),NumberSequenceKeypoint.new(0.337754,0.842959,0.579327),NumberSequenceKeypoint.new(0.392709,0.913227,0.579327),NumberSequenceKeypoint.new(0.452035,0.97407,0.579327),NumberSequenceKeypoint.new(0.515043,1.02496,0.579327),NumberSequenceKeypoint.new(0.58088,1.06607,0.579327),NumberSequenceKeypoint.new(0.648722,1.09814,0.579327),NumberSequenceKeypoint.new(0.717898,1.1222,0.579327),NumberSequenceKeypoint.new(0.787908,1.13933,0.579327),NumberSequenceKeypoint.new(0.858403,1.15055,0.579327),NumberSequenceKeypoint.new(0.929151,1.15674,0.579327),NumberSequenceKeypoint.new(1,1.15865,0.579327)}),["Speed"]=NumberRange.new(0.00115865,0.00115865),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16845227778",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Head.OffCentered Spec 57",occurrence=1,properties={["Acceleration"]=Vector3.new(0,5,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.6,1.6),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=10,["RotSpeed"]=NumberRange.new(-100,100),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0.6875),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://15419161283",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Torso.Fire6",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.579327),NumberSequenceKeypoint.new(0.0617071,0.200621,0.579327),NumberSequenceKeypoint.new(0.12693,0.398453,0.579327),NumberSequenceKeypoint.new(0.162264,0.495033,0.579327),NumberSequenceKeypoint.new(0.200324,0.58901,0.579327),NumberSequenceKeypoint.new(0.241846,0.679279,0.579327),NumberSequenceKeypoint.new(0.287501,0.764457,0.579327),NumberSequenceKeypoint.new(0.337754,0.842959,0.579327),NumberSequenceKeypoint.new(0.392709,0.913227,0.579327),NumberSequenceKeypoint.new(0.452035,0.97407,0.579327),NumberSequenceKeypoint.new(0.515043,1.02496,0.579327),NumberSequenceKeypoint.new(0.58088,1.06607,0.579327),NumberSequenceKeypoint.new(0.648722,1.09814,0.579327),NumberSequenceKeypoint.new(0.717898,1.1222,0.579327),NumberSequenceKeypoint.new(0.787908,1.13933,0.579327),NumberSequenceKeypoint.new(0.858403,1.15055,0.579327),NumberSequenceKeypoint.new(0.929151,1.15674,0.579327),NumberSequenceKeypoint.new(1,1.15865,0.579327)}),["Speed"]=NumberRange.new(0.00115865,0.00115865),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16845227778",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Torso.Fire19",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.5),NumberSequenceKeypoint.new(0.0617071,0.17315,0.5),NumberSequenceKeypoint.new(0.12693,0.343893,0.5),NumberSequenceKeypoint.new(0.162264,0.427249,0.5),NumberSequenceKeypoint.new(0.200324,0.508357,0.5),NumberSequenceKeypoint.new(0.241846,0.586266,0.5),NumberSequenceKeypoint.new(0.287501,0.65978,0.5),NumberSequenceKeypoint.new(0.337754,0.727533,0.5),NumberSequenceKeypoint.new(0.392709,0.788179,0.5),NumberSequenceKeypoint.new(0.452035,0.840691,0.5),NumberSequenceKeypoint.new(0.515043,0.884609,0.5),NumberSequenceKeypoint.new(0.58088,0.920092,0.5),NumberSequenceKeypoint.new(0.648722,0.947775,0.5),NumberSequenceKeypoint.new(0.717898,0.968541,0.5),NumberSequenceKeypoint.new(0.787908,0.983325,0.5),NumberSequenceKeypoint.new(0.858403,0.993004,0.5),NumberSequenceKeypoint.new(0.929151,0.998345,0.5),NumberSequenceKeypoint.new(1,1,0.5)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16847032740",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Torso.OffCentered Spec 57",occurrence=1,properties={["Acceleration"]=Vector3.new(0,5,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.6,1.6),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=10,["RotSpeed"]=NumberRange.new(-100,100),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0.6875),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://15419161283",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Left Arm.Fire19",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.5),NumberSequenceKeypoint.new(0.0617071,0.17315,0.5),NumberSequenceKeypoint.new(0.12693,0.343893,0.5),NumberSequenceKeypoint.new(0.162264,0.427249,0.5),NumberSequenceKeypoint.new(0.200324,0.508357,0.5),NumberSequenceKeypoint.new(0.241846,0.586266,0.5),NumberSequenceKeypoint.new(0.287501,0.65978,0.5),NumberSequenceKeypoint.new(0.337754,0.727533,0.5),NumberSequenceKeypoint.new(0.392709,0.788179,0.5),NumberSequenceKeypoint.new(0.452035,0.840691,0.5),NumberSequenceKeypoint.new(0.515043,0.884609,0.5),NumberSequenceKeypoint.new(0.58088,0.920092,0.5),NumberSequenceKeypoint.new(0.648722,0.947775,0.5),NumberSequenceKeypoint.new(0.717898,0.968541,0.5),NumberSequenceKeypoint.new(0.787908,0.983325,0.5),NumberSequenceKeypoint.new(0.858403,0.993004,0.5),NumberSequenceKeypoint.new(0.929151,0.998345,0.5),NumberSequenceKeypoint.new(1,1,0.5)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16847032740",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Left Arm.Fire6",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.579327),NumberSequenceKeypoint.new(0.0617071,0.200621,0.579327),NumberSequenceKeypoint.new(0.12693,0.398453,0.579327),NumberSequenceKeypoint.new(0.162264,0.495033,0.579327),NumberSequenceKeypoint.new(0.200324,0.58901,0.579327),NumberSequenceKeypoint.new(0.241846,0.679279,0.579327),NumberSequenceKeypoint.new(0.287501,0.764457,0.579327),NumberSequenceKeypoint.new(0.337754,0.842959,0.579327),NumberSequenceKeypoint.new(0.392709,0.913227,0.579327),NumberSequenceKeypoint.new(0.452035,0.97407,0.579327),NumberSequenceKeypoint.new(0.515043,1.02496,0.579327),NumberSequenceKeypoint.new(0.58088,1.06607,0.579327),NumberSequenceKeypoint.new(0.648722,1.09814,0.579327),NumberSequenceKeypoint.new(0.717898,1.1222,0.579327),NumberSequenceKeypoint.new(0.787908,1.13933,0.579327),NumberSequenceKeypoint.new(0.858403,1.15055,0.579327),NumberSequenceKeypoint.new(0.929151,1.15674,0.579327),NumberSequenceKeypoint.new(1,1.15865,0.579327)}),["Speed"]=NumberRange.new(0.00115865,0.00115865),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16845227778",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Left Arm.OffCentered Spec 57",occurrence=1,properties={["Acceleration"]=Vector3.new(0,5,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.6,1.6),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=10,["RotSpeed"]=NumberRange.new(-100,100),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0.6875),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://15419161283",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Right Arm.Fire19",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.5),NumberSequenceKeypoint.new(0.0617071,0.17315,0.5),NumberSequenceKeypoint.new(0.12693,0.343893,0.5),NumberSequenceKeypoint.new(0.162264,0.427249,0.5),NumberSequenceKeypoint.new(0.200324,0.508357,0.5),NumberSequenceKeypoint.new(0.241846,0.586266,0.5),NumberSequenceKeypoint.new(0.287501,0.65978,0.5),NumberSequenceKeypoint.new(0.337754,0.727533,0.5),NumberSequenceKeypoint.new(0.392709,0.788179,0.5),NumberSequenceKeypoint.new(0.452035,0.840691,0.5),NumberSequenceKeypoint.new(0.515043,0.884609,0.5),NumberSequenceKeypoint.new(0.58088,0.920092,0.5),NumberSequenceKeypoint.new(0.648722,0.947775,0.5),NumberSequenceKeypoint.new(0.717898,0.968541,0.5),NumberSequenceKeypoint.new(0.787908,0.983325,0.5),NumberSequenceKeypoint.new(0.858403,0.993004,0.5),NumberSequenceKeypoint.new(0.929151,0.998345,0.5),NumberSequenceKeypoint.new(1,1,0.5)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16847032740",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Right Arm.Fire6",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.579327),NumberSequenceKeypoint.new(0.0617071,0.200621,0.579327),NumberSequenceKeypoint.new(0.12693,0.398453,0.579327),NumberSequenceKeypoint.new(0.162264,0.495033,0.579327),NumberSequenceKeypoint.new(0.200324,0.58901,0.579327),NumberSequenceKeypoint.new(0.241846,0.679279,0.579327),NumberSequenceKeypoint.new(0.287501,0.764457,0.579327),NumberSequenceKeypoint.new(0.337754,0.842959,0.579327),NumberSequenceKeypoint.new(0.392709,0.913227,0.579327),NumberSequenceKeypoint.new(0.452035,0.97407,0.579327),NumberSequenceKeypoint.new(0.515043,1.02496,0.579327),NumberSequenceKeypoint.new(0.58088,1.06607,0.579327),NumberSequenceKeypoint.new(0.648722,1.09814,0.579327),NumberSequenceKeypoint.new(0.717898,1.1222,0.579327),NumberSequenceKeypoint.new(0.787908,1.13933,0.579327),NumberSequenceKeypoint.new(0.858403,1.15055,0.579327),NumberSequenceKeypoint.new(0.929151,1.15674,0.579327),NumberSequenceKeypoint.new(1,1.15865,0.579327)}),["Speed"]=NumberRange.new(0.00115865,0.00115865),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16845227778",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Right Arm.OffCentered Spec 57",occurrence=1,properties={["Acceleration"]=Vector3.new(0,5,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.6,1.6),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=10,["RotSpeed"]=NumberRange.new(-100,100),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0.6875),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://15419161283",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Left Leg.Fire19",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.5),NumberSequenceKeypoint.new(0.0617071,0.17315,0.5),NumberSequenceKeypoint.new(0.12693,0.343893,0.5),NumberSequenceKeypoint.new(0.162264,0.427249,0.5),NumberSequenceKeypoint.new(0.200324,0.508357,0.5),NumberSequenceKeypoint.new(0.241846,0.586266,0.5),NumberSequenceKeypoint.new(0.287501,0.65978,0.5),NumberSequenceKeypoint.new(0.337754,0.727533,0.5),NumberSequenceKeypoint.new(0.392709,0.788179,0.5),NumberSequenceKeypoint.new(0.452035,0.840691,0.5),NumberSequenceKeypoint.new(0.515043,0.884609,0.5),NumberSequenceKeypoint.new(0.58088,0.920092,0.5),NumberSequenceKeypoint.new(0.648722,0.947775,0.5),NumberSequenceKeypoint.new(0.717898,0.968541,0.5),NumberSequenceKeypoint.new(0.787908,0.983325,0.5),NumberSequenceKeypoint.new(0.858403,0.993004,0.5),NumberSequenceKeypoint.new(0.929151,0.998345,0.5),NumberSequenceKeypoint.new(1,1,0.5)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16847032740",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Left Leg.Fire6",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.579327),NumberSequenceKeypoint.new(0.0617071,0.200621,0.579327),NumberSequenceKeypoint.new(0.12693,0.398453,0.579327),NumberSequenceKeypoint.new(0.162264,0.495033,0.579327),NumberSequenceKeypoint.new(0.200324,0.58901,0.579327),NumberSequenceKeypoint.new(0.241846,0.679279,0.579327),NumberSequenceKeypoint.new(0.287501,0.764457,0.579327),NumberSequenceKeypoint.new(0.337754,0.842959,0.579327),NumberSequenceKeypoint.new(0.392709,0.913227,0.579327),NumberSequenceKeypoint.new(0.452035,0.97407,0.579327),NumberSequenceKeypoint.new(0.515043,1.02496,0.579327),NumberSequenceKeypoint.new(0.58088,1.06607,0.579327),NumberSequenceKeypoint.new(0.648722,1.09814,0.579327),NumberSequenceKeypoint.new(0.717898,1.1222,0.579327),NumberSequenceKeypoint.new(0.787908,1.13933,0.579327),NumberSequenceKeypoint.new(0.858403,1.15055,0.579327),NumberSequenceKeypoint.new(0.929151,1.15674,0.579327),NumberSequenceKeypoint.new(1,1.15865,0.579327)}),["Speed"]=NumberRange.new(0.00115865,0.00115865),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16845227778",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Left Leg.OffCentered Spec 57",occurrence=1,properties={["Acceleration"]=Vector3.new(0,5,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.6,1.6),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=10,["RotSpeed"]=NumberRange.new(-100,100),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0.6875),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://15419161283",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Right Leg.Fire6",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.579327),NumberSequenceKeypoint.new(0.0617071,0.200621,0.579327),NumberSequenceKeypoint.new(0.12693,0.398453,0.579327),NumberSequenceKeypoint.new(0.162264,0.495033,0.579327),NumberSequenceKeypoint.new(0.200324,0.58901,0.579327),NumberSequenceKeypoint.new(0.241846,0.679279,0.579327),NumberSequenceKeypoint.new(0.287501,0.764457,0.579327),NumberSequenceKeypoint.new(0.337754,0.842959,0.579327),NumberSequenceKeypoint.new(0.392709,0.913227,0.579327),NumberSequenceKeypoint.new(0.452035,0.97407,0.579327),NumberSequenceKeypoint.new(0.515043,1.02496,0.579327),NumberSequenceKeypoint.new(0.58088,1.06607,0.579327),NumberSequenceKeypoint.new(0.648722,1.09814,0.579327),NumberSequenceKeypoint.new(0.717898,1.1222,0.579327),NumberSequenceKeypoint.new(0.787908,1.13933,0.579327),NumberSequenceKeypoint.new(0.858403,1.15055,0.579327),NumberSequenceKeypoint.new(0.929151,1.15674,0.579327),NumberSequenceKeypoint.new(1,1.15865,0.579327)}),["Speed"]=NumberRange.new(0.00115865,0.00115865),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16845227778",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Right Leg.Fire19",occurrence=1,properties={["Acceleration"]=Vector3.new(0,0,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.Custom,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.4,0.7),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=true,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=5,["RotSpeed"]=NumberRange.new(0,0),["Rotation"]=NumberRange.new(0,0),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0.5),NumberSequenceKeypoint.new(0.0617071,0.17315,0.5),NumberSequenceKeypoint.new(0.12693,0.343893,0.5),NumberSequenceKeypoint.new(0.162264,0.427249,0.5),NumberSequenceKeypoint.new(0.200324,0.508357,0.5),NumberSequenceKeypoint.new(0.241846,0.586266,0.5),NumberSequenceKeypoint.new(0.287501,0.65978,0.5),NumberSequenceKeypoint.new(0.337754,0.727533,0.5),NumberSequenceKeypoint.new(0.392709,0.788179,0.5),NumberSequenceKeypoint.new(0.452035,0.840691,0.5),NumberSequenceKeypoint.new(0.515043,0.884609,0.5),NumberSequenceKeypoint.new(0.58088,0.920092,0.5),NumberSequenceKeypoint.new(0.648722,0.947775,0.5),NumberSequenceKeypoint.new(0.717898,0.968541,0.5),NumberSequenceKeypoint.new(0.787908,0.983325,0.5),NumberSequenceKeypoint.new(0.858403,0.993004,0.5),NumberSequenceKeypoint.new(0.929151,0.998345,0.5),NumberSequenceKeypoint.new(1,1,0.5)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(0,0),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://16847032740",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
 {root="PrimeBombDeathAura",path="Right Leg.OffCentered Spec 57",occurrence=1,properties={["Acceleration"]=Vector3.new(0,5,0),["Brightness"]=10,["Color"]=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,0.396078,0.27451)),ColorSequenceKeypoint.new(1,Color3.new(1,0.396078,0.27451))}),["Drag"]=0,["EmissionDirection"]=Enum.NormalId.Top,["FlipbookBlendFrames"]=true,["FlipbookFramerate"]=NumberRange.new(16,16),["FlipbookLayout"]=Enum.ParticleFlipbookLayout.None,["FlipbookMode"]=Enum.ParticleFlipbookMode.OneShot,["FlipbookStartRandom"]=false,["Lifetime"]=NumberRange.new(0.6,1.6),["LightEmission"]=-1,["LightInfluence"]=0,["LockedToPart"]=false,["Orientation"]=Enum.ParticleOrientation.FacingCamera,["Rate"]=10,["RotSpeed"]=NumberRange.new(-100,100),["Rotation"]=NumberRange.new(-360,360),["Shape"]=Enum.ParticleEmitterShape.Box,["ShapeInOut"]=Enum.ParticleEmitterShapeInOut.Outward,["ShapePartial"]=1,["ShapeStyle"]=Enum.ParticleEmitterShapeStyle.Volume,["Size"]=NumberSequence.new({NumberSequenceKeypoint.new(0,1,0.6875),NumberSequenceKeypoint.new(1,0,0)}),["Speed"]=NumberRange.new(0.001,0.001),["SpreadAngle"]=Vector2.new(360,360),["Squash"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["Texture"]="rbxassetid://15419161283",["TimeScale"]=1,["Transparency"]=NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),["VelocityInheritance"]=0,["WindAffectsDrag"]=false,["ZOffset"]=0.10000000149011612}},
}
function H.RestorePrimeBombDumpProperties(template, rootName)
 if not template then return end
 local byPath, restored = {}, 0
 local function walk(parent, prefix)
  for _, child in ipairs(parent:GetChildren()) do
   local path = prefix == "" and child.Name or (prefix .. "." .. child.Name)
   if child:IsA("ParticleEmitter") then
    byPath[path] = byPath[path] or {}
    table.insert(byPath[path],child)
   end
   walk(child,path)
  end
 end
 walk(template,"")
 for _,record in ipairs(PrimeBombDumpProperties) do
  if record.root == rootName then
   local siblings=byPath[record.path]
   local emitter=siblings and siblings[record.occurrence]
   if emitter then
    for property,value in pairs(record.properties) do
     local ok,err=pcall(function() emitter[property]=value end)
     if not ok then warn("[PrimeBomb] Property failed:",record.path,property,err) end
    end
    restored += 1
   else
    warn("[PrimeBomb] Emitter missing from template:",record.path,"#",record.occurrence)
   end
  end
 end
 print("[PrimeBomb] Full dump emitter properties restored:",rootName,restored)
end

-- Keep pristine game assets untouched. Hydrate private, unparented copies only.
-- These are templates, NOT active effects; the bomb ending clones them on demand.
function H.MakePrimeVfxTemplate(name, fileName, specs)
 local source = H.LoadEffectModel(name,fileName)
 if not source then
  warn("[PrimeBomb] Missing VFX template:",name)
  return nil
 end
 local template = source:Clone()
 template.Name = name .. "_LocalTemplate"
 template.Parent = nil
 H.HydrateEmitterAttributes(template,specs)
 H.RestorePrimeBombDumpProperties(template,name)
 -- Templates must not run particle emissions before they are spawned.
 for _,item in ipairs(template:GetDescendants()) do
  if item:IsA("ParticleEmitter") then item.Enabled = false end
 end
 return template
end

local primeExplosionTemplate = H.MakePrimeVfxTemplate(
 "PrimeBombExplosion",C.PRIME_BOMB_EXPLOSION_FILE,explosionEmitterSpecs)
local primeAuraTemplate = H.MakePrimeVfxTemplate(
 "PrimeBombDeathAura",C.PRIME_BOMB_DEATH_AURA_FILE,deathAuraEmitterSpecs)

function H.TryLoadModule(folder, name)
 local mod=folder and folder:FindFirstChild(name)
 if not (mod and mod:IsA("ModuleScript")) then return nil end
 local ok,result=pcall(require,mod)
 if ok then return result end
 warn("[PrimeBomb] Could not load", name, result)
end

local modules=ReplicatedStorage:FindFirstChild("Modules")
local client=modules and modules:FindFirstChild("Client")
local utilities=modules and modules:FindFirstChild("Utilities")
local gamePrimeBombExplosion=H.TryLoadModule(client,"primeBombExplosion")
local gamePrimeBombDeathAura=H.TryLoadModule(client,"primeBombDeathAura")
local gameVfxDispatcher=H.TryLoadModule(utilities,"vfxDispatcher")

-- Texture asset diagnostics: exported RBXMX keeps references, but it cannot
-- grant access to private Roblox image assets. Preload so we can report failures
-- and switch to a reliable procedural flash instead of blank/default sprites.
local unavailableVfxTextures = {}
local vfxTexturesChecked = false
function H.TextureUnavailable(asset)
 if unavailableVfxTextures[asset] then return true end
 local ok, status = pcall(function() return ContentProvider:GetAssetFetchStatus(asset) end)
 return ok and status == Enum.AssetFetchStatus.Failure
end

task.spawn(function()
 local assets,seen={},{}
 for _,template in ipairs({primeExplosionTemplate,primeAuraTemplate}) do
  if template then
   for _,obj in ipairs(template:GetDescendants()) do
    if obj:IsA("ParticleEmitter") and obj.Texture~="" and not seen[obj.Texture] then
     seen[obj.Texture]=true
     table.insert(assets,obj.Texture)
    end
   end
  end
 end
 if #assets==0 then return end
 local bad=0
 local ok,err=pcall(function()
  ContentProvider:PreloadAsync(assets,function(asset,status)
   if status~=Enum.AssetFetchStatus.Success then
    unavailableVfxTextures[asset]=true
    bad+=1
   end
  end)
 end)
 if not ok then warn("[PrimeBomb] VFX preload encountered a problem:",err) end
 vfxTexturesChecked=true
 if bad>0 then
  warn("[PrimeBomb] ",bad," of ",#assets," particle textures failed to load. RBXMX properties do NOT unlock private asset IDs; using procedural fallback for missing visuals.")
 else
  print("[PrimeBomb] VFX preload: ",#assets," texture IDs checked, ",bad," reported failures")
 end
end)

-- Texture-free, locally rendered neon blast. This provides a recognizable
-- effect even if the source game's sprites are private/inaccessible.
function H.EmitProceduralPrimeBlast(position, strengthen)
 local parent=Instance.new("Folder")
 parent.Name="PrimeBombReliableBlast"
 parent.Parent=Workspace:FindFirstChild("VFXLive") or Workspace
 Debris:AddItem(parent,3)
 local function flashPart(name,size,color,transparency)
  local p=Instance.new("Part")
  p.Name=name
  p.Anchored=true
  p.CanCollide=false
  p.CanTouch=false
  p.CanQuery=false
  p.CastShadow=false
  p.Material=Enum.Material.Neon
  p.Color=color
  p.Transparency=transparency
  p.Size=size
  p.CFrame=CFrame.new(position)
  p.Parent=parent
  return p
 end
 local intensity=strengthen and 1 or 0.62
 local flash=flashPart("FlashCore",Vector3.new(3,3,3),Color3.fromRGB(255,220,245),0.1)
 flash.Shape=Enum.PartType.Ball
 TweenService:Create(flash,TweenInfo.new(0.31,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
  Size=Vector3.new(50,50,50)*intensity,Transparency=1
 }):Play()
 local halo=flashPart("PulseHalo",Vector3.new(1,1,1),Color3.fromRGB(255,25,160),0.34)
 halo.Shape=Enum.PartType.Ball
 TweenService:Create(halo,TweenInfo.new(0.72,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{
  Size=Vector3.new(76,76,76)*intensity,Transparency=1
 }):Play()
 -- Independent expanding rays: no textures, UI, or private permissions.
 local rng=Random.new()
 for _=1,18 do
  local dir=Vector3.new(rng:NextNumber(-1,1),rng:NextNumber(-0.6,1),rng:NextNumber(-1,1))
  if dir.Magnitude<0.05 then dir=Vector3.yAxis end
  dir=dir.Unit
  local origin=position+dir*rng:NextNumber(1,4)
  local streak=flashPart("BlastStreak",Vector3.new(0.45,0.45,3),
   rng:NextInteger(1,3)==1 and Color3.fromRGB(255,225,245) or C.BOMB_VISUAL_COLOR,0.08)
  streak.CFrame=CFrame.lookAt(origin,origin+dir)
  local endpoint=position+dir*rng:NextNumber(23,44)*intensity
  TweenService:Create(streak,TweenInfo.new(rng:NextNumber(0.33,0.65),Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{
   CFrame=CFrame.lookAt(endpoint,endpoint+dir),Transparency=1,Size=Vector3.new(0.1,0.1,8)
  }):Play()
 end
end

function H.EmitFromAttributes(vfx)
 -- Fallback uses the emitter's saved texture, Size/Color/Transparency curves,
 -- and attributes. Old code used guessed counts of 14-30 particles, which
 -- overwhelmed effects with intended EmitCount values of 1-5.
 for _,emitter in ipairs(vfx:GetDescendants()) do
  if emitter:IsA("ParticleEmitter") then
   emitter.Enabled=false
   if emitter.Texture=="" or H.TextureUnavailable(emitter.Texture) then
    -- An inaccessible texture produces default-looking squares/circles.
    -- The guaranteed geometry-based blast below replaces those visuals.
    continue
   end
   local count=tonumber(emitter:GetAttribute("EmitCount"))
   if count==nil then count=math.max(1,math.floor(emitter.Rate*0.1)) end
   count=math.clamp(math.floor(count),0,80)
   local delay=tonumber(emitter:GetAttribute("EmitDelay")) or 0
   delay=math.clamp(delay,0,5)
   local duration=tonumber(emitter:GetAttribute("EmitDuration")) or 0
   if count>0 then
    task.delay(delay,function()
     if emitter.Parent then emitter:Emit(count) end
    end)
   end
   if duration>0 then
    task.delay(delay,function()
     if not emitter.Parent then return end
     emitter.Enabled=true
     task.delay(math.min(duration,5),function()
      if emitter.Parent then emitter.Enabled=false end
     end)
    end)
   end
  end
 end
end

function H.PositionPrimeGroundFx(vfx,hit)
 local anchor=vfx:FindFirstChild("Anchor",true)
 local blast=anchor and anchor:FindFirstChild("Explosion")
 if not blast then return end
 if not hit then
  for _,name in ipairs({"Ground","Debris"}) do
   local attachment=blast:FindFirstChild(name)
   if attachment then attachment:Destroy() end
  end
  return
 end
 local up=hit.Normal.Unit
 local tangent=up:Cross(Vector3.xAxis)
 if tangent.Magnitude<0.001 then tangent=up:Cross(Vector3.zAxis) end
 local pos=hit.Position+up*0.05
 local groundFrame=CFrame.lookAt(pos,pos+tangent.Unit,up)
 local ground=blast:FindFirstChild("Ground")
 local rubble=blast:FindFirstChild("Debris")
 if ground and ground:IsA("Attachment") then ground.WorldCFrame=groundFrame end
 if rubble and rubble:IsA("Attachment") then
  rubble.WorldCFrame=groundFrame*CFrame.Angles(-math.pi/2,0,0)
 end
end

function H.EmitPrimeBombExplosion(position,hit)
 -- Path A: invoke the exact original client effect, if this game provides it.
 -- Its vfxDispatcher restores runtime emitter properties and authored curves.
 if type(gamePrimeBombExplosion)=="function" then
  local ok,err=pcall(gamePrimeBombExplosion,{
   position=position,
   groundPosition=hit and hit.Position or nil,
   groundNormal=hit and hit.Normal or nil,
  })
  if ok then print("[PrimeBomb] VFX path: original game explosion module"); return end
  warn("[PrimeBomb] Game explosion module failed; using bundled VFX:",err)
 end
 if not primeExplosionTemplate then
  warn("[PrimeBomb] PrimeBombExplosion asset unavailable: rendering guaranteed procedural shockwave.")
  H.EmitProceduralPrimeBlast(position,true)
  return
 end
 local vfx=primeExplosionTemplate:Clone()
 vfx.Name="TerminalPrimeBombExplosion"
 -- Path B: preserve the game's original preparation/animation of attributes.
 local prepared=false
 if type(gameVfxDispatcher)=="table" and type(gameVfxDispatcher.prepare)=="function" then
  prepared=pcall(function() gameVfxDispatcher.prepare(vfx,{anchored=true}) end)
 end
 if vfx:IsA("Model") then vfx:PivotTo(CFrame.new(position))
 elseif vfx:IsA("BasePart") then vfx.CFrame=CFrame.new(position) end
 for _,part in ipairs(vfx:GetDescendants()) do
  if part:IsA("BasePart") then
   part.Anchored=true
   part.CanCollide=false
   part.CanTouch=false
   part.CanQuery=false
  end
 end
 vfx.Parent=Workspace:FindFirstChild("VFXLive") or Workspace
 H.PositionPrimeGroundFx(vfx,hit)
 if prepared and type(gameVfxDispatcher.emit)=="function" then
  local ok,err=pcall(function()
   gameVfxDispatcher.emit(vfx,{destroyOnFinish=true,minimumLifetime=6.5,fallbackLifetime=8})
  end)
  if ok then print("[PrimeBomb] VFX path: game dispatcher + bundled model"); return end
  warn("[PrimeBomb] Dispatcher emit failed; using attribute counts:",err)
 end
 -- Path C: respect the provided RBXMX's serialized sequences and counts.
 print("[PrimeBomb] VFX path: bundled emitters + procedural shockwave (textures checked:",vfxTexturesChecked,")")
 H.EmitFromAttributes(vfx)
 H.EmitProceduralPrimeBlast(position,true)
 Debris:AddItem(vfx,8)
end

-- The dump has exactly three particle types for each of the six R6 limbs.
-- Use the hydrated template directly, so the original visual settings survive.
function H.EmitPrimeBombDeathAura(model)
 if not model or not model.Parent or not primeAuraTemplate then return end
 local affected = 0
 for _, fxFolder in ipairs(primeAuraTemplate:GetChildren()) do
  local limb = model:FindFirstChild(fxFolder.Name, true)
  if limb and limb:IsA("BasePart") then
   local origin = Instance.new("Attachment")
   origin.Name = "TerminalBombDeathAura"
   origin.Parent = limb
   for _, emitter in ipairs(fxFolder:GetChildren()) do
    if emitter:IsA("ParticleEmitter") then
     local copy = emitter:Clone()
     copy.Enabled = false
     copy.Parent = origin
     -- Unlike the explosion, the death effect is a short-lived flame aura.
     -- Keep all three emitters running on every limb for a visible duration.
     copy.Enabled = true
     affected += 1
     task.delay(2.5, function()
      if copy.Parent then copy.Enabled = false end
     end)
    end
   end
   Debris:AddItem(origin, 5)
  end
 end
 print("[PrimeBomb] Death aura applied:", model.Name, affected, "emitters")
end

function H.MakeFinalUprightPortal(model, portalCenter, outwardNormal)
 local portal,root=H.CreatePortal(model)
 if not portal then return end
 portal.Name="FinalDimensionPortal"
 portal:SetAttribute("FinalDimensionPortal",true)
 H.MakeTerminalPortalGreen(portal)
 H.PlacePortal(portal,root,portalCenter,outwardNormal)
 local face=H.GetVisibleFace(root)
 local panelUp=(face==Enum.NormalId.Top or face==Enum.NormalId.Bottom)
  and root.CFrame.LookVector or root.CFrame.UpVector
 panelUp -= outwardNormal*panelUp:Dot(outwardNormal)
 if panelUp.Magnitude>0.02 then
  panelUp=panelUp.Unit
  local roll=math.atan2(outwardNormal:Dot(panelUp:Cross(Vector3.yAxis)),panelUp:Dot(Vector3.yAxis))
  local pivot=portal:GetPivot()
  portal:PivotTo(CFrame.new(pivot.Position)*CFrame.fromAxisAngle(outwardNormal,roll)
   *(pivot-pivot.Position))
 end
 return portal,root
end

function H.HoldModelInsidePortal(model, portalCenter, normal)
 -- Hide and suspend the ragdoll during the five-second cartoon machinery
 -- sequence. Return a restore function for the eventual ejection.
 local old={}
 local pivot=model:GetPivot()
 model:PivotTo(CFrame.new(portalCenter-normal*1.8)*(pivot-pivot.Position))
 for _, obj in ipairs(model:GetDescendants()) do
  if obj:IsA("BasePart") then
   table.insert(old,{obj,obj.Anchored,obj.CanCollide,obj.LocalTransparencyModifier})
   obj.Anchored=true
   obj.CanCollide=false
   obj.LocalTransparencyModifier=1
  end
 end
 return function()
  for _, entry in ipairs(old) do
   local part=entry[1]
   if part.Parent then
    part.Anchored=entry[2]
    part.CanCollide=entry[3]
    part.LocalTransparencyModifier=entry[4]
   end
  end
 end
end

-- Shared across ordinary chains, active terminals, and bomb shockwaves.
H.StopOpaqueBypass = nil -- defined below, after the terminal handlers
local activeFlows = setmetatable({}, {__mode="k"})
local activeOpaqueRestores = setmetatable({}, {__mode="k"})

function H.RunBlenderPortal(model)
 local body=H.GetBodyPart(model)
 if not body then return end
 local camera=Workspace.CurrentCamera
 local look=camera and camera.CFrame.LookVector or body.CFrame.LookVector
 local flat=Vector3.new(look.X,0,look.Z)
 if flat.Magnitude<0.08 then flat=Vector3.new(1,0,0) end
 flat=flat.Unit
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={model,RAGDOLLS_FOLDER,fluidFolder}
 params.RespectCanCollide=true
 local portal,root,portalCenter,outwardNormal
 -- Try several camera-facing angles and distances. No portal is allowed to
 -- spawn inside solid geometry or pull a ragdoll through an opaque wall.
 for _, degrees in ipairs({0,35,-35,70,-70,110,-110,180}) do
  if portal then break end
  local direction=(CFrame.fromAxisAngle(Vector3.yAxis,math.rad(degrees))*flat).Unit
  for _, distance in ipairs({C.FINAL_PORTAL_DISTANCE,11,14}) do
   local candidate=body.Position+direction*distance
   local floor=Workspace:Raycast(candidate+Vector3.yAxis*6,Vector3.new(0,-22,0),params)
   if floor and math.abs(candidate.Y-floor.Position.Y)<6 then
    candidate=Vector3.new(candidate.X,floor.Position.Y+5.4,candidate.Z)
   end
   if H.BlenderCorridorClear(model,candidate,nil) then
    local trial,trialRoot=H.MakeFinalUprightPortal(model,candidate,-direction)
    if trial and not H.PortalHasObstruction(trial,model,nil)
     and H.BlenderCorridorClear(model,candidate,trial) then
     portal,root,portalCenter,outwardNormal=trial,trialRoot,candidate,-direction
     break
    end
    if trial then trial:Destroy() end
   end
  end
 end
 if not portal then
  warn("[Portal] Blender ending unavailable: no unobstructed entrance corridor")
  return false
 end
 H.PlayPortalSound(C.AUDIO.Open,portal)
 task.spawn(H.ElasticPortalIntro,portal,root)
 task.wait(C.FINAL_PORTAL_OPEN_WAIT)
 if not model.Parent or model:GetAttribute("BombCharred") then
  task.spawn(H.ClosePortal,portal,nil)
  return
 end
 local restoreCollisions=H.DisableCollision(model)
 local prev=body.Position
 local began=os.clock()
 local crossed=false
 while model.Parent and portal.Parent and os.clock()-began<C.FINAL_SUCTION_MAX_DURATION do
  body=H.GetBodyPart(model)
  if not body then break end
  local dt=RunService.Heartbeat:Wait()
  local current=body.Position
  local prevDistance=(prev-portalCenter):Dot(outwardNormal)
  local distance=(current-portalCenter):Dot(outwardNormal)
  local lateral=(current-portalCenter-outwardNormal*distance).Magnitude
  if prevDistance>0 and distance<=0 and lateral<=C.FINAL_SUCTION_CAPTURE_RADIUS then
   crossed=true;break
  end
  if distance<=0.35 and lateral<=C.FINAL_SUCTION_CAPTURE_RADIUS then
   crossed=true;break
  end
  local aim=portalCenter-outwardNormal*3
  local delta=aim-current
  if delta.Magnitude>0.02 then
   local velocity=delta.Unit*math.min(C.FINAL_SUCTION_MAX_SPEED,math.max(28,delta.Magnitude*15))
   H.SetRagdollVelocity(model,body.AssemblyLinearVelocity:Lerp(velocity,math.clamp(dt*C.FINAL_SUCTION_RESPONSE,0,1)))
  end
  prev=current
 end
 if model:GetAttribute("BombCharred") then
  task.spawn(H.ClosePortal,portal,nil)
  return
 end
 if model.Parent then
  H.PlayPortalSound(C.AUDIO.Enter,portal)
  local restoreHold=H.HoldModelInsidePortal(model,portalCenter,outwardNormal)
  -- Slowly chew for five seconds; the supplied old shake visual remains.
  task.spawn(H.SpillPortalBloodDuringShake,portal,C.FINAL_PORTAL_SHAKE_DURATION)
  H.ShakeFinalPortal(portal,C.FINAL_PORTAL_SHAKE_DURATION,model)
  if model:GetAttribute("BombCharred") or not model.Parent then
   -- Blast won the race against this blender ending; never eject/restart it.
   if portal.Parent then task.spawn(H.ClosePortal,portal,nil) end
   return
  end
  if model.Parent then
   local originalPivot=model:GetPivot()
   model:PivotTo(CFrame.new(portalCenter+outwardNormal*3)*(originalPivot-originalPivot.Position))
   restoreHold()
   restoreCollisions()
   -- Ejected body must collide again; remove all locally-added pass-through
   -- constraints before applying velocity. Keep HRP intangible as usual.
   H.StopOpaqueBypass(model)
   for _, piece in ipairs(model:GetDescendants()) do
    if piece:IsA("BasePart") then
     piece.Anchored=false
     piece.CanCollide=(piece.Name~="HumanoidRootPart")
     piece.CanTouch=true
     piece.CanQuery=true
    end
   end
   H.SetRagdollVelocity(model,outwardNormal*C.FINAL_EJECT_SPEED
    +Vector3.new(math.random(-24,24),math.random(12,30),math.random(-24,24)))
   -- Release separate Roblox pieces, then briefly emit cartoon fluid only
   -- from the points where the pieces were attached to the remaining model.
   local fluidSites = H.TearOffRandomLimbs(model,C.FINAL_BLOOD_COLOR,outwardNormal)
   H.StartBlenderExitFluid(model,fluidSites)
   if portal:GetAttribute("RainbowPortal") then H.StartRainbowRagdoll(model) end
  end
 else
  restoreCollisions()
 end
 if portal.Parent then H.ClosePortal(portal,nil) end
 if model.Parent then Debris:AddItem(model,C.FINAL_RAGDOLL_CLEANUP_DELAY) end
end


-- Bomb impact operates on Roblox ragdoll Models only, never live Player
-- characters or the world's collision settings. The black appearance and
-- temporary cleanup are purely client-side effects in this script.
function H.CharBombRagdoll(model)
 if not model or not model.Parent or not model:IsA("Model") then return false end
 if model:GetAttribute("BombCharred") then return true end
 -- Set the terminal state FIRST, so concurrent entry, clone, and watchdog
 -- coroutines all observe that this ragdoll is permanently out of the chain.
 model:SetAttribute("BombCharred", true)
 model:SetAttribute("FinalPortalTriggered", true)
 model:SetAttribute("FinalPortalCompleted", true)
 model:SetAttribute("FinalPortalKind", "bomb")
 local flow = activeFlows[model]
 if flow then flow.finalizing = true end
 if H.StopOpaqueBypass then H.StopOpaqueBypass(model) end
 for _, item in ipairs(model:GetDescendants()) do
  if item:IsA("BodyColors") or item:IsA("Shirt") or item:IsA("Pants")
   or item:IsA("ShirtGraphic") or item:IsA("Decal") or item:IsA("Texture")
   or item:IsA("SurfaceAppearance") or item:IsA("Highlight") then
   item:Destroy()
  elseif item:IsA("SpecialMesh") then
   pcall(function() item.TextureId = "" end)
  elseif item:IsA("BasePart") then
   -- Cover accessories, mesh limbs, faces, and all remaining parts.
   item.Color = Color3.new(0,0,0)
   item.Material = C.BOMB_CHAR_MATERIAL
   -- Preserve original transparency: invisible helper hitboxes can be balls,
   -- and forcing Transparency=0 made them look like physical black spheres.
   -- Only the visible ragdoll geometry is recolored; no new char parts spawn.
   if item.Transparency < 0.99 then item.LocalTransparencyModifier = 0 end
   if item:IsA("MeshPart") then
    pcall(function() item.TextureID = "" end)
   end
  end
 end
 Debris:AddItem(model, C.BOMB_CHARRED_CLEANUP_DELAY)
 return true
end

function H.ApplyBombShockwave(blastAt, primaryTarget)
 local candidates = {}
 -- Always affect the target, even if physics moved it away during arming.
 if primaryTarget and primaryTarget.Parent then
  candidates[primaryTarget] = true
 end
 for _, ragdoll in ipairs(RAGDOLLS_FOLDER:GetChildren()) do
  if ragdoll:IsA("Model") and ragdoll.Parent then
   local body = H.GetBodyPart(ragdoll)
   if body and (body.Position - blastAt).Magnitude <= C.BOMB_BLAST_RADIUS then
    candidates[ragdoll] = true
   end
  end
 end
 for ragdoll in pairs(candidates) do
  local body = H.GetBodyPart(ragdoll)
  if body and H.CharBombRagdoll(ragdoll) then
   local delta = body.Position - blastAt
   local dist = delta.Magnitude
   local strength = (ragdoll == primaryTarget) and 1
    or math.clamp(1 - dist/C.BOMB_BLAST_RADIUS, 0.22, 1)
   local direction = Vector3.new(delta.X, math.max(delta.Y, 0) + 5, delta.Z)
   if direction.Magnitude < 0.05 then direction = Vector3.yAxis end
   H.SetRagdollVelocity(ragdoll,
    direction.Unit * (C.BOMB_SHOCKWAVE_SPEED * strength)
    + Vector3.yAxis * (C.BOMB_SHOCKWAVE_LIFT * strength))
   local assemblies = {}
   for _, piece in ipairs(ragdoll:GetDescendants()) do
    if piece:IsA("BasePart") and not piece.Anchored then
     local assembly = piece.AssemblyRootPart or piece
     if not assemblies[assembly] then
      assemblies[assembly] = true
      assembly.AssemblyAngularVelocity = Vector3.new(
       math.random(-12,12), math.random(-12,12), math.random(-12,12))
     end
    end
   end
   -- Final visual pass: make every body piece and accessory plain black.
   -- This also catches pieces whose appearance was changed during shockwave setup.
   for _,part in ipairs(ragdoll:GetDescendants()) do
    if part:IsA("BasePart") then
     part.Color = Color3.new(0,0,0)
     part.Material = Enum.Material.SmoothPlastic
     if part:IsA("MeshPart") then
      pcall(function() part.TextureID = "" end)
     end
    end
   end
   -- Optional cartoony ragdoll-part ejection with brief red fluid at the
   -- former Roblox joint points. This does not create wounds or physical gore.
   if math.random() < C.BOMB_PART_SEPARATION_CHANCE then
    local sprayDirection=direction.Magnitude>0.01 and direction.Unit or Vector3.yAxis
    local sites=H.TearOffRandomLimbs(ragdoll,C.BLENDER_EXIT_FLUID_COLOR,sprayDirection)
    H.StartBlenderExitFluid(ragdoll,sites,true,C.BOMB_SEPARATION_FLUID_DURATION)
   end
   H.EmitPrimeBombDeathAura(ragdoll)
  end
 end
end

function H.CreateTerminalBomb(position)
 local bomb=Instance.new("Part")
 bomb.Name="FinalDimensionBomb"
 bomb.Shape=Enum.PartType.Ball
 bomb.Size=Vector3.new(2.5,2.5,2.5)
 bomb.Color=Color3.fromRGB(35,34,45)
 bomb.Material=Enum.Material.Metal
 bomb.Anchored=false
 bomb.CanCollide=true
 bomb.CanTouch=false
 bomb.CanQuery=false
 bomb.CFrame=CFrame.new(position)
 bomb.Parent=Workspace
 local indicator=Instance.new("Part")
 indicator.Name="PrimeBombPinkIndicator"
 indicator.Size=Vector3.new(0.38,0.38,0.38)
 indicator.Shape=Enum.PartType.Ball
 indicator.Material=Enum.Material.Neon
 indicator.Color=C.BOMB_VISUAL_COLOR
 indicator.Anchored=false
 indicator.CanCollide=false
 indicator.CanTouch=false
 indicator.CanQuery=false
 indicator.Massless=true
 indicator.CFrame=bomb.CFrame*CFrame.new(0,1.25,0)
 indicator.Parent=Workspace
 local weld=Instance.new("WeldConstraint")
 weld.Part0, weld.Part1=bomb,indicator
 weld.Parent=bomb
 return bomb,indicator
end

function H.RunBombPortal(model)
 if not model.Parent or model:GetAttribute("BombCharred") then return end
 local body=H.GetBodyPart(model)
 if not body then return end
 local function canceled()
  return not model.Parent or model:GetAttribute("BombCharred")
 end
 -- Horizontal portal exactly five studs above the current ragdoll.
 local center=body.Position+Vector3.yAxis*C.BOMB_OVERHEAD_HEIGHT
 local portal,root=H.CreatePortal(model)
 if not portal then return end
 portal.Name="TerminalBombPortal"
 portal:SetAttribute("FinalDimensionPortal",true)
 H.MakeTerminalPortalGreen(portal)
 local placed,chosen=H.TryPlacePortal(portal,root,center,-Vector3.yAxis,model,nil)
 if not placed then
  portal:Destroy()
  warn("[Portal] Prime Bomb portal skipped: no unobstructed overhead space")
  return
 end
 center=chosen
 H.PlayPortalSound(C.AUDIO.Open,portal)
 local stopBombSpin
 local function closeBombPortal()
  if portal.Parent then H.ClosePortal(portal,function()
   if stopBombSpin then stopBombSpin(); stopBombSpin=nil end
  end) end
 end
 task.spawn(function()
  H.ElasticPortalIntro(portal,root)
  if portal.Parent and not portal:GetAttribute("RainbowClosingScheduled") then
   stopBombSpin=H.StartRotation(portal,portal:GetPivot(),-Vector3.yAxis)
  end
 end)
 task.wait(C.FINAL_PORTAL_OPEN_WAIT)
 if canceled() then
  if portal.Parent then task.spawn(closeBombPortal) end
  return
 end
 if not portal.Parent then return end
 -- Spawn the bomb just beneath the portal's horizontal opening.
 local bomb,indicator=H.CreateTerminalBomb(center-Vector3.yAxis*1.2)
 -- Arming audio starts once, using ticking.mp3\n PlayTerminalBombSound(bomb.Position,false,1)
 local bombStart=os.clock()
 task.wait(C.BOMB_DROP_SETTLE)
 -- Arm for 2.75 seconds; reproduce the uploaded pink blink cue.
 local armedAt=os.clock()
 local nextBeepAt=-1
 while bomb.Parent and os.clock()-armedAt<C.BOMB_ARM_TIME and not canceled() do
  local elapsed=os.clock()-armedAt
  if elapsed>=nextBeepAt then
   H.PlayTerminalBombSound(bomb.Position,false,1+elapsed/C.BOMB_ARM_TIME*0.6)
   nextBeepAt=elapsed+C.BOMB_BEEP_INTERVAL
  end
  if indicator.Parent then
   local blinking=math.floor((os.clock()-armedAt)/0.1)%2==0
   indicator.Transparency=blinking and 0 or 0.7
   indicator.Material=blinking and Enum.Material.Neon or Enum.Material.SmoothPlastic
  end
  RunService.Heartbeat:Wait()
 end
 if canceled() then
  if indicator.Parent then indicator:Destroy() end
  if bomb.Parent then bomb:Destroy() end
  if portal.Parent then task.spawn(closeBombPortal) end
  return
 end
 local blastAt=bomb.Parent and bomb.Position or center-Vector3.yAxis*2
 if indicator.Parent then indicator:Destroy() end
 if bomb.Parent then bomb:Destroy() end
 local ray=RaycastParams.new()
 ray.FilterType=Enum.RaycastFilterType.Exclude
 ray.FilterDescendantsInstances={model,RAGDOLLS_FOLDER,portal,fluidFolder}
 ray.RespectCanCollide=true
 local ground=Workspace:Raycast(blastAt+Vector3.yAxis*2,Vector3.new(0,-22,0),ray)
 H.EmitPrimeBombExplosion(blastAt,ground)
 H.PlayTerminalBombSound(blastAt,true,1)
 -- Visually char and propel every nearby ragdoll, including mid-chain clones.
 -- CharBombRagdoll stops each chain before applying shockwave velocity.
 H.ApplyBombShockwave(blastAt,model)
 if portal.Parent then closeBombPortal() end
end

function H.RunFinalPortalSequence(model,flow)
 if not model.Parent then return end
 local chosen=flow.terminalKind or (math.random()<C.TERMINAL_BOMB_CHANCE and "bomb" or "blender")
 model:SetAttribute("FinalPortalKind",chosen)
 if chosen=="bomb" then
  H.RunBombPortal(model)
 else
  if H.RunBlenderPortal(model) == false and model.Parent
   and not model:GetAttribute("BombCharred") then
   H.RunBombPortal(model)
  end
 end
 if model.Parent then model:SetAttribute("FinalPortalCompleted",true) end
end

-- END FINAL ONE-WAY PORTAL ---------------------------------------------------

local processing = {}
H.StopOpaqueBypass = function(model)
 local restore=activeOpaqueRestores[model]
 activeOpaqueRestores[model]=nil
 if restore then restore() end
 -- Also remove any inherited folder that may have come from a cloned ragdoll.
 local inherited=model:FindFirstChild("PortalOpaquePassThrough")
 if inherited then inherited:Destroy() end
end
function H.BeginTerminalSequence(model,flow,reason)
 if not model or not model.Parent or model:GetAttribute("FinalPortalTriggered") then return false end
 -- A clone may have exhausted ordinary hops before its 20s expiration;
 -- terminal playback must still work even when that hop loop has ended.
 if not flow then flow={lastTeleportAt=os.clock(),finalizing=false} end
 if flow.finalizing then return false end
 activeFlows[model]=flow
 -- The ejecting ragdoll must collide with the map again, unlike chain ragdolls.
 H.StopOpaqueBypass(model)
 flow.finalizing=true
 flow.terminalKind=(math.random()<C.TERMINAL_BOMB_CHANCE) and "bomb" or "blender"
 model:SetAttribute("FinalPortalTriggered",true)
 model:SetAttribute("FinalPortalCompleted",false)
 model:SetAttribute("FinalPortalReason",reason)
 task.spawn(function()
  local ok,err=pcall(H.RunFinalPortalSequence,model,flow)
  if not ok then
   warn("[Portal] Terminal sequence failed:",err)
   if model.Parent then Debris:AddItem(model,2) end
  end
 end)
 return true
end
local activeClones, totalClones = 0, 0
local cloneExpiry = setmetatable({}, {__mode = "k"})
H.ProcessRagdoll = nil

function H.SpawnChainClone(source)
 if activeClones >= C.MAX_ACTIVE_CLONES or totalClones >= C.MAX_TOTAL_CLONES then return end
 if not source.Parent or source:GetAttribute("FinalPortalTriggered") or source:GetAttribute("BombCharred") then return end
 local oldArchivable = source.Archivable
 source.Archivable = true
 local ok, clone = pcall(function() return source:Clone() end)
 source.Archivable = oldArchivable
 if not ok or not clone then return end
 -- Avoid inheriting active behavior scripts and NoCollisionConstraints.
 local inheritedPassThrough=clone:FindFirstChild("PortalOpaquePassThrough")
 if inheritedPassThrough then inheritedPassThrough:Destroy() end
 for _, item in ipairs(clone:GetDescendants()) do
  if item:IsA("Script") or item:IsA("LocalScript") then item:Destroy() end
 end
 totalClones += 1
 activeClones += 1
 clone.Name = source.Name .. "_PortalClone_" .. totalClones
 -- A clone independently rolls its own lifetime portal mode.
 clone:SetAttribute("PortalAirOnly", nil)
 clone:SetAttribute("BlueLoopUsed",nil)
 clone:SetAttribute("BlueLoopActive",nil)
 local pivot = source:GetPivot()
 clone:PivotTo(pivot * CFrame.new(math.random(-3,3), 1.5, math.random(-3,3)))
 cloneExpiry[clone] = os.clock() + C.CLONE_LIFETIME
 clone.Parent = RAGDOLLS_FOLDER
 task.spawn(H.ProcessRagdoll, clone)
 -- Expired clones get an animated terminal portal, never silent deletion.
 task.delay(C.CLONE_LIFETIME, function()
  if clone.Parent then H.BeginTerminalSequence(clone,activeFlows[clone],"clone_lifetime") end
 end)
 task.delay(C.CLONE_FAILSAFE_TIME, function()
  if clone.Parent then H.BeginTerminalSequence(clone,activeFlows[clone],"clone_failsafe") end
 end)
 clone.Destroying:Once(function()
  activeClones = math.max(0, activeClones - 1)
  cloneExpiry[clone] = nil
 end)
end

-- Permanent midair-only chains still START with a real floor entrance.
-- After its first actual crossing, only airborne pairs are used.
-- This intentionally reuses the same predictive ground entry and 2.5s
-- rescue logic as ordinary portal chains; no timer-based teleport.
function H.EnterStartingGroundPortal(model,flow)
 local body=H.GetBodyPart(model)
 if not body or flow.finalizing then return false end
 local ground=H.PredictGroundImpact(model,body) or H.GetGround(model,body)
 if not ground or ground.Normal.Y<0.65 then return false end
 local position,normal=ground.Position,ground.Normal
 local portal,root=H.CreatePortal(model)
 if not portal then return false end
 portal.Name="RagdollPortal"
 portal:SetAttribute("GroundLocked",true)
 H.PlacePortal(portal,root,position,normal)
 local tracking={
  position=position,initialPosition=position,normal=normal,
  surface=ground.Instance,moves=0,lastMoveAt=-math.huge,
  lastTeleportAt=flow.lastTeleportAt,flow=flow,opening=true
 }
 H.PlayPortalSound(C.AUDIO.Open,portal)
 local stopRotation
 task.spawn(function()
  H.ElasticPortalIntro(portal,root,position,normal,ground.Instance,model,function()
   return tracking.position
  end)
  tracking.opening=false
  if portal.Parent then stopRotation=H.StartRotation(portal,portal:GetPivot(),tracking.normal) end
 end)
 local crossed=H.WaitForPredictedImpact(model,portal,root,tracking)
 if crossed and model.Parent and not flow.finalizing then
  H.PlayPortalSound(C.AUDIO.Enter,portal)
  if portal:GetAttribute("RainbowPortal") then H.StartRainbowRagdoll(model) end
  -- The crossing is a genuine entrance; the airborne corridor will open next.
  task.spawn(H.ClosePortal,portal,function() if stopRotation then stopRotation() end end)
  return true
 end
 task.spawn(H.ClosePortal,portal,function() if stopRotation then stopRotation() end end)
 return false
end


H.ProcessRagdoll = function(model)
 if processing[model] or model:GetAttribute("BombCharred") then return end
 processing[model]=true
 local stopOpaqueCollisions = H.StartOpaquePassThrough(model)
 activeOpaqueRestores[model]=stopOpaqueCollisions
 local ok,err = pcall(function()
  local originalGroundY = nil
  local completedHops = 0
  local flow = {lastTeleportAt = os.clock(), finalizing = false}
  activeFlows[model]=flow
  -- Completed teleports reset the idle clock; clone age is tracked separately.
  task.spawn(function()
   while model.Parent and not flow.finalizing do
    if os.clock()-flow.lastTeleportAt>=C.FINAL_PORTAL_STALL_TIME then
     H.BeginTerminalSequence(model,flow,"no_teleport_5s")
     break
    end
    RunService.Heartbeat:Wait()
   end
  end)
  -- Roll ONCE per ragdoll (including each clone); never switch modes mid-chain.
  local airOnly = math.random() < C.AIR_ONLY_LIFETIME_CHANCE
  local airOnlyInitialGroundEntered=false
  model:SetAttribute("PortalAirOnly", airOnly)
  if model:GetAttribute("RainbowRagdoll") then H.StartRainbowRagdoll(model) end
  while model.Parent and not flow.finalizing and (cloneExpiry[model] or completedHops < C.MAX_PORTAL_HOPS) do
   if not model.Parent then break end
   local body=H.GetBodyPart(model)
   if not body then break end

   if airOnly then
    -- Exactly one real grounded starting portal. The next portals are floating.
    if not airOnlyInitialGroundEntered then
     if not H.EnterStartingGroundPortal(model,flow) then
      RunService.Heartbeat:Wait()
      continue
     end
     airOnlyInitialGroundEntered=true
     if flow.finalizing or not model.Parent then break end
     body=H.GetBodyPart(model)
     if not body then break end
    end
    -- Once the initial floor opening is crossed, fly only through air pairs.
    local first, second, startPos, targetPos = H.SpawnAirPair(model, body, true)
    if flow.finalizing then
     if first then task.spawn(H.ClosePortal,first,nil) end
     if second then task.spawn(H.ClosePortal,second,nil) end
     break
    end
    if not first then
     -- Never silently downgrade an air-only ragdoll to a floor chain.
     -- Wait for a camera-visible, unobstructed airborne pair instead.
     task.wait(C.AIR_ONLY_RETRY_INTERVAL)
     continue
    end
    local rainbowAfterAir=first:GetAttribute("RainbowPortal") or second:GetAttribute("RainbowPortal")
    local blueAfterAir=not rainbowAfterAir and H.RollBlueLoopForExit(model,flow)
    if blueAfterAir then H.TintBluePortal(second) end
    local restore = H.DisableCollision(model)
    H.PlayPortalSound(C.AUDIO.Enter, first)
    local crossed = H.FlyBetweenAirPortals(model, startPos, targetPos, flow)
    restore()
    if crossed and model.Parent and not flow.finalizing then
     H.PlayPortalSound(C.AUDIO.Enter, second)
     if rainbowAfterAir then H.StartRainbowRagdoll(model) end
     completedHops += 1
     flow.lastTeleportAt = os.clock()
     if cloneExpiry[model] and os.clock() >= cloneExpiry[model] then
      H.BeginTerminalSequence(model,flow,"clone_lifetime")
     elseif model.Parent and math.random() < C.CLONE_CHANCE then
      H.SpawnChainClone(model)
     end
    end
    task.spawn(H.ClosePortal, first, nil)
    task.spawn(H.ClosePortal, second, nil)
    -- A blue-colored second portal signals the upcoming falling detour.
    if crossed and not flow.finalizing then
     H.MaybeRunBlueFallingLoop(model,flow,blueAfterAir)
    end
    if model.Parent then RunService.Heartbeat:Wait() end
    continue
   end

   -- No fixed wait and no nearest-ground fallback: a portal is spawned ONLY
   -- after the current trajectory is actually predicted to strike a floor.
   local ground = H.PredictGroundImpact(model,body)
   if not ground and body.AssemblyLinearVelocity.Y<8 then
    local nearby=H.GetGround(model,body)
    if nearby and (body.Position-nearby.Position).Magnitude<11 then ground=nearby end
   end
   if flow.finalizing then break end
   if not ground then
    -- Allow the next frame to sample a genuinely different trajectory.
    RunService.Heartbeat:Wait()
    continue
   end
   if originalGroundY == nil then originalGroundY = ground.Position.Y end
   local inPos,inNormal = ground.Position,ground.Normal
   local support = ground
   local abovePortal = false
   local banishOnEntry = cloneExpiry[model] ~= nil and os.clock() >= cloneExpiry[model]
   local entrance,root=H.CreatePortal(model)
   if not entrance then break end
   -- Lock floor entrances to the raycast surface, not the model bounding box.
   entrance:SetAttribute("GroundLocked", not abovePortal)
   local placementOk, safePosition = H.TryPlacePortal(entrance,root,inPos,inNormal,model,support.Instance)
   if not placementOk then
    entrance:Destroy()
    RunService.Heartbeat:Wait()
    continue
   end
   inPos=safePosition
   local tracking = {
    position=inPos, initialPosition=inPos, normal=inNormal,
    surface=support.Instance, moves=0, lastMoveAt=-math.huge,
    lastTeleportAt=flow.lastTeleportAt,
    flow=flow,
    opening=true
   }
   -- Animate concurrently with prediction tracking: no 0.53s opening pause.
   task.spawn(function()
    H.ElasticPortalIntro(entrance,root,inPos,inNormal,support.Instance,model,function()
     return tracking.position
    end)
    tracking.opening = false
   end)
   H.PlayPortalSound(C.AUDIO.Open, entrance)
   -- Rotation starts after opening to avoid fighting the elastic part animation.
   local stopEntrance
   task.spawn(function()
    while model.Parent and entrance.Parent and tracking.opening do
     RunService.Heartbeat:Wait()
    end
    if entrance.Parent then
     stopEntrance = H.StartRotation(entrance,entrance:GetPivot(),tracking.normal)
    end
   end)
   if not H.WaitForPredictedImpact(model,entrance,root,tracking) or not model.Parent then
    task.spawn(H.ClosePortal,entrance,function() if stopEntrance then stopEntrance() end end)
    if not model.Parent then break end
    RunService.Heartbeat:Wait()
    continue
   end
   -- A portal ENTRY is not yet a completed transfer: keep the 5s timer
   -- running until a real exit occurs.
   -- Actual final landing point may move as the ragdoll spins/falls.
   inPos, inNormal = tracking.position, tracking.normal
   body=H.GetBodyPart(model)
   if not body then H.ClosePortal(entrance,function() if stopEntrance then stopEntrance() end end); break end
   if flow.finalizing then
    task.spawn(H.ClosePortal,entrance,function() if stopEntrance then stopEntrance() end end)
    break
   end
   if banishOnEntry or (cloneExpiry[model] and os.clock() >= cloneExpiry[model]) then
    H.BeginTerminalSequence(model,flow,"clone_lifetime")
    task.spawn(H.ClosePortal,entrance,function() if stopEntrance then stopEntrance() end end)
    break
   end
   -- Choose the blue detour before its preceding exit opens, so that
   -- preceding portal is ALREADY blue when the ragdoll exits from it.
   local blueAfterExit=H.RollBlueLoopForExit(model,flow)
   local airFirst,airSecond,airStart,airTarget
   if math.random() < C.MIDAIR_CHAIN_CHANCE then
    airFirst,airSecond,airStart,airTarget = H.SpawnAirPair(model,body)
   end
   -- Capture any rainbow override before asynchronous portal close tasks run.
   local airPairRainbow=airFirst and airSecond and
    (airFirst:GetAttribute("RainbowPortal") or airSecond:GetAttribute("RainbowPortal"))
   local exit,stopExit,exitPos,exitNormal
   if not airFirst then
    exit,stopExit,exitPos,exitNormal=H.SpawnExit(model,body,originalGroundY)
    if not exit then H.ClosePortal(entrance,function() if stopEntrance then stopEntrance() end end); break end
   end
   H.PlayPortalSound(C.AUDIO.Enter, entrance)
   if airFirst then
    -- Immediate transfer into the first midair exit.
    H.PlayPortalSound(C.AUDIO.Enter,airFirst)
    local reached = H.FlyBetweenAirPortals(model,airStart,airTarget,flow)
    if reached then H.PlayPortalSound(C.AUDIO.Enter,airSecond) end
    -- If the ballistic throw misses, let the ragdoll keep flying/falling.
    -- The next hop predicts its new landing point; no scripted rescue snap.
    task.spawn(H.ClosePortal,airFirst,nil)
    task.spawn(H.ClosePortal,airSecond,nil)
    if reached then
     exit,stopExit,exitPos,exitNormal=H.SpawnExit(model,H.GetBodyPart(model) or body,originalGroundY)
    else
     task.spawn(H.ClosePortal,entrance,function() if stopEntrance then stopEntrance() end end)
     if model.Parent then RunService.Heartbeat:Wait() end
     continue
    end
   end
   if flow.finalizing then
    task.spawn(H.ClosePortal,entrance,function() if stopEntrance then stopEntrance() end end)
    if exit then task.spawn(H.ClosePortal,exit,stopExit) end
    break
   end
   if not exit then
    H.ClosePortal(entrance,function() if stopEntrance then stopEntrance() end end)
    break
   end
   -- Any portal involved in this hop can be rainbow, including the floor
   -- entrance and the intermediate air pair (not just the last exit).
   local rainbowAfterExit=entrance:GetAttribute("RainbowPortal")
    or exit:GetAttribute("RainbowPortal") or airPairRainbow
   -- Rainbow has precedence over a blue-loop detour when rolled on this hop.
   if rainbowAfterExit then blueAfterExit=false end
   if blueAfterExit then H.TintBluePortal(exit) end
   if C.TRAVEL_TIME > 0 then task.wait(C.TRAVEL_TIME) end
   if model.Parent and not flow.finalizing then
    local restore=H.DisableCollision(model)
    local pivot=model:GetPivot()
    model:PivotTo(CFrame.new(exitPos+exitNormal*3)*(pivot-pivot.Position))
    -- Keep ragdoll spin and relative limb velocities. Only reorient the bulk
    -- exit momentum and add a fresh randomized kick; no fixed trajectory.
    local torso = H.GetBodyPart(model)
    local currentVelocity = torso and torso.AssemblyLinearVelocity or Vector3.zero
    local randomLateral = Vector3.new(math.random(-26,26),math.random(3,25),math.random(-26,26))
    local retainedMomentum = currentVelocity.Magnitude > 110
     and currentVelocity.Unit*110 or currentVelocity
    local targetVelocity = exitNormal * math.random(34,65)
     + randomLateral + retainedMomentum * 0.22
    local change = targetVelocity-currentVelocity
    local seen={}
    for _,part in ipairs(model:GetDescendants()) do
     if part:IsA("BasePart") and not part.Anchored then
      local assembly=part.AssemblyRootPart or part
      if not seen[assembly] then
       seen[assembly]=true
       assembly.AssemblyLinearVelocity += change
      end
     end
    end
    restore()
    -- Rainbow coloration begins only after the exit teleport is completed.
    if rainbowAfterExit then H.StartRainbowRagdoll(model) end
   end
   if flow.finalizing then
    task.spawn(H.ClosePortal,entrance,function() if stopEntrance then stopEntrance() end end)
    if exit then task.spawn(H.ClosePortal,exit,stopExit) end
    break
   end
   completedHops += 1
   flow.lastTeleportAt = os.clock()
   -- Clone after the teleport so its own independent chain starts at the exit.
   if model.Parent and math.random() < C.CLONE_CHANCE then H.SpawnChainClone(model) end
   task.spawn(H.ClosePortal,entrance,function() if stopEntrance then stopEntrance() end end)
   task.delay(C.LINGER_TIME,function() H.ClosePortal(exit,stopExit) end)
   -- The previous exit is already blue if this prototype detour was selected.
   H.MaybeRunBlueFallingLoop(model,flow,blueAfterExit)
   if model.Parent then RunService.Heartbeat:Wait() end
  end
 end)
 H.StopOpaqueBypass(model)
 activeFlows[model]=nil
 if not ok then warn("[Portal Ragdoll] Error:",err) end
 processing[model]=nil
end

-- Ragdoll discovery belongs exclusively to the FunnyRagdolls loader.
-- All original helpers, physics and timer behavior above are preserved.
return H.ProcessRagdoll
