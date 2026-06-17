--!strict
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local StarterGui = game:GetService("StarterGui")
local PathfindingService = game:GetService("PathfindingService") -- Ditambahkan untuk pathfinding

local player = Players.LocalPlayer

-- List of gloves to completely ignore
local IGNORED_GLOVES = {
    ["Spectator"] = true,
    ["Diamond"] = true,
    ["MEGAROCK"] = true,
    ["Custom"] = true,
    ["Ghost"] = true, 
    ["Adios"] = true,
    ["Counter"] = true
}

-- Function to check if a target is "slappable"
local function isTargetable(otherPlayer)
    if not otherPlayer or not otherPlayer.Character then return false end
    
    local char = otherPlayer.Character
    local head = char:FindFirstChild("Head")
    local hum = char:FindFirstChild("Humanoid")
    
    -- 1. Basic checks
    if not head or not hum or hum.Health <= 0 then return false end

    -- 2. Check Glove Name in Leaderstats
    local leaderstats = otherPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local gloveValue = leaderstats:FindFirstChild("Glove")
        if gloveValue and IGNORED_GLOVES[gloveValue.Value] then
            return false
        end
    end

    -- 3. Check for "Rock" form
    if char:FindFirstChild("Rock") or char:FindFirstChild("Crystal") then
        return false
    end

    -- 4. Check for Ghost / Invisibility
    if head.Transparency > 0.5 then
        return false
    end

    return true
end

local function runBot(character)
    local humanoid = character:WaitForChild("Humanoid")
    local hrp = character:WaitForChild("HumanoidRootPart")

    -- 1. Move to the Red Portal (Normal Arena)
    local lobby = workspace:WaitForChild("Lobby")
    local portal = lobby:WaitForChild("Teleport1")

    task.wait(1)
    print("Walking to portal...")
    humanoid:MoveTo(portal.Position)

    repeat
        task.wait(0.1)
        if humanoid.MoveDirection.Magnitude == 0 and (hrp.Position - portal.Position).Magnitude > 5 then
             humanoid:MoveTo(portal.Position)
        end
    until (hrp.Position - portal.Position).Magnitude < 4 or not character.Parent

    -- 2. Wait for Arena Transition
    local startY = hrp.Position.Y
    repeat task.wait(0.5) until math.abs(hrp.Position.Y - startY) > 50 or not character.Parent

    StarterGui:SetCore("SendNotification", {
        Title = "Arena Active",
        Text = "Pathfinding & Height Check Active",
        Duration = 3
    })

    -- Variable global untuk target saat ini
    local currentTarget: BasePart? = nil

    -- 3. Target Scanner & Height Check (Berjalan tanpa delay)
    task.spawn(function()
        while character.Parent and humanoid.Health > 0 do
            local closest, shortest = nil, math.huge
            
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and isTargetable(other) then
                    local ohrp = other.Character:FindFirstChild("HumanoidRootPart")
                    if ohrp then
                        local dist = (hrp.Position - ohrp.Position).Magnitude
                        local heightDiff = math.abs(hrp.Position.Y - ohrp.Position.Y)
                        
                        -- Hanya target player yang ada di arena DAN beda ketinggian TIDAK lebih dari 3 stud
                        if dist < shortest and ohrp.Position.Y < 1000 and heightDiff <= 3 then 
                            shortest = dist
                            closest = ohrp
                        end
                    end
                end
            end

            -- Update target secara real-time
            currentTarget = closest

            -- Logika jump & slap jarak dekat
            if currentTarget then
                if (hrp.Position - currentTarget.Position).Magnitude <= 12 then
                    humanoid.Jump = true 
                end
            end
            task.wait(0.1)
        end
    end)

    -- 4. Pathfinding Follower (Berjalan di thread terpisah agar tidak lag/delay)
    task.spawn(function()
        local path = PathfindingService:CreatePath({
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true,
            WaypointSpacing = 4
        })
        
        local lastTargetPos = Vector3.new(0, 0, 0)

        while character.Parent and humanoid.Health > 0 do
            if currentTarget then
                local targetPos = currentTarget.Position
                local distToTarget = (hrp.Position - targetPos).Magnitude
                local posDiff = (targetPos - lastTargetPos).Magnitude

                -- Buat path baru hanya jika target bergerak signifikan atau bot masih jauh
                if posDiff > 3 or distToTarget > 6 then
                    lastTargetPos = targetPos
                    
                    local success = pcall(function()
                        path:ComputePath(hrp.Position, targetPos)
                    end)
                    
                    if success and path.Status == Enum.PathStatus.Success then
                        local waypoints = path:GetWaypoints()
                        
                        for i = 2, #waypoints do
                            -- Hentikan path jika target hilang, karakter mati, atau target berpindah terlalu jauh
                            if not currentTarget or not character.Parent or humanoid.Health <= 0 then break end
                            if (currentTarget.Position - targetPos).Magnitude > 8 then break end
                            
                            local wp = waypoints[i]
                            humanoid:MoveTo(wp.Position)
                            
                            -- Lompat jika waypoint memerintahkan untuk lompat
                            if wp.Action == Enum.PathWaypointAction.Jump then
                                humanoid.Jump = true
                            end
                            
                            -- Timeout cepat (0.2 detik) per waypoint agar pergerakan terasa instan tanpa delay
                            humanoid.MoveToFinished:Wait(0.2)
                        end
                    else
                        -- Fallback: Jika path gagal (misal di udara), maju langsung ke target
                        humanoid:MoveTo(targetPos)
                        task.wait(0.1)
                    end
                else
                    -- Jika target dekat dan tidak banyak bergerak, kejar langsung tanpa compute path berat
                    humanoid:MoveTo(targetPos)
                    task.wait(0.1)
                end
            else
                -- Reset posisi jika tidak ada target
                lastTargetPos = Vector3.new(0, 0, 0)
                task.wait(0.1)
            end
        end
    end)

    -- 5. Slap/Tool Loop
    task.spawn(function()
        while character.Parent and humanoid.Health > 0 do
            local tool = character:FindFirstChildOfClass("Tool")
            if tool then
                pcall(function()
                    tool:Activate()
                    local remote = tool:FindFirstChildWhichIsA("RemoteEvent", true)
                    if remote then remote:FireServer() end
                end)
            end
            task.wait(0.1)
        end
    end)

    -- 6. Auto-Equip & E-Ability Spams
    task.spawn(function()
        while character.Parent and humanoid.Health > 0 do
            local tool = player.Backpack:FindFirstChildOfClass("Tool")
            if tool then humanoid:EquipTool(tool) end
            
            -- Use E ability
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, nil)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, nil)
            
            task.wait(2)
        end
    end)
end

-- Start bot
if player.Character then task.spawn(runBot, player.Character) end
player.CharacterAdded:Connect(function(char) runBot(char) end)