local UILibrary = {}

-- Создание основного класса UI-элемента
local UIElement = {}
UIElement.__index = UIElement

function UIElement.new(instance)
	local self = setmetatable({}, UIElement)
	self.Instance = instance
	return self
end

function UIElement:SetPosition(x, y, scaleOrOffset)
	self.Instance.Position = UDim2.new(x, scaleOrOffset or 0, y, scaleOrOffset or 0)
	return self
end

function UIElement:SetSize(width, height, scaleOrOffset)
	self.Instance.Size = UDim2.new(width, scaleOrOffset or 0, height, scaleOrOffset or 0)
	return self
end

function UIElement:SetAnchorPoint(x, y)
	self.Instance.AnchorPoint = Vector2.new(x, y)
	return self
end

function UIElement:SetParent(parent)
	self.Instance.Parent = parent
	return self
end

function UIElement:SetVisible(visible)
	self.Instance.Visible = visible
	return self
end

-- Функция для создания ScreenGui
function UILibrary.CreateScreenGui(name, parent)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = name
	screenGui.Parent = parent or game.Players.LocalPlayer.PlayerGui
	return UIElement.new(screenGui)
end

-- Функция для создания Frame
function UILibrary.CreateFrame(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return UIElement.new(frame)
end

-- Функция для создания TextLabel
function UILibrary.CreateTextLabel(name, text, parent)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSans
	label.Parent = parent
	return UIElement.new(label)
end

-- Функция для создания TextButton
function UILibrary.CreateButton(name, text, parent, callback)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.SourceSans
	button.Parent = parent
	
	local uiElement = UIElement.new(button)
	if callback then
		button.MouseButton1Click:Connect(callback)
	end
	return uiElement
end

-- Функция для добавления закругленных углов (UICorner)
function UILibrary.AddCorner(element, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(radius or 0, 8)
	corner.Parent = element.Instance
	return element
end

-- Функция для добавления тени (UIStroke)
function UILibrary.AddStroke(element, thickness, color)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness or 2
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Parent = element.Instance
	return element
end

return UILibrary