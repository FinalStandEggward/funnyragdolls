--==================================================
-- EXPLOSION / GIB EFFECT
--==================================================

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")


return function(model, CONFIG)

    if not model or not model:IsA("Model") then
        return
    end


    --==================================================
    -- DESCENDANTS
    --==================================================

    local descendants =
        model:GetDescendants()


    --==================================================
    -- CENTER
    --==================================================

    local explosionPosition =
        model:GetPivot().Position


    --==================================================
    -- COSMETIC EXPLOSION
    --==================================================

    local explosion =
        Instance.new("Explosion")

    explosion.Position =
        explosionPosition

    explosion.BlastRadius = 0
    explosion.BlastPressure = 0

    explosion.DestroyJointRadiusPercent = 0

    explosion.ExplosionType =
        Enum.ExplosionType.NoCraters

    explosion.Parent =
        Workspace


    --==================================================
    -- BOOM SOUND
    --==================================================

    local soundPart =
        Instance.new("Part")

    soundPart.Name =
        "GibBoom"

    soundPart.Anchored = true
    soundPart.CanCollide = false
    soundPart.CanTouch = false
    soundPart.CanQuery = false

    soundPart.Transparency = 1
    soundPart.Size =
        Vector3.new(1, 1, 1)

    soundPart.Position =
        explosionPosition

    soundPart.Parent =
        Workspace


    local sound =
        Instance.new("Sound")

    sound.SoundId =
        CONFIG.SOUND_ID

    sound.Volume = 1
    sound.RollOffMaxDistance = 100

    sound.Parent =
        soundPart

    sound:Play()

    Debris:AddItem(
        soundPart,
        5
    )


    --==================================================
    -- CRITICAL HIT IMAGE
    --==================================================

    local effectPart =
        Instance.new("Part")

    effectPart.Name =
        "CriticalHitEffect"

    effectPart.Anchored = true
    effectPart.CanCollide = false
    effectPart.CanTouch = false
    effectPart.CanQuery = false

    effectPart.Transparency = 1

    effectPart.Size =
        Vector3.new(1, 1, 1)

    effectPart.Position =
        explosionPosition

    effectPart.Parent =
        Workspace


    local billboard =
        Instance.new("BillboardGui")

    billboard.Name =
        "CriticalHit"

    billboard.Adornee =
        effectPart

    billboard.AlwaysOnTop = false
    billboard.LightInfluence = 0

    billboard.Size =
        UDim2.fromOffset(
            250,
            250
        )

    billboard.StudsOffset =
        Vector3.zero

    billboard.Parent =
        effectPart


    local image =
        Instance.new("ImageLabel")

    image.Name =
        "CriticalImage"

    image.BackgroundTransparency = 1
    image.BorderSizePixel = 0

    image.Image =
        CONFIG.IMAGE_ID

    image.ImageTransparency = 1

    image.Size =
        UDim2.fromScale(1, 1)

    image.Parent =
        billboard


    --==================================================
    -- IMAGE POP
    --==================================================

    local popTween =
        TweenService:Create(
            image,
            TweenInfo.new(
                0.12,
                Enum.EasingStyle.Back,
                Enum.EasingDirection.Out
            ),
            {
                ImageTransparency = 0
            }
        )

    popTween:Play()


    --==================================================
    -- IMAGE RISE / FADE
    --==================================================

    task.delay(0.4, function()

        if not effectPart.Parent then
            return
        end


        local riseTween =
            TweenService:Create(
                effectPart,
                TweenInfo.new(
                    0.5,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {
                    Position =
                        explosionPosition
                        + Vector3.new(0, 3, 0)
                }
            )


        local fadeTween =
            TweenService:Create(
                image,
                TweenInfo.new(
                    0.5,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {
                    ImageTransparency = 1
                }
            )


        riseTween:Play()
        fadeTween:Play()


        fadeTween.Completed:Connect(function()

            if effectPart then
                effectPart:Destroy()
            end

        end)

    end)


    --==================================================
    -- REMOVE JOINTS / CONSTRAINTS
    --==================================================

    for _, obj in ipairs(descendants) do

        if obj:IsA("Motor6D")
            or obj:IsA("Weld")
            or obj:IsA("WeldConstraint")
            or obj:IsA("HingeConstraint")
            or obj:IsA("BallSocketConstraint")
            or obj:IsA("RodConstraint")
            or obj:IsA("RopeConstraint")
            or obj:IsA("SpringConstraint")
            or obj:IsA("AlignPosition")
            or obj:IsA("AlignOrientation")
            or obj:IsA("Attachment") then

            obj:Destroy()
        end
    end


    --==================================================
    -- REMOVE ROOT
    --==================================================

    local root =
        model:FindFirstChild(
            "HumanoidRootPart"
        )

    if root then
        root:Destroy()
    end


    --==================================================
    -- BLOOD FUNCTIONS
    --==================================================

    local bloodCooldown = {}


    local function createBloodPixel(
        position,
        normal,
        finalSize,
        rotation
    )

        local blood =
            Instance.new("Part")

        blood.Name =
            "PixelBlood"

        blood.Anchored = true
        blood.CanCollide = false
        blood.CanTouch = false
        blood.CanQuery = false

        blood.Material =
            Enum.Material.SmoothPlastic

        blood.Color =
            CONFIG.BLOOD_COLOR

        blood.Size =
            Vector3.new(
                0.03,
                0.02,
                0.03
            )


        local surfacePosition =
            position
            + normal
            * CONFIG.BLOOD_SURFACE_OFFSET


        local surfaceCFrame =
            CFrame.lookAlong(
                surfacePosition,
                normal
            )
            * CFrame.Angles(
                -math.pi / 2,
                0,
                0
            )
            * CFrame.Angles(
                0,
                rotation,
                0
            )


        blood.CFrame =
            surfaceCFrame

        blood.Parent =
            Workspace


        local expandTween =
            TweenService:Create(
                blood,
                TweenInfo.new(
                    CONFIG.BLOOD_EXPAND_TIME,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                {
                    Size =
                        Vector3.new(
                            finalSize,
                            0.02,
                            finalSize
                        )
                }
            )

        expandTween:Play()


        Debris:AddItem(
            blood,
            CONFIG.BLOOD_LIFETIME
        )
    end


    local function spawnPixelSplatter(
        position,
        normal
    )

        local amount =
            math.random(
                CONFIG.BLOOD_MIN_PARTS,
                CONFIG.BLOOD_MAX_PARTS
            )


        for i = 1, amount do

            local randomX =
                math.random(-100, 100) / 100

            local randomZ =
                math.random(-100, 100) / 100


            local spreadOffset =
                Vector3.new(
                    randomX,
                    0,
                    randomZ
                )


            if spreadOffset.Magnitude > 0 then

                spreadOffset =
                    spreadOffset.Unit
                    * math.random(10, 100) / 100
                    * CONFIG.BLOOD_SPREAD

            end


            local targetPosition =
                position
                + spreadOffset
                + normal * 0.5


            local rayParams =
                RaycastParams.new()

            rayParams.FilterType =
                Enum.RaycastFilterType.Include


            local map =
                Workspace:FindFirstChild("Map")

            local domains =
                Workspace:FindFirstChild("Domains")


            local filter = {}


            if map then
                table.insert(
                    filter,
                    map
                )
            end


            if domains then
                table.insert(
                    filter,
                    domains
                )
            end


            rayParams.FilterDescendantsInstances =
                filter


            local result =
                Workspace:Raycast(
                    targetPosition,
                    -normal * 2,
                    rayParams
                )


            if result then

                local finalSize =
                    math.random(
                        CONFIG.BLOOD_MIN_SIZE * 100,
                        CONFIG.BLOOD_MAX_SIZE * 100
                    ) / 100


                local rotation =
                    math.random(0, 360)


                createBloodPixel(
                    result.Position,
                    result.Normal,
                    finalSize,
                    math.rad(rotation)
                )

            end
        end
    end


    local function setupBloodTouch(part)

        if not part:IsA("BasePart") then
            return
        end


        part.Touched:Connect(function(hit)

            if not hit
                or not hit:IsA("BasePart") then

                return
            end


            if part.Parent
                and hit:IsDescendantOf(part.Parent) then

                return
            end


            if hit.Parent
                and hit.Parent:FindFirstChildOfClass(
                    "Humanoid"
                ) then

                return
            end


            if bloodCooldown[part] then
                return
            end


            bloodCooldown[part] = true


            local rayParams =
                RaycastParams.new()

            rayParams.FilterType =
                Enum.RaycastFilterType.Include


            local map =
                Workspace:FindFirstChild("Map")

            local domains =
                Workspace:FindFirstChild("Domains")


            local filter = {}


            if map then
                table.insert(
                    filter,
                    map
                )
            end


            if domains then
                table.insert(
                    filter,
                    domains
                )
            end


            rayParams.FilterDescendantsInstances =
                filter


            local upVector =
                part.CFrame.UpVector


            local result =
                Workspace:Raycast(
                    part.Position + upVector,
                    -upVector * 4,
                    rayParams
                )


            if result then

                spawnPixelSplatter(
                    result.Position,
                    result.Normal
                )

            end


            task.delay(
                CONFIG.BLOOD_COOLDOWN,
                function()

                    bloodCooldown[part] = nil

                end
            )

        end)
    end


    --==================================================
    -- TURN LIMBS INTO GIBS
    --==================================================

    for _, obj in ipairs(descendants) do

        if obj:IsA("BasePart")
            and obj.Parent then

            if obj.Name ~= "HumanoidRootPart" then

                obj.Anchored = false
                obj.CanCollide = true
                obj.CanTouch = true
                obj.CanQuery = true

                obj.CollisionGroup =
                    "Default"

                obj.Massless = false


                setupBloodTouch(obj)


                obj.CFrame =
                    obj.CFrame
                    + Vector3.new(
                        0,
                        0.15,
                        0
                    )


                obj.AssemblyLinearVelocity =
                    Vector3.new(
                        math.random(-45, 45),
                        math.random(50, 80),
                        math.random(-45, 45)
                    )


                obj.AssemblyAngularVelocity =
                    Vector3.new(
                        math.random(-8, 8),
                        math.random(-8, 8),
                        math.random(-8, 8)
                    )

            end
        end
    end

end
