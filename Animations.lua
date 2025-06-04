-- Animations.lua: Animation management module for SnowtUI
-- Provides tweening, keyframe animations, and easing functions
-- Dependencies: Core.lua, Theme.lua, Config.lua, Icons.lua
local Animations = {}
Animations.Version = "1.0.0"
Animations.Dependencies = { "Core", "Theme", "Config", "Icons" }

-- Services
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Internal state
local activeAnimations = {} -- Tracks running animations
local defaultEasingStyle = Enum.EasingStyle.Quad
local defaultEasingDirection = Enum.EasingDirection.InOut
local defaultDuration = 0.3 -- Seconds

-- Initialize module with SnowtUI context
function Animations.init(params)
    local SnowtUI = params.SnowtUIInstance
    Animations.SnowtUI = SnowtUI
    Animations.Theme = SnowtUI:GetModule("Theme")
    Animations.Config = SnowtUI:GetModule("Config")
    Animations.Icons = SnowtUI:GetModule("Icons")
    
    -- Check if animations are enabled
    Animations.enabled = Animations.Config:get("AnimationsEnabled", true)
end

-- Create a tween animation
function Animations.tween(element, properties, duration, easingStyle, easingDirection, callback)
    if not Animations.enabled then
        -- Apply properties instantly if animations are disabled
        for prop, value in pairs(properties) do
            element[prop] = value
        end
        if callback then callback() end
        return nil
    end

    if not element or not properties then
        warn("Animations.tween: Missing element or properties")
        return nil
    end

    duration = duration or Animations.Theme:get("AnimationDuration", defaultDuration)
    easingStyle = easingStyle or Animations.Theme:get("AnimationEasingStyle", defaultEasingStyle)
    easingDirection = easingDirection or Animations.Theme:get("AnimationEasingDirection", defaultEasingDirection)

    local tweenInfo = TweenInfo.new(
        duration,
        easingStyle,
        easingDirection,
        0, -- Repeat count
        false, -- Reverses
        0 -- Delay
    )

    local tween = TweenService:Create(element, tweenInfo, properties)
    local animationId = HttpService:GenerateGUID(false)
    activeAnimations[animationId] = tween

    tween.Completed:Connect(function()
        activeAnimations[animationId] = nil
        if callback then callback() end
    end)

    tween:Play()
    return animationId
end

-- Create a keyframe animation (sequence of tweens)
function Animations.keyframe(element, keyframes, callback)
    if not Animations.enabled then
        -- Apply final keyframe properties instantly
        local lastFrame = keyframes[#keyframes]
        if lastFrame and lastFrame.properties then
            for prop, value in pairs(lastFrame.properties) do
                element[prop] = value
            end
        end
        if callback then callback() end
        return nil
    end

    if not element or not keyframes or #keyframes == 0 then
        warn("Animations.keyframe: Missing element or keyframes")
        return nil
    end

    local animationId = HttpService:GenerateGUID(false)
    local currentIndex = 1
    local sequence = {}

    local function playNext()
        if currentIndex > #keyframes then
            activeAnimations[animationId] = nil
            if callback then callback() end
            return
        end

        local frame = keyframes[currentIndex]
        local tweenId = Animations.tween(
            element,
            frame.properties,
            frame.duration,
            frame.easingStyle,
            frame.easingDirection,
            function()
                currentIndex = currentIndex + 1
                playNext()
            end
        )

        if tweenId then
            sequence[tweenId] = true
        end
    end

    activeAnimations[animationId] = sequence
    playNext()
    return animationId
end

-- Stop an animation by ID
function Animations.stop(animationId)
    if not animationId or not activeAnimations[animationId] then
        return
    end

    local animation = activeAnimations[animationId]
    if typeof(animation) == "table" then
        -- Keyframe sequence
        for tweenId, _ in pairs(animation) do
            local tween = activeAnimations[tweenId]
            if tween then
                tween:Cancel()
            end
        end
    elseif typeof(animation) == "Instance" and animation:IsA("Tween") then
        -- Single tween
        animation:Cancel()
    end

    activeAnimations[animationId] = nil
end

-- Stop all animations for an element
function Animations.stop_element(element)
    for animationId, animation in pairs(activeAnimations) do
        if typeof(animation) == "Instance" and animation:IsA("Tween") and animation.Instance == element then
            animation:Cancel()
            activeAnimations[animationId] = nil
        elseif typeof(animation) == "table" then
            for tweenId, _ in pairs(animation) do
                local tween = activeAnimations[tweenId]
                if tween and tween.Instance == element then
                    tween:Cancel()
                    activeAnimations[tweenId] = nil
                end
            end
        end
    end
end

-- Create a spinning animation (e.g., for loading icon)
function Animations.spin(element, speed, callback)
    if not Animations.enabled then
        if callback then callback() end
        return nil
    end

    speed = speed or 360 -- Degrees per second
    local animationId = HttpService:GenerateGUID(false)
    local connection
    local startTime = tick()

    connection = RunService.RenderStepped:Connect(function()
        if not element or not element.Parent then
            connection:Disconnect()
            activeAnimations[animationId] = nil
            if callback then callback() end
            return
        end

        local elapsed = tick() - startTime
        element.Rotation = (speed * elapsed) % 360
    end)

    activeAnimations[animationId] = connection
    return animationId
end

-- Apply loading spinner animation (using hourglass_top icon)
function Animations.apply_loading_spinner(element, speed)
    if not element:IsA("ImageLabel") and not element:IsA("ImageButton") then
        warn("Animations.apply_loading_spinner: Element must be ImageLabel or ImageButton")
        return
    end

    Animations.Icons:apply_to(element, "hourglass_top", "Material", { theme = "Loading" })
    return Animations.spin(element, speed)
end

-- Handle theme updates
function Animations.on_theme_update()
    -- Update default animation properties if theme changes
    defaultEasingStyle = Animations.Theme:get("AnimationEasingStyle", defaultEasingStyle)
    defaultEasingDirection = Animations.Theme:get("AnimationEasingDirection", defaultEasingDirection)
    defaultDuration = Animations.Theme:get("AnimationDuration", defaultDuration)
end

-- Handle config updates
function Animations.on_config_update()
    local newEnabled = Animations.Config:get("AnimationsEnabled", true)
    if newEnabled ~= Animations.enabled then
        Animations.enabled = newEnabled
        if not newEnabled then
            -- Cancel all animations if disabled
            for animationId, _ in pairs(activeAnimations) do
                Animations.stop(animationId)
            end
        end
    end
end

-- Connect to SnowtUI lifecycle
function Animations.connect_lifecycle()
    if Animations.SnowtUI then
        Animations.SnowtUI:OnModuleLoaded("Theme", function(theme)
            Animations.Theme = theme
            theme:Subscribe("ThemeUpdated", Animations.on_theme_update)
        end)

        Animations.SnowtUI:OnModuleLoaded("Config", function(config)
            Animations.Config = config
            config:Subscribe("ConfigUpdated", Animations.on_config_update)
        end)

        Animations.SnowtUI:OnModuleLoaded("LoadingScreen", function(loadingScreen)
            loadingScreen:OnShow(function(element)
                Animations.apply_loading_spinner(element, 180)
            end)
        end)
    end
end

-- Initialize lifecycle connections
Animations.connect_lifecycle()

return Animations