-- Elements.lua: Comprehensive UI element library for SnowtUI
-- Provides a rich set of UI components with animations, theming, and accessibility
-- Dependencies: Core.lua, Theme.lua, Animations.lua (assumed future module)
local Elements = {}
Elements.Version = "1.0.0"
Elements.Dependencies = { "Core", "Theme", "Animations" }

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Internal state
Elements.ElementCache = {} -- Stores created elements for theme updates
Elements.EventCallbacks = {} -- Stores callbacks for events
Elements.ConfigFlags = {} -- Stores element states for config saving
Elements.FocusableElements = {} -- Tracks focusable elements per window
Elements.AnimationCache = {} -- Caches tweens for reuse

-- Default configurations for elements
Elements.Defaults = {
    Button = {
        Size = UDim2.new(1, -10, 0, 30),
        TextSize = 14,
        Font = Enum.Font.SourceSans,
        Padding = UDim.new(0, 5),
        Animation = { HoverScale = 1.05, ClickScale = 0.95, Duration = 0.2, Ripple = true },
        Tooltip = "",
        Enabled = true
    },
    Toggle = {
        Size = UDim2.new(1, -10, 0, 30),
        KnobSize = UDim2.new(0, 20, 0, 20),
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = "",
        Enabled = true
    },
    Slider = {
        Size = UDim2.new(1, -10, 0, 30),
        BarHeight = 6,
        KnobSize = UDim2.new(0, 12, 0, 12),
        Min = 0,
        Max = 100,
        Step = 1,
        Animation = { Duration = 0.15, EasingStyle = Enum.EasingStyle.Quad },
        Tooltip = "",
        Enabled = true
    },
    ColorPicker = {
        Size = UDim2.new(1, -10, 0, 200),
        HueBarSize = UDim2.new(0, 20, 1, -10),
        SaturationValueSize = UDim2.new(1, -30, 1, -40),
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = "",
        Enabled = true
    },
    Dropdown = {
        Size = UDim2.new(1, -10, 0, 30),
        MenuSize = UDim2.new(1, 0, 0, 100),
        ItemHeight = 25,
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = "",
        Enabled = true
    },
    TextField = {
        Size = UDim2.new(1, -10, 0, 30),
        TextSize = 14,
        Font = Enum.Font.SourceSans,
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        ClearOnFocus = false,
        Tooltip = "",
        Enabled = true
    },
    Keybind = {
        Size = UDim2.new(1, -10, 0, 30),
        TextSize = 14,
        Font = Enum.Font.SourceSans,
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = "",
        Enabled = true
    },
    Input = {
        Size = UDim2.new(1, -10, 0, 30),
        TextSize = 14,
        Font = Enum.Font.SourceSans,
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        ClearOnFocus = false,
        Tooltip = "",
        Enabled = true
    },
    Paragraph = {
        Size = UDim2.new(1, -10, 0, 50),
        TextSize = 14,
        Font = Enum.Font.SourceSans,
        TextWrapped = true,
        Tooltip = ""
    },
    Section = {
        Size = UDim2.new(1, -10, 0, 30),
        TextSize = 16,
        Font = Enum.Font.SourceSansBold,
        Collapsible = false,
        Expanded = true,
        Tooltip = ""
    },
    Divider = {
        Size = UDim2.new(1, -10, 0, 2),
        Thickness = 1,
        Tooltip = ""
    },
    Code = {
        Size = UDim2.new(1, -10, 0, 100),
        TextSize = 12,
        Font = Enum.Font.Code,
        TextWrapped = true,
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = ""
    },
    ImageLabel = {
        Size = UDim2.new(1, -10, 0, 100),
        Image = "",
        ImageTransparency = 0,
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = ""
    },
    ProgressBar = {
        Size = UDim2.new(1, -10, 0, 20),
        BarHeight = 6,
        Animation = { Duration = 0.3, EasingStyle = Enum.EasingStyle.Linear },
        Tooltip = "",
        Enabled = true
    },
    Checkbox = {
        Size = UDim2.new(1, -10, 0, 30),
        CheckSize = UDim2.new(0, 20, 0, 20),
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = "",
        Enabled = true
    },
    RadioButton = {
        Size = UDim2.new(1, -10, 0, 30),
        RadioSize = UDim2.new(0, 20, 0, 20),
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Group = "",
        Tooltip = "",
        Enabled = true
    }
}

-- Utility function to create tweens
local function CreateTween(obj, props, duration, easingStyle, easingDirection)
    local tweenInfo = TweenInfo.new(
        duration or Elements.Defaults.Button.Animation.Duration,
        easingStyle or Enum.EasingStyle.Sine,
        easingDirection or Enum.EasingDirection.InOut
    )
    local tween = Elements.AnimationCache[obj] or TweenService:Create(obj, tweenInfo, props)
    Elements.AnimationCache[obj] = tween
    tween:Play()
    return tween
end

-- Utility function to apply theme styles
local function ApplyThemeStyle(element, theme, elementType)
    if not SnowtUI or not SnowtUI.Modules.Theme then
        SnowtUI.Debug("Theme module not loaded for element styling", "error")
        return
    end
    local style = theme[elementType] or theme.Button
    for prop, value in pairs(style) do
        if prop == "HoverColor" or prop == "Gradient" then
            -- Handled separately
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
        end
    end)
end

-- Button element
function Elements:CreateButton(parent, settings)
    settings = settings or {}
    local button = SnowtUI:GetPooledObject("TextButton")
    button.Size = settings.Size or Elements.Defaults.Button.Size
    button.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    button.Text = settings.Text or "Button"
    button.TextSize = settings.TextSize or Elements.Defaults.Button.TextSize
    button.Font = settings.Font or Elements.Defaults.Button.Font
    button.BackgroundTransparency = 0
    button.AutoButtonColor = false
    button.Parent = parent
    button.Name = settings.Name or "Button_" .. HttpService:GenerateGUID(false)
    button.Active = settings.Enabled ~= false

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(button, theme, "Button")
    CreateStroke(button, theme)
    CreateCorner(button, theme)

    local callback = settings.Callback or function() end
    local hoverScale = Elements.Defaults.Button.Animation.HoverScale
    local clickScale = Elements.Defaults.Button.Animation.ClickScale
    local duration = settings.Animation and settings.Animation.Duration or Elements.Defaults.Button.Animation.Duration

    button.MouseEnter:Connect(function()
        if not button.Active then return end
        CreateTween(button, {
            Size = UDim2.new(
                button.Size.X.Scale * hoverScale,
                button.Size.X.Offset * hoverScale,
                button.Size.Y.Scale * hoverScale,
                button.Size.Y.Offset * hoverScale
            ),
            BackgroundColor3 = theme.Button.HoverColor
        }, duration):Play()
        AddTooltip(button, settings.Tooltip or Elements.Defaults.Button.Tooltip)
    end)

    button.MouseLeave:Connect(function()
        if not button.Active then return end
        CreateTween(button, {
            Size = settings.Size or Elements.Defaults.Button.Size,
            BackgroundColor3 = theme.Button.BackgroundColor3
        }, duration):Play()
        SnowtUI:HideTooltip()
    end)

    button.MouseButton1Down:Connect(function()
        if not button.Active then return end
        if settings.Animation and settings.Animation.Ripple then
            local mousePos = UserInputService:GetMouseLocation()
            local relPos = UDim2.new(0, mousePos.X - button.AbsolutePosition.X, 0, mousePos.Y - button.AbsolutePosition.Y)
            CreateRipple(button, relPos)
        end
        CreateTween(button, {
            Size = UDim2.new(
                button.Size.X.Scale * clickScale,
                button.Size.X.Offset * clickScale,
                button.Size.Y.Scale * clickScale,
                button.Size.Y.Offset * clickScale
            )
        }, duration / 2):Play()
    end)

    button.MouseButton1Up:Connect(function()
        if not button.Active then return end
        CreateTween(button, {
            Size = settings.Size or Elements.Defaults.Button.Size
        }, duration / 2):Play()
        callback()
        SnowtUI.FireEvent("ButtonClicked", button.Name)
    end)

    AddContextMenu(button, {
        { Name = "Copy Text", Callback = function() setclipboard(button.Text) end },
        { Name = "Disable", Callback = function() button.Active = false end }
    })

    Elements.ElementCache[button.Name] = button
    SnowtUI:AddFocusableElement(parent, button)
    return button
end

-- Toggle element
function Elements:CreateToggle(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.Toggle.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "Toggle_" .. HttpService:GenerateGUID(false)
    frame.Active = settings.Enabled ~= false

    local label = SnowtUI:GetPooledObject("TextLabel")
    label.Size = UDim2.new(0.8, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = settings.Text or "Toggle"
    label.TextSize = Elements.Defaults.Button.TextSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local knob = SnowtUI:GetPooledObject("Frame")
    knob.Size = settings.KnobSize or Elements.Defaults.Toggle.KnobSize
    knob.Position = UDim2.new(1, -45, 0.5, -10)
    knob.BackgroundTransparency = 0
    knob.Parent = frame

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(label, theme, "Text")
    ApplyThemeStyle(knob, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(knob, theme)

    local state = settings.Default or false
    local callback = settings.Callback or function(value) end
    Elements.ConfigFlags[frame.Name] = state

    local function updateToggle()
        local pos = state and UDim2.new(1, -25, 0.5, -10) or UDim2.new(1, -45, 0.5, -10)
        CreateTween(knob, { Position = pos }, Elements.Defaults.Toggle.Animation.Duration, Elements.Defaults.Toggle.Animation.EasingStyle):Play()
        knob.BackgroundColor3 = state and theme.Button.HoverColor or theme.Button.BackgroundColor3
        callback(state)
        SnowtUI.FireEvent("ToggleChanged", frame.Name, state)
    end

    frame.InputBegan:Connect(function(input)
        if not frame.Active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            state = not state
            Elements.ConfigFlags[frame.Name] = state
            updateToggle()
            if settings.Animation and settings.Animation.Ripple then
                local mousePos = UserInputService:GetMouseLocation()
                local relPos = UDim2.new(0, mousePos.X - frame.AbsolutePosition.X, 0, mousePos.Y - frame.AbsolutePosition.Y)
                CreateRipple(frame, relPos)
            end
        end
    end)

    frame.MouseEnter:Connect(function()
        if not frame.Active then return end
        CreateTween(frame, { BackgroundColor3 = theme.Button.HoverColor }, Elements.Defaults.Toggle.Animation.Duration):Play()
        AddTooltip(frame, settings.Tooltip or Elements.Defaults.Toggle.Tooltip)
    end)

    frame.MouseLeave:Connect(function()
        if not frame.Active then return end
        CreateTween(frame, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Elements.Defaults.Toggle.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(frame, {
        { Name = "Copy State", Callback = function() setclipboard(tostring(state)) end },
        { Name = "Disable", Callback = function() frame.Active = false end }
    })

    updateToggle()
    Elements.ElementCache[frame.Name] = frame
    SnowtUI:AddFocusableElement(parent, frame)
    return frame
end

-- Slider element
function Elements:CreateSlider(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.Slider.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "Slider_" .. HttpService:GenerateGUID(false)
    frame.Active = settings.Enabled ~= false

    local label = SnowtUI:GetPooledObject("TextLabel")
    label.Size = UDim2.new(0.8, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = settings.Text or "Slider"
    label.TextSize = Elements.Defaults.Button.TextSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = SnowtUI:GetPooledObject("Frame")
    bar.Size = UDim2.new(1, 0, 0, Elements.Defaults.Slider.BarHeight)
    bar.Position = UDim2.new(0, 0, 1, -Elements.Defaults.Slider.BarHeight)
    bar.BackgroundTransparency = 0.5
    bar.Parent = frame

    local fill = SnowtUI:GetPooledObject("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundTransparency = 0
    fill.Parent = bar

    local knob = SnowtUI:GetPooledObject("Frame")
    knob.Size = settings.KnobSize or Elements.Defaults.Slider.KnobSize
    knob.Position = UDim2.new(0, 0, 0.5, -6)
    knob.BackgroundTransparency = 0
    knob.Parent = bar

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(label, theme, "Text")
    ApplyThemeStyle(bar, theme, "Button")
    ApplyThemeStyle(fill, theme, "Button")
    ApplyThemeStyle(knob, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(knob, theme)

    local min = settings.Min or Elements.Defaults.Slider.Min
    local max = settings.Max or Elements.Defaults.Slider.Max
    local step = settings.Step or Elements.Defaults.Slider.Step
    local value = settings.Default or min
    Elements.ConfigFlags[frame.Name] = value
    local callback = settings.Callback or function(val) end

    local function updateSlider(inputX)
        local barWidth = bar.AbsoluteSize.X
        local relativeX = math.clamp(inputX - bar.AbsolutePosition.X, 0, barWidth)
        local ratio = relativeX / barWidth
        value = math.floor((min + (max - min) * ratio) / step + 0.5) * step
        value = math.clamp(value, min, max)
        Elements.ConfigFlags[frame.Name] = value
        local fillWidth = ratio * barWidth
        CreateTween(fill, { Size = UDim2.new(0, fillWidth, 1, 0) }, Elements.Defaults.Slider.Animation.Duration, Elements.Defaults.Slider.Animation.EasingStyle):Play()
        CreateTween(knob, { Position = UDim2.new(0, fillWidth - knob.Size.X.Offset / 2, 0.5, -6) }, Elements.Defaults.Slider.Animation.Duration, Elements.Defaults.Slider.Animation.EasingStyle):Play()
        label.Text = (settings.Text or "Slider") .. ": " .. tostring(value)
        callback(value)
        SnowtUI.FireEvent("SliderChanged", frame.Name, value)
    end

    bar.InputBegan:Connect(function(input)
        if not frame.Active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            updateSlider(input.Position.X)
            if settings.Animation and settings.Animation.Ripple then
                CreateRipple(bar, UDim2.new(0, input.Position.X - bar.AbsolutePosition.X, 0.5, 0))
            end
        end
    end)

    bar.InputChanged:Connect(function(input)
        if not frame.Active then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                updateSlider(input.Position.X)
            end
        end
    end)

    bar.MouseEnter:Connect(function()
        if not frame.Active then return end
        CreateTween(bar, { BackgroundTransparency = 0.3 }, Elements.Defaults.Slider.Animation.Duration):Play()
        AddTooltip(bar, settings.Tooltip or Elements.Defaults.Slider.Tooltip)
    end)

    bar.MouseLeave:Connect(function()
        if not frame.Active then return end
        CreateTween(bar, { BackgroundTransparency = 0.5 }, Elements.Defaults.Slider.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(bar, {
        { Name = "Copy Value", Callback = function() setclipboard(tostring(value)) end },
        { Name = "Set to Min", Callback = function() updateSlider(bar.AbsolutePosition.X) end },
        { Name = "Set to Max", Callback = function() updateSlider(bar.AbsolutePosition.X + bar.AbsoluteSize.X) end }
    })

    updateSlider(bar.AbsolutePosition.X + (value - min) / (max - min) * bar.AbsoluteSize.X)
    Elements.ElementCache[frame.Name] = frame
    SnowtUI:AddFocusableElement(parent, frame)
    return frame
end

-- ColorPicker element
function Elements:CreateColorPicker(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.ColorPicker.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "ColorPicker_" .. HttpService:GenerateGUID(false)
    frame.Active = settings.Enabled ~= false

    local label = SnowtUI:GetPooledObject("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = settings.Text or "Color Picker"
    label.TextSize = Elements.Defaults.Button.TextSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local svFrame = SnowtUI:GetPooledObject("Frame")
    svFrame.Size = settings.SaturationValueSize or Elements.Defaults.ColorPicker.SaturationValueSize
    svFrame.Position = UDim2.new(0, 5, 0, 30)
    svFrame.BackgroundTransparency = 0
    svFrame.Parent = frame

    local hueBar = SnowtUI:GetPooledObject("Frame")
    hueBar.Size = settings.HueBarSize or Elements.Defaults.ColorPicker.HueBarSize
    hueBar.Position = UDim2.new(1, -25, 0, 30)
    hueBar.BackgroundTransparency = 0
    hueBar.Parent = frame

    local svGradient = SnowtUI:GetPooledObject("UIGradient")
    svGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    })
    svGradient.Parent = svFrame

    local hueGradient = SnowtUI:GetPooledObject("UIGradient")
    hueGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
    })
    hueGradient.Rotation = 90
    hueGradient.Parent = hueBar

    local svKnob = SnowtUI:GetPooledObject("Frame")
    svKnob.Size = UDim2.new(0, 10, 0, 10)
    svKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    svKnob.Position = UDim2.new(1, -5, 1, -5)
    svKnob.Parent = svFrame

    local hueKnob = SnowtUI:GetPooledObject("Frame")
    hueKnob.Size = UDim2.new(1, 0, 0, 5)
    hueKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hueKnob.Position = UDim2.new(0, 0, 0, 0)
    hueKnob.Parent = hueBar

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(label, theme, "Text")
    ApplyThemeStyle(svFrame, theme, "Button")
    ApplyThemeStyle(hueBar, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(svFrame, theme)
    CreateCorner(hueBar, theme)

    local color = settings.Default or Color3.fromRGB(255, 0, 0)
    local h, s, v = Color3.toHSV(color)
    Elements.ConfigFlags[frame.Name] = color
    local callback = settings.Callback or function(col) end

    local function updateColor()
        svFrame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(h, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
        })
        color = Color3.fromHSV(h, s, v)
        Elements.ConfigFlags[frame.Name] = color
        callback(color)
        SnowtUI.FireEvent("ColorPickerChanged", frame.Name, color)
    end

    svFrame.InputBegan:Connect(function(input)
        if not frame.Active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local svWidth, svHeight = svFrame.AbsoluteSize.X, svFrame.AbsoluteSize.Y
            s = math.clamp((input.Position.X - svFrame.AbsolutePosition.X) / svWidth, 0, 1)
            v = 1 - math.clamp((input.Position.Y - svFrame.AbsolutePosition.Y) / svHeight, 0, 1)
            CreateTween(svKnob, { Position = UDim2.new(s, -5, 1 - v, -5) }, Elements.Defaults.ColorPicker.Animation.Duration):Play()
            updateColor()
        end
    end)

    svFrame.InputChanged:Connect(function(input)
        if not frame.Active then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                local svWidth, svHeight = svFrame.AbsoluteSize.X, svFrame.AbsoluteSize.Y
                s = math.clamp((input.Position.X - svFrame.AbsolutePosition.X) / svWidth, 0, 1)
                v = 1 - math.clamp((input.Position.Y - svFrame.AbsolutePosition.Y) / svHeight, 0, 1)
                CreateTween(svKnob, { Position = UDim2.new(s, -5, 1 - v, -5) }, Elements.Defaults.ColorPicker.Animation.Duration):Play()
                updateColor()
            end
        end
    end)

    hueBar.InputBegan:Connect(function(input)
        if not frame.Active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            h = math.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
            CreateTween(hueKnob, { Position = UDim2.new(0, 0, h, 0) }, Elements.Defaults.ColorPicker.Animation.Duration):Play()
            updateColor()
        end
    end)

    hueBar.InputChanged:Connect(function(input)
        if not frame.Active then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                h = math.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
                CreateTween(hueKnob, { Position = UDim2.new(0, 0, h, 0) }, Elements.Defaults.ColorPicker.Animation.Duration):Play()
                updateColor()
            end
        end
    end)

    svFrame.MouseEnter:Connect(function()
        if not frame.Active then return end
        AddTooltip(svFrame, settings.Tooltip or Elements.Defaults.ColorPicker.Tooltip)
    end)

    svFrame.MouseLeave:Connect(function()
        if not frame.Active then return end
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(svFrame, {
        { Name = "Copy Color", Callback = function() setclipboard(tostring(color)) end }
    })

    updateColor()
    Elements.ElementCache[frame.Name] = frame
    SnowtUI:AddFocusableElement(parent, frame)
    return frame
end

-- Dropdown element
function Elements:CreateDropdown(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.Dropdown.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "Dropdown_" .. HttpService:GenerateGUID(false)
    frame.Active = settings.Enabled ~= false

    local button = SnowtUI:GetPooledObject("TextButton")
    button.Size = UDim2.new(1, 0, 1, 0)
    button.Text = settings.Text or "Select..."
    button.TextSize = Elements.Defaults.Button.TextSize
    button.AutoButtonColor = false
    button.Parent = frame

    local menu = SnowtUI:GetPooledObject("Frame")
    menu.Size = settings.MenuSize or Elements.Defaults.Dropdown.MenuSize
    menu.Position = UDim2.new(0, 0, 1, 5)
    menu.BackgroundTransparency = 0
    menu.Visible = false
    menu.Parent = frame
    menu.ClipsDescendants = true

    local list = SnowtUI:GetPooledObject("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.Padding = UDim.new(0, 2)
    list.Parent = menu

    local scroll = SnowtUI:GetPooledObject("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.Parent = menu

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(button, theme, "Button")
    ApplyThemeStyle(menu, theme, "Button")
    ApplyThemeStyle(scroll, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(menu, theme)

    local items = settings.Items or {}
    local selected = settings.Default or (items[1] and tostring(items[1])) or "None"
    Elements.ConfigFlags[frame.Name] = selected
    local callback = settings.Callback or function(item) end

    local function updateMenu()
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        local itemHeight = Elements.Defaults.Dropdown.ItemHeight
        for _, item in ipairs(items) do
            local itemButton = SnowtUI:GetPooledObject("TextButton")
            itemButton.Size = UDim2.new(1, -10, 0, itemHeight)
            itemButton.Text = tostring(item)
            itemButton.TextSize = Elements.Defaults.Button.TextSize
            itemButton.AutoButtonColor = false
            ApplyThemeStyle(itemButton, theme, "Button")
            itemButton.Parent = scroll
            itemButton.MouseButton1Click:Connect(function()
                selected = item
                Elements.ConfigFlags[frame.Name] = selected
                button.Text = tostring(item)
                menu.Visible = false
                CreateTween(menu, { BackgroundTransparency = 1 }, Elements.Defaults.Dropdown.Animation.Duration):Play()
                callback(item)
                SnowtUI.FireEvent("DropdownChanged", frame.Name, item)
            end)
            itemButton.MouseEnter:Connect(function()
                CreateTween(itemButton, { BackgroundColor3 = theme.Button.HoverColor }, Elements.Defaults.Dropdown.Animation.Duration):Play()
            end)
            itemButton.MouseLeave:Connect(function()
                CreateTween(itemButton, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Elements.Defaults.Dropdown.Animation.Duration):Play()
            end)
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, #items * (itemHeight + 2))
    end

    button.MouseButton1Click:Connect(function()
        if not frame.Active then return end
        menu.Visible = not menu.Visible
        CreateTween(menu, { BackgroundTransparency = menu.Visible and 0 or 1 }, Elements.Defaults.Dropdown.Animation.Duration, Elements.Defaults.Dropdown.Animation.EasingStyle):Play()
        if menu.Visible and settings.Animation and settings.Animation.Ripple then
            CreateRipple(button, UDim2.new(0.5, 0, 0.5, 0))
        end
    end)

    button.MouseEnter:Connect(function()
        if not frame.Active then return end
        CreateTween(button, { BackgroundColor3 = theme.Button.HoverColor }, Elements.Defaults.Dropdown.Animation.Duration):Play()
        AddTooltip(button, settings.Tooltip or Elements.Defaults.Dropdown.Tooltip)
    end)

    button.MouseLeave:Connect(function()
        if not frame.Active then return end
        CreateTween(button, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Elements.Defaults.Dropdown.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(button, {
        { Name = "Copy Selection", Callback = function() setclipboard(tostring(selected)) end },
        { Name = "Clear Selection", Callback = function()
            selected = "None"
            Elements.ConfigFlags[frame.Name] = selected
            button.Text = "Select..."
            callback(nil)
            SnowtUI.FireEvent("DropdownChanged", frame.Name, nil)
        end }
    })

    updateMenu()
    button.Text = tostring(selected)
    Elements.ElementCache[frame.Name] = frame
    SnowtUI:AddFocusableElement(parent, frame)
    return frame
end

-- TextField element
function Elements:CreateTextField(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.TextField.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "TextField_" .. HttpService:GenerateGUID(false)
    frame.Active = settings.Enabled ~= false

    local textBox = SnowtUI:GetPooledObject("TextBox")
    textBox.Size = UDim2.new(1, -10, 1, -10)
    textBox.Position = UDim2.new(0, 5, 0, 5)
    textBox.Text = settings.Text or ""
    textBox.TextSize = settings.TextSize or Elements.Defaults.TextField.TextSize
    textBox.Font = settings.Font or Elements.Defaults.TextField.Font
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.ClearTextOnFocus = settings.ClearOnFocus or Elements.Defaults.TextField.ClearOnFocus
    textBox.Parent = frame

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(textBox, theme, "Text")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)

    local callback = settings.Callback or function(text) end
    Elements.ConfigFlags[frame.Name] = textBox.Text

    textBox.Focused:Connect(function()
        if not frame.Active then textBox:ReleaseFocus() return end
        CreateTween(frame, { BackgroundColor3 = theme.Button.HoverColor }, Elements.Defaults.TextField.Animation.Duration):Play()
        AddTooltip(frame, settings.Tooltip or Elements.Defaults.TextField.Tooltip)
    end)

    textBox.FocusLost:Connect(function(enterPressed)
        if not frame.Active then return end
        CreateTween(frame, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Elements.Defaults.TextField.Animation.Duration):Play()
        SnowtUI:HideTooltip()
        if enterPressed then
            Elements.ConfigFlags[frame.Name] = textBox.Text
            callback(textBox.Text)
            SnowtUI.FireEvent("TextFieldChanged", frame.Name, textBox.Text)
        end
    end)

    AddContextMenu(textBox, {
        { Name = "Copy Text", Callback = function() setclipboard(textBox.Text) end },
        { Name = "Paste", Callback = function() textBox.Text = getclipboard() end }
    })

    Elements.ElementCache[frame.Name] = frame
    SnowtUI:AddFocusableElement(parent, frame)
    return frame
end

-- Keybind element
function Elements:CreateKeybind(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.Keybind.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "Keybind_" .. HttpService:GenerateGUID(false)
    frame.Active = settings.Enabled ~= false

    local label = SnowtUI:GetPooledObject("TextLabel")
    label.Size = UDim2.new(0.8, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = settings.Text or "Keybind"
    label.TextSize = Elements.Defaults.Button.TextSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local button = SnowtUI:GetPooledObject("TextButton")
    button.Size = UDim2.new(0.2, 0, 1, 0)
    button.Position = UDim2.new(0.8, 0, 0, 0)
    button.Text = settings.Default and tostring(settings.Default) or "None"
    button.TextSize = Elements.Defaults.Button.TextSize
    button.AutoButtonColor = false
    button.Parent = frame

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(label, theme, "Text")
    ApplyThemeStyle(button, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(button, theme)

    local key = settings.Default
    local callback = settings.Callback or function(k) end
    Elements.ConfigFlags[frame.Name] = key
    local waitingForKey = false

    button.MouseButton1Click:Connect(function()
        if not frame.Active then return end
        waitingForKey = true
        button.Text = "..."
        CreateTween(button, { BackgroundColor3 = theme.Button.HoverColor }, Elements.Defaults.Keybind.Animation.Duration):Play()
        if settings.Animation and settings.Animation.Ripple then
            CreateRipple(button, UDim2.new(0.5, 0, 0.5, 0))
        end
    end)

    UserInputService.InputBegan:Connect(function(input)
        if not waitingForKey or not frame.Active then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            key = input.KeyCode
            Elements.ConfigFlags[frame.Name] = key
            button.Text = tostring(key)
            waitingForKey = false
            CreateTween(button, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Elements.Defaults.Keybind.Animation.Duration):Play()
            callback(key)
            SnowtUI.FireEvent("KeybindChanged", frame.Name, key)
        end
    end)

    button.MouseEnter:Connect(function()
        if not frame.Active then return end
        CreateTween(button, { BackgroundColor3 = theme.Button.HoverColor }, Elements.Defaults.Keybind.Animation.Duration):Play()
        AddTooltip(button, settings.Tooltip or Elements.Defaults.Keybind.Tooltip)
    end)

    button.MouseLeave:Connect(function()
        if not frame.Active then return end
        CreateTween(button, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Elements.Defaults.Keybind.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(button, {
        { Name = "Clear Keybind", Callback = function()
            key = nil
            Elements.ConfigFlags[frame.Name] = nil
            button.Text = "None"
            callback(nil)
            SnowtUI.FireEvent("KeybindChanged", frame.Name, nil)
        end }
    })

    Elements.ElementCache[frame.Name] = frame
    SnowtUI:AddFocusableElement(parent, frame)
    return frame
end

-- Input element
function Elements:CreateInput(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.Input.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "Input_" .. HttpService:GenerateGUID(false)
    frame.Active = settings.Enabled ~= false

    local textBox = SnowtUI:GetPooledObject("TextBox")
    textBox.Size = UDim2.new(1, -10, 1, -10)
    textBox.Position = UDim2.new(0, 5, 0, 5)
    textBox.Text = settings.Text or ""
    textBox.TextSize = settings.TextSize or Elements.Defaults.Input.TextSize
    textBox.Font = settings.Font or Elements.Defaults.Input.Font
    textBox.TextXAlignment = Enum.TextXAlignment.Left
    textBox.ClearTextOnFocus = settings.ClearOnFocus or Elements.Defaults.Input.ClearOnFocus
    textBox.Parent = frame

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(textBox, theme, "Text")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)

    local callback = settings.Callback or function(text) end
    Elements.ConfigFlags[frame.Name] = textBox.Text

    textBox.Focused:Connect(function()
        if not frame.Active then textBox:ReleaseFocus() return end
        CreateTween(frame, { BackgroundColor3 = theme.Button.HoverColor }, Elements.Defaults.Input.Animation.Duration):Play()
        AddTooltip(frame, settings.Tooltip or Elements.Defaults.Input.Tooltip)
    end)

    textBox.FocusLost:Connect(function(enterPressed)
        if not frame.Active then return end
        CreateTween(frame, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Elements.Defaults.Input.Animation.Duration):Play()
        SnowtUI:HideTooltip()
        if enterPressed then
            Elements.ConfigFlags[frame.Name] = textBox.Text
            callback(textBox.Text)
            SnowtUI.FireEvent("InputChanged", frame.Name, textBox.Text)
        end
    end)

    AddContextMenu(textBox, {
        { Name = "Copy Text", Callback = function() setclipboard(textBox.Text) end },
        { Name = "Paste", Callback = function() textBox.Text = getclipboard() end }
    })

    Elements.ElementCache[frame.Name] = frame
    SnowtUI:AddFocusableElement(parent, frame)
    return frame
end

-- Paragraph element
function Elements:CreateParagraph(parent, settings)
    settings = settings or {}
    local text = SnowtUI:GetPooledObject("TextLabel")
    text.Size = settings.Size or Elements.Defaults.Paragraph.Size
    text.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    text.BackgroundTransparency = 1
    text.Text = settings.Text or "Paragraph"
    text.TextSize = settings.TextSize or Elements.Defaults.Paragraph.TextSize
    text.Font = settings.Font or Elements.Defaults.Paragraph.Font
    text.TextWrapped = Elements.Defaults.Paragraph.TextWrapped
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = parent
    text.Name = settings.Name or "Paragraph_" .. HttpService:GenerateGUID(false)

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(text, theme, "Text")

    text.MouseEnter:Connect(function()
        AddTooltip(text, settings.Tooltip or Elements.Defaults.Paragraph.Tooltip)
    end)

    text.MouseLeave:Connect(function()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(text, {
        { Name = "Copy Text", Callback = function() setclipboard(text.Text) end }
    })

    Elements.ElementCache[text.Name] = text
    return text
end

-- Section element
function Elements:CreateSection(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.Section.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    frame.Name = settings.Name or "Section_" .. HttpService:GenerateGUID(false)

    local label = SnowtUI:GetPooledObject("TextLabel")
    label.Size = UDim2.new(1, -30, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = settings.Text or "Section"
    label.TextSize = settings.TextSize or Elements.Defaults.Section.TextSize
    label.Font = settings.Font or Elements.Defaults.Section.Font
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local content = SnowtUI:GetPooledObject("Frame")
    content.Size = UDim2.new(1, 0, 0, 0)
    content.Position = UDim2.new(0, 0, 1, 5)
    content.BackgroundTransparency = 1
    content.Visible = settings.Expanded ~= false
    content.Parent = frame

    local contentList = SnowtUI:GetPooledObject("UIListLayout")
    contentList.FillDirection = Enum.FillDirection.Vertical
    contentList.Padding = UDim.new(0, 5)
    contentList.Parent = content

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(label, theme, "Text")

    if settings.Collapsible then
        local toggle = SnowtUI:GetPooledObject("TextButton")
        toggle.Size = UDim2.new(0, 20, 0, 20)
        toggle.Position = UDim2.new(1, -25, 0, 5)
        toggle.BackgroundTransparency = 1
        toggle.Text = content.Visible and "▼" or "▶"
        toggle.TextSize = 14
        toggle.TextColor3 = theme.Text.TextColor3
        toggle.Parent = frame

        toggle.MouseButton1Click:Connect(function()
            content.Visible = not content.Visible
            toggle.Text = content.Visible and "▼" or "▶"
            CreateTween(toggle, { Rotation = content.Visible and 0 or -90 }, Elements.Defaults.Button.Animation.Duration):Play()
            SnowtUI.FireEvent("SectionToggled", frame.Name, content.Visible)
        end)
    end

    frame.MouseEnter:Connect(function()
        AddTooltip(frame, settings.Tooltip or Elements.Defaults.Section.Tooltip)
    end)

    frame.MouseLeave:Connect(function()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(frame, {
        { Name = "Copy Section Title", Callback = function() setclipboard(label.Text) end }
    })

    Elements.ElementCache[frame.Name] = frame
    return frame, content
end

-- Divider element
function Elements:CreateDivider(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.Divider.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "Divider_" .. HttpService:GenerateGUID(false)

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    CreateStroke(frame, theme)

    frame.MouseEnter:Connect(function()
        AddTooltip(frame, settings.Tooltip or Elements.Defaults.Divider.Tooltip)
    end)

    frame.MouseLeave:Connect(function()
        SnowtUI:HideTooltip()
    end)

    Elements.ElementCache[frame.Name] = frame
    return frame
end

-- Code element
function Elements:CreateCode(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.Code.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "Code_" .. HttpService:GenerateGUID(false)

    local text = SnowtUI:GetPooledObject("TextLabel")
    text.Size = UDim2.new(1, -10, 1, -10)
    text.Position = UDim2.new(0, 5, 0, 5)
    text.BackgroundTransparency = 1
    text.Text = settings.Text or "-- Code here"
    text.TextSize = settings.TextSize or Elements.Defaults.Code.TextSize
    text.Font = settings.Font or Elements.Defaults.Code.Font
    text.TextWrapped = Elements.Defaults.Code.TextWrapped
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextYAlignment = Enum.TextYAlignment.Top
    text.Parent = frame

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(text, theme, "Text")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)

    text.MouseEnter:Connect(function()
        CreateTween(frame, { BackgroundColor3 = theme.Button.HoverColor }, Elements.Defaults.Code.Animation.Duration):Play()
        AddTooltip(text, settings.Tooltip or Elements.Defaults.Code.Tooltip)
    end)

    text.MouseLeave:Connect(function()
        CreateTween(frame, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Elements.Defaults.Code.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(text, {
        { Name = "Copy Code", Callback = function() setclipboard(text.Text) end }
    })

    Elements.ElementCache[frame.Name] = frame
    return frame
end

-- ImageLabel element
function Elements:CreateImageLabel(parent, settings)
    settings = settings or {}
    local image = SnowtUI:GetPooledObject("ImageLabel")
    image.Size = settings.Size or Elements.Defaults.ImageLabel.Size
    image.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    image.BackgroundTransparency = 1
    image.Image = settings.Image or Elements.Defaults.ImageLabel.Image
    image.ImageTransparency = settings.ImageTransparency or Elements.Defaults.ImageLabel.ImageTransparency
    image.Parent = parent
    image.Name = settings.Name or "ImageLabel_" .. HttpService:GenerateGUID(false)

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    CreateStroke(image, theme)
    CreateCorner(image, theme)

    image.MouseEnter:Connect(function()
        CreateTween(image, { ImageTransparency = 0.2 }, Elements.Defaults.ImageLabel.Animation.Duration):Play()
        AddTooltip(image, settings.Tooltip or Elements.Defaults.ImageLabel.Tooltip)
    end)

    image.MouseLeave:Connect(function()
        CreateTween(image, { ImageTransparency = Elements.Defaults.ImageLabel.ImageTransparency }, Elements.Defaults.ImageLabel.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(image, {
        { Name = "Copy Image ID", Callback = function() setclipboard(image.Image) end }
    })

    Elements.ElementCache[image.Name] = image
    return image
end

-- ProgressBar element
function Elements:CreateProgressBar(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.ProgressBar.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "ProgressBar_" .. HttpService:GenerateGUID(false)
    frame.Active = settings.Enabled ~= false

    local label = SnowtUI:GetPooledObject("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = settings.Text or "Progress"
    label.TextSize = Elements.Defaults.Button.TextSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local bar = SnowtUI:GetPooledObject("Frame")
    bar.Size = UDim2.new(1, 0, 0, Elements.Defaults.ProgressBar.BarHeight)
    bar.Position = UDim2.new(0, 0, 1, -Elements.Defaults.ProgressBar.BarHeight)
    bar.BackgroundTransparency = 0.5
    bar.Parent = frame

    local fill = SnowtUI:GetPooledObject("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundTransparency = 0
    fill.Parent = bar

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(label, theme, "Text")
    ApplyThemeStyle(bar, theme, "Button")
    ApplyThemeStyle(fill, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)

    local progress = settings.Default or 0
    Elements.ConfigFlags[frame.Name] = progress
    local callback = settings.Callback or function(val) end

    local function updateProgress(newProgress)
        progress = math.clamp(newProgress, 0, 1)
        Elements.ConfigFlags[frame.Name] = progress
        local fillWidth = bar.AbsoluteSize.X * progress
        CreateTween(fill, { Size = UDim2.new(0, fillWidth, 1, 0) }, Elements.Defaults.ProgressBar.Animation.Duration, Elements.Defaults.ProgressBar.Animation.EasingStyle):Play()
        label.Text = (settings.Text or "Progress") .. ": " .. math.floor(progress * 100) .. "%"
        callback(progress)
        SnowtUI.FireEvent("ProgressBarChanged", frame.Name, progress)
    end

    bar.MouseEnter:Connect(function()
        if not frame.Active then return end
        CreateTween(bar, { BackgroundTransparency = 0.3 }, Elements.Defaults.ProgressBar.Animation.Duration):Play()
        AddTooltip(bar, settings.Tooltip or Elements.Defaults.ProgressBar.Tooltip)
    end)

    bar.MouseLeave:Connect(function()
        if not frame.Active then return end
        CreateTween(bar, { BackgroundTransparency = 0.5 }, Elements.Defaults.ProgressBar.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(bar, {
        { Name = "Copy Progress", Callback = function() setclipboard(tostring(progress)) end }
    })

    updateProgress(progress)
    Elements.ElementCache[frame.Name] = frame
    return frame, updateProgress
end

-- Checkbox element
function Elements:CreateCheckbox(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.Checkbox.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "Checkbox_" .. HttpService:GenerateGUID(false)
    frame.Active = settings.Enabled ~= false

    local label = SnowtUI:GetPooledObject("TextLabel")
    label.Size = UDim2.new(0.8, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = settings.Text or "Checkbox"
    label.TextSize = Elements.Defaults.Button.TextSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local check = SnowtUI:GetPooledObject("Frame")
    check.Size = settings.CheckSize or Elements.Defaults.Checkbox.CheckSize
    check.Position = UDim2.new(1, -25, 0.5, -10)
    check.BackgroundTransparency = 0
    check.Parent = frame

    local checkMark = SnowtUI:GetPooledObject("ImageLabel")
    checkMark.Size = UDim2.new(1, -4, 1, -4)
    checkMark.Position = UDim2.new(0, 2, 0, 2)
    checkMark.BackgroundTransparency = 1
    checkMark.Image = "rbxassetid://123456789" -- Placeholder for checkmark icon
    checkMark.ImageTransparency = 1
    checkMark.Parent = check

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(label, theme, "Text")
    ApplyThemeStyle(check, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(check, theme)

    local state = settings.Default or false
    local callback = settings.Callback or function(value) end
    Elements.ConfigFlags[frame.Name] = state

    local function updateCheckbox()
        CreateTween(checkMark, { ImageTransparency = state and 0 or 1 }, Elements.Defaults.Checkbox.Animation.Duration, Elements.Defaults.Checkbox.Animation.EasingStyle):Play()
        check.BackgroundColor3 = state and theme.Button.HoverColor or theme.Button.BackgroundColor3
        callback(state)
        SnowtUI.FireEvent("CheckboxChanged", frame.Name, state)
    end

    frame.InputBegan:Connect(function(input)
        if not frame.Active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            state = not state
            Elements.ConfigFlags[frame.Name] = state
            updateCheckbox()
            if settings.Animation and settings.Animation.Ripple then
                CreateRipple(frame, UDim2.new(0.5, 0, 0.5, 0))
            end
        end
    end)

    frame.MouseEnter:Connect(function()
        if not frame.Active then return end
        CreateTween(frame, { BackgroundColor3 = theme.Button.HoverColor }, Elements.Defaults.Checkbox.Animation.Duration):Play()
        AddTooltip(frame, settings.Tooltip or Elements.Defaults.Checkbox.Tooltip)
    end)

    frame.MouseLeave:Connect(function()
        if not frame.Active then return end
        CreateTween(frame, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Elements.Defaults.Checkbox.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(frame, {
        { Name = "Copy State", Callback = function() setclipboard(tostring(state)) end },
        { Name = "Disable", Callback = function() frame.Active = false end }
    })

    updateCheckbox()
    Elements.ElementCache[frame.Name] = frame
    SnowtUI:AddFocusableElement(parent, frame)
    return frame
end

-- RadioButton element
function Elements:CreateRadioButton(parent, settings)
    settings = settings or {}
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Elements.Defaults.RadioButton.Size
    frame.Position = settings.Position or UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 0
    frame.Parent = parent
    frame.Name = settings.Name or "RadioButton_" .. HttpService:GenerateGUID(false)
    frame.Active = settings.Enabled ~= false

    local label = SnowtUI:GetPooledObject("TextLabel")
    label.Size = UDim2.new(0.8, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = settings.Text or "Radio Button"
    label.TextSize = Elements.Defaults.Button.TextSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local radio = SnowtUI:GetPooledObject("Frame")
    radio.Size = settings.RadioSize or Elements.Defaults.RadioButton.RadioSize
    radio.Position = UDim2.new(1, -25, 0.5, -10)
    radio.BackgroundTransparency = 0
    radio.Parent = frame

    local radioDot = SnowtUI:GetPooledObject("Frame")
    radioDot.Size = UDim2.new(0.5, 0, 0.5, 0)
    radioDot.Position = UDim2.new(0.25, 0, 0.25, 0)
    radioDot.BackgroundTransparency = 1
    radioDot.Parent = radio

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(label, theme, "Text")
    ApplyThemeStyle(radio, theme, "Button")
    ApplyThemeStyle(radioDot, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(radio, theme)
    CreateCorner(radioDot, theme)

    local state = settings.Default or false
    local group = settings.Group or frame.Name
    local callback = settings.Callback or function(value) end
    Elements.ConfigFlags[frame.Name] = state
    Elements.ConfigFlags[group] = Elements.ConfigFlags[group] or {}

    local function updateRadio()
        if state then
            for otherName, _ in pairs(Elements.ConfigFlags[group]) do
                if otherName ~= frame.Name then
                    Elements.ConfigFlags[otherName] = false
                    local otherFrame = Elements.ElementCache[otherName]
                    if otherFrame then
                        local otherDot = otherFrame:FindFirstChild("RadioDot", true)
                        if otherDot then
                            CreateTween(otherDot, { BackgroundTransparency = 1 }, Elements.Defaults.RadioButton.Animation.Duration):Play()
                        end
                    end
                end
            end
            CreateTween(radioDot, { BackgroundTransparency = 0 }, Elements.Defaults.RadioButton.Animation.Duration, Elements.Defaults.RadioButton.Animation.EasingStyle):Play()
        else
            CreateTween(radioDot, { BackgroundTransparency = 1 }, Elements.Defaults.RadioButton.Animation.Duration, Elements.Defaults.RadioButton.Animation.EasingStyle):Play()
        end
        callback(state)
        SnowtUI.FireEvent("RadioButtonChanged", frame.Name, state)
    end

    frame.InputBegan:Connect(function(input)
        if not frame.Active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not state then
                state = true
                Elements.ConfigFlags[frame.Name] = state
                Elements.ConfigFlags[group][frame.Name] = true
                updateRadio()
                if settings.Animation and settings.Animation.Ripple then
                    CreateRipple(frame, UDim2.new(0.5, 0, 0.5, 0))
                end
            end
        end
    end)

    frame.MouseEnter:Connect(function()
        if not frame.Active then return end
        CreateTween(frame, { BackgroundColor3 = theme.Button.HoverColor }, Elements.Defaults.RadioButton.Animation.Duration):Play()
        AddTooltip(frame, settings.Tooltip or Elements.Defaults.RadioButton.Tooltip)
    end)

    frame.MouseLeave:Connect(function()
        if not frame.Active then return end
        CreateTween(frame, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Elements.Defaults.RadioButton.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(frame, {
        { Name = "Copy State", Callback = function() setclipboard(tostring(state)) end },
        { Name = "Disable", Callback = function() frame.Active = false end }
    })

    updateRadio()
    Elements.ElementCache[frame.Name] = frame
    Elements.ConfigFlags[group][frame.Name] = state
    SnowtUI:AddFocusableElement(parent, frame)
    return frame
end

-- Initialize the Elements module
function Elements:Init(core)
    SnowtUI = core
    SnowtUI.Debug("Elements module initialized")
    
    -- Handle theme changes
    SnowtUI:RegisterEvent("ThemeChanged", function(themeName)
        local theme = SnowtUI.Modules.Theme.Themes[themeName]
        for name, element in pairs(Elements.ElementCache) do
            if element:IsA("Frame") or element:IsA("TextButton") or element:IsA("TextLabel") or element:IsA("ImageLabel") then
                ApplyThemeStyle(element, theme, element.ClassName == "TextLabel" and "Text" or "Button")
                for _, child in ipairs(element:GetDescendants()) do
                    if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then
                        ApplyThemeStyle(child, theme, child.ClassName == "TextLabel" and "Text" or "Button")
                    elseif child:IsA("UIStroke") then
                        ApplyThemeStyle(child, theme, "Stroke")
                    elseif child:IsA("UICorner") then
                        ApplyThemeStyle(child, theme, "Corner")
                    elseif child:IsA("UIGradient") then
                        -- Update gradients if needed
                        if element.Name:find("ColorPicker") then
                            local h, _, _ = Color3.toHSV(Elements.ConfigFlags[element.Name] or Color3.fromRGB(255, 0, 0))
                            if child.Parent.Name == "SVFrame" then
                                child.Color = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0, Color3.fromHSV(h, 1, 1)),
                                    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
                                })
                            end
                        end
                    end
                end
            end
        end
    end)

    -- Handle scale changes
    SnowtUI:RegisterEvent("ScaleAdjusted", function()
        for name, element in pairs(Elements.ElementCache) do
            if element:IsA("Frame") or element:IsA("TextButton") or element:IsA("TextLabel") or element:IsA("ImageLabel") then
                SnowtUI.Modules.Theme:ApplyAdaptiveStyle(element, SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()].Button)
                for _, child in ipairs(element:GetDescendants()) do
                    if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then
                        SnowtUI.Modules.Theme:ApplyAdaptiveStyle(child, SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()].Button)
                    end
                end
            end
        end
    end)

    -- Gamepad support
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent or not SnowtUI.Config.GamepadEnabled then return end
        if input.UserInputType == Enum.UserInputType.Gamepad1 then
            for _, window in ipairs(SnowtUI.Windows) do
                if window.FocusableElements and #window.FocusableElements > 0 then
                    SnowtUI:FocusNextElement(window)
                end
            end
        end
    end)
end

return Elements