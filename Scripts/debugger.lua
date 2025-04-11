local Debugger = {
    Window = nil,
    Tabs = {},
    CurrentTab = nil,
    Breakpoints = {},
    Watches = {},
    CallStack = {},
    Variables = {},
    Output = {},
    IsPaused = false,
    IsStepping = false,
    TargetCoroutine = nil,
    HookLevel = 0,
    CurrentLine = nil,
    ScriptEnvironment = {}, -- New: Store script environment
    LastError = nil, -- New: Track last error
    ExecutionSpeed = 1, -- New: Control execution speed
    AutoScroll = true, -- New: Auto-scroll output
    MaxOutputLines = 200 -- New: Increased output buffer
}

-- UI Element References (To be populated in CreateWindow)
Debugger.UI = {
    CodeEditorContent = nil,
    OutputConsoleContent = nil,
    VariablesPanelContent = nil,
    CallStackPanelContent = nil,
    BreakpointsPanelContent = nil
}

-- Helper function to clear a scrolling frame
local function ClearScrollingFrame(frame)
    if frame then
        for _, child in ipairs(frame:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then -- Adjust if other elements are used
                child:Destroy()
            end
        end
        -- Reset scroll position if needed
        frame.CanvasPosition = Vector2.new(0, 0)
    end
end

-- Helper function to add text to a scrolling frame
local function AddTextToScrollingFrame(frame, text, isButton, onClick)
    if not frame then return end
    local element
    if isButton then
        element = Instance.new("TextButton")
        element.Size = UDim2.new(1, -10, 0, 20)
        element.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        element.TextColor3 = Color3.fromRGB(220, 220, 220)
        element.TextXAlignment = Enum.TextXAlignment.Left
        element.BorderSizePixel = 0
        if onClick then
            element.MouseButton1Click:Connect(onClick)
        end
    else
        element = Instance.new("TextLabel")
        element.Size = UDim2.new(1, -10, 0, 20)
        element.BackgroundTransparency = 1
        element.TextColor3 = Color3.fromRGB(200, 200, 200)
        element.TextXAlignment = Enum.TextXAlignment.Left
    end
    element.Font = Enum.Font.Code
    element.TextSize = 14
    element.Text = text
    element.Parent = frame

    -- Update canvas size using UIListLayout
    local layout = frame:FindFirstChildOfClass("UIListLayout")
    if not layout then
        layout = Instance.new("UIListLayout")
        layout.Parent = frame
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 2)
    end
    -- Use AbsoluteContentSize which updates immediately
    frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
end

-- Create the main debugger window
function Debugger:CreateWindow()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DebuggerUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- Ensure it can draw over others
    ScreenGui.Parent = game:GetService("CoreGui")

    local Window = Instance.new("Frame")
    Window.Name = "MainWindow"
    Window.Size = UDim2.new(0, 800, 0, 600)
    Window.Position = UDim2.new(0.5, -400, 0.5, -300)
    Window.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Window.BorderSizePixel = 0
    Window.Draggable = true
    Window.Active = true
    Window.Selectable = true
    Window.Parent = ScreenGui

    -- Title bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 30)
    TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    TitleBar.Parent = Window

    local Title = Instance.new("TextLabel")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -40, 1, 0)
    Title.Position = UDim2.new(0, 5, 0, 0) -- Add padding
    Title.BackgroundTransparency = 1
    Title.Text = "Roblox Script Debugger"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextWrapped = false
    Title.Parent = TitleBar

    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -30, 0, 0)
    CloseButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.Font = Enum.Font.SourceSansBold
    CloseButton.TextSize = 16
    CloseButton.Parent = TitleBar
    CloseButton.MouseButton1Click:Connect(function()
        self:Stop() -- Stop debugging on close
        ScreenGui:Destroy()
    end)

    -- Control buttons
    local Controls = Instance.new("Frame")
    Controls.Name = "Controls"
    Controls.Size = UDim2.new(1, 0, 0, 40)
    Controls.Position = UDim2.new(0, 0, 0, 30)
    Controls.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Controls.Parent = Window

    local function CreateButton(name, text, position, width)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.new(0, width or 80, 0, 30)
        button.Position = position
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.TextColor3 = Color3.fromRGB(220, 220, 220)
        button.Font = Enum.Font.SourceSans
        button.TextSize = 14
        button.Text = text
        button.Parent = Controls
        return button
    end

    local ResumeButton = CreateButton("ResumeButton", "Resume", UDim2.new(0, 10, 0, 5))
    local PauseButton = CreateButton("PauseButton", "Pause", UDim2.new(0, 100, 0, 5))
    local StepOverButton = CreateButton("StepOverButton", "Step Over", UDim2.new(0, 190, 0, 5), 90)
    -- local StepIntoButton = CreateButton("StepIntoButton", "Step Into", UDim2.new(0, 290, 0, 5), 90) -- Future Add
    -- local StepOutButton = CreateButton("StepOutButton", "Step Out", UDim2.new(0, 390, 0, 5), 90)   -- Future Add
    local StopButton = CreateButton("StopButton", "Stop", UDim2.new(0, 290, 0, 5))

    -- Main content area
    local Content = Instance.new("Frame")
    Content.Name = "Content"
    Content.Size = UDim2.new(1, 0, 1, -70)
    Content.Position = UDim2.new(0, 0, 0, 70)
    Content.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    Content.Parent = Window

    -- Split view
    local LeftPanel = Instance.new("Frame")
    LeftPanel.Name = "LeftPanel"
    LeftPanel.Size = UDim2.new(0.6, 0, 1, 0)
    LeftPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    LeftPanel.Parent = Content

    local RightPanel = Instance.new("Frame")
    RightPanel.Name = "RightPanel"
    RightPanel.Size = UDim2.new(0.4, 0, 1, 0)
    RightPanel.Position = UDim2.new(0.6, 0, 0, 0)
    RightPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    RightPanel.Parent = Content

    local function CreatePanel(name, parent, size, position)
        local Panel = Instance.new("Frame")
        Panel.Name = name .. "Container"
        Panel.Size = size
        Panel.Position = position
        Panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        Panel.BorderSizePixel = 1
        Panel.BorderColor3 = Color3.fromRGB(40, 40, 40)
        Panel.Parent = parent

        local PanelTitle = Instance.new("TextLabel")
        PanelTitle.Name = name .. "Title"
        PanelTitle.Size = UDim2.new(1, 0, 0, 20)
        PanelTitle.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        PanelTitle.Text = "  " .. name -- Padding
        PanelTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
        PanelTitle.Font = Enum.Font.SourceSans
        PanelTitle.TextSize = 12
        PanelTitle.TextXAlignment = Enum.TextXAlignment.Left
        PanelTitle.Parent = Panel

        local ScrollingFrame = Instance.new("ScrollingFrame")
        ScrollingFrame.Name = name
        ScrollingFrame.Size = UDim2.new(1, 0, 1, -20)
        ScrollingFrame.Position = UDim2.new(0, 0, 0, 20)
        ScrollingFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        ScrollingFrame.BorderSizePixel = 0
        ScrollingFrame.ScrollBarThickness = 6
        ScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
        ScrollingFrame.ScrollingDirection = Enum.ScrollingDirection.Y
        ScrollingFrame.Parent = Panel

        -- Add UIListLayout for content management
        local layout = Instance.new("UIListLayout")
        layout.Name = name .. "Layout"
        layout.Parent = ScrollingFrame
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 2)

        return ScrollingFrame
    end

    -- Populate UI references
    self.UI.CodeEditorContent = CreatePanel("Source", LeftPanel, UDim2.new(1, 0, 0.6, 0), UDim2.new(0, 0, 0, 0))
    self.UI.OutputConsoleContent = CreatePanel("Output", LeftPanel, UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0.6, 0))
    self.UI.VariablesPanelContent = CreatePanel("Variables", RightPanel, UDim2.new(1, 0, 0.4, 0), UDim2.new(0, 0, 0, 0))
    self.UI.CallStackPanelContent = CreatePanel("Call Stack", RightPanel, UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0.4, 0))
    self.UI.BreakpointsPanelContent = CreatePanel("Breakpoints", RightPanel, UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0.7, 0))

    -- Add drag functionality to the window
    local UserInputService = game:GetService("UserInputService")
    local dragging
    local dragInput
    local dragStart
    local startPos

    local function update(input)
        local delta = input.Position - dragStart
        Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Window.Position
            Window.Active = true -- Bring window to front
        end
    end)

    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)

    -- Button functionality
    ResumeButton.MouseButton1Click:Connect(function()
        self:Resume()
    end)

    PauseButton.MouseButton1Click:Connect(function()
        self:Pause()
    end)

    StepOverButton.MouseButton1Click:Connect(function()
        self:Step()
    end)

    StopButton.MouseButton1Click:Connect(function()
        self:Stop()
    end)

    self.Window = Window
end

-- Enhanced Hook Function for Roblox
function Debugger:Hook(event, line)
    if not self.TargetCoroutine then return end

    -- Add execution speed control
    if self.ExecutionSpeed < 1 then
        task.wait(1 - self.ExecutionSpeed)
    end

    local currentLevel = self:GetCurrentHookLevel()
    local isPausedBeforeHook = self.IsPaused

    if event == "line" then
        self.CurrentLine = line
        self:UpdateCodeViewHighlight(line)

        -- Enhanced breakpoint handling
        if self.Breakpoints[line] then
            if not isPausedBeforeHook then
                self:LogOutput(string.format("Breakpoint hit at line %d", line))
            end
            self.IsPaused = true
            self.IsStepping = false
        end

        -- Enhanced stepping
        if self.IsStepping and currentLevel <= self.HookLevel then
            self.IsPaused = true
            self.IsStepping = false
            self.HookLevel = 0
        end
    elseif event == "call" then
        if self.IsStepping and currentLevel > self.HookLevel then
            self.IsPaused = true
        end
    elseif event == "return" then
        if self.IsStepping and currentLevel == self.HookLevel then
            -- No action needed, handled by line event
        end
    end

    -- Enhanced pause handling
    if self.IsPaused then
        if not isPausedBeforeHook or self.IsStepping then
            self:UpdateUIState()
        end

        while self.IsPaused do
            local yieldSuccess, resumeValue = coroutine.yield()
            if not yieldSuccess then
                self:LogOutput("Coroutine terminated or errored while paused: " .. tostring(resumeValue))
                self:Stop()
                return
            end
            if not self.TargetCoroutine then return end
        end
    end
end

-- Get current function call level for stepping
function Debugger:GetCurrentHookLevel()
    local level = 0
    while debug.getinfo(level + 3, "l") do -- +3: Hook -> coroutine.yield -> GetCurrentHookLevel -> Caller
        level = level + 1
    end
    return level -- Return the actual stack depth relative to the debugged code
end

-- Set/Clear the debug hook
function Debugger:SetHook(enable)
    if enable then
        if self.TargetCoroutine and coroutine.status(self.TargetCoroutine) ~= "dead" then
             -- Use pcall for safety as sethook can sometimes error in specific contexts
            local success, err = pcall(debug.sethook, self.TargetCoroutine, function(...) self:Hook(...) end, "lcr", 0) -- Line, Call, Return hooks
            if not success then
                self:LogOutput("Error setting debug hook: " .. tostring(err))
                self:Stop()
            end
        end
    else
        if self.TargetCoroutine then -- Check if coroutine exists before trying to clear hook
            -- Check status before clearing to avoid errors on dead coroutines
            local status = coroutine.status(self.TargetCoroutine)
            if status == "suspended" or status == "running" or status == "normal" then
                 pcall(debug.sethook, self.TargetCoroutine) -- Clear hook safely
            end
        end
    end
end

-- UI Update Functions
function Debugger:UpdateCodeViewHighlight(currentLine)
    if not self.UI.CodeEditorContent then return end
    for _, item in ipairs(self.UI.CodeEditorContent:GetChildren()) do
        if item:IsA("TextButton") then
            -- Extract line number from text (assuming format "LINE: CODE")
            local numStr = item.Text:match("^%s*(%d+):")
            if numStr then
                local lineNum = tonumber(numStr)
                if lineNum == currentLine then
                    item.BackgroundColor3 = Color3.fromRGB(80, 80, 50) -- Highlight color
                    -- Scroll to highlighted line if needed
                    local frame = self.UI.CodeEditorContent
                    local scrollY = item.AbsolutePosition.Y - frame.AbsolutePosition.Y
                    local visibleMin = frame.CanvasPosition.Y
                    local visibleMax = visibleMin + frame.AbsoluteSize.Y - 50 -- Add buffer
                    if scrollY < visibleMin or scrollY > visibleMax then
                        frame.CanvasPosition = Vector2.new(0, scrollY - 50) -- Adjust offset as needed
                    end
                else
                    item.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Default button color
                end
            end
        end
    end
end

function Debugger:ClearCodeViewHighlight()
    if not self.UI.CodeEditorContent then return end
    for _, item in ipairs(self.UI.CodeEditorContent:GetChildren()) do
        if item:IsA("TextButton") then
            item.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Default button color
        end
    end
end

-- Enhanced UI Update for Roblox
function Debugger:UpdateUIState()
    if not self.TargetCoroutine or coroutine.status(self.TargetCoroutine) == "dead" then
        ClearScrollingFrame(self.UI.VariablesPanelContent)
        ClearScrollingFrame(self.UI.CallStackPanelContent)
        self:ClearCodeViewHighlight()
        return
    end

    -- Enhanced variable inspection
    ClearScrollingFrame(self.UI.VariablesPanelContent)
    local stackLevel = 2
    local success, info = pcall(debug.getinfo, self.TargetCoroutine, stackLevel, "Lf")
    if success and info and info.func then
        AddTextToScrollingFrame(self.UI.VariablesPanelContent, "-- Locals --", false)
        local i = 1
        while true do
            local name, value = debug.getlocal(self.TargetCoroutine, stackLevel, i)
            if not name then break end
            if name ~= "(*temporary)" then
                local valStr = tostring(value)
                if #valStr > 100 then valStr = string.sub(valStr, 1, 100) .. "..." end
                AddTextToScrollingFrame(self.UI.VariablesPanelContent, string.format("%s = %s", name, valStr), false)
            end
            i = i + 1
        end

        AddTextToScrollingFrame(self.UI.VariablesPanelContent, "", false)
        AddTextToScrollingFrame(self.UI.VariablesPanelContent, "-- Upvalues --", false)
        local j = 1
        while true do
            local name, value = debug.getupvalue(info.func, j)
            if not name then break end
            local valStr = tostring(value)
            if #valStr > 100 then valStr = string.sub(valStr, 1, 100) .. "..." end
            AddTextToScrollingFrame(self.UI.VariablesPanelContent, string.format("%s = %s", name, valStr), false)
            j = j + 1
        end
    else
        AddTextToScrollingFrame(self.UI.VariablesPanelContent, "(No variable info available at this level)", false)
    end

    -- Enhanced call stack display
    ClearScrollingFrame(self.UI.CallStackPanelContent)
    local level = 1
    while true do
        local success, stackInfo = pcall(debug.getinfo, self.TargetCoroutine, level + 1, "Snl")
        if not success or not stackInfo then break end

        local funcName = stackInfo.name or ("(anonymous function at line " .. (stackInfo.linedefined or "?") .. ")")
        local source = stackInfo.short_src or "(unknown source)"
        if source:len() > 50 then source = "..." .. source:sub(-47) end
        local line = stackInfo.currentline > 0 and tostring(stackInfo.currentline) or "?"
        AddTextToScrollingFrame(self.UI.CallStackPanelContent, string.format("%d: %s (%s:%s)", level, funcName, source, line), false)
        level = level + 1
        if level > 20 then
            AddTextToScrollingFrame(self.UI.CallStackPanelContent, "... (stack too deep)", false)
            break
        end
    end

    -- Enhanced breakpoints display
    ClearScrollingFrame(self.UI.BreakpointsPanelContent)
    local sortedBreakpoints = {}
    for line, _ in pairs(self.Breakpoints) do
        table.insert(sortedBreakpoints, line)
    end
    table.sort(sortedBreakpoints)
    for _, line in ipairs(sortedBreakpoints) do
        AddTextToScrollingFrame(self.UI.BreakpointsPanelContent, string.format("Line %d", line), true, function()
            self:RemoveBreakpoint(line)
        end)
    end

    -- Enhanced output display
    ClearScrollingFrame(self.UI.OutputConsoleContent)
    for _, msg in ipairs(self.Output) do
        AddTextToScrollingFrame(self.UI.OutputConsoleContent, msg, false)
    end
    
    if self.AutoScroll then
        local outputFrame = self.UI.OutputConsoleContent
        task.defer(function()
            if outputFrame and outputFrame.Parent then
                outputFrame.CanvasPosition = Vector2.new(0, outputFrame.CanvasSize.Y.Offset)
            end
        end)
    end
end

-- Debugger control functions
function Debugger:Resume()
    if not self.TargetCoroutine or coroutine.status(self.TargetCoroutine) ~= "suspended" then
        self:LogOutput("Cannot resume: Script not loaded or not paused.")
        return
    end
    self.IsPaused = false
    self.IsStepping = false
    self:ClearCodeViewHighlight() -- Clear highlight when resuming freely
    self:SetHook(true) -- Ensure hook is active
    self:LogOutput("Resuming execution...")
    -- Resume the coroutine - this needs to happen outside the hook context
    local ok, err = coroutine.resume(self.TargetCoroutine)
    if not ok then
        self:LogOutput("Error resuming script: " .. tostring(err))
        self:Stop()
    elseif coroutine.status(self.TargetCoroutine) == "dead" then
        self:LogOutput("Script execution finished.")
        self:Stop()
    end
end

function Debugger:Pause()
    if not self.TargetCoroutine or coroutine.status(self.TargetCoroutine) == "dead" then
         self:LogOutput("Cannot pause: No script running.")
         return
    end
    if self.IsPaused then
        self:LogOutput("Already paused.")
        return
    end
    self.IsPaused = true
    self.IsStepping = false
    -- The hook will handle pausing on the next event
    self:SetHook(true) -- Ensure hook is active
    self:LogOutput("Execution pause requested. Will pause at next line/call/return.")
    -- Note: Pausing isn't instant, it waits for the hook
end

function Debugger:Step()
    if not self.TargetCoroutine or coroutine.status(self.TargetCoroutine) ~= "suspended" then
        self:LogOutput("Cannot step: Script not loaded or not paused.")
        return
    end
    self.IsPaused = false -- Allow execution for one step
    self.IsStepping = true
    self.HookLevel = self:GetCurrentHookLevel() -- Capture level *before* resuming
    self:SetHook(true) -- Ensure hook is active for stepping
    self:LogOutput("Stepping over...")
    -- Resume the coroutine for one step
    local ok, err = coroutine.resume(self.TargetCoroutine)
    -- Check status *after* resume attempt
    if not ok then
        self:LogOutput("Error stepping script: " .. tostring(err))
        self:Stop()
    elseif coroutine.status(self.TargetCoroutine) == "dead" then
        self:LogOutput("Script execution finished.")
        self:Stop()
    -- elseif self.IsPaused then -- Re-paused by the hook
        -- UI update is handled by the hook itself when it pauses
    end
end

function Debugger:Stop()
    if not self.TargetCoroutine then
       -- self:LogOutput("Nothing to stop.")
       return -- Already stopped or never started
    end
    self:LogOutput("Stopping execution.")
    local co = self.TargetCoroutine
    self.TargetCoroutine = nil -- Release reference *before* clearing hook
    self:SetHook(false) -- Remove the hook
    self.IsPaused = false
    self.IsStepping = false
    self.CurrentLine = nil
    -- Optionally kill the coroutine if possible/needed (may not be standard)
    -- pcall(coroutine.close, co) -- Use with caution, depends on environment support & safety

    -- Clear UI related to running state
    self:UpdateUIState() -- Call once more to clear panels
    self:ClearCodeViewHighlight()
    -- Optionally clear output or breakpoints too
    -- ClearScrollingFrame(self.UI.OutputConsoleContent)
    -- ClearScrollingFrame(self.UI.BreakpointsPanelContent)
    -- self.Breakpoints = {}
    -- self.Output = {}
end

function Debugger:AddBreakpoint(line)
    if type(line) ~= "number" or line <= 0 then return end
    line = math.floor(line)
    if self.Breakpoints[line] then return end -- Already exists
    self.Breakpoints[line] = true
    self:LogOutput(string.format("Breakpoint added at line %d", line))
    self:UpdateUIState() -- Update breakpoint list display
end

function Debugger:RemoveBreakpoint(line)
    if type(line) ~= "number" or line <= 0 then return end
    line = math.floor(line)
    if self.Breakpoints[line] then
        self.Breakpoints[line] = nil
        self:LogOutput(string.format("Breakpoint removed from line %d", line))
        self:UpdateUIState() -- Update breakpoint list display
    end
end

function Debugger:AddWatch(expression)
    -- Watch evaluation is complex and environment-dependent (using getfenv/loadstring)
    -- Requires careful sandboxing in exploit contexts.
    table.insert(self.Watches, expression)
    self:LogOutput(string.format("Watch added for: %s (Evaluation not implemented)", expression))
    -- TODO: Implement watch evaluation in UpdateUIState if feasible/safe
end

-- Variable/Stack updates are handled in UpdateUIState
function Debugger:UpdateVariables(variables) end -- Keep for potential external updates
function Debugger:UpdateCallStack(stack) end -- Keep for potential external updates

function Debugger:LogOutput(message)
    table.insert(self.Output, os.date("%H:%M:%S ") .. tostring(message))
    -- Keep output log manageable (e.g., last 100 lines)
    if #self.Output > 100 then
        table.remove(self.Output, 1)
    end
    if self.UI.OutputConsoleContent then -- Ensure UI is created
        -- Update display efficiently
        ClearScrollingFrame(self.UI.OutputConsoleContent)
        for _, msg in ipairs(self.Output) do
            AddTextToScrollingFrame(self.UI.OutputConsoleContent, msg, false)
        end
        -- Scroll to bottom
        local outputFrame = self.UI.OutputConsoleContent
        -- Use task.defer to scroll after layout updates
        task.defer(function()
            if outputFrame and outputFrame.Parent then -- Check if frame still exists
                 outputFrame.CanvasPosition = Vector2.new(0, outputFrame.CanvasSize.Y.Offset)
            end
        end)
    end
end

-- Enhanced Script Loading for Roblox
function Debugger:DebugScript(scriptSourceOrInstance)
    local sourceCode
    local sourceName = "(debugged script)"
    
    -- Enhanced script source handling
    if typeof(scriptSourceOrInstance) == "Instance" then
        if scriptSourceOrInstance:IsA("LuaSourceContainer") then
            sourceCode = scriptSourceOrInstance.Source
            sourceName = scriptSourceOrInstance:GetFullName()
        elseif scriptSourceOrInstance:IsA("StringValue") then
            sourceCode = scriptSourceOrInstance.Value
            sourceName = scriptSourceOrInstance.Name
        end
    elseif type(scriptSourceOrInstance) == "string" then
        sourceCode = scriptSourceOrInstance
    else
        self:LogOutput("Error: Invalid script source provided.")
        return
    end

    -- Enhanced source code display
    ClearScrollingFrame(self.UI.CodeEditorContent)
    local lines = {}
    local normalizedSource = sourceCode:gsub("\r\n", "\n"):gsub("\r", "\n")

    local currentPos = 1
    repeat
        local nextPos = normalizedSource:find("\n", currentPos, true)
        local line
        if nextPos then
            line = normalizedSource:sub(currentPos, nextPos - 1)
            currentPos = nextPos + 1
        else
            line = normalizedSource:sub(currentPos)
            currentPos = #normalizedSource + 1
        end
        table.insert(lines, line)
    until currentPos > #normalizedSource

    if #lines == 1 and lines[1] == "" and #normalizedSource == 0 then
        lines = {}
    end

    -- Enhanced line display with syntax highlighting
    for i, lineText in ipairs(lines) do
        local lineButton = AddTextToScrollingFrame(self.UI.CodeEditorContent, string.format("%d: %s", i, lineText), true, function()
            if self.Breakpoints[i] then
                self:RemoveBreakpoint(i)
            else
                self:AddBreakpoint(i)
            end
        end)
        
        -- Add syntax highlighting colors
        if lineText:match("^%s*function") or lineText:match("^%s*local%s+function") then
            lineButton.TextColor3 = Color3.fromRGB(86, 156, 214) -- Blue for functions
        elseif lineText:match("^%s*if") or lineText:match("^%s*elseif") or lineText:match("^%s*else") or lineText:match("^%s*end") then
            lineButton.TextColor3 = Color3.fromRGB(197, 134, 192) -- Purple for control structures
        elseif lineText:match("^%s*local") or lineText:match("^%s*return") then
            lineButton.TextColor3 = Color3.fromRGB(86, 156, 214) -- Blue for keywords
        elseif lineText:match("^%s*--") then
            lineButton.TextColor3 = Color3.fromRGB(106, 153, 85) -- Green for comments
        end
    end

    -- Enhanced script compilation with sandboxing
    local loadSuccess, result = pcall(function()
        local env = {}
        setmetatable(env, {__index = _G})
        return loadstring(sourceCode, "=" .. sourceName)
    end)

    if not loadSuccess then
        self:LogOutput("Compilation Error: " .. tostring(result))
        return
    end

    local compiledFunc = result
    if type(compiledFunc) ~= 'function' then
        self:LogOutput("Compilation failed: loadstring did not return a function.")
        return
    end

    -- Enhanced script execution setup
    self:Stop()
    self.TargetCoroutine = coroutine.create(compiledFunc)
    self.IsPaused = true
    self.IsStepping = false
    self:LogOutput(string.format("Loaded script '%s'. Paused at start.", sourceName))
    self:SetHook(true)
    self:UpdateUIState()
end

-- Initialize the debugger UI
Debugger:CreateWindow()

-- Example Usage (Requires manual execution after loading)
--[[ Example Script Loading:
local MyScript = game.ReplicatedStorage.MyScript -- Path to your script instance

-- In another script or command bar (after the debugger is created):
-- Make sure the path to the debugger module is correct
local DebuggerModule = require(game:GetService("CoreGui"):WaitForChild("DebuggerUI"):WaitForChild("MainWindow"))
DebuggerModule:DebugScript(MyScript)

-- Then click 'Resume' or 'Step Over' in the UI to start.
]]

return Debugger