--!strict
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer

-- Variabel Global untuk Toggle & Visualisasi
local showPathfinding = false
local visualParts = {}

local function clearVisuals()
    for _, p in ipairs(visualParts) do
        if p and p.Parent then p:Destroy() end
    end
    table.clear(visualParts)
end

local function drawMarker(pos, color, size)
    if not showPathfinding then return end
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Size = size or Vector3.new(1.2, 1.2, 1.2)
    part.Color = color
    part.Material = Enum.Material.Neon
    part.Position = pos
    part.Parent = workspace
    table.insert(visualParts, part)
end

-- Membuat GUI Toggle
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PathfindingToggleGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 160, 0, 40)
toggleButton.Position = UDim2.new(0, 10, 0.5, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "Show Path: OFF"
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 18
toggleButton.Parent = screenGui

toggleButton.MouseButton1Click:Connect(function()
    showPathfinding = not showPathfinding
    if showPathfinding then
        toggleButton.Text = "Show Path: ON"
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    else
        toggleButton.Text = "Show Path: OFF"
        toggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        clearVisuals()
    end
end)

-- Daftar sarung tangan yang diabaikan
local IGNORED_GLOVES = {
    ["Spectator"] = true,
    ["Diamond"] = true,
    ["MEGAROCK"] = true,
    ["Custom"] = true,
    ["Ghost"] = true, 
    ["Adios"] = true,
    ["Counter"] = true,
    ["Alchemist"] = true,
    ["Error"] = true,
    ["God's Hand"] = true,
    ["The Flex"] = true,
    ["OVERKILL"] = true
}

-- Fungsi mengecek apakah target bisa ditampar
local function isTargetable(otherPlayer)
    if not otherPlayer or not otherPlayer.Character then return false end
    
    local char = otherPlayer.Character
    local head = char:FindFirstChild("Head")
    local hum = char:FindFirstChild("Humanoid")
    
    if not head or not hum or hum.Health <= 0 then return false end

    local leaderstats = otherPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local gloveValue = leaderstats:FindFirstChild("Glove")
        if gloveValue and IGNORED_GLOVES[gloveValue.Value] then
            return false
        end
    end

    if char:FindFirstChild("Rock") or char:FindFirstChild("Crystal") then
        return false
    end

    if head.Transparency > 0.5 then
        return false
    end

    return true
end

-- Validasi Posisi Lantai (Abaikan Karakter)
local function getFloorPosition(pos)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local ignoreList = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then table.insert(ignoreList, p.Character) end
    end
    raycastParams.FilterDescendantsInstances = ignoreList
    
    local rayResult = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), raycastParams)
    if rayResult then
        return rayResult.Position + Vector3.new(0, 1.5, 0)
    end
    return pos
end

local function runBot(character)
    local humanoid = character:WaitForChild("Humanoid")
    local hrp = character:WaitForChild("HumanoidRootPart")

    -- 1. Berjalan ke Portal Merah
    local lobby = workspace:WaitForChild("Lobby")
    local portal = lobby:WaitForChild("Teleport1")

    task.wait(1)
    print("Berjalan ke portal...")
    humanoid:MoveTo(portal.Position)

    repeat
        task.wait(0.1)
        if humanoid.MoveDirection.Magnitude == 0 and (hrp.Position - portal.Position).Magnitude > 5 then
             humanoid:MoveTo(portal.Position)
        end
    until (hrp.Position - portal.Position).Magnitude < 4 or not character.Parent

    -- 2. Tunggu Transisi Arena
    local startY = hrp.Position.Y
    repeat task.wait(0.5) until math.abs(hrp.Position.Y - startY) > 50 or not character.Parent

    StarterGui:SetCore("SendNotification", {
        Title = "Bot Anti-Stutter",
        Text = "Gerakan diperhalus secara maksimal",
        Duration = 3
    })

    -- 3. Membuat Hitbox Transparan di sekitar bot
    local hitbox = Instance.new("Part")
    hitbox.Name = "BotAttackHitbox"
    hitbox.Size = Vector3.new(12, 8, 12)
    hitbox.Transparency = 0.7
    hitbox.Color = Color3.fromRGB(255, 0, 100)
    hitbox.CanCollide = false
    hitbox.Massless = true
    hitbox.Anchored = false
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hrp
    weld.Part1 = hitbox
    weld.Parent = hitbox
    hitbox.CFrame = hrp.CFrame
    hitbox.Parent = character

    local currentTarget: BasePart? = nil

    -- 4. Scanner Target & Cek Tinggi (Max 6 Stud)
    task.spawn(function()
        while character.Parent and humanoid.Health > 0 do
            local closest, shortest = nil, math.huge
            
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and isTargetable(other) then
                    local ochar = other.Character
                    local ohrp = ochar:FindFirstChild("HumanoidRootPart")
                    local ohum = ochar:FindFirstChild("Humanoid")
                    if ohrp and ohum then
                        local dist = (hrp.Position - ohrp.Position).Magnitude
                        local heightDiff = math.abs(hrp.Position.Y - ohrp.Position.Y)
                        
                        local isInAir = ohum:GetState() == Enum.HumanoidStateType.Freefall or ohum:GetState() == Enum.HumanoidStateType.Jumping
                        
                        if dist < shortest and ohrp.Position.Y < 1000 and (isInAir or heightDiff <= 6) then 
                            shortest = dist
                            closest = ohrp
                        end
                    end
                end
            end

            currentTarget = closest
            task.wait(0.1)
        end
    end)

    -- 5. Movement Loop yang 100% Smooth
    task.spawn(function()
        local path = PathfindingService:CreatePath({
            AgentRadius = 1.2, 
            AgentHeight = 5,
            AgentCanJump = true,
            AgentCanClimb = false,
            WaypointSpacing = 4 -- Diperbesar sedikit agar titiknya tidak terlalu rapat, membantu kelancaran
        })
        
        while character.Parent and humanoid.Health > 0 do
            if currentTarget then
                local targetPos = currentTarget.Position
                local distToTarget = (hrp.Position - targetPos).Magnitude
                
                if distToTarget > 12 then
                    local pathTargetPos = getFloorPosition(targetPos)
                    
                    -- Pancing gerak agar tidak diam saat loading ComputeAsync
                    humanoid:MoveTo(pathTargetPos) 
                    
                    local success, _ = pcall(function()
                        path:ComputeAsync(hrp.Position, pathTargetPos)
                    end)
                    
                    if success and path.Status == Enum.PathStatus.Success then
                        local waypoints = path:GetWaypoints()
                        clearVisuals()
                        
                        if showPathfinding then
                            drawMarker(pathTargetPos, Color3.fromRGB(255, 0, 0), Vector3.new(1.8, 1.8, 1.8))
                            for _, wp in ipairs(waypoints) do
                                drawMarker(wp.Position, Color3.fromRGB(0, 255, 0))
                            end
                        end
                        
                        -- Loop pergerakan anti ngadat
                        for i = 2, #waypoints do
                            if not currentTarget or not character.Parent or humanoid.Health <= 0 then break end
                            
                            -- Jika target pindah posisi lebih dari 8 stud, hentikan untuk kalkulasi ulang
                            if (currentTarget.Position - targetPos).Magnitude > 8 then break end
                            
                            local wp = waypoints[i]
                            humanoid:MoveTo(wp.Position)
                            
                            if wp.Action == Enum.PathWaypointAction.Jump then
                                humanoid.Jump = true
                            end
                            
                            local startTime = tick()
                            -- ANTI-STUTTER: Gunakan jarak 2D (Horizontal) dan lewati waypoint sebelum benar-benar sampai (threshold 3.5)
                            repeat
                                task.wait()
                                local pos1 = Vector2.new(hrp.Position.X, hrp.Position.Z)
                                local pos2 = Vector2.new(wp.Position.X, wp.Position.Z)
                                local dist2D = (pos1 - pos2).Magnitude
                            until dist2D <= 3.5 or tick() - startTime > 0.5 or not currentTarget or (currentTarget.Position - targetPos).Magnitude > 8
                        end
                    else
                        humanoid:MoveTo(targetPos)
                        task.wait(0.1)
                    end
                else
                    clearVisuals()
                    humanoid:MoveTo(targetPos)
                    task.wait(0.05)
                end
            else
                clearVisuals()
                task.wait(0.1)
            end
            task.wait()
        end
        
        clearVisuals()
    end)

    -- 6. Logika Menyerang berbasis Hitbox
    task.spawn(function()
        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Include
        
        while character.Parent and humanoid.Health > 0 do
            if currentTarget then
                overlapParams.FilterDescendantsInstances = {currentTarget.Parent}
                
                local partsInHitbox = workspace:GetPartsInPart(hitbox, overlapParams)
                
                if #partsInHitbox > 0 then
                    local tool = character:FindFirstChildOfClass("Tool") or player.Backpack:FindFirstChildOfClass("Tool")
                    if tool then
                        if tool.Parent ~= character then
                            humanoid:EquipTool(tool)
                        end
                        
                        pcall(function()
                            tool:Activate()
                            local remote = tool:FindFirstChildWhichIsA("RemoteEvent", true)
                            if remote then remote:FireServer() end
                        end)
                    end
                end
            end
            task.wait(0.05)
        end
    end)

    -- 7. Spam E-Ability
    task.spawn(function()
        while character.Parent and humanoid.Health > 0 do
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, nil)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, nil)
            task.wait(2)
        end
    end)
end

-- Start bot
if player.Character then task.spawn(runBot, player.Character) end
player.CharacterAdded:Connect(function(char) runBot(char) end)
