
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local function createLightningPart(startPosition, endPosition, thickness)
    local distance = (endPosition - startPosition).Magnitude

    local part = Instance.new("Part")
    part.Name = "LightningBolt"
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(220, 240, 255)

    part.Size = Vector3.new(thickness, thickness, distance)
    part.CFrame = CFrame.lookAt(
        (startPosition + endPosition) / 2,
        endPosition
    )

    part.Parent = Workspace
    Debris:AddItem(part, 0.25)
end

local function createMainBolt(startPosition, targetPosition, thickness)
    local points = {startPosition}
    local segments = 14

    for i = 1, segments do
        local progress = i / segments
        local nextPosition = startPosition:Lerp(targetPosition, progress)

        if i < segments then
            nextPosition += Vector3.new(
                math.random(-5, 5),
                math.random(-2, 2),
                math.random(-5, 5)
            )
        end

        table.insert(points, nextPosition)
    end

    for i = 1, #points - 1 do
        createLightningPart(
            points[i],
            points[i + 1],
            thickness
        )
    end

    return points
end

local function createBranch(startPosition, thickness)
    local current = startPosition
    local length = math.random(4, 7)

    for _ = 1, length do
        local nextPosition = current + Vector3.new(
            math.random(-6, 6),
            math.random(-4, 2),
            math.random(-6, 6)
        )

        createLightningPart(
            current,
            nextPosition,
            thickness
        )

        current = nextPosition
    end
end

local function lightningFlash(position)
    local flashPart = Instance.new("Part")
    flashPart.Name = "LightningFlash"
    flashPart.Anchored = true
    flashPart.CanCollide = false
    flashPart.CanTouch = false
    flashPart.CanQuery = false
    flashPart.Transparency = 1
    flashPart.Size = Vector3.new(2, 2, 2)
    flashPart.Position = position
    flashPart.Parent = Workspace

    local light = Instance.new("PointLight")
    light.Brightness = 25
    light.Range = 60
    light.Color = Color3.fromRGB(200, 225, 255)
    light.Parent = flashPart

    task.spawn(function()
        task.wait(0.05)

        if light.Parent then
            light.Brightness = 8
        end

        task.wait(0.08)

        if light.Parent then
            light.Brightness = 0
        end
    end)

    Debris:AddItem(flashPart, 0.3)
end

local function playThunder(position, soundId, volume)
    local soundPart = Instance.new("Part")
    soundPart.Name = "LightningThunder"
    soundPart.Anchored = true
    soundPart.CanCollide = false
    soundPart.CanTouch = false
    soundPart.CanQuery = false
    soundPart.Transparency = 1
    soundPart.Position = position
    soundPart.Parent = Workspace

    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume
    sound.RollOffMaxDistance = 500
    sound.RollOffMinDistance = 50
    sound.Parent = soundPart
    sound:Play()

    Debris:AddItem(soundPart, 10)
end

local function blackenObject(object, meshTexture)
    if object:IsA("BasePart") then
        object.Color = Color3.new(0, 0, 0)
        object.Material = Enum.Material.SmoothPlastic
        object.Reflectance = 0
    end

    if object:IsA("SpecialMesh") then
        object.TextureId = meshTexture
        object.VertexColor = Vector3.new(0, 0, 0)
    end

    if object:IsA("SurfaceAppearance")
        or object:IsA("Texture")
        or object:IsA("Decal") then
        object:Destroy()
    end
end

local function charRagdoll(model, meshTexture)
    for _, object in ipairs(model:GetDescendants()) do
        blackenObject(object, meshTexture)
    end

    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("Shirt")
            or object:IsA("Pants")
            or object:IsA("ShirtGraphic")
            or object:IsA("CharacterMesh") then
            object:Destroy()
        end
    end
end

local function addBurningEffects(model, fireTexture, smokeTexture)
    local root = model:FindFirstChild("HumanoidRootPart", true)

    if not root or not root:IsA("BasePart") then
        return
    end

    if root:FindFirstChild("LightningFireAttachment") then
        return
    end

    local attachment = Instance.new("Attachment")
    attachment.Name = "LightningFireAttachment"
    attachment.Parent = root

    local fire = Instance.new("ParticleEmitter")
    fire.Name = "LightningFire"
    fire.Texture = fireTexture
    fire.Rate = 100
    fire.Lifetime = NumberRange.new(1, 1)
    fire.Speed = NumberRange.new(5, 5)
    fire.EmissionDirection = Enum.NormalId.Top
    fire.SpreadAngle = Vector2.new(15, 15)
    fire.VelocitySpread = 15
    fire.Rotation = NumberRange.new(0, 360)
    fire.RotSpeed = NumberRange.new(0, 100)
    fire.LightEmission = 0
    fire.LightInfluence = 1

    fire.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 1)
    })

    fire.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 0)
    })

    fire.Parent = attachment

    local smoke = Instance.new("ParticleEmitter")
    smoke.Name = "LightningSmoke"
    smoke.Texture = smokeTexture
    smoke.Rate = 20
    smoke.Lifetime = NumberRange.new(3.3, 3.3)
    smoke.Speed = NumberRange.new(5, 5)
    smoke.EmissionDirection = Enum.NormalId.Top
    smoke.SpreadAngle = Vector2.new(15, 15)
    smoke.VelocitySpread = 15
    smoke.Rotation = NumberRange.new(0, 360)
    smoke.RotSpeed = NumberRange.new(0, 50)
    smoke.LightEmission = 0
    smoke.LightInfluence = 1

    smoke.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.25),
        NumberSequenceKeypoint.new(1, 1.25)
    })

    smoke.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(1, 0.35)
    })

    smoke.Parent = attachment
end

local function bounceRagdoll(model, upwardSpeed, sideSpeed, spin)
    local root = model:FindFirstChild("HumanoidRootPart", true)

    if root and root:IsA("BasePart") then
        root.AssemblyLinearVelocity = Vector3.new(
            math.random(-sideSpeed, sideSpeed),
            upwardSpeed,
            math.random(-sideSpeed, sideSpeed)
        )

        root.AssemblyAngularVelocity = Vector3.new(
            math.random(-spin, spin),
            math.random(-spin, spin),
            math.random(-spin, spin)
        )

        root:ApplyImpulse(
            Vector3.new(0, root.AssemblyMass * 12, 0)
        )

        return
    end

    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("BasePart") then
            object.AssemblyLinearVelocity = Vector3.new(
                math.random(-sideSpeed, sideSpeed),
                upwardSpeed,
                math.random(-sideSpeed, sideSpeed)
            )

            break
        end
    end
end

local function strikeRagdoll(model, CONFIG)
    if not model or not model.Parent then
        return
    end

    if model:GetAttribute("LightningStruck") then
        return
    end

    local root = model:FindFirstChild("HumanoidRootPart", true)

    if not root or not root:IsA("BasePart") then
        return
    end

    model:SetAttribute("LightningStruck", true)

    local targetPosition = root.Position

    local startPosition = targetPosition + Vector3.new(
        math.random(-CONFIG.LIGHTNING_RADIUS, CONFIG.LIGHTNING_RADIUS),
        CONFIG.LIGHTNING_HEIGHT,
        math.random(-CONFIG.LIGHTNING_RADIUS, CONFIG.LIGHTNING_RADIUS)
    )

    local points = createMainBolt(
        startPosition,
        targetPosition,
        CONFIG.LIGHTNING_MAIN_THICKNESS
    )

    for i = 2, #points - 2 do
        if math.random() < 0.45 then
            createBranch(
                points[i],
                CONFIG.LIGHTNING_BRANCH_THICKNESS
            )
        end
    end

    lightningFlash(targetPosition)

    playThunder(
        targetPosition,
        CONFIG.LIGHTNING_THUNDER_SOUND_ID,
        CONFIG.LIGHTNING_THUNDER_VOLUME
    )

    charRagdoll(
        model,
        CONFIG.LIGHTNING_CHARRED_MESH_TEXTURE
    )

    addBurningEffects(
        model,
        CONFIG.LIGHTNING_FIRE_TEXTURE,
        CONFIG.LIGHTNING_SMOKE_TEXTURE
    )

    bounceRagdoll(
        model,
        CONFIG.LIGHTNING_BOUNCE_UPWARD_SPEED,
        CONFIG.LIGHTNING_BOUNCE_SIDE_SPEED,
        CONFIG.LIGHTNING_BOUNCE_SPIN
    )
end

return function(ragdoll, CONFIG)
    task.wait(CONFIG.LIGHTNING_STRIKE_DELAY)

    if ragdoll.Parent then
        strikeRagdoll(ragdoll, CONFIG)
    end
end

