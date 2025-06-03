-- Notifications.lua: Notification system for SnowtUI
-- Provides toasts, prompts, and confirmations with animations, theming, and accessibility
-- Dependencies: Core.lua, Theme.lua, Elements.lua
local Notifications = {}
Notifications.Version = "1.0.0"
Notifications.Dependencies = { "Core", "Theme", "Elements" }

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Internal state
Notifications.NotificationCache = {} -- Stores active notifications by ID
Notifications.Queue = {} -- Queue for pending notifications
Notifications.ActivePrompts = {} -- Tracks active prompts/confirmations
Notifications.EventCallbacks = {} -- Stores event callbacks
Notifications.AnimationCache = {} -- Caches tweens for reuse
Notifications.FocusableElements = {} -- Tracks focusable elements per notification
Notifications.MaxNotifications = 5 -- Max simultaneous notifications

-- Default configurations for notifications
Notifications.Defaults = {
    Toast = {
        Size = UDim2.new(0, 300, 0, 80),
        Position = UDim2.new(1, -310, 0, 10),
        BackgroundTransparency = 0,
        TextSize = 14,
        Font = Enum.Font.SourceSans,
        Duration = 5, -- Seconds
        StackDirection = "TopRight", -- TopRight, BottomRight, TopLeft, BottomLeft
        Animation = { SlideDuration = 0.3, FadeDuration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = "Notification",
        Padding = UDim.new(0, 10)
    },
    Prompt = {
        Size = UDim2.new(0, 400, 0, 150),
        Position = UDim2.new(0.5, -200, 0.5, -75),
        BackgroundTransparency = 0,
        TextSize = 14,
        Font = Enum.Font.SourceSans,
        Animation = { SlideDuration = 0.3, FadeDuration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = "Enter your response",
        ButtonSize = UDim2.new(0, 100, 0, 30)
    },
    Confirmation = {
        Size = UDim2.new(0, 400, 0, 120),
        Position = UDim2.new(0.5, -200, 0.5, -60),
        BackgroundTransparency = 0,
        TextSize = 14,
        Font = Enum.Font.SourceSans,
        Animation = { SlideDuration = 0.3, FadeDuration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = "Confirm your choice",
        ButtonSize = UDim2.new(0, 100, 0, 30)
    }
}

-- Utility function to create tweens
local function CreateTween(obj, props, duration, easingStyle, easingDirection)
    local tweenInfo = TweenInfo.new(
        duration or Notifications.Defaults.Toast.Animation.SlideDuration,
        easingStyle or Notifications.Defaults.Toast.Animation.EasingStyle,
        easingDirection or Enum.EasingDirection.InOut
    )
    local tween = Notifications.AnimationCache[obj] or TweenService:Create(obj, tweenInfo, props)
    Notifications.AnimationCache[obj] = tween
    tween:Play()
    return tween
end

-- Utility function to apply theme styles
local function ApplyThemeStyle(element, theme, elementType)
    if not SnowtUI or not SnowtUI.Modules.Theme then
        SnowtUI.Debug("Theme module not loaded for notification styling", "error")
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

-- Utility function to add context menu support
local function AddContextMenu(element, items)
    element.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            SnowtUI:ShowContextMenu(items, UDim2.new(0, input.Position.X, 0, input.Position.Y))
        end)
    end
end

-- Update notification positions based on stack direction
local function UpdateNotificationPositions()
    local activeNotifications = {}
    for id, notification in pairs(Notifications.NotificationCache) do
        if notification.Type == "Toast" then
            table.insert(activeNotifications, notification)
        end
    end
    table.sort(activeNotifications, function(a, b) return a.CreatedAt < b.CreatedAt end)
    
    local stackDirection = Notifications.Defaults.Toast.StackDirection
    local offset = 10
    local spacing = 10
    
    for i, notification in ipairs(activeNotifications) do
        local targetPos
        if stackDirection == "TopRight" then
            targetPos = UDim2.new(1, -310, 0, offset + (i - 1) * (notification.Frame.Size.Y.Offset + spacing))
        elseif stackDirection == "BottomRight" then
            targetPos = UDim2.new(1, -310, 1, -offset - i * (notification.Frame.Size.Y.Offset + spacing))
        elseif stackDirection == "TopLeft" then
            targetPos = UDim2.new(0, 10, 0, offset + (i - 1) * (notification.Frame.Size.Y.Offset + spacing))
        else -- BottomLeft
            targetPos = UDim2.new(0, 10, 1, -offset - i * (notification.Frame.Size.Y.Offset + spacing))
        end
        CreateTween(notification.Frame, { Position = targetPos }, Notifications.Defaults.Toast.Animation.SlideDuration):Play()
    end
end

-- Process notification queue
local function ProcessQueue()
    if #Notifications.Queue == 0 or table.getn(Notifications.NotificationCache) >= Notifications.MaxNotifications then
        return
    end
    local notification = table.remove(Notifications.Queue, 1)
    if notification.Type == "Toast" then
        Notifications:CreateToast(notification.Settings)
    elseif notification.Type == "Prompt" then
        Notifications:CreatePrompt(notification.Settings, notification.Callback)
    elseif notification.Type == "Confirmation" then
        Notifications:CreateConfirmation(notification.Settings, notification.Callback)
    end
end

-- Create a toast notification
function Notifications:CreateToast(settings)
    settings = settings or {}
    if table.getn(Notifications.NotificationCache) >= Notifications.MaxNotifications then
        table.insert(Notifications.Queue, { Type = "Toast", Settings = settings })
        return
    end

    local notificationId = settings.Id or "Toast_" .. HttpService:GenerateGUID(false)
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Notifications.Defaults.Toast.Size
    frame.Position = settings.Position or Notifications.Defaults.Toast.Position
    frame.BackgroundTransparency = 1
    frame.Parent = SnowtUI.ScreenGui
    frame.Name = notificationId
    frame.ZIndex = 1000

    local title = SnowtUI:GetPooledObject("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 20)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = settings.Title or "Notification"
    title.TextSize = settings.TextSize or Notifications.Defaults.Toast.TextSize
    title.Font = settings.Font or Notifications.Defaults.Toast.Font
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local message = SnowtUI:GetPooledObject("TextLabel")
    message.Size = UDim2.new(1, -20, 0, 40)
    message.Position = UDim2.new(0, 10, 0, 30)
    message.BackgroundTransparency = 1
    message.Text = settings.Message or ""
    message.TextSize = settings.TextSize or Notifications.Defaults.Toast.TextSize
    message.Font = settings.Font or Notifications.Defaults.Toast.Font
    message.TextWrapped = true
    message.TextXAlignment = Enum.TextXAlignment.Left
    message.Parent = frame

    local closeButton = SnowtUI:GetPooledObject("TextButton")
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Position = UDim2.new(1, -30, 0, 10)
    closeButton.Text = "X"
    closeButton.TextSize = 14
    closeButton.BackgroundTransparency = 0
    closeButton.AutoButtonColor = false
    closeButton.Parent = frame

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(title, theme, "Text")
    ApplyThemeStyle(message, theme, "Text")
    ApplyThemeStyle(closeButton, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(closeButton, theme)

    local notificationData = {
        Id = notificationId,
        Frame = frame,
        Type = "Toast",
        CreatedAt = os.clock()
    }
    Notifications.NotificationCache[notificationId] = notificationData
    Notifications.FocusableElements[notificationId] = { closeButton }

    -- Slide-in animation
    local startPos = UDim2.new(
        frame.Position.X.Scale, frame.Position.X.Offset + (Notifications.Defaults.Toast.StackDirection:find("Right") and 310 or -310),
        frame.Position.Y.Scale, frame.Position.Y.Offset
    )
    frame.Position = startPos
    CreateTween(frame, { Position = settings.Position or Notifications.Defaults.Toast.Position, BackgroundTransparency = 0 }, Notifications.Defaults.Toast.Animation.SlideDuration):Play()

    local function dismiss()
        CreateTween(frame, {
            Position = startPos,
            BackgroundTransparency = 1
        }, Notifications.Defaults.Toast.Animation.SlideDuration):Play()
        task.delay(Notifications.Defaults.Toast.Animation.SlideDuration, function()
            frame:Destroy()
            Notifications.NotificationCache[notificationId] = nil
            UpdateNotificationPositions()
            ProcessQueue()
            SnowtUI.FireEvent("NotificationDismissed", notificationId)
        end)
    end

    closeButton.MouseButton1Click:Connect(function()
        dismiss()
        CreateRipple(closeButton, UDim2.new(0.5, 0, 0.5, 0))
    end)

    closeButton.MouseEnter:Connect(function()
        CreateTween(closeButton, { BackgroundColor3 = theme.Button.HoverColor }, Notifications.Defaults.Toast.Animation.FadeDuration):Play()
        AddTooltip(closeButton, "Dismiss notification")
    end)

    closeButton.MouseLeave:Connect(function()
        CreateTween(closeButton, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Notifications.Defaults.Toast.Animation.FadeDuration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(frame, {
        { Name = "Dismiss", Callback = dismiss },
        { Name = "Copy Message", Callback = function() setclipboard(message.Text) end }
    })

    -- Auto-dismiss after duration
    task.spawn(function()
        task.wait(settings.Duration or Notifications.Defaults.Toast.Duration)
        if Notifications.NotificationCache[notificationId] then
            dismiss()
        end
    end)

    UpdateNotificationPositions()
    SnowtUI.FireEvent("NotificationCreated", notificationId, "Toast")
    SnowtUI:AddFocusableElement(SnowtUI.ScreenGui, closeButton)
    return notificationId
end

-- Create a prompt dialog
function Notifications:CreatePrompt(settings, callback)
    settings = settings or {}
    local notificationId = settings.Id or "Prompt_" .. HttpService:GenerateGUID(false)
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Notifications.Defaults.Prompt.Size
    frame.Position = settings.Position or Notifications.Defaults.Prompt.Position
    frame.BackgroundTransparency = 1
    frame.Parent = SnowtUI.ScreenGui
    frame.Name = notificationId
    frame.ZIndex = 2000

    local title = SnowtUI:GetPooledObject("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 20)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = settings.Title or "Prompt"
    title.TextSize = settings.TextSize or Notifications.Defaults.Prompt.TextSize
    title.Font = settings.Font or Notifications.Defaults.Prompt.Font
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local message = SnowtUI:GetPooledObject("TextLabel")
    message.Size = UDim2.new(1, -20, 0, 40)
    message.Position = UDim2.new(0, 10, 0, 30)
    message.BackgroundTransparency = 1
    message.Text = settings.Message or "Enter your response:"
    message.TextSize = settings.TextSize or Notifications.Defaults.Prompt.TextSize
    message.Font = settings.Font or Notifications.Defaults.Prompt.Font
    message.TextWrapped = true
    message.TextXAlignment = Enum.TextXAlignment.Left
    message.Parent = frame

    local input = SnowtUI:GetPooledObject("TextBox")
    input.Size = UDim2.new(1, -20, 0, 30)
    input.Position = UDim2.new(0, 10, 0, 70)
    input.BackgroundTransparency = 0
    input.Text = settings.DefaultText or ""
    input.TextSize = settings.TextSize or Notifications.Defaults.Prompt.TextSize
    input.Font = settings.Font or Notifications.Defaults.Prompt.Font
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.Parent = frame

    local confirmButton = SnowtUI:GetPooledObject("TextButton")
    confirmButton.Size = settings.ButtonSize or Notifications.Defaults.Prompt.ButtonSize
    confirmButton.Position = UDim2.new(0, 10, 1, -40)
    confirmButton.Text = "Confirm"
    confirmButton.TextSize = 14
    confirmButton.BackgroundTransparency = 0
    confirmButton.AutoButtonColor = false
    confirmButton.Parent = frame

    local cancelButton = SnowtUI:GetPooledObject("TextButton")
    cancelButton.Size = settings.ButtonSize or Notifications.Defaults.Prompt.ButtonSize
    cancelButton.Position = UDim2.new(0, 120, 1, -40)
    cancelButton.Text = "Cancel"
    cancelButton.TextSize = 14
    cancelButton.BackgroundTransparency = 0
    cancelButton.AutoButtonColor = false
    cancelButton.Parent = frame

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(title, theme, "Text")
    ApplyThemeStyle(message, theme, "Text")
    ApplyThemeStyle(input, theme, "Button")
    ApplyThemeStyle(confirmButton, theme, "Button")
    ApplyThemeStyle(cancelButton, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(input, theme)
    CreateCorner(confirmButton, theme)
    CreateCorner(cancelButton, theme)

    local notificationData = {
        Id = notificationId,
        Frame = frame,
        Type = "Prompt",
        CreatedAt = os.clock()
    }
    Notifications.NotificationCache[notificationId] = notificationData
    Notifications.ActivePrompts[notificationId] = true
    Notifications.FocusableElements[notificationId] = { input, confirmButton, cancelButton }

    -- Fade-in animation
    CreateTween(frame, { BackgroundTransparency = 0 }, Notifications.Defaults.Prompt.Animation.FadeDuration):Play()

    local function dismiss(result)
        CreateTween(frame, { BackgroundTransparency = 1 }, Notifications.Defaults.Prompt.Animation.FadeDuration):Play()
        task.delay(Notifications.Defaults.Prompt.Animation.FadeDuration, function()
            frame:Destroy()
            Notifications.NotificationCache[notificationId] = nil
            Notifications.ActivePrompts[notificationId] = nil
            if callback then
                callback(result)
            end
            ProcessQueue()
            SnowtUI.FireEvent("NotificationDismissed", notificationId)
        end)
    end

    confirmButton.MouseButton1Click:Connect(function()
        dismiss(input.Text)
        CreateRipple(confirmButton, UDim2.new(0.5, 0, 0.5, 0))
    end)

    cancelButton.MouseButton1Click:Connect(function()
        dismiss(nil)
        CreateRipple(cancelButton, UDim2.new(0.5, 0, 0.5, 0))
    end)

    input.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            dismiss(input.Text)
        end
    end)

    confirmButton.MouseEnter:Connect(function()
        CreateTween(confirmButton, { BackgroundColor3 = theme.Button.HoverColor }, Notifications.Defaults.Prompt.Animation.FadeDuration):Play()
        AddTooltip(confirmButton, "Submit response")
    end)

    confirmButton.MouseLeave:Connect(function()
        CreateTween(confirmButton, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Notifications.Defaults.Prompt.Animation.FadeDuration):Play()
        SnowtUI:HideTooltip()
    end)

    cancelButton.MouseEnter:Connect(function()
        CreateTween(cancelButton, { BackgroundColor3 = theme.Button.HoverColor }, Notifications.Defaults.Prompt.Animation.FadeDuration):Play()
        AddTooltip(cancelButton, "Cancel")
    end)

    cancelButton.MouseLeave:Connect(function()
        CreateTween(cancelButton, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Notifications.Defaults.Prompt.Animation.FadeDuration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(frame, {
        { Name = "Dismiss", Callback = function() dismiss(nil) end },
        { Name = "Copy Message", Callback = function() setclipboard(message.Text) end }
    })

    SnowtUI.FireEvent("NotificationCreated", notificationId, "Prompt")
    for _, element in ipairs(Notifications.FocusableElements[notificationId]) do
        SnowtUI:AddFocusableElement(SnowtUI.ScreenGui, element)
    end
    return notificationId
end

-- Create a confirmation dialog
function Notifications:CreateConfirmation(settings, callback)
    settings = settings or {}
    local notificationId = settings.Id or "Confirmation_" .. HttpService:GenerateGUID(false)
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Notifications.Defaults.Confirmation.Size
    frame.Position = settings.Position or Notifications.Defaults.Confirmation.Position
    frame.BackgroundTransparency = 1
    frame.Parent = SnowtUI.ScreenGui
    frame.Name = notificationId
    frame.ZIndex = 2000

    local title = SnowtUI:GetPooledObject("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 20)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = settings.Title or "Confirmation"
    title.TextSize = settings.TextSize or Notifications.Defaults.Confirmation.TextSize
    title.Font = settings.Font or Notifications.Defaults.Confirmation.Font
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local message = SnowtUI:GetPooledObject("TextLabel")
    message.Size = UDim2.new(1, -20, 0, 40)
    message.Position = UDim2.new(0, 10, 0, 30)
    message.BackgroundTransparency = 1
    message.Text = settings.Message or "Are you sure?"
    message.TextSize = settings.TextSize or Notifications.Defaults.Confirmation.TextSize
    message.Font = settings.Font or Notifications.Defaults.Confirmation.Font
    message.TextWrapped = true
    message.TextXAlignment = Enum.TextXAlignment.Left
    message.Parent = frame

    local yesButton = SnowtUI:GetPooledObject("TextButton")
    yesButton.Size = settings.ButtonSize or Notifications.Defaults.Confirmation.ButtonSize
    yesButton.Position = UDim2.new(0, 10, 1, -40)
    yesButton.Text = "Yes"
    yesButton.TextSize = 14
    yesButton.BackgroundTransparency = 0
    yesButton.AutoButtonColor = false
    yesButton.Parent = frame

    local noButton = SnowtUI:GetPooledObject("TextButton")
    noButton.Size = settings.ButtonSize or Notifications.Defaults.Confirmation.ButtonSize
    noButton.Position = UDim2.new(0, 120, 1, -40)
    noButton.Text = "No"
    noButton.TextSize = 14
    noButton.BackgroundTransparency = 0
    noButton.AutoButtonColor = false
    noButton.Parent = frame

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(title, theme, "Text")
    ApplyThemeStyle(message, theme, "Text")
    ApplyThemeStyle(yesButton, theme, "Button")
    ApplyThemeStyle(noButton, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(yesButton, theme)
    CreateCorner(noButton, theme)

    local notificationData = {
        Id = notificationId,
        Frame = frame,
        Type = "Confirmation",
        CreatedAt = os.clock()
    }
    Notifications.NotificationCache[notificationId] = notificationData
    Notifications.ActivePrompts[notificationId] = true
    Notifications.FocusableElements[notificationId] = { yesButton, noButton }

    -- Fade-in animation
    CreateTween(frame, { BackgroundTransparency = 0 }, Notifications.Defaults.Confirmation.Animation.FadeDuration):Play()

    local function dismiss(result)
        CreateTween(frame, { BackgroundTransparency = 1 }, Notifications.Defaults.Confirmation.Animation.FadeDuration):Play()
        task.delay(Notifications.Defaults.Confirmation.Animation.FadeDuration, function()
            frame:Destroy()
            Notifications.NotificationCache[notificationId] = nil
            Notifications.ActivePrompts[notificationId] = nil
            if callback then
                callback(result)
            end
            ProcessQueue()
            SnowtUI.FireEvent("NotificationDismissed", notificationId)
        end)
    end

    yesButton.MouseButton1Click:Connect(function()
        dismiss(true)
        CreateRipple(yesButton, UDim2.new(0.5, 0, 0.5, 0))
    end)

    noButton.MouseButton1Click:Connect(function()
        dismiss(false)
        CreateRipple(noButton, UDim2.new(0.5, 0, 0.5, 0))
    end)

    yesButton.MouseEnter:Connect(function()
        CreateTween(yesButton, { BackgroundColor3 = theme.Button.HoverColor }, Notifications.Defaults.Confirmation.Animation.FadeDuration):Play()
        AddTooltip(yesButton, "Confirm")
    end)

    yesButton.MouseLeave:Connect(function()
        CreateTween(yesButton, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Notifications.Defaults.Confirmation.Animation.FadeDuration):Play()
        SnowtUI:HideTooltip()
    end)

    noButton.MouseEnter:Connect(function()
        CreateTween(noButton, { BackgroundColor3 = theme.Button.HoverColor }, Notifications.Defaults.Confirmation.Animation.FadeDuration):Play()
        AddTooltip(noButton, "Cancel")
    end)

    noButton.MouseLeave:Connect(function()
        CreateTween(noButton, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Notifications.Defaults.Confirmation.Animation.FadeDuration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(frame, {
        { Name = "Dismiss", Callback = function() dismiss(false) end },
        { Name = "Copy Message", Callback = function() setclipboard(message.Text) end }
    })

    SnowtUI.FireEvent("NotificationCreated", notificationId, "Confirmation")
    for _, element in ipairs(Notifications.FocusableElements[notificationId]) do
        SnowtUI:AddFocusableElement(SnowtUI.ScreenGui, element)
    end
    return notificationId
end

-- Dismiss a specific notification
function Notifications:DismissNotification(notificationId)
    local notification = Notifications.NotificationCache[notificationId]
    if not notification then
        SnowtUI.Debug("Notification not found: " .. notificationId, "error")
        return
    end
    CreateTween(notification.Frame, { BackgroundTransparency = 1 }, Notifications.Defaults[notification.Type].Animation.FadeDuration):Play()
    task.delay(Notifications.Defaults[notification.Type].Animation.FadeDuration, function()
        notification.Frame:Destroy()
        Notifications.NotificationCache[notificationId] = nil
        Notifications.ActivePrompts[notificationId] = nil
        UpdateNotificationPositions()
        ProcessQueue()
        SnowtUI.FireEvent("NotificationDismissed", notificationId)
    end)
end

-- Dismiss all notifications
function Notifications:DismissAll()
    for id, notification in pairs(Notifications.NotificationCache) do
        Notifications:DismissNotification(id)
    end
    Notifications.Queue = {}
end

-- Initialize the Notifications module
function Notifications:Init(core)
    SnowtUI = core
    SnowtUI.Debug("Notifications module initialized")

    -- Handle theme changes
    SnowtUI:RegisterEvent("ThemeChanged", function(themeName)
        local theme = SnowtUI.Modules.Theme.Themes[themeName]
        for _, notification in pairs(Notifications.NotificationCache) do
            ApplyThemeStyle(notification.Frame, theme, "Button")
            for _, child in ipairs(notification.Frame:GetDescendants()) do
                if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextBox") then
                    ApplyThemeStyle(child, theme, "Button")
                elseif child:IsA("TextLabel") then
                    ApplyThemeStyle(child, theme, "Text")
                elseif child:IsA("UIStroke") then
                    ApplyThemeStyle(child, theme, "Stroke")
                elseif child:IsA("UICorner") then
                    ApplyThemeStyle(child, theme, "Corner")
                end
            end
        end
    end)

    -- Handle scale changes
    SnowtUI:RegisterEvent("ScaleAdjusted", function()
        for _, notification in pairs(Notifications.NotificationCache) do
            SnowtUI.Modules.Theme:ApplyAdaptiveStyle(notification.Frame, SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()].Button)
            for _, child in ipairs(notification.Frame:GetDescendants()) do
                if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextBox") or child:IsA("TextLabel") then
                    SnowtUI.Modules.Theme:ApplyAdaptiveStyle(child, SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()].Button)
                end
            end
        end
        UpdateNotificationPositions()
    end)

    -- Gamepad support
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent or not SnowtUI.Config.GamepadEnabled then return
        if input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonA then
            for id, elements in pairs(Notifications.FocusableElements) do
                if Notifications.ActivePrompts[id] then
                    for _, element in ipairs(elements) do
                        if element:IsA("TextButton") and element.Text == "Confirm" or element.Text == "Yes" then
                            element:MouseButton1Click()
                            break
                        end
                    end
                    break
                end
            end
        end
    end)

    -- Expose Prompt function for other modules
    SnowtUI.Prompt = function(message, callback)
        return Notifications:CreatePrompt({ Message = message }, callback)
    end
end

return Notifications