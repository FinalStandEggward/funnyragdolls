local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = _G.RagdollConfig

if not Config then
    warn("RagdollConfig was not initialized.")
    return
end

local RagdollFolder = Workspace:WaitForChild("Ragdolls")

local FURNACE_DISTANCE = Config.FURNACE_DISTANCE
local FURNACE_SIZE = Config.FURNACE_SIZE
local FURNACE_PULL_DELAY = Config.FURNACE_PULL_DELAY
local FURNACE_PULL_SPEED = Config.FURNACE_PULL_SPEED
local FURNACE_PULL_DURATION = Config.FURNACE_PULL_DURATION
local FURNACE_IMPACT_DELAY = Config.FURNACE_IMPACT_DELAY
local FURNACE_ENTRY_FLING_SPEED = Config.FURNACE_ENTRY_FLING_SPEED
local FURNACE_ENTRY_FLING_TIME = Config.FURNACE_ENTRY_FLING_TIME
local FURNACE_ENTRY_SPIN = Config.FURNACE_ENTRY_SPIN
local FURNACE_COMPACT_SCALE = Config.FURNACE_COMPACT_SCALE
local FURNACE_DING_DELAY = Config.FURNACE_DING_DELAY
local FURNACE_LOOF_ASSET = Config.FURNACE_LOOF_ASSET
local FURNACE_COOK_TIME = Config.FURNACE_COOK_TIME
local FURNACE_EXIT_SPEED = Config.FURNACE_EXIT_SPEED
local FURNACE_EXIT_UPWARD = Config.FURNACE_EXIT_UPWARD
local FURNACE_EXIT_DISTANCE = Config.FURNACE_EXIT_DISTANCE
local FURNACE_FADE_TIME = Config.FURNACE_FADE_TIME
local FURNACE_FIRE_PARTICLE_RATE = Config.FURNACE_FIRE_PARTICLE_RATE
local FURNACE_FIRE_TEXTURE = Config.FURNACE_FIRE_TEXTURE
local FURNACE_SMOKE_TEXTURE = Config.FURNACE_SMOKE_TEXTURE
local FURNACE_THUD_SOUND = Config.FURNACE_THUD_SOUND

local function furnaceRagdollEffect(ragdoll)
    if not ragdoll
        or not ragdoll.Parent
        or not ragdoll:IsA("Model")
    then
        return
    end

    -- Get ragdoll parts
    local ragdollParts = {}

    for _, obj in ipairs(
        ragdoll:GetDescendants()
    ) do
        if obj:IsA("BasePart") then
            table.insert(ragdollParts, obj)
        end
    end

    if #ragdollParts == 0 then
        return
    end

    local center = Vector3.zero

    for _, part in ipairs(ragdollParts) do
        center += part.Position
    end

    center /= #ragdollParts

    -- Random furnace position
    local angle =
        math.random() * math.pi * 2

    local direction =
        Vector3.new(
            math.cos(angle),
            0,
            math.sin(angle)
        ).Unit

    local furnacePosition =
        center
        + direction * FURNACE_DISTANCE

    local furnaceCFrame =
        CFrame.lookAt(
            furnacePosition,
            center
        )

    -- Create furnace
    local furnace =
        Instance.new("Part")

    furnace.Name = "RagdollFurnace"
    furnace.Size = FURNACE_SIZE
    furnace.CFrame = furnaceCFrame
    furnace.Anchored = true
    furnace.CanCollide = false
    furnace.CanTouch = false
    furnace.CanQuery = true
    furnace.Material = Enum.Material.Metal
    furnace.Transparency = 0
    furnace.Parent = Workspace

    -- Decals
    local function addDecal(face, textureId)
        local decal =
            Instance.new("Decal")

        decal.Name =
            face.Name .. "Decal"

        decal.Face = face
        decal.Texture =
            "rbxassetid://" .. textureId

        decal.Transparency = 0
        decal.Parent = furnace

        return decal
    end

    addDecal(
        Enum.NormalId.Front,
        "87665103173374"
    )

    addDecal(
        Enum.NormalId.Back,
        "7331076496"
    )

    addDecal(
        Enum.NormalId.Left,
        "7331076496"
    )

    addDecal(
        Enum.NormalId.Right,
        "7331076496"
    )

    addDecal(
        Enum.NormalId.Top,
        "7348486479"
    )

    addDecal(
        Enum.NormalId.Bottom,
        "7348486479"
    )

    local function setFrontTexture(textureId)
        if not furnace.Parent then
            return
        end

        for _, obj in ipairs(
            furnace:GetChildren()
        ) do
            if obj:IsA("Decal")
                and obj.Face == Enum.NormalId.Front
            then
                obj:Destroy()
            end
        end

        local newFront =
            Instance.new("Decal")

        newFront.Name = "FrontDecal"
        newFront.Face = Enum.NormalId.Front
        newFront.Texture =
            "rbxassetid://" .. tostring(textureId)
        newFront.Transparency = 0
        newFront.ZIndex = 10
        newFront.Parent = furnace
    end

    -- Sounds
    local furnaceSound1 =
        Instance.new("Sound")

    furnaceSound1.Name = "FurnaceSound1"

    local loofAsset = nil

    pcall(function()
        loofAsset =
            getcustomasset(FURNACE_LOOF_ASSET)
    end)

    furnaceSound1.SoundId =
        loofAsset
        or "rbxassetid://5418867840"

    furnaceSound1.Volume = 1
    furnaceSound1.Looped = false
    furnaceSound1.Parent = furnace

    local furnaceSound2 =
        Instance.new("Sound")

    furnaceSound2.Name = "FurnaceSound2"
    furnaceSound2.SoundId =
        "rbxassetid://158853971"

    furnaceSound2.Volume = 1
    furnaceSound2.Looped = true
    furnaceSound2.Parent = furnace

    -- Allow ragdoll to exist normally first
    task.wait(FURNACE_PULL_DELAY)

    if not furnace.Parent
        or not ragdoll.Parent
    then
        if furnace.Parent then
            furnace:Destroy()
        end

        return
    end

    -- Refresh parts
    ragdollParts = {}

    for _, obj in ipairs(
        ragdoll:GetDescendants()
    ) do
        if obj:IsA("BasePart") then
            table.insert(
                ragdollParts,
                obj
            )
        end
    end

    local currentCenter = Vector3.zero

    for _, part in ipairs(ragdollParts) do
        currentCenter += part.Position
    end

    if #ragdollParts > 0 then
        currentCenter /= #ragdollParts
    else
        furnace:Destroy()
        return
    end

    local currentPivot =
        ragdoll:GetPivot()

    local entryDistance =
        (FURNACE_SIZE.Z / 2) + 0.7

    local insideDistance = -0.65

    local entryPosition =
        furnace.Position
        + furnace.CFrame.LookVector
        * entryDistance

    local insidePosition =
        furnace.Position
        + furnace.CFrame.LookVector
        * insideDistance

    local entryCFrame =
        CFrame.new(entryPosition)
        * currentPivot.Rotation

    local insideCFrame =
        CFrame.new(insidePosition)
        * currentPivot.Rotation

    -- Disable collisions
    for _, part in ipairs(ragdollParts) do
        if part.Parent then
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false

            part.AssemblyAngularVelocity =
                Vector3.new(
                    math.random(
                        -FURNACE_ENTRY_SPIN,
                        FURNACE_ENTRY_SPIN
                    ),
                    math.random(
                        -FURNACE_ENTRY_SPIN,
                        FURNACE_ENTRY_SPIN
                    ),
                    math.random(
                        -FURNACE_ENTRY_SPIN,
                        FURNACE_ENTRY_SPIN
                    )
                )
        end
    end

    -- Move to furnace entrance
    local pivotValue =
        Instance.new("CFrameValue")

    pivotValue.Value = currentPivot

    local pivotConnection =
        pivotValue:GetPropertyChangedSignal(
            "Value"
        ):Connect(function()
            if ragdoll.Parent then
                ragdoll:PivotTo(
                    pivotValue.Value
                )
            end
        end)

    local approachTween =
        TweenService:Create(
            pivotValue,
            TweenInfo.new(
                0.35,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            ),
            {
                Value = entryCFrame
            }
        )

    approachTween:Play()
    approachTween.Completed:Wait()

    pivotConnection:Disconnect()
    pivotValue:Destroy()

    if not furnace.Parent
        or not ragdoll.Parent
    then
        if furnace.Parent then
            furnace:Destroy()
        end

        return
    end

    ragdoll:PivotTo(entryCFrame)

    -- Move into furnace
    local finalPivotValue =
        Instance.new("CFrameValue")

    finalPivotValue.Value = entryCFrame

    local finalPivotConnection =
        finalPivotValue:GetPropertyChangedSignal(
            "Value"
        ):Connect(function()
            if ragdoll.Parent then
                ragdoll:PivotTo(
                    finalPivotValue.Value
                )
            end
        end)

    local finalThrowTween =
        TweenService:Create(
            finalPivotValue,
            TweenInfo.new(
                0.10,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.In
            ),
            {
                Value = insideCFrame
            }
        )

    finalThrowTween:Play()
    finalThrowTween.Completed:Wait()

    finalPivotConnection:Disconnect()
    finalPivotValue:Destroy()

    if not furnace.Parent
        or not ragdoll.Parent
    then
        if furnace.Parent then
            furnace:Destroy()
        end

        return
    end

    ragdoll:PivotTo(insideCFrame)

    -- Furnace light
    local pointLight =
        Instance.new("PointLight")

    pointLight.Name = "FurnaceLight"
    pointLight.Brightness = 3
    pointLight.Range = 12
    pointLight.Shadows = true
    pointLight.Parent = furnace

    furnace.CanCollide = false

    -- Clone
    local clone

    local success =
        pcall(function()
            clone = ragdoll:Clone()
        end)

    if not success or not clone then
        if pointLight then
            pointLight:Destroy()
        end

        furnace:Destroy()
        return
    end

    clone.Name = "FurnaceRagdoll"
    clone.Parent = Workspace

    -- Make clone burnt
    for _, obj in ipairs(
        clone:GetDescendants()
    ) do
        if obj:IsA("Shirt")
            or obj:IsA("Pants")
            or obj:IsA("ShirtGraphic")
            or obj:IsA("CharacterMesh")
        then
            obj:Destroy()

        elseif obj:IsA("Decal")
            or obj:IsA("Texture")
            or obj:IsA("SurfaceAppearance")
        then
            obj:Destroy()

        elseif obj:IsA("SpecialMesh") then
            obj.TextureId =
                "rbxassetid://8039518300"

            obj.VertexColor =
                Vector3.new(0, 0, 0)
        end
    end

    -- Compact clone
    local cloneParts = {}

    for _, obj in ipairs(
        clone:GetDescendants()
    ) do
        if obj:IsA("BasePart") then
            table.insert(
                cloneParts,
                obj
            )

            obj.Color =
                Color3.new(0, 0, 0)

            obj.Material =
                Enum.Material.SmoothPlastic

            if obj:IsA("MeshPart") then
                pcall(function()
                    obj.TextureID = ""
                end)
            end

            obj.Anchored = true
            obj.CanCollide = false
            obj.CanTouch = false
            obj.CanQuery = false
            obj.Massless = false
        end
    end

    if #cloneParts == 0 then
        clone:Destroy()
        furnace:Destroy()
        return
    end

    pcall(function()
        clone:ScaleTo(
            FURNACE_COMPACT_SCALE
        )
    end)

    clone:PivotTo(furnace.CFrame)

    -- Fire/smoke host
    local flameHost =
        clone:FindFirstChild(
            "HumanoidRootPart",
            true
        )

    if not flameHost
        or not flameHost:IsA("BasePart")
    then
        flameHost = cloneParts[1]
    end

    -- Fire
    local flameParticles =
        Instance.new("ParticleEmitter")

    flameParticles.Name =
        "FurnaceFireParticles"

    flameParticles.Texture =
        FURNACE_FIRE_TEXTURE

    flameParticles.Rate =
        FURNACE_FIRE_PARTICLE_RATE

    flameParticles.Lifetime =
        NumberRange.new(1, 1)

    flameParticles.Speed =
        NumberRange.new(5, 5)

    flameParticles.SpreadAngle =
        Vector2.new(15, 15)

    flameParticles.VelocitySpread = 15
    flameParticles.Rotation =
        NumberRange.new(0, 360)

    flameParticles.RotSpeed =
        NumberRange.new(0, 100)

    flameParticles.Size =
        NumberSequence.new({
            NumberSequenceKeypoint.new(
                0,
                1.188
            ),
            NumberSequenceKeypoint.new(
                1,
                0
            )
        })

    flameParticles.Squash =
        NumberSequence.new(0)

    flameParticles.Transparency =
        NumberSequence.new({
            NumberSequenceKeypoint.new(
                0,
                0.1
            ),
            NumberSequenceKeypoint.new(
                1,
                0.1
            )
        })

    flameParticles.Brightness = 1
    flameParticles.LightEmission = 0
    flameParticles.LightInfluence = 1
    flameParticles.Orientation =
        Enum.ParticleOrientation.FacingCamera

    flameParticles.EmissionDirection =
        Enum.NormalId.Top

    flameParticles.LockedToPart = false
    flameParticles.Parent = flameHost

    -- Smoke
    local smokeParticles =
        Instance.new("ParticleEmitter")

    smokeParticles.Name =
        "FurnaceSmokeParticles"

    smokeParticles.Texture =
        FURNACE_SMOKE_TEXTURE

    smokeParticles.Rate = 20
    smokeParticles.Lifetime =
        NumberRange.new(3.3, 3.3)

    smokeParticles.Speed =
        NumberRange.new(5, 5)

    smokeParticles.SpreadAngle =
        Vector2.new(15, 15)

    smokeParticles.VelocitySpread = 15
    smokeParticles.Rotation =
        NumberRange.new(0, 360)

    smokeParticles.RotSpeed =
        NumberRange.new(0, 50)

    smokeParticles.Size =
        NumberSequence.new({
            NumberSequenceKeypoint.new(
                0,
                1
            ),
            NumberSequenceKeypoint.new(
                1,
                3.25
            )
        })

    smokeParticles.Squash =
        NumberSequence.new(0)

    smokeParticles.Transparency =
        NumberSequence.new({
            NumberSequenceKeypoint.new(
                0,
                0.35
            ),
            NumberSequenceKeypoint.new(
                1,
                0.1
            )
        })

    smokeParticles.Brightness = 1
    smokeParticles.Color =
        ColorSequence.new(
            Color3.fromRGB(80, 80, 80)
        )

    smokeParticles.LightEmission = 0
    smokeParticles.LightInfluence = 1
    smokeParticles.Orientation =
        Enum.ParticleOrientation.FacingCamera

    smokeParticles.EmissionDirection =
        Enum.NormalId.Top

    smokeParticles.LockedToPart = false
    smokeParticles.Parent = flameHost

    -- Furnace ON
    setFrontTexture(
        "101854274054509"
    )

    -- Remove original
    if ragdoll.Parent then
        ragdoll:Destroy()
    end

    furnaceSound1:Play()
    furnaceSound2:Play()

    -- Cook
    task.wait(FURNACE_COOK_TIME)

    if not furnace.Parent
        or not clone.Parent
    then
        if furnace.Parent then
            furnace:Destroy()
        end

        if clone.Parent then
            clone:Destroy()
        end

        return
    end

    -- Exit sound
    local exitSound =
        Instance.new("Sound")

    exitSound.Name = "FurnaceExit"
    exitSound.SoundId =
        "rbxassetid://114005773348535"

    exitSound.Volume = 1
    exitSound.Parent = furnace
    exitSound:Play()

    if pointLight then
        pointLight:Destroy()
        pointLight = nil
    end

    task.wait(FURNACE_DING_DELAY)

    -- Full-size again
    pcall(function()
        clone:ScaleTo(1)
    end)

    local exitPosition =
        furnace.Position
        + furnace.CFrame.LookVector
        * (
            FURNACE_SIZE.Z / 2
            + FURNACE_EXIT_DISTANCE
        )

    clone:PivotTo(
        CFrame.new(exitPosition)
        * furnace.CFrame.Rotation
    )

    -- Launch out
    for _, part in ipairs(cloneParts) do
        if part.Parent then
            part.Anchored = false
            part.CanCollide = true
            part.CanTouch = true
            part.CanQuery = true

            local exitVelocity =
                furnace.CFrame.LookVector
                * FURNACE_EXIT_SPEED
                + Vector3.new(
                    0,
                    FURNACE_EXIT_UPWARD,
                    0
                )

            part.AssemblyLinearVelocity =
                exitVelocity

            pcall(function()
                part:ApplyImpulse(
                    exitVelocity
                    * part.AssemblyMass
                )
            end)
        end
    end

    -- Thud
    local thudSound =
        Instance.new("Sound")

    thudSound.Name =
        "FurnaceRagdollThud"

    thudSound.SoundId =
        FURNACE_THUD_SOUND

    thudSound.Volume = 1
    thudSound.RollOffMaxDistance = 80
    thudSound.Parent = flameHost

    local thudDebounce = false

    local function playThud(hit)
        if thudDebounce
            or not clone.Parent
            or not hit
        then
            return
        end

        if hit:IsDescendantOf(clone) then
            return
        end

        thudDebounce = true

        thudSound:Stop()
        thudSound.TimePosition = 0
        thudSound:Play()

        task.delay(0.12, function()
            thudDebounce = false
        end)
    end

    for _, part in ipairs(cloneParts) do
        if part.Parent then
            part.Touched:Connect(
                playThud
            )
        end
    end

    -- Restore furnace texture
    task.wait(0.2)

    if furnace.Parent then
        setFrontTexture(
            "87665103173374"
        )
    end

    furnaceSound1:Stop()
    furnaceSound2:Stop()

    -- Fade furnace
    local fadeInfo =
        TweenInfo.new(
            FURNACE_FADE_TIME,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )

    TweenService:Create(
        furnace,
        fadeInfo,
        {
            Transparency = 1
        }
    ):Play()

    for _, obj in ipairs(
        furnace:GetChildren()
    ) do
        if obj:IsA("Decal") then
            TweenService:Create(
                obj,
                fadeInfo,
                {
                    Transparency = 1
                }
            ):Play()
        end
    end

    Debris:AddItem(
        furnace,
        FURNACE_FADE_TIME + 0.1
    )

    Debris:AddItem(
        exitSound,
        3
    )
end

-- Existing ragdolls
for _, existing in ipairs(
    RagdollFolder:GetChildren()
) do
    task.spawn(
        furnaceRagdollEffect,
        existing
    )
end

-- New ragdolls
RagdollFolder.ChildAdded:Connect(
    function(child)
        task.spawn(
            furnaceRagdollEffect,
            child
        )
    end
)
