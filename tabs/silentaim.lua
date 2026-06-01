local userInputService = game:GetService('UserInputService')
local players = game:GetService("Players")
local localpalyer = players.LocalPlayer
local httpService = game:GetService("HttpService")

local module = {
    _camera = workspace.CurrentCamera,
    _mouse = localpalyer:GetMouse(),
    _aimbotConnection = {
        index = Instance.new("BindableEvent"),
        connection = nil,
    },
    _fov = { radius = 400 },
    _activePlayer = nil,
    _aimbotOn = false,
    _isInUse = false,
    _toggle = {
        isOn = false,
        isToggleable = true
    },
    _hitTracer = false,
    _toggledText = nil,
    useMethodTwo = false,
    _whitelistedPlayers = {},
    _target = nil,
    _desync = false,
    _skipKeyUse = false,
}

local file, info = pcall(function()
    return readfile('ProjectLore/whitelisted_players.json')
end)
if file then
    module._whitelistedPlayers = httpService:JSONDecode(readfile('ProjectLore/whitelisted_players.json'))
end

function module:_returnParts(character)
    if character then
        return {
            head = character:FindFirstChild('Head'),
            humanoid = character:FindFirstChild('Humanoid'),
            humanoidrootpart = character:FindFirstChild('HumanoidRootPart'),
        }
    end
end

function module:_mousePosition() return Vector2.new(self._mouse.X,self._mouse.Y) end

function module:_changeCFrame(cframe) self._camera.CFrame = cframe end

function module:_getPlayer()
    local target = nil
    local closest = { mouse = math.huge, player = math.huge }
    local distance = { mouse = math.huge, player = math.huge }
    for _, player in pairs(players:GetPlayers()) do
        if player ~= localpalyer and player.Character and player.Character:FindFirstChild('Humanoid') and player.Character:FindFirstChild('HumanoidRootPart')  then
            if table.find(self._whitelistedPlayers,player.Name) or table.find(self._whitelistedPlayers,player.UserId) then break end
            local character = player.Character
            local parts = self:_returnParts(character)
            local vector, isVisible = self._camera:WorldToViewportPoint(parts.humanoidrootpart.Position)
            if isVisible then
                distance.mouse = ( Vector2.new(vector.X,vector.Y) - self:_mousePosition() ).magnitude
                if distance.mouse < math.min(self._fov.radius,closest.mouse) then
                    distance.player = math.abs( (parts.humanoidrootpart.Position - localpalyer.Character.HumanoidRootPart.Position ).magnitude )
                    if distance.player < closest.player then
                        closest.player = distance.player
                        closest.mouse = distance.mouse
                        target = player
                    end
                end
            end
        end
    end
    return target
end

function module:_calculate(player)
    if self.useMethodTwo then
        local parts = self:_returnParts(player.Character)
        local newPos = parts.humanoidrootpart.CFrame.Position + ( parts.humanoidrootpart.Velocity / 5.4 )
        local newPosForY = parts.humanoidrootpart.CFrame.Position + ( parts.humanoidrootpart.Velocity / 6 )
        return Vector3.new( newPos.X, newPosForY.Y, newPos.Z)
    end
    local parts = self:_returnParts(player.Character)
    local offset = parts.humanoid.MoveDirection * ( parts.humanoid.WalkSpeed / 3.6 )
    local position = parts.humanoidrootpart.CFrame.p + offset
    local lookVector = parts.humanoidrootpart.CFrame.lookVector
    local orientation = CFrame.new(position, position + lookVector)
    return orientation.Position
end

-- UI affect
local circle = Drawing.new('Circle')
circle.Filled = false
circle.Radius = module._fov.radius
circle.Visible = false
circle.Position = module:_mousePosition() + Vector2.new(0,40)
circle.NumSides = 32
circle.Color = Color3.fromRGB(25, 25, 25)
circle.Thickness = 1

local tracerLine = Drawing.new('Line')
tracerLine.Visible = false
tracerLine.Color = Color3.fromRGB(45, 45, 45)
tracerLine.Thickness = 1

local tracerCircle = Drawing.new('Circle')
tracerCircle.Filled = true
tracerCircle.Radius = 5
tracerCircle.Visible = false
tracerCircle.NumSides = 32
tracerCircle.Color = Color3.fromRGB(64, 255, 153)
tracerCircle.Thickness = 0

local __index
__index = hookmetamethod(game, "__index", function(t, k)
    if (t:IsA("Mouse") and (k == "Hit" or k == "Target") and module._aimbotOn and module._activePlayer) then
        local SelectedPart = module._activePlayer.Character.HumanoidRootPart
        local Hit = CFrame.new(module:_calculate( module._activePlayer ))
        return (k == "Hit" and Hit or SelectedPart)
    end
    return __index(t, k)
end)

game:GetService("RunService").heartbeat:Connect(function()
    if module._desync then
        local old = localpalyer.Character.HumanoidRootPart.Velocity
        localpalyer.Character.HumanoidRootPart.Velocity = Vector3.new(1,1,1) * (2^16)
        game:GetService("RunService").RenderStepped:Wait()
        localpalyer.Character.HumanoidRootPart.Velocity = old
    end
end)

game.RunService.RenderStepped:Connect(function()
    if module._toggledText and module._aimbotOn and module._activePlayer then
        if module._activePlayer.Character and module._activePlayer.Character.HumanoidRootPart then
            local parts = module:_returnParts(module._activePlayer.Character)
            if math.abs(parts.humanoidrootpart.Velocity.X) >= 35 or math.abs(parts.humanoidrootpart.Velocity.Y) >= 35 or math.abs(parts.humanoidrootpart.Velocity.Z) >= 35 then
                module._toggledText.setColor(Color3.fromRGB(250, 62, 119))
            else
                module._toggledText.setColor(Color3.fromRGB(64, 255, 153))
            end
        end
    end
    if module._activePlayer == nil then
        tracerLine.Visible = false
        tracerCircle.Visible = false
    end
    if module._aimbotOn and module._activePlayer then
        circle.Color = Color3.fromRGB(64, 255, 153)
        circle.Position = module:_mousePosition() + Vector2.new(0,40)

        -- visual tracer affect
        local predictionLocation = module:_calculate( module._activePlayer )
        local vector, isVisible = module._camera:WorldToViewportPoint(predictionLocation)
        if module._hitTracer then
            tracerLine.To = module:_mousePosition() + Vector2.new(5, 5)
            tracerLine.From = Vector2.new(vector.X,vector.Y)
            tracerCircle.Position = Vector2.new(vector.X + (10 / 2),vector.Y + (10 / 2))
        end

        if module._activePlayer.Character.Humanoid:GetState() == Enum.HumanoidStateType.Dead then
            circle.Color = Color3.fromRGB(25, 25, 25)
            circle.Position = module:_mousePosition() + Vector2.new(0,40)
            module._activePlayer = nil
            module._aimbotOn = false
            tracerLine.Visible = false
            tracerCircle.Visible = false
        end
        return
    end
    circle.Color = Color3.fromRGB(25, 25, 25)
    circle.Position = module:_mousePosition() + Vector2.new(0,40)
end)

userInputService.InputBegan:Connect(function(input,gameEvent)
    if not gameEvent and input.KeyCode == Enum.KeyCode.Q and module._isInUse then
        if module._toggle._skipKeyUse then
            module._toggle.isOn = true
            module._aimbotConnection.index:Fire({
                player = module:_getPlayer()
            })
        elseif module._toggle.isToggleable and module._toggle.isOn == false then
            module._toggle.isOn = true
            module._aimbotConnection.index:Fire({
                player = module:_getPlayer()
            })
        elseif module._toggle.isToggleable and module._toggle.isOn then
            module._toggle.isOn = false
            module._aimbotOn = false
            module._activePlayer = nil
            circle.Color = Color3.fromRGB(25, 25, 25)
        elseif not module._toggle.isToggleable then
            module._aimbotConnection.index:Fire({
                player = module:_getPlayer()
            })
        end
    end
end)

userInputService.InputEnded:Connect(function(input,gameEvent)
    if not gameEvent and input.KeyCode == Enum.KeyCode.Q then
        if not module._toggle.isToggleable then
            module._aimbotOn = false
            module._activePlayer = nil
            circle.Color = Color3.fromRGB(25, 25, 25)
        end
    end
end)

function new(window)
    local silent = window.new({ text = "Silent", })

    local target_label = silent.new('label', { text = "Target: Nick ( Username )" })
    
    module._toggledText = target_label
    
    silent.new("switch", { text = "Enabled?"; }).event:Connect(function(bool)
        module._isInUse = bool
        circle.Visible = bool
        module._aimbotOn = false
        module._activePlayer = nil
    end)
    
    silent.new("switch", { text = "Use original prediction?"; }).event:Connect(function(bool)
        module.useMethodTwo = bool
    end)
    silent.new("switch", { text = "Hold to toggle?"; }).event:Connect(function(bool)
        module._toggle.isToggleable = not bool
        module._toggle.isOn = false
    end)

    silent.new("switch", { text = "Skip key press?"; }).event:Connect(function(bool)
        module._toggle._skipKeyUse = bool
        module._toggle.isOn = false
    end)
    
    silent.new("slider", { text = "Fov", color = Color3.fromRGB(45, 45, 45), min = 20, max = 1000, value = 400, rounding = 0.5, }).event:Connect(function(x)
        module._fov.radius = x
        circle.Radius = x
    end)
    silent.new("switch", { text = "Visual tracer?"; }).event:Connect(function(bool)
        module._hitTracer = bool
    end)
    
    local tracerConfig = silent.new("folder", {
        text = "Tracer",
        color = Color3.fromRGB(45, 45, 45)
    })
    tracerConfig.new("color", { color = Color3.fromRGB(45, 45, 45), text = "Tracer Dot",}).event:Connect(function(color)
        tracerCircle.Color = Color3.fromRGB(color.r*255,color.g*255,color.b*255)
    end)
    tracerConfig.new("color", { color = Color3.fromRGB(45, 45, 45), text = "Tracer Line",}).event:Connect(function(color)
        tracerLine.Color = Color3.fromRGB(color.r*255,color.g*255,color.b*255)
    end)
    local filled = tracerConfig.new("switch", { text = "Filled Dot?"; })
    filled.event:Connect(function(bool)
        tracerCircle.Filled = bool
    end)
    filled.set(true)
    
    -- connection for setting up the camlock.
    module._aimbotConnection.connection = module._aimbotConnection.index.Event:Connect(function(payload)
        if payload.player then
            module._aimbotOn = true
            module._activePlayer = payload.player
            tracerLine.Visible = (module._hitTracer and true) or false
            tracerCircle.Visible = (module._hitTracer and true) or false
            if module._activePlayer then
                target_label.setText(string.format('Target: %s ( %s )',payload.player.DisplayName,payload.player.Name))
            else
                target_label.setText('Target: Nick ( Username )')
            end
        end
    end)
    
    local playersFolder = silent.new("folder", {
        text = "Whitelist",
        color = Color3.fromRGB(45, 45, 45)
    })
    
    local playerDropdown = playersFolder.new("dropdown", { text = "Players", color = Color3.fromRGB(25, 25, 25) })
    playerDropdown.event:Connect(function(player)
        module._target = player
        print(player)
    end)
    for i,v in pairs(players:GetPlayers()) do playerDropdown.new(v.Name, { color = Color3.fromRGB(45, 45, 45) }) end
    players.ChildAdded:Connect(function(child)
        local new = playerDropdown.new(child.Name)
        local connection = nil
        connection = players.ChildRemoved:Connect(function(child)
            if new.name == child.Name then
                new:Destroy()
                connection:Disconnect()
            end
        end)
    end)
    
    playersFolder.new("button", { text = "Add", color = Color3.fromRGB(64, 255, 153) }).event:Connect(function()
        local player = players:FindFirstChild(module._target)
        if player and not table.find(module._whitelistedPlayers,player.UserId) then
            table.insert(module._whitelistedPlayers,player.UserId)
            writefile('ProjectLore/whitelisted_players.json',httpService:JSONEncode(module._whitelistedPlayers))
        end
    end)
    
    playersFolder.new("button", { text = "Remove", color = Color3.fromRGB(250, 62, 119) }).event:Connect(function()
        local player = players:FindFirstChild(module._target)
        if player and table.find(module._whitelistedPlayers,player.UserId) then
            for i,v in pairs(module._whitelistedPlayers) do
                if v == player.UserId or v == player.Name then
                    table.remove(module._whitelistedPlayers,i)
                    return writefile('ProjectLore/whitelisted_players.json',httpService:JSONEncode(module._whitelistedPlayers))
                end
            end
        end
    end)
    
    silent.new("switch", { text = "Desync?"; }).event:Connect(function(bool)
        module._desync = bool
    end)
end

return new
