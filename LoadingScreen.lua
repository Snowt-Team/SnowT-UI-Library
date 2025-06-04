-- LoadingScreen.lua: Loading screen module for SnowtUI
-- Provides customizable loading screens with progress bars, spinners, and animations
-- Dependencies: Core.lua, Theme.lua, Elements.lua, Notifications.lua, Config.lua
local LoadingScreen = {}
LoadingScreen.Version = "1.0.0"
LoadingScreen.Dependencies = { "Core", "Theme", "Elements", "Notifications", "Config" }

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Internal state
LoadingScreen.ScreenCache = {} -- Stores active loading screens by ID
LoadingScreen.EventCallbacks = {} -- Event callbacks
LoadingScreen.AnimationCache = {} -- Cached tweens
LoadingScreen.FocusableElements = {} -- Focusable elements per screen
LoadingScreen.Tips = { -- Sample loading tips
    "Did you know? SnowtUI supports gamepad navigation!",
    "Tip: Customize your UI scale in the settings menu.",
    "Fun fact: SnowtUI is built for performance and style."
}

-- Default configurations
LoadingScreen.Defaults = {
    FullScreen = {
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 0.5,
        ZIndex = 10000,
        Animation = { FadeDuration = 0.3, EasingStyle = Enum.EasingStyle.Sine },
        ProgressBarSize = UDim2.new(0, 300, 0, 20),
        SpinnerSize = UDim2.new(0, 50, 0, 50),
        TextSize = 16,
        Font = Enum.Font.SourceSans,
        ShowTips = true,
        TipInterval = 5, -- Seconds
        Tooltip = "Loading screen"
    },
    Overlay = {
        Size = UDim2.new(0, 400, 0, 200),
        Position = UDim2.new(0.5, -200, 0.5, -100),
        BackgroundTransparency = 0.2,
        ZIndex = 11000,
        Animation = { FadeDuration = 0.3, EasingStyle = Enum.EasingStyle.Sine },
        ProgressBarSize = UDim2.new(0, 250, 0, 15),
        SpinnerSize = UDim2.new(0, 40, 0, 40),
        TextSize = 14,
        Font = Enum.Font.SourceSans,
        ShowTips = false,
        Tooltip = "Loading overlay"
    },
    Modal = {
        Size = UDim2.new(0, 300, 0, 150),
        Position = UDim2.new(0.5, -150, 0.5, -75),
        BackgroundTransparency = 0,
        ZIndex = 12000,
        Animation = { FadeDuration = 0.3, EasingStyle = Enum.EasingStyle.Sine },
        ProgressBarSize = UDim2.new(0, 200, 0, 10),
        SpinnerSize = UDim2.new(0, 30, 0, 30),
        TextSize = 12,
        Font = Enum.Font.SourceSans,
        ShowTips = false,
        Tooltip = "Loading modal"
    }
}

-- Utility function to create tweens
local function CreateTween(obj, props, duration, easingStyle, easingDirection)
    local tweenInfo = TweenInfo.new(
        duration or LoadingScreen.Defaults.FullScreen.Animation.FadeDuration,
        easingStyle or LoadingScreen.Defaults.FullScreen.Animation.EasingStyle,
        easingDirection or Enum.EasingDirection.InOut
    )
    local tween = LoadingScreen.AnimationCache[obj] or TweenService:Create(obj, tweenInfo, props)
    LoadingScreen.AnimationCache[obj] = tween
    tween:Play()
    return tween
end

-- Utility function to apply theme styles
local function ApplyThemeStyle(element, theme, elementType)
    if not SnowtUI or not SnowtUI.Modules.Theme then
        SnowtUI.Debug("Theme module not loaded for loading screen styling", "error")
        return
    end
    local style = theme[elementType] or theme.Button
    for prop, value in pairs(style) do
        if prop == "HoverColor" or prop == "Gradient" then
            -- Handled in interaction events
        elseif prop == "Transparency" then
            element.BackgroundTransparency = value
        else
            element[prop] = value
        end
    end
    SnowtUI.Modules.Theme:ApplyAdaptiveStyle(element, style)
end

-- Utility function to create a UIStroke
local function CreateStroke(parent, theme)
    local stroke = SnowtUI:GetPooledObject("UIStroke")
    stroke.Thickness = theme.Stroke.Thickness
    stroke.Color = theme.Stroke.Color
    stroke.Transparency = theme.Stroke.Transparency
    stroke.Parent = parent
    return stroke
end

-- Utility function to create a UICorner
local function CreateCorner(parent, theme)
    local corner = SnowtUI:GetPooledObject("UICorner")
    corner.CornerRadius = theme.Corner.Radius
    corner.Parent = parent
    return corner
end

-- Utility function to add tooltip support
local function AddTooltip(element, tooltipText)
    if tooltipText and tooltipText ~= "" then
        element.MouseEnter:Connect(function()
            SnowtUI:ShowTooltip(tooltipText, UDim2.new(0, element.AbsolutePosition.X, 0, element.AbsolutePosition.Y + element.AbsoluteSize.Y))
        end)
        element.MouseLeave:Connect(function()
            SnowtUI:HideTooltip()
        end)
    end
end

-- Utility function to create a ripple effect
local function CreateRipple(parent, position)
    local ripple = SnowtUI:GetPooledObject("Frame")
    ripple.Size = UDim2.new(0, 0, 0, 0)
    ripple.Position = position
    ripple.BackgroundTransparency = 0.5
    ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ripple.ZIndex = parent.ZIndex + 1
    ripple.Parent = parent
    CreateCorner(ripple, { Corner = { Radius = UDim.new(1, 0) } })
    
    local tween = CreateTween(ripple, {
        Size = UDim2.new(0, 100, 0, 100),
        BackgroundTransparency = 1
    }, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    tween.Completed:Connect(function()
        ripple:Destroy()
    end)
end

-- Create a loading screen
function LoadingScreen:CreateLoadingScreen(settings)
    settings = settings or {}
    local screenType = settings.Type or "FullScreen"
    local defaults = LoadingScreen.Defaults[screenType] or LoadingScreen.Defaults.FullScreen
    local screenId = settings.Id or "LoadingScreen_" .. HttpService:GenerateGUID(false)
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or defaults.Size
    frame.Position = settings.Position or defaults.Position
    frame.BackgroundTransparency = 1
    frame.Parent = SnowtUI.ScreenGui
    frame.Name = screenId
    frame.ZIndex = defaults.ZIndex
    frame.ClipsDescendants = true

    local title = SnowtUI:GetPooledObject("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 20)
    title.BackgroundTransparency = 1
    title.Text = settings.Title or "Loading..."
    title.TextSize = settings.TextSize or defaults.TextSize
    title.Font = settings.Font or defaults.Font
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = frame

    local message = SnowtUI:GetPooledObject("TextLabel")
    message.Size = UDim2.new(1, -20, 0, 20)
    message.Position = UDim2.new(0, 10, 0, 60)
    message.BackgroundTransparency = 1
    message.Text = settings.Message or ""
    message.TextSize = settings.TextSize or defaults.TextSize
    message.Font = settings.Font or defaults.Font
    message.TextXAlignment = Enum.TextXAlignment.Center
    message.TextWrapped = true
    message.Parent = frame

    local progressFrame = SnowtUI:GetPooledObject("Frame")
    progressFrame.Size = settings.ProgressBarSize or defaults.ProgressBarSize
    progressFrame.Position = UDim2.new(0.5, -(defaults.ProgressBarSize.X.Offset / 2), 0, 90)
    progressFrame.BackgroundTransparency = 0
    progressFrame.Parent = frame

    local progressFill = SnowtUI:GetPooledObject("Frame")
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundTransparency = 0
    progressFill.Parent = progressFrame
    progressFill.ZIndex = progressFrame.ZIndex + 1

    local spinner = SnowtUI:GetPooledObject("ImageLabel")
    spinner.Size = settings.SpinnerSize or defaults.SpinnerSize
    spinner.Position = UDim2.new(0.5, -(defaults.SpinnerSize.X.Offset / 2), 0, 90)
    spinner.BackgroundTransparency = 1
    spinner.Image = "rbxassetid://1234567890" -- Placeholder; replace with spinner asset
    spinner.Visible = not settings.ShowProgressBar
    spinner.Parent = frame

    local progressText = SnowtUI:GetPooledObject("TextLabel")
    progressText.Size = UDim2.new(0, 100, 0, 20)
    progressText.Position = UDim2.new(0.5, -50, 0, 115)
    progressText.BackgroundTransparency = 1
    progressText.Text = "0%"
    progressText.TextSize = defaults.TextSize - 2
    progressText.Font = defaults.Font
    progressText.TextXAlignment = Enum.TextXAlignment.Center
    progressText.Visible = settings.ShowProgressBar
    progressText.Parent = frame

    local tipText = SnowtUI:GetPooledObject("TextLabel")
    tipText.Size = UDim2.new(1, -20, 0, 20)
    tipText.Position = UDim2.new(0, 10, 1, -30)
    tipText.BackgroundTransparency = 1
    tipText.Text = defaults.ShowTips and LoadingScreen.Tips[math.random(1, #LoadingScreen.Tips)] or ""
    tipText.TextSize = defaults.TextSize - 2
    tipText.Font = defaults.Font
    tipText.TextXAlignment = Enum.TextXAlignment.Center
    tipText.TextWrapped = true
    tipText.Visible = defaults.ShowTips
    tipText.Parent = frame

    local cancelButton = SnowtUI:GetPooledObject("TextButton")
    cancelButton.Size = UDim2.new(0, 100, 0, 30)
    cancelButton.Position = UDim2.new(0.5, -50, 0, 140)
    cancelButton.Text = "Cancel"
    cancelButton.TextSize = defaults.TextSize
    cancelButton.BackgroundTransparency = 0
    cancelButton.AutoButtonColor = false
    cancelButton.Visible = settings.AllowCancel
    cancelButton.Parent = frame

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(title, theme, "Text")
    ApplyThemeStyle(message, theme, "Text")
    ApplyThemeStyle(progressFrame, theme, "Button")
    ApplyThemeStyle(progressFill, theme, "Button", { BackgroundColor3 = theme.Button.HoverColor })
    ApplyThemeStyle(spinner, theme, "Image")
    ApplyThemeStyle(progressText, theme, "Text")
    ApplyThemeStyle(tipText, theme, "Text")
    ApplyThemeStyle(cancelButton, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(progressFrame, theme)
    CreateCorner(cancelButton, theme)

    local screenData = {
        Id = screenId,
        Frame = frame,
        Type = screenType,
        ProgressFrame = progressFrame,
        ProgressFill = progressFill,
        ProgressText = progressText,
        Spinner = spinner,
        TipText = tipText,
        CancelButton = cancelButton,
        Progress = 0,
        IsActive = true
    }
    LoadingScreen.ScreenCache[screenId] = screenData
    LoadingScreen.FocusableElements[screenId] = settings.AllowCancel and { cancelButton } or {}

    -- Fade-in animation
    local reducedMotion = SnowtUI.Modules.Config:Get("Global", "Accessibility.ReducedMotion")
    if not reducedMotion then
        CreateTween(frame, { BackgroundTransparency = defaults.BackgroundTransparency }, defaults.Animation.FadeDuration):Play()
    else
        frame.BackgroundTransparency = defaults.BackgroundTransparency
    end

    -- Spinner animation
    if not settings.ShowProgressBar and not reducedMotion then
        local rotation = { Rotation = 360 }
        local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1)
        local tween = TweenService:Create(spinner, tweenInfo, rotation)
        LoadingScreen.AnimationCache[spinner] = tween
        tween:Play()
    end

    -- Tip rotation
    if defaults.ShowTips then
        task.spawn(function()
            while screenData.IsActive do
                if not reducedMotion then
                    CreateTween(tipText, { TextTransparency = 1 }, 0.5):Play()
                    task.wait(0.5)
                    tipText.Text = LoadingScreen.Tips[math.random(1, #LoadingScreen.Tips)]
                    CreateTween(tipText, { TextTransparency = 0 }, 0.5):Play()
                else
                    tipText.Text = LoadingScreen.Tips[math.random(1, #LoadingScreen.Tips)]
                end
                task.wait(defaults.TipInterval)
            end
        end)
    end

    -- Cancel button interactions
    if settings.AllowCancel then
        cancelButton.MouseButton1Click:Connect(function()
            if settings.CancelCallback then
                settings.CancelCallback()
            end
            LoadingScreen:Dismiss(screenId)
            CreateRipple(cancelButton, UDim2.new(0.5, 0, 0.5, 0))
        end)
        cancelButton.MouseEnter:Connect(function()
            CreateTween(cancelButton, { BackgroundColor3 = theme.Button.HoverColor }, 0.2):Play()
            AddTooltip(cancelButton, "Cancel loading")
        end)
        cancelButton.MouseLeave:Connect(function()
            CreateTween(cancelButton, { BackgroundColor3 = theme.Button.BackgroundColor3 }, 0.2):Play()
            SnowtUI:HideTooltip()
        end)
    end

    -- Add tooltip to frame
    AddTooltip(frame, settings.Tooltip or defaults.Tooltip)

    -- Gamepad support
    if settings.AllowCancel then
        SnowtUI:AddFocusableElement(frame, cancelButton)
    end

    SnowtUI.FireEvent("LoadingScreenCreated", screenId, screenType)
    return screenId
end

-- Update progress
function LoadingScreen:UpdateProgress(screenId, progress, message)
    local screen = LoadingScreen.ScreenCache[screenId]
    if not screen then
        SnowtUI.Debug("Loading screen not found: " .. screenId, "error")
        return
    end
    progress = math.clamp(progress or screen.Progress, 0, 1)
    screen.Progress = progress
    if screen.ProgressFrame.Visible then
        local targetSize = UDim2.new(progress, 0, 1, 0)
        local reducedMotion = SnowtUI.Modules.Config:Get("Global", "Accessibility.ReducedMotion")
        if not reducedMotion then
            CreateTween(screen.ProgressFill, { Size = targetSize }, 0.3):Play()
        else
            screen.ProgressFill.Size = targetSize
        end
        screen.ProgressText.Text = math.floor(progress * 100) .. "%"
    end
    if message then
        screen.Frame:FindFirstChildWhichIsA("TextLabel", true).Text = message
    end
    SnowtUI.FireEvent("LoadingScreenProgressUpdated", screenId, progress)
end

-- Dismiss loading screen
function LoadingScreen:Dismiss(screenId)
    local screen = LoadingScreen.ScreenCache[screenId]
    if not screen then
        SnowtUI.Debug("Loading screen not found: " .. screenId, "error")
        return
    end
    screen.IsActive = false
    local reducedMotion = SnowtUI.Modules.Config:Get("Global", "Accessibility.ReducedMotion")
    if not reducedMotion then
        CreateTween(screen.Frame, { BackgroundTransparency = 1 }, LoadingScreen.Defaults[screen.Type].Animation.FadeDuration):Play()
        task.delay(LoadingScreen.Defaults[screen.Type].Animation.FadeDuration, function()
            screen.Frame:Destroy()
            LoadingScreen.ScreenCache[screenId] = nil
            LoadingScreen.FocusableElements[screenId] = nil
            if screen.Spinner then
                LoadingScreen.AnimationCache[screen.Spinner]:Cancel()
            end
            SnowtUI.FireEvent("LoadingScreenDismissed", screenId)
        end)
    else
        screen.Frame:Destroy()
        LoadingScreen.ScreenCache[screenId] = nil
        LoadingScreen.FocusableElements[screenId] = nil
        if screen.Spinner then
            LoadingScreen.AnimationCache[screen.Spinner]:Cancel()
        end
        SnowtUI.FireEvent("LoadingScreenDismissed", screenId)
    end
end

-- Set loading screen message
function LoadingScreen:SetMessage(screenId, message)
    local screen = LoadingScreen.ScreenCache[screenId]
    if not screen then
        SnowtUI.Debug("Loading screen not found: " .. screenId, "error")
        return
    end
    local messageLabel = screen.Frame:FindFirstChildWhichIsA("TextLabel", true)
    if messageLabel and messageLabel.Name ~= "Title" then
        messageLabel.Text = message or ""
    end
end

-- Initialize the LoadingScreen module
function LoadingScreen:Init(core)
    SnowtUI = core
    SnowtUI.Debug("LoadingScreen module initialized")

    -- Register settings with Config
    if SnowtUI.Modules.Config then
        SnowtUI.Modules.Config:RegisterModule("LoadingScreen", LoadingScreen.Defaults, {
            FullScreen = {
                ShowTips = function(value)
                    return type(value) == "boolean", "ShowTips must be a boolean"
                end,
                TipInterval = function(value)
                    return type(value) == "number" and value >= 1 and value <= 30, "TipInterval must be a number between 1 and 30"
                end
            },
            Overlay = {
                ShowTips = function(value)
                    return type(value) == "boolean", "ShowTips must be a boolean"
                end
            },
            Modal = {
                ShowTips = function(value)
                    return type(value) == "boolean", "ShowTips must be a boolean"
                end
            }
        })
    end

    -- Handle theme changes
    SnowtUI:RegisterEvent("ThemeChanged", function(themeName)
        local theme = SnowtUI.Modules.Theme.Themes[themeName]
        for _, screen in pairs(LoadingScreen.ScreenCache) do
            ApplyThemeStyle(screen.Frame, theme, "Button")
            for _, child in ipairs(screen.Frame:GetDescendants()) do
                if child:IsA("Frame") or child:IsA("TextButton") then
                    ApplyThemeStyle(child, theme, "Button")
                elseif child:IsA("TextLabel") then
                    ApplyThemeStyle(child, theme, "Text")
                elseif child:IsA("ImageLabel") then
                    ApplyThemeStyle(child, theme, "Image")
                elseif child:IsA("UIStroke") then
                    ApplyThemeStyle(child, theme, "Stroke")
                elseif child:IsA("UICorner") then
                    ApplyThemeStyle(child, theme, "Corner")
                end
            end
            if screen.ProgressFill then
                ApplyThemeStyle(screen.ProgressFill, theme, "Button", { BackgroundColor3 = theme.Button.HoverColor })
            end
        end
    end)

    -- Handle scale changes
    SnowtUI:RegisterEvent("ScaleAdjusted", function()
        for _, screen in pairs(LoadingScreen.ScreenCache) do
            SnowtUI.Modules.Theme:ApplyAdaptiveStyle(screen.Frame, SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()].Button)
            for _, child in ipairs(screen.Frame:GetDescendants()) do
                if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("ImageLabel") then
                    SnowtUI.Modules.Theme:ApplyAdaptiveStyle(child, SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()].Button)
                end
            end
        end
    end)

    -- Gamepad support
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent or not SnowtUI.Config.GamepadEnabled then return
        if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonB then
            for screenId, elements in pairs(LoadingScreen.FocusableElements) do
                if #elements > 0 then
                    elements[1]:MouseButton1Click()
                    break
                end
            end
        end
    end)
end

return LoadingScreen