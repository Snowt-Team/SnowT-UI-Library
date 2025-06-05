local UILibrary = {}
local UserInputService = game:GetService("UserInputService")

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

function UIElement:SetBackgroundTransparency(transparency)
	self.Instance.BackgroundTransparency = transparency or 0
	return self
end

-- Метод для включения перетаскивания (Dragging)
function UIElement:MakeDraggable()
	local dragging = false
	local dragStart = nil
	local startPos = nil

	localload function updatePosition(input)
		local delta = input.Position - dragStart
		local newPosX = startPos.X.Scale + (delta.X / self.Instance.Parent.AbsoluteSize.X)
		local newPosY = startPos.Y.Scale + (delta.Y / self.Instance.Parent.AbsoluteSize.Y)
		self.Instance.Position = UDim2.new(newPosX, startPos.X.Offset, newPosY, startPos.Y.Offset)
	end

	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and self.Instance:IsDescendantOf(game) then
			local guiObjects = UserInputService:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)
			if guiObjects[1] == self.Instance then -- Проверяем, что касание только на фрейме
				dragging = true
				dragStart = input.Position
				startPos = self.Instance.Position
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and dragging then
			updatePosition(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

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

-- Функция для создания системы табов с прокруткой
function UILibrary.CreateTabSystem(name, parent, tabs)
	local tabSystem = {}
	
	-- Создаем контейнер для табов (ScrollingFrame)
	local tabContainer = Instance.new("ScrollingFrame")
	tabContainer.Name = name .. "TabContainer"
	tabContainer.BackgroundTransparency = 1
	tabContainer.Size = UDim2.new(0.3, 0, 1, 0) -- 30% ширины слева
	tabContainer.Position = UDim2.new(0, 0, 0, 0)
	tabContainer.CanvasSize = UDim2.new(0, 0, 0, 0) -- Автоматический размер
	tabContainer.ScrollBarThickness = 4
	tabContainer.Parent = parent

	local contentContainer = Instance.new("Frame")
	contentContainer.Name = name .. "ContentContainer"
	contentContainer.BackgroundTransparency = 1
	contentContainer.Size = UDim2.new(0.7, 0, 1, 0) -- 70% ширины справа
	contentContainer.Position = UDim2.new(0.3, 0, 0, 0)
	contentContainer.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = tabContainer

	-- Обновляем CanvasSize при добавлении новых табов
	local function updateCanvasSize()
		local totalHeight = layout.AbsoluteContentSize.Y
		tabContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
	end

	tabSystem.Tabs = {}
	tabSystem.ContentFrames = {}
	tabSystem.SelectTab = function(tabName)
		for name, contentFrame in pairs(tabSystem.ContentFrames) do
			contentFrame:SetVisible(name == tabName)
		end
		for name, tabButton in pairs(tabSystem.Tabs) do
			tabButton.Instance.BackgroundColor3 = name == tabName and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(50, 50, 50)
		end
	end

	for _, tab in ipairs(tabs) do
		local tabName = tab.Name
		local contentFrame = UILibrary.CreateFrame(tabName .. "Content", contentContainer)
			:SetSize(1, 1)
			:SetVisible(false)
		tabSystem.ContentFrames[tabName] = contentFrame

		local tabButton = UILibrary.CreateButton(tabName .. "Tab", tabName, tabContainer, function()
			tabSystem.SelectTab(tabName)
		end)
			:SetSize(0.9, 0, 0, 40) -- Фиксированная высота кнопки
		UILibrary.AddCorner(tabButton, 0.1)
		tabSystem.Tabs[tabName] = tabButton

		if tab.Content then
			tab.Content(contentFrame.Instance)
		end
	end

	-- Обновляем CanvasSize после создания всех табов
	updateCanvasSize()

	-- Подключаем обновление CanvasSize при изменении содержимого
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)

	-- Активируем первую вкладку по умолчанию
	if tabs[1] then
		tabSystem.SelectTab(tabs[1].Name)
	end

	return UIElement.new(tabContainer)
end

return UILibrary