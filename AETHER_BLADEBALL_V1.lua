-- AETHER / BLADE BALL V1
-- One-file Luau UI: loader, SVG-style vector navigation, best-effort Auto Parry,
-- reaction training, cosmetic particles, and optional server-backed AI chat.
-- The public client cannot guarantee a successful Blade Ball parry.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
if not player then return end
if game.PlaceId ~= 13772394625 then
    warn("[AETHER] This build is for Blade Ball (13772394625), current place: " .. tostring(game.PlaceId))
    return
end

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.__AETHER_BB_UNLOAD) == "function" then pcall(env.__AETHER_BB_UNLOAD) end
local connections, pageConnections = {}, {}
local alive = true
local function track(c, page)
    table.insert(page and pageConnections or connections, c)
    return c
end
local function clearPageEvents()
    for _, c in ipairs(pageConnections) do pcall(function() c:Disconnect() end) end
    table.clear(pageConnections)
end

local C = {
    bg=Color3.fromRGB(7,7,8), card=Color3.fromRGB(17,17,19),
    card2=Color3.fromRGB(22,22,24), line=Color3.fromRGB(42,42,45),
    text=Color3.fromRGB(244,244,246), muted=Color3.fromRGB(144,146,152),
    accent=Color3.fromRGB(239,239,243), dark=Color3.fromRGB(9,9,11),
    danger=Color3.fromRGB(255,92,106), good=Color3.fromRGB(114,227,181),
    warning=Color3.fromRGB(255,193,109)
}
local F = Enum.Font.Gotham
local FB = Enum.Font.GothamBold
local config = {
    autoParry=false, lead=0.19, cooldown=0.62, minApproach=0.55,
    particles=true, worldTrail=false, particleCount=14,
    aura=false, fov=70, uiScale=1,
    sound=true, aiEndpoint="", snapSafe=true
}
local status = {parry="ВЫКЛ.", distance="—", speed=0, latency="—", fps=60,
    attempts=0, successful=0, lastParry=0, reactionBest=nil, reactionSum=0, reactionRuns=0}
local gui, loader, panel, pageHost, tabText, infoText, mainScale
local activeTab="Parry"
local frameParticles = {}
local trailEmitter
local viewport, viewportClone, previewAuraStroke
local reaction = {phase="idle", start=0, nonce=0}
local currentPageControls = {}

local function create(kind,parent,props)
    local obj = Instance.new(kind)
    for k,v in pairs(props or {}) do obj[k]=v end
    obj.Parent=parent
    return obj
end
local function corner(o,r)
    create("UICorner",o,{CornerRadius=UDim.new(0,r or 8)})
end
local function stroke(o, col, width, transparency)
    create("UIStroke",o,{Color=col or C.line,Thickness=width or 1,Transparency=transparency or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function tween(o, props, duration)
    if not alive or not o or not o.Parent then return end
    local t = TweenService:Create(o,TweenInfo.new(duration or .17,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
    t:Play()
    return t
end
local function label(parent,text,x,y,w,h,size,color,bold,align)
    return create("TextLabel",parent,{
        Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        TextColor3=color or C.text,TextSize=size or 12,Font=bold and FB or F,
        TextXAlignment=align or Enum.TextXAlignment.Left,
        BackgroundTransparency=1,TextTruncate=Enum.TextTruncate.AtEnd,
    })
end
local function basicButton(parent,text,x,y,w,h,callback,filled)
    local b=create("TextButton",parent,{
        Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        TextColor3=filled and C.dark or C.text,TextSize=12,Font=FB,
        BackgroundColor3=filled and C.text or C.card2,AutoButtonColor=false,
        BorderSizePixel=0
    });corner(b,7)
    if not filled then stroke(b,C.line) end
    track(b.MouseButton1Click:Connect(function() if callback then callback() end end),true)
    track(b.MouseEnter:Connect(function() tween(b,{BackgroundColor3=filled and Color3.fromRGB(221,221,225) or Color3.fromRGB(36,36,40)},.16) end),true)
    track(b.MouseLeave:Connect(function() tween(b,{BackgroundColor3=filled and C.text or C.card2},.16) end),true)
    return b
end
local function makeTextBox(parent,placeholder,x,y,w,h)
    local box=create("TextBox",parent,{
        Text="",PlaceholderText=placeholder,ClearTextOnFocus=false,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundColor3=C.card2,BorderSizePixel=0,
        TextColor3=C.text,PlaceholderColor3=C.muted,TextSize=12,
        Font=F,TextXAlignment=Enum.TextXAlignment.Left,
    });corner(box,8);stroke(box,C.line)
    create("UIPadding",box,{PaddingLeft=UDim.new(0,11),PaddingRight=UDim.new(0,10)})
    return box
end
local function makeCard(parent,x,y,w,h,title)
    local card=create("Frame",parent,{
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundColor3=C.card,BorderSizePixel=0
    });corner(card,10);stroke(card,C.line,.9)
    label(card,title,15,11,w-30,23,12,C.text,true)
    create("Frame",card,{Position=UDim2.fromOffset(0,39),Size=UDim2.new(1,0,0,1),BackgroundColor3=C.line,BackgroundTransparency=.2,BorderSizePixel=0})
    return card
end
local function toggle(parent, text, y, value, onChange, width)
    width=width or 250
    label(parent,text,14,y,width-78,31,11,C.muted,false)
    local bg=create("TextButton",parent,{
        Text="",Position=UDim2.fromOffset(width-57,y+5),Size=UDim2.fromOffset(40,21),
        BackgroundColor3=value and C.text or Color3.fromRGB(44,44,47),BorderSizePixel=0,AutoButtonColor=false
    });corner(bg,13)
    local dot=create("Frame",bg,{
        Position=UDim2.fromOffset(value and 21 or 3,3),Size=UDim2.fromOffset(15,15),
        BackgroundColor3=value and C.dark or C.muted,BorderSizePixel=0
    });corner(dot,10)
    track(bg.MouseButton1Click:Connect(function()
        value=not value
        tween(bg,{BackgroundColor3=value and C.text or Color3.fromRGB(44,44,47)},.18)
        tween(dot,{Position=UDim2.fromOffset(value and 21 or 3,3),BackgroundColor3=value and C.dark or C.muted},.18)
        onChange(value)
    end),true)
    return bg
end
local function slider(parent,title,y,minVal,maxVal,startVal,callback,width,fmt)
    width=width or 250
    local valueLabel=label(parent,"",width-83,y,width-16-(width-83),22,10,C.text,false,Enum.TextXAlignment.Right)
    label(parent,title,14,y,width-105,22,11,C.muted)
    local tx=14; local tw=width-28
    local trackbar=create("Frame",parent,{
        Position=UDim2.fromOffset(tx,y+31),Size=UDim2.fromOffset(tw,3),
        BackgroundColor3=Color3.fromRGB(56,56,59),BorderSizePixel=0
    });corner(trackbar,2)
    local fill=create("Frame",trackbar,{Size=UDim2.fromScale(.5,1),BackgroundColor3=C.text,BorderSizePixel=0});corner(fill,2)
    local knob=create("TextButton",trackbar,{Text="",Size=UDim2.fromOffset(13,13),AnchorPoint=Vector2.new(.5,.5),BackgroundColor3=C.text,BorderSizePixel=0,AutoButtonColor=false});corner(knob,10)
    local cur=startVal
    local function render(v,notify)
        cur=math.clamp(v,minVal,maxVal)
        local p=(cur-minVal)/(maxVal-minVal)
        fill.Size=UDim2.fromScale(p,1)
        knob.Position=UDim2.fromScale(p,.5)
        valueLabel.Text=fmt and fmt(cur) or string.format("%.2f",cur)
        if notify then callback(cur) end
    end
    render(cur,false)
    local dragging=false
    local function fromX(x)
        local p=math.clamp((x-trackbar.AbsolutePosition.X)/math.max(1,trackbar.AbsoluteSize.X),0,1)
        render(minVal+(maxVal-minVal)*p,true)
    end
    track(knob.MouseButton1Down:Connect(function() dragging=true end),true)
    track(trackbar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;fromX(i.Position.X) end
    end),true)
    track(UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then fromX(i.Position.X) end
    end),true)
    track(UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end),true)
end

-- Each icon is built from vector strokes in Roblox GUI (no external asset ID).
-- Matching .svg source files are included in the archive for optional import.
local ICON_LINES={
    aim={{4,12,20,12},{12,4,12,20},{7,7,9,9},{15,15,17,17}},
    parry={{12,2,12,7},{12,17,12,22},{2,12,7,12},{17,12,22,12},{7,7,17,17},{17,7,7,17}},
    visuals={{4,12,8,8},{8,8,12,12},{12,12,18,6},{4,18,9,13},{14,19,20,13}},
    reaction={{8,2,16,2},{12,2,12,5},{5,6,7,8},{12,12,17,8},{12,12,12,5}},
    ai={{4,5,20,5},{4,5,4,17},{4,17,9,17},{9,17,12,21},{12,21,15,17},{15,17,20,17},{20,17,20,5},{8,11,9,11},{15,11,16,11}},
    settings={{4,6,20,6},{4,12,20,12},{4,18,20,18}},
    info={{12,10,12,18},{12,5,12,6}},
    close={{5,5,19,19},{19,5,5,19}},
    back={{18,5,7,12},{7,12,18,19}},
}
local function icon(parent,kind,x,y,sz,color)
    sz=sz or 24
    local holder=create("Frame",parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(sz,sz),BackgroundTransparency=1})
    local mul=sz/24
    local data=ICON_LINES[kind] or ICON_LINES.parry
    for _,seg in ipairs(data) do
        local x1,y1,x2,y2=seg[1]*mul,seg[2]*mul,seg[3]*mul,seg[4]*mul
        local dx,dy=x2-x1,y2-y1
        local length=math.sqrt(dx*dx+dy*dy)
        local line=create("Frame",holder,{
            Size=UDim2.fromOffset(length,1.75*mul),Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2),
            AnchorPoint=Vector2.new(.5,.5),Rotation=math.deg(math.atan2(dy,dx)),
            BackgroundColor3=color or C.muted,BorderSizePixel=0
        });corner(line,2)
    end
    return holder
end

local rootGui=player:WaitForChild("PlayerGui")
gui=create("ScreenGui",rootGui,{
    Name="AETHER_BLADEBALL_GUI",IgnoreGuiInset=true,ResetOnSpawn=false,
    DisplayOrder=98765,ZIndexBehavior=Enum.ZIndexBehavior.Sibling
})
local dim=create("Frame",gui,{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.24,BorderSizePixel=0})
local alertSound=create("Sound",gui,{SoundId="rbxasset://sounds/electronicpingshort.wav",Volume=.25})
local function playUIBeep()
    if config.sound and alertSound and alertSound.Parent then pcall(function() alertSound:Play() end) end
end

local function addParticles(parent)
    for i=1,28 do
        local p=create("Frame",parent,{
            Position=UDim2.fromScale(math.random(),math.random()),Size=UDim2.fromOffset(math.random(2,5),math.random(2,5)),
            BackgroundColor3=i%4==0 and C.danger or C.text,BackgroundTransparency=.65,BorderSizePixel=0
        });corner(p,4)
        table.insert(frameParticles,{object=p,speed=.013+math.random()*.045,ox=math.random(),phase=math.random()*6.28})
    end
end
addParticles(dim)
local pulse=0
local particleTick=0

local function makeShell()
    panel=create("Frame",gui,{
        Name="Main",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
        Size=UDim2.fromOffset(935,556),BackgroundColor3=C.bg,BorderSizePixel=0,Visible=false
    });corner(panel,10);stroke(panel,C.line,1)
    mainScale=create("UIScale",panel,{Scale=1})
    local dragActive,dragOrigin,panelOrigin=false,nil,nil
    track(panel.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 and i.Position.Y<panel.AbsolutePosition.Y+55 then
            dragActive=true;dragOrigin=i.Position;panelOrigin=panel.Position
        end
    end))
    track(UIS.InputChanged:Connect(function(i)
        if dragActive and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-dragOrigin
            panel.Position=UDim2.new(panelOrigin.X.Scale,panelOrigin.X.Offset+d.X,panelOrigin.Y.Scale,panelOrigin.Y.Offset+d.Y)
        end
    end))
    track(UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then dragActive=false end
    end))
    local sidebar=create("Frame",panel,{Position=UDim2.fromOffset(0,0),Size=UDim2.new(0,71,1,0),BackgroundColor3=Color3.fromRGB(10,10,11),BorderSizePixel=0});corner(sidebar,10)
    create("Frame",panel,{Position=UDim2.fromOffset(71,0),Size=UDim2.new(0,1,1,0),BackgroundColor3=C.line,BorderSizePixel=0})
    label(sidebar,"A",24,16,30,34,22,C.text,true)
    create("Frame",sidebar,{Position=UDim2.fromOffset(13,64),Size=UDim2.fromOffset(45,1),BackgroundColor3=C.line,BorderSizePixel=0})
    local navTabs={
        {"Parry","parry"},{"Visuals","visuals"},{"Reaction","reaction"},
        {"AI","ai"},{"Settings","settings"}
    }
    local nav={}
    local function navigate(name) end
    for i,item in ipairs(navTabs) do
        local btn=create("TextButton",sidebar,{Text="",Position=UDim2.fromOffset(13,77+(i-1)*54),Size=UDim2.fromOffset(45,43),BackgroundColor3=C.card2,BackgroundTransparency=1,BorderSizePixel=0,AutoButtonColor=false})
        corner(btn,7);local ico=icon(btn,item[2],10,9,25,C.muted)
        nav[item[1]]={button=btn,lines=ico:GetChildren()}
        track(btn.MouseButton1Click:Connect(function() navigate(item[1]) end))
    end
    create("Frame",sidebar,{Position=UDim2.fromOffset(13,369),Size=UDim2.fromOffset(45,1),BackgroundColor3=C.line,BorderSizePixel=0})
    icon(sidebar,"info",23,386,24,C.muted)
    label(sidebar,"v1",24,515,35,20,10,C.muted)
    label(panel,"AETHER",94,15,115,23,14,C.text,true)
    tabText=label(panel,"/ PARRY",201,16,250,22,11,C.muted)
    label(panel,"BLADE BALL",722,17,128,18,10,C.muted,true,Enum.TextXAlignment.Right)
    local closeBtn=create("TextButton",panel,{Text="",Position=UDim2.fromOffset(896,12),Size=UDim2.fromOffset(27,27),BackgroundTransparency=1,BorderSizePixel=0})
    icon(closeBtn,"close",4,4,18,C.muted)
    track(closeBtn.MouseButton1Click:Connect(function() panel.Visible=false;dim.Visible=false end))
    create("Frame",panel,{Position=UDim2.fromOffset(72,53),Size=UDim2.new(1,-72,0,1),BackgroundColor3=C.line,BorderSizePixel=0})
    pageHost=create("Frame",panel,{Position=UDim2.fromOffset(88,70),Size=UDim2.fromOffset(574,455),BackgroundTransparency=1})
    local right=create("Frame",panel,{Position=UDim2.fromOffset(675,70),Size=UDim2.fromOffset(244,455),BackgroundColor3=Color3.fromRGB(10,10,11),BorderSizePixel=0});corner(right,9)
    label(right,"PLAYER PREVIEW",14,11,214,20,10,C.muted,true)
    viewport=create("ViewportFrame",right,{Position=UDim2.fromOffset(8,39),Size=UDim2.fromOffset(228,294),BackgroundColor3=Color3.fromRGB(9,9,11),BackgroundTransparency=.35,BorderSizePixel=0,Ambient=Color3.fromRGB(170,172,185),LightColor=Color3.fromRGB(255,248,245),LightDirection=Vector3.new(-1,-1,-1)})
    corner(viewport,6)
    local frame=create("Frame",right,{Position=UDim2.fromOffset(38,69),Size=UDim2.fromOffset(167,234),BackgroundTransparency=1})
    previewAuraStroke=create("UIStroke",frame,{Color=C.muted,Thickness=1,Transparency=.35})
    infoText=label(right,"BALL: scanning",14,348,215,19,10,C.muted)
    label(right,"AUTO-PARRY STATUS",14,380,216,19,10,C.muted,true)
    local stat=label(right,"DISABLED",14,400,217,22,12,C.warning,true)
    label(right,"Пробел/частицы и анимации локальные",14,430,217,15,9,C.muted)
    currentPageControls.statLabel=stat
    -- ViewportFrame is a true Roblox 3D viewport, not a screenshot.
    local cam=create("Camera",viewport,{CFrame=CFrame.new(Vector3.new(0,1.7,9),Vector3.new(0,1.7,0)),FieldOfView=41})
    viewport.CurrentCamera=cam
    local world=create("WorldModel",viewport,{})
    local function rebuildPreview()
        for _,obj in ipairs(world:GetChildren()) do obj:Destroy() end
        viewportClone=nil
        local source=player.Character
        if not source then return end
        local was=source.Archivable
        source.Archivable=true
        local ok,cl=pcall(function() return source:Clone() end)
        source.Archivable=was
        if not ok or not cl then return end
        cl.Name="Preview"
        for _,desc in ipairs(cl:GetDescendants()) do
            if desc:IsA("BaseScript") or desc:IsA("Tool") then
                desc:Destroy()
            elseif desc:IsA("BasePart") then
                desc.Anchored=true;desc.CanCollide=false
            end
        end
        cl.Parent=world
        pcall(function() cl:PivotTo(CFrame.new(0,0,0)) end)
        viewportClone=cl
    end
    rebuildPreview()
    track(player.CharacterAdded:Connect(function() task.delay(2,function() if alive and panel.Parent then rebuildPreview() end end) end))

    local function resetPage()
        clearPageEvents()
        for _,ch in ipairs(pageHost:GetChildren()) do ch:Destroy() end
        currentPageControls={statLabel=stat}
    end
    local function showStatus()
        if stat and stat.Parent then
            stat.Text=status.parry
            stat.TextColor3=config.autoParry and C.good or C.warning
        end
        if infoText and infoText.Parent then
            infoText.Text="BALL: "..status.distance.."  /  "..math.floor(status.speed).." studs/s"
        end
    end
    local function buildParry()
        local left=makeCard(pageHost,0,0,276,352,"Auto Parry")
        toggle(left,"Включить Auto Parry",53,config.autoParry,function(v)
            config.autoParry=v
            status.parry=v and "ПОИСК МЯЧА" or "ВЫКЛ."
            showStatus()
        end,276)
        toggle(left,"Визуальный индикатор",89,config.aura,function(v) config.aura=v end,276)
        slider(left,"Время реакции, сек",141,.08,.45,config.lead,function(v) config.lead=v end,276,function(v)return string.format("%.2f",v)end)
        slider(left,"Задержка между попытками",208,.35,1.5,config.cooldown,function(v) config.cooldown=v end,276,function(v)return string.format("%.2f",v)end)
        local note=label(left,"Отражение зависит от ввода и сервера.\nНе гарантирует успешный блок.",14,279,249,48,10,C.muted)
        note.TextWrapped=true;note.TextYAlignment=Enum.TextYAlignment.Top
        local rightCard=makeCard(pageHost,292,0,282,232,"Текущая сессия")
        local counters={}
        counters.attempts=label(rightCard,"Попыток: 0",15,59,244,26,11,C.text)
        counters.mode=label(rightCard,"Цель: —",15,92,244,24,11,C.text)
        counters.input=label(rightCard,"Ввод: не проверен",15,125,250,25,11,C.muted)
        counters.fps=label(rightCard,"FPS: —",15,158,245,22,11,C.muted)
        basicButton(pageHost,"F — стандартное отражение",292,252,282,42,function() end,false).Active=false
        local footer=label(pageHost,"Только Blade Ball · обнаружение по игровым атрибутам мяча",0,382,554,33,10,C.muted)
        track(RunService.Heartbeat:Connect(function()
            if not alive or not counters.attempts.Parent then return end
            counters.attempts.Text="Попыток: "..status.attempts
            counters.mode.Text="Состояние: "..status.parry
            counters.input.Text="Ввод: "..status.latency
            counters.fps.Text="FPS: "..status.fps
        end),true)
    end
    local function buildVisuals()
        local left=makeCard(pageHost,0,0,276,309,"Visual Effects")
        toggle(left,"Частицы интерфейса",54,config.particles,function(v) config.particles=v end,276)
        toggle(left,"След частиц персонажа",89,config.worldTrail,function(v) config.worldTrail=v end,276)
        toggle(left,"Цветная аура",124,config.aura,function(v) config.aura=v end,276)
        slider(left,"Количество частиц",179,4,28,config.particleCount,function(v) config.particleCount=math.floor(v+.5) end,276,function(v)return tostring(math.floor(v+.5))end)
        local tip=label(left,"Лёгкий режим для Intel UHD. Эффекты\nсоздаются локально и отключаются.",14,257,252,42,10,C.muted)
        tip.TextWrapped=true
        local rightCard=makeCard(pageHost,292,0,282,274,"Camera")
        slider(rightCard,"Field of View",69,55,110,config.fov,function(v)
            config.fov=v;local camera=workspace.CurrentCamera;if camera then camera.FieldOfView=v end
        end,282,function(v)return tostring(math.floor(v+.5))end)
        basicButton(rightCard,"Сбросить FOV",14,144,253,36,function()
            config.fov=70;local camera=workspace.CurrentCamera;if camera then camera.FieldOfView=70 end
            navigate("Visuals")
        end)
        label(rightCard,"Красивые эффекты, без изменения\nигровых серверных объектов.",14,197,248,45,10,C.muted)
    end
    local function buildReaction()
        reaction.nonce=reaction.nonce+1
        reaction.phase="idle"
        local card=makeCard(pageHost,0,0,574,387,"REACTION TEST / тренировка")
        label(card,"Нажми «Начать», дождись зелёного сигнала и сразу нажми большую кнопку.",17,54,539,35,11,C.muted)
        local board=create("TextButton",card,{Text="ГОТОВ?",Position=UDim2.fromOffset(16,103),Size=UDim2.fromOffset(541,180),BackgroundColor3=Color3.fromRGB(38,39,43),TextColor3=C.text,TextSize=27,Font=FB,AutoButtonColor=false,BorderSizePixel=0});corner(board,11)
        local readout=label(card,"Личный рекорд: —",18,299,536,26,12,C.text)
        local avg=label(card,"Среднее: —",18,332,533,24,11,C.muted)
        local function refresh()
            readout.Text="Личный рекорд: "..(status.reactionBest and tostring(status.reactionBest).." мс" or "—")
            avg.Text="Среднее: "..(status.reactionRuns>0 and tostring(math.floor(status.reactionSum/status.reactionRuns)).." мс" or "—")
        end
        refresh()
        local function start()
            if reaction.phase=="wait" or reaction.phase=="go" then return end
            reaction.nonce=reaction.nonce+1
            local n=reaction.nonce
            reaction.phase="wait"
            board.BackgroundColor3=Color3.fromRGB(142,70,69);board.Text="ЖДИ СИГНАЛ..."
            task.delay(1.3+math.random()*2.2,function()
                if not alive or reaction.nonce~=n or reaction.phase~="wait" or not board.Parent then return end
                reaction.phase="go";reaction.start=os.clock()
                board.BackgroundColor3=Color3.fromRGB(59,176,117);board.Text="НАЖМИ!"
                playUIBeep()
            end)
        end
        track(board.MouseButton1Click:Connect(function()
            if reaction.phase=="idle" or reaction.phase=="done" then start();return end
            if reaction.phase=="wait" then
                reaction.nonce=reaction.nonce+1;reaction.phase="done"
                board.BackgroundColor3=Color3.fromRGB(145,66,73);board.Text="РАНО! ПОПРОБУЙ ЕЩЁ"
            elseif reaction.phase=="go" then
                local ms=math.max(0,math.floor((os.clock()-reaction.start)*1000+.5))
                reaction.phase="done";board.Text=tostring(ms).." МС — ЕЩЁ РАЗ?"
                board.BackgroundColor3=Color3.fromRGB(34,99,77)
                status.reactionRuns=status.reactionRuns+1;status.reactionSum=status.reactionSum+ms
                status.reactionBest=math.min(status.reactionBest or ms,ms)
                refresh()
            end
        end),true)
        label(pageHost,"Проверка проводится локально и не влияет на игровой матч.",0,404,571,27,10,C.muted)
    end
    local function offlineIdea(message)
        local m=string.lower(message)
        if string.find(m,"fps",1,true) or string.find(m,"фпс",1,true) or string.find(m,"лага",1,true) then
            return "Идея: уменьшить количество частиц, отключить след и держать FOV 70–85 для слабого GPU."
        elseif string.find(m,"реак",1,true) or string.find(m,"трен",1,true) then
            return "Идея: пройти 10 попыток в Reaction Test и сравнить свой средний результат с личным рекордом."
        elseif string.find(m,"визуал",1,true) or string.find(m,"крас",1,true) then
            return "Идея: графитовый HUD, белые контуры, редкие красные частицы и плавное свечение без мерцания."
        elseif string.find(m,"парир",1,true) or string.find(m,"мяч",1,true) then
            return "Идея: показывать скорость приближающегося мяча и тренировать нажатие F по сигналу, а не пытаться угадать по расстоянию."
        else
            return "Идея для Blade Ball: режим реакции, минималистичная статистика, собственные темы HUD или цветные следы мяча. Это локальные советы, не ответы ChatGPT."
        end
    end
    local function askRemote(question,callback)
        if config.aiEndpoint=="" then callback(nil,"Сервер не настроен") return end
        if not string.match(config.aiEndpoint,"^https?://") then callback(nil,"Нужен URL http(s)") return end
        local req=(type(request)=="function" and request) or (type(http_request)=="function" and http_request) or (syn and type(syn.request)=="function" and syn.request)
        if not req then callback(nil,"HTTP API окружения недоступен") return end
        task.spawn(function()
            local ok,r=pcall(function()return req({Url=config.aiEndpoint,Method="POST",Headers={["Content-Type"]="application/json"},Body=HttpService:JSONEncode({message=question})})end)
            if not alive then return end
            if not ok or not r then callback(nil,"Нет ответа сервера") return end
            local raw=r.Body or r.body
            local parsedOk,json=pcall(function()return HttpService:JSONDecode(raw or "")end)
            if not parsedOk then callback(nil,"Ошибка формата ответа") return end
            if json.answer then callback(tostring(json.answer)) else callback(nil,tostring(json.error or "Неизвестный ответ")) end
        end)
    end
    local function buildAI()
        local card=makeCard(pageHost,0,0,574,419,"AI ASSISTANT / советы и идеи")
        local hint=label(card,config.aiEndpoint=="" and "Локальный помощник · не ChatGPT" or "Подключён внешний AI endpoint",16,48,541,22,11,config.aiEndpoint=="" and C.warning or C.good)
        local history=create("ScrollingFrame",card,{Position=UDim2.fromOffset(15,81),Size=UDim2.fromOffset(543,232),BackgroundColor3=Color3.fromRGB(12,12,14),BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.fromOffset(0,240)});corner(history,7)
        local body=label(history,"AETHER: Спроси про реакцию, оптимизацию FPS, визуалы или идеи для Blade Ball.",12,11,516,200,12,C.text)
        body.TextWrapped=true;body.TextYAlignment=Enum.TextYAlignment.Top
        local question=makeTextBox(card,"Напиши вопрос или идею...",15,330,409,39)
        local function respond(text)
            if not body.Parent then return end
            body.Text="ВОПРОС: "..text.."\n\nAETHER: "..(config.aiEndpoint=="" and offlineIdea(text) or "Соединение...")
            if config.aiEndpoint~="" then
                askRemote(text,function(answer,err)
                    if body.Parent then body.Text="ВОПРОС: "..text.."\n\nAI: "..(answer or ("Ошибка: "..tostring(err))) end
                end)
            end
        end
        basicButton(card,"Отправить",435,330,122,39,function()
            local q=question.Text
            if #q>1 and #q<500 then respond(q);question.Text="" end
        end,true)
        label(card,"Реальный ChatGPT работает только через твой защищённый сервер (см. README).",15,380,537,25,10,C.muted)
    end
    local function buildSettings()
        local left=makeCard(pageHost,0,0,276,349,"Appearance")
        slider(left,"Масштаб интерфейса",60,.72,1.04,config.uiScale,function(v)
            config.uiScale=v
            if mainScale then mainScale.Scale=v end
        end,276,function(v)return string.format("%.2f",v)end)
        toggle(left,"Звуковые сигналы",138,config.sound,function(v)config.sound=v end,276)
        toggle(left,"Экранные частицы",176,config.particles,function(v)config.particles=v end,276)
        local key=label(left,"Горячие клавиши",14,231,250,22,11,C.text,true)
        label(left,"Right Ctrl / Left Ctrl — меню\nF — стандартная клавиша отражения",14,261,250,53,11,C.muted)
        local rightCard=makeCard(pageHost,292,0,282,349,"AI connection")
        label(rightCard,"HTTPS адрес собственного proxy",14,52,249,23,11,C.muted)
        local ep=makeTextBox(rightCard,"https://.../chat",14,84,252,40)
        ep.Text=config.aiEndpoint
        basicButton(rightCard,"Сохранить endpoint",14,136,252,36,function()
            local v=ep.Text
            if #v==0 or string.match(v,"^https?://") then config.aiEndpoint=v end
        end,true)
        local msg=label(rightCard,"API-ключ OpenAI не вводить в Roblox.\nОн должен храниться только на сервере.",14,197,253,50,10,C.muted)
        msg.TextWrapped=true;msg.TextYAlignment=Enum.TextYAlignment.Top
        basicButton(rightCard,"Скрыть меню",14,272,252,36,function() panel.Visible=false;dim.Visible=false end)
    end
    function navigate(name)
        activeTab=name
        tabText.Text="/ "..string.upper(name)
        resetPage()
        for tab,navItem in pairs(nav) do
            local selected=tab==name
            navItem.button.BackgroundTransparency=selected and 0 or 1
            navItem.button.BackgroundColor3=C.card2
            for _,seg in ipairs(navItem.lines) do
                if seg:IsA("Frame") then seg.BackgroundColor3=selected and C.text or C.muted end
            end
        end
        if name=="Parry" then buildParry()
        elseif name=="Visuals" then buildVisuals()
        elseif name=="Reaction" then buildReaction()
        elseif name=="AI" then buildAI()
        else buildSettings() end
    end
    navigate("Parry")
    showStatus()
    return showStatus
end

local showStatus=makeShell()
local function showMain()
    if not alive then return end
    if loader then loader:Destroy();loader=nil end
    panel.Visible=true;dim.Visible=true
    tween(panel,{Position=UDim2.fromScale(.5,.5)},.25)
end

-- Startup: MoonStone-inspired black loader, original AETHER branding; no copied logo.
loader=create("Frame",gui,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(760,515),BackgroundColor3=Color3.fromRGB(0,0,0),BorderSizePixel=0})
corner(loader,10);stroke(loader,C.line)
label(loader,"AETHER",22,12,150,28,15,C.text,true)
label(loader,"Loader",162,18,76,20,10,C.muted)
local closeLoader=create("TextButton",loader,{Text="×",Position=UDim2.fromOffset(720,11),Size=UDim2.fromOffset(31,31),TextColor3=C.muted,TextSize=25,BackgroundTransparency=1,BorderSizePixel=0})
track(closeLoader.MouseButton1Click:Connect(function()
    if type(env.__AETHER_BB_UNLOAD)=="function" then env.__AETHER_BB_UNLOAD() else gui:Destroy() end
end))
local loaderCard=create("Frame",loader,{Position=UDim2.fromOffset(190,111),Size=UDim2.fromOffset(380,360),BackgroundColor3=Color3.fromRGB(11,11,12),BorderSizePixel=0})
corner(loaderCard,15);stroke(loaderCard,C.line,1)
label(loaderCard,"A",154,20,80,60,43,C.text,true,Enum.TextXAlignment.Center)
label(loaderCard,"Вход",28,87,324,35,20,C.text,true,Enum.TextXAlignment.Center)
label(loaderCard,"Демо-ключ или гостевой запуск",33,123,316,22,11,C.muted,false,Enum.TextXAlignment.Center)
local selection=create("Frame",loaderCard,{Position=UDim2.fromOffset(26,166),Size=UDim2.fromOffset(328,36),BackgroundColor3=C.card,BorderSizePixel=0});corner(selection,8);stroke(selection,C.line)
local keyTab=create("TextButton",selection,{Text="Ключ",Size=UDim2.fromOffset(161,32),Position=UDim2.fromOffset(2,2),BackgroundColor3=C.card2,BorderSizePixel=0,TextColor3=C.text,Font=FB,TextSize=11,AutoButtonColor=false});corner(keyTab,7)
local guestTab=create("TextButton",selection,{Text="Гость",Size=UDim2.fromOffset(161,32),Position=UDim2.fromOffset(165,2),BackgroundTransparency=1,BorderSizePixel=0,TextColor3=C.muted,Font=F,TextSize=11,AutoButtonColor=false});corner(guestTab,7)
local keyBox=makeTextBox(loaderCard,"AETHER-OPEN",26,222,328,43)
local keyMessage=label(loaderCard,"Демо-ключ: AETHER-OPEN",26,274,326,17,10,C.muted)
local startButton=create("TextButton",loaderCard,{Text="Активировать демо",Position=UDim2.fromOffset(26,297),Size=UDim2.fromOffset(328,40),BackgroundColor3=C.text,TextColor3=C.dark,Font=FB,TextSize=12,BorderSizePixel=0,AutoButtonColor=false});corner(startButton,9)
local authMode="key"
local function setAuth(mode)
    authMode=mode
    keyTab.BackgroundTransparency=mode=="key" and 0 or 1
    guestTab.BackgroundTransparency=mode=="guest" and 0 or 1
    keyTab.TextColor3=mode=="key" and C.text or C.muted
    guestTab.TextColor3=mode=="guest" and C.text or C.muted
    keyBox.Visible=mode=="key"
    keyMessage.Text=mode=="key" and "Демо-ключ: AETHER-OPEN" or "Гостевой режим без проверки ключа"
    startButton.Text=mode=="key" and "Активировать демо" or "Продолжить без входа"
end
track(keyTab.MouseButton1Click:Connect(function()setAuth("key")end))
track(guestTab.MouseButton1Click:Connect(function()setAuth("guest")end))
track(startButton.MouseButton1Click:Connect(function()
    if authMode=="guest" or string.upper((keyBox.Text:gsub("%s+","")))=="AETHER-OPEN" then
        showMain()
    else
        keyMessage.Text="Неверный демо-ключ"
        keyMessage.TextColor3=C.danger
    end
end))
local guestClick=create("TextButton",loader,{Text="Продолжить без входа →",Position=UDim2.fromOffset(284,477),Size=UDim2.fromOffset(192,24),BackgroundTransparency=1,TextSize=11,TextColor3=C.muted,Font=F,BorderSizePixel=0})
track(guestClick.MouseButton1Click:Connect(showMain))
label(loader,"v1.0.0",20,482,100,18,10,C.muted)
label(loader,"LOCAL / NO REAL AUTH",550,482,187,17,10,C.muted,false,Enum.TextXAlignment.Right)

local vi
pcall(function()vi=game:GetService("VirtualInputManager")end)
local function sendParry()
    local ok=false
    -- Optional executor input helpers vary; never pretend success if they fail.
    if type(keypress)=="function" and type(keyrelease)=="function" then
        ok=pcall(function() keypress(0x46);task.wait(.035);keyrelease(0x46) end)
    elseif vi then
        ok=pcall(function()
            vi:SendKeyEvent(true,Enum.KeyCode.F,false,game)
            task.wait(.035)
            vi:SendKeyEvent(false,Enum.KeyCode.F,false,game)
        end)
    end
    status.latency=ok and "событие F отправлено" or "ввод недоступен"
    return ok
end
local function ballVelocity(ball)
    local a=ball:FindFirstChild("zoomies")
    if a and a:IsA("LinearVelocity") then return a.VectorVelocity end
    return ball.AssemblyLinearVelocity
end
local function findBall()
    local folder=workspace:FindFirstChild("Balls")
    if not folder then return nil end
    for _,b in ipairs(folder:GetChildren()) do
        if b:IsA("BasePart") and b:GetAttribute("realBall")==true then return b end
    end
    return nil
end
local function isMeTarget(ball)
    local t=ball:GetAttribute("target") or ball:GetAttribute("Target")
    if not t then return false end
    return tostring(t)==player.Name or tostring(t)==tostring(player.UserId)
end
local effectRoot
local function manageWorldTrail()
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        if trailEmitter then trailEmitter:Destroy();trailEmitter=nil end
        return
    end
    if config.worldTrail and not trailEmitter then
        local p=create("ParticleEmitter",root,{
            Name="AETHER_Local_Trail",Texture="rbxasset://textures/particles/sparkles_main.dds",
            Rate=9,Lifetime=NumberRange.new(.2,.54),Speed=NumberRange.new(.1,.9),
            LightEmission=.45,Size=NumberSequence.new(.17),
            Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(1,1)}),
            Color=ColorSequence.new(C.text,C.danger),Enabled=true
        })
        trailEmitter=p
    elseif (not config.worldTrail) and trailEmitter then
        trailEmitter:Destroy();trailEmitter=nil
    elseif trailEmitter and trailEmitter.Parent~=root then
        trailEmitter:Destroy();trailEmitter=nil
    end
end
local lastScan=0
local spin=0
local fpsTime=0
track(RunService.Heartbeat:Connect(function(dt)
    if not alive then return end
    pulse=pulse+dt
    fpsTime=fpsTime+dt
    if dt>0 then status.fps=math.floor(1/math.max(dt,.002)+.5) end
    if fpsTime>.14 then
        fpsTime=0
        manageWorldTrail()
        local cam=workspace.CurrentCamera
        if cam and mainScale then
            local vs=cam.ViewportSize
            mainScale.Scale=math.min(config.uiScale,(vs.X-20)/935,(vs.Y-20)/556)
        end
        if previewAuraStroke and previewAuraStroke.Parent then
            previewAuraStroke.Color=config.aura and C.danger or C.muted
            previewAuraStroke.Thickness=config.aura and 1.7 or 1
            previewAuraStroke.Transparency=config.aura and (.13+.35*(.5+.5*math.sin(pulse*4))) or .35
        end
        if showStatus then showStatus() end
    end
    particleTick=particleTick+dt
    if particleTick>.035 then
        particleTick=0
        for i,p in ipairs(frameParticles) do
            local f=p.object
            if f and f.Parent then
                local active=config.particles and i<=config.particleCount
                f.Visible=active
                if active then
                    p.ox=(p.ox+p.speed*dt*27)%1
                    f.Position=UDim2.fromScale(p.ox,.5+.48*math.sin(p.phase+pulse*.22))
                    f.BackgroundTransparency=.65+.15*math.sin(pulse*1.6+i)
                end
            end
        end
        if viewportClone and viewportClone.Parent then
            spin=spin+.22*dt
            pcall(function() viewportClone:PivotTo(CFrame.new(0,0,0)*CFrame.Angles(0,spin,0))end)
        end
    end
    if not config.autoParry then return end
    if os.clock()-lastScan<.055 then return end
    lastScan=os.clock()
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local humanoid=char and char:FindFirstChildOfClass("Humanoid")
    local ball=findBall()
    if not root or not humanoid or humanoid.Health<=0 or not ball then
        status.parry="МЯЧ НЕ НАЙДЕН";status.distance="—";status.speed=0;return
    end
    local rel=root.Position-ball.Position
    local dist=rel.Magnitude
    status.distance=string.format("%.0f",dist)
    local vel=ballVelocity(ball)
    status.speed=vel.Magnitude
    if not isMeTarget(ball) then status.parry="ДРУГАЯ ЦЕЛЬ / UNKNOWN";return end
    if dist<.1 or vel.Magnitude<1 then status.parry="МЯЧ НЕ ДВИЖЕТСЯ";return end
    local toward=vel:Dot(rel.Unit)
    if toward<=math.max(1,config.minApproach*vel.Magnitude) then status.parry="МЯЧ УДАЛЯЕТСЯ";return end
    local tti=math.max(0,dist-5)/toward
    status.parry=string.format("ЦЕЛЬ: ВЫ · %.2f C",tti)
    if tti<=config.lead and os.clock()-status.lastParry>=config.cooldown then
        status.lastParry=os.clock()
        status.attempts=status.attempts+1
        playUIBeep()
        sendParry()
    end
end))
track(UIS.InputBegan:Connect(function(input,processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.LeftControl or input.KeyCode==Enum.KeyCode.RightControl then
        if not loader and panel then
            panel.Visible=not panel.Visible
            dim.Visible=panel.Visible
        end
    end
end))

local function unload()
    if not alive then return end
    alive=false
    reaction.nonce=reaction.nonce+1
    clearPageEvents()
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end) end
    table.clear(connections)
    if trailEmitter then trailEmitter:Destroy();trailEmitter=nil end
    if gui then gui:Destroy();gui=nil end
    if env.__AETHER_BB_UNLOAD==unload then env.__AETHER_BB_UNLOAD=nil end
end
env.__AETHER_BB_UNLOAD=unload
print("[AETHER] Blade Ball V1 loaded. Use the loader (guest or demo key); Ctrl toggles menu after entering.")
