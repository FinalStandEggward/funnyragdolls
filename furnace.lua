--==================================================
-- FURNACE EFFECT
--==================================================

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")


return function(ragdoll, CONFIG)

    if not ragdoll
        or not ragdoll.Parent
        or not ragdoll:IsA("Model") then
        return
    end


    --==================================================
    -- GET RAGDOLL PARTS / CENTER
    --==================================================

    local ragdollParts = {}

    for _, obj in ipairs(ragdoll:GetDescendants()) do
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


    --==================================================
    -- RANDOM FURNACE POSITION
    --==================================================

    local angle = math.random() * math.pi * 2

    local direction = Vector3.new(
        math.cos(angle),
        0,
        math.sin(angle)
    ).Unit

    local furnacePosition =
        center + direction * CONFIG.FURNACE_DISTANCE

    local furnaceCFrame = CFrame.lookAt(
        furnacePosition,
        center
    )


    --==================================================
    -- CREATE FURNACE
    --==================================================

    local furnace = Instance.new("Part")

    furnace.Name = "RagdollFurnace"
    furnace.Size = CONFIG.FURNACE_SIZE
    furnace.CFrame = furnaceCFrame

    furnace.Anchored = true
    furnace.CanCollide = false
    furnace.CanTouch = false
    furnace.CanQuery = true

    furnace.Material = Enum.Material.Metal
    furnace.Transparency = 0

    furnace.Parent = Workspace


    --==================================================
    -- FURNACE DECALS
    --==================================================

    local function addDecal(face, textureId)

        local decal = Instance.new("Decal")

        decal.Name = face.Name .. "Decal"
        decal.Face = face
        decal.Texture = "rbxassetid://" .. textureId
        decal.Transparency = 0

        decal.Parent = furnace

        return decal
    end


    local frontDecal = addDecal(
        Enum.NormalId.Front,
        "87665103173374"
    )

    addDecal(Enum.NormalId.Back, "7331076496")
    addDecal(Enum.NormalId.Left, "7331076496")
    addDecal(Enum.NormalId.Right, "7331076496")

    addDecal(Enum.NormalId.Top, "7348486479")
    addDecal(Enum.NormalId.Bottom, "7348486479")


    local function setFrontTexture(textureId)

        if not furnace.Parent then
            return
        end

        for _, obj in ipairs(furnace:GetChildren()) do
            if obj:IsA("Decal")
                and obj.Face == Enum.NormalId.Front then

                obj:Destroy()
            end
        end

        local newFront = Instance.new("Decal")

        newFront.Name = "FrontDecal"
        newFront.Face = Enum.NormalId.Front
        newFront.Texture = "rbxassetid://" .. tostring(textureId)

        newFront.Transparency = 0
        newFront.ZIndex = 10

        newFront.Parent = furnace

        frontDecal = newFront
    end


    --==================================================
    -- SOUNDS
    --==================================================

    local furnaceSound1 = Instance.new("Sound")

    furnaceSound1.Name = "FurnaceSound1"

    local loofAsset

    pcall(function()
        if getcustomasset then
            loofAsset = getcustomasset(
                CONFIG.FURNACE_LOOF_ASSET
            )
        end
    end)

    furnaceSound1.SoundId =
        loofAsset or "rbxassetid://5418867840"

    furnaceSound1.Volume = 1
    furnaceSound1.Looped = false

    furnaceSound1.Parent = furnace


    local furnaceSound2 = Instance.new("Sound")

    furnaceSound2.Name = "FurnaceSound2"
    furnaceSound2.SoundId = "rbxassetid://158853971"

    furnaceSound2.Volume = 1
    furnaceSound2.Looped = true

    furnaceSound2.Parent = furnace


    --==================================================
    -- WAIT
    --==================================================

    task.wait(CONFIG.FURNACE_PULL_DELAY)

    if not furnace.Parent
        or not ragdoll.Parent then

        if furnace.Parent then
            furnace:Destroy()
        end

        return
    end


    --==================================================
    -- REFRESH PARTS
    --==================================================

    ragdollParts = {}

    for _, obj in ipairs(ragdoll:GetDescendants()) do
        if obj:IsA("BasePart") then
            table.insert(ragdollParts, obj)
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


    --==================================================
    -- ENTRY
    --==================================================

    local currentPivot = ragdoll:GetPivot()

    local entryDistance =
        (CONFIG.FURNACE_SIZE.Z / 2) + 0.7

    local insideDistance = -0.65

    local entryPosition =
        furnace.Position
        + furnace.CFrame.LookVector * entryDistance

    local insidePosition =
        furnace.Position
        + furnace.CFrame.LookVector * insideDistance

    local entryCFrame =
        CFrame.new(entryPosition)
        * currentPivot.Rotation

    local insideCFrame =
        CFrame.new(insidePosition)
        * currentPivot.Rotation


    for _, part in ipairs(ragdollParts) do

        if part.Parent then

            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false

            part.AssemblyAngularVelocity =
                Vector3.new(
                    math.random(
                        -CONFIG.FURNACE_ENTRY_SPIN,
                        CONFIG.FURNACE_ENTRY_SPIN
                    ),
                    math.random(
                        -CONFIG.FURNACE_ENTRY_SPIN,
                        CONFIG.FURNACE_ENTRY_SPIN
                    ),
                    math.random(
                        -CONFIG.FURNACE_ENTRY_SPIN,
                        CONFIG.FURNACE_ENTRY_SPIN
                    )
                )
        end
    end


    local pivotValue = Instance.new("CFrameValue")

    pivotValue.Value = currentPivot

    local pivotConnection =
        pivotValue:GetPropertyChangedSignal("Value"):Connect(
            function()

                if ragdoll.Parent then
                    ragdoll:PivotTo(pivotValue.Value)
                end

            end
        )


    local approachTween = TweenService:Create(
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
        or not ragdoll.Parent then

        if furnace.Parent then
            furnace:Destroy()
        end

        return
    end


    ragdoll:PivotTo(entryCFrame)


    --==================================================
    -- THROW INTO FURNACE
    --==================================================

    local finalPivotValue = Instance.new("CFrameValue")

    finalPivotValue.Value = entryCFrame

    local finalPivotConnection =
        finalPivotValue:GetPropertyChangedSignal("Value"):Connect(
            function()

                if ragdoll.Parent then
                    ragdoll:PivotTo(finalPivotValue.Value)
                end

            end
        )


    local finalThrowTween = TweenService:Create(
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
        or not ragdoll.Parent then

        if furnace.Parent then
            furnace:Destroy()
        end

        return
    end


    ragdoll:PivotTo(insideCFrame)


    --==================================================
    -- LIGHT
    --==================================================

    local pointLight = Instance.new("PointLight")

    pointLight.Name = "FurnaceLight"
    pointLight.Brightness = 3
    pointLight.Range = 12
    pointLight.Shadows = true

    pointLight.Parent = furnace


    furnace.CanCollide = false


    --==================================================
    -- CLONE
    --==================================================

    local clone

    local success = pcall(function()
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


    --==================================================
    -- BURNT LOOK
    --==================================================

    for _, obj in ipairs(clone:GetDescendants()) do

        if obj:IsA("Shirt")
            or obj:IsA("Pants")
            or obj:IsA("ShirtGraphic")
            or obj:IsA("CharacterMesh") then

            obj:Destroy()

        elseif obj:IsA("Decal")
            or obj:IsA("Texture")
            or obj:IsA("SurfaceAppearance") then

            obj:Destroy()

        elseif obj:IsA("SpecialMesh") then

            obj.TextureId = "rbxassetid://8039518300"
            obj.VertexColor = Vector3.new(0, 0, 0)

        end
    end


    --==================================================
    -- COMPACT CLONE
    --==================================================

    local cloneParts = {}

    for _, obj in ipairs(clone:GetDescendants()) do

        if obj:IsA("BasePart") then

            table.insert(cloneParts, obj)

            obj.Color = Color3.new(0, 0, 0)
            obj.Material = Enum.Material.SmoothPlastic

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
            CONFIG.FURNACE_COMPACT_SCALE
        )
    end)

    clone:PivotTo(furnace.CFrame)


    --==================================================
    -- FIRE / SMOKE
    --==================================================

    local flameHost =
        clone:FindFirstChild(
            "HumanoidRootPart",
            true
        )

    if not flameHost
        or not flameHost:IsA("BasePart") then

        flameHost = cloneParts[1]
    end


    local flameParticles =
        Instance.new("ParticleEmitter")

    flameParticles.Name =
        "FurnaceFireParticles"

    flameParticles.Texture =
        CONFIG.FURNACE_FIRE_TEXTURE

    flameParticles.Rate =
        CONFIG.FURNACE_FIRE_PARTICLE_RATE

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
            NumberSequenceKeypoint.new(0, 1.188),
            NumberSequenceKeypoint.new(1, 0)
        })

    flameParticles.Squash =
        NumberSequence.new(0)

    flameParticles.Transparency =
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(1, 0.1)
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


    local smokeParticles =
        Instance.new("ParticleEmitter")

    smokeParticles.Name =
        "FurnaceSmokeParticles"

    smokeParticles.Texture =
        CONFIG.FURNACE_SMOKE_TEXTURE

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
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 3.25)
        })

    smokeParticles.Squash =
        NumberSequence.new(0)

    smokeParticles.Transparency =
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(1, 0.1)
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


    --==================================================
    -- FURNACE ON
    --==================================================

    setFrontTexture("101854274054509")


    if ragdoll.Parent then
        ragdoll:Destroy()
    end


    furnaceSound1:Play()
    furnaceSound2:Play()


    --==================================================
    -- COOK
    --==================================================

    task.wait(CONFIG.FURNACE_COOK_TIME)


    if not furnace.Parent
        or not clone.Parent then

        if furnace.Parent then
            furnace:Destroy()
        end

        if clone.Parent then
            clone:Destroy()
        end

        return
    end


    --==================================================
    -- EXIT SOUND
    --==================================================

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


    task.wait(CONFIG.FURNACE_DING_DELAY)


    --==================================================
    -- LAUNCH OUT
    --==================================================

    pcall(function()
        clone:ScaleTo(1)
    end)


    local exitPosition =
        furnace.Position
        + furnace.CFrame.LookVector
        * (
            CONFIG.FURNACE_SIZE.Z / 2
            + CONFIG.FURNACE_EXIT_DISTANCE
        )


    clone:PivotTo(
        CFrame.new(exitPosition)
        * furnace.CFrame.Rotation
    )


    for _, part in ipairs(cloneParts) do

        if part.Parent then

            part.Anchored = false
            part.CanCollide = true
            part.CanTouch = true
            part.CanQuery = true

            local exitVelocity =
                furnace.CFrame.LookVector
                * CONFIG.FURNACE_EXIT_SPEED
                + Vector3.new(
                    0,
                    CONFIG.FURNACE_EXIT_UPWARD,
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


    --==================================================
    -- THUD
    --==================================================

    local thudSound =
        Instance.new("Sound")

    thudSound.Name =
        "FurnaceRagdollThud"

    thudSound.SoundId =
        CONFIG.FURNACE_THUD_SOUND

    thudSound.Volume = 1
    thudSound.RollOffMaxDistance = 80

    thudSound.Parent = flameHost


    local thudDebounce = false

    local function playThud(hit)

        if thudDebounce
            or not clone.Parent
            or not hit then

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
            part.Touched:Connect(playThud)
        end
    end


    --==================================================
    -- RESTORE FURNACE
    --==================================================

    task.wait(0.2)

    if furnace.Parent then
        setFrontTexture("87665103173374")
    end

    furnaceSound1:Stop()
    furnaceSound2:Stop()


    --==================================================
    -- FADE FURNACE
    --==================================================

    local fadeInfo = TweenInfo.new(
        CONFIG.FURNACE_FADE_TIME,
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


    for _, obj in ipairs(furnace:GetChildren()) do

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
        CONFIG.FURNACE_FADE_TIME + 0.1
    )

    Debris:AddItem(exitSound, 3)

end
