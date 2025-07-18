local tHex = require("tHex")
local dfpwm = require("cc.audio.dfpwm")

local STATE = {
    Uninitialized = "Uninitialized",
    Initializing  = "Initializing",
    Ready         = "Ready",
    Stopping      = "Stopping",
    Stopped       = "Stopped",
    Playing       = "Playing",
}

local BACKGROUNDSTATE = {
    None              = "None",
    FindingClients    = "FindingClients",
    WaitingForClients = "WaitingForClients",
    DecodingChunk     = "Decoding",
}

table.append = function(target, source)
    for _, value in ipairs(source) do
        table.insert(target, value)
    end

    return target
end

table.longest = function(tbl)
    local longestIndex = 0

    for _, value in ipairs(tbl) do
        if (#value > longestIndex) then
            longestIndex = #value
        end
    end

    return longestIndex
end

table.contains = function (tbl, value)
    if (type(tbl) ~= "table") then
        return false
    end

    for _, v in pairs(tbl) do
        if (v == value) then
            return true
        end
    end

    return false
end

table.sameValues = function (t1, t2)
    -- Check if both inputs are tables
    if type(t1) ~= "table" or type(t2) ~= "table" then
        return false
    end

    for _, v in pairs(t1) do
        if (not table.contains(t2, v)) then
            return false
        end
    end

    return true
end

string.newlineSplit = function(str)
    local result = {}
    local pattern = "(.-)\n"
    local lastPos = 1

    -- Find all matches for non-newline content followed by \n
    for substr in str:gmatch(pattern) do
        table.insert(result, substr)
        lastPos = str:find("\n", lastPos) + 1
    end

    -- Add the remaining part after the last \n (or the whole string if no \n)
    local remaining = str:sub(lastPos)
    if remaining ~= "" then
        table.insert(result, remaining)
    else
        table.insert(result, "")
    end

    return result
end

local rep, find, gmatch, sub, len, newlineSplit = string.rep, string.find, string.gmatch, string.sub, string.len, string.newlineSplit



return function(name, basalt)
    local base = basalt.getObject("ChangeableObject")(name, basalt)
    local objectType = "AudioPlayer"
    local hIndex, wIndex, textX, textY = 1, 1, 1, 1

    local lines = { "" }
    local bgLines = { "" }
    local fgLines = { "" }
    local keyWords = { }
    local rules = { }
    local isShifting = false

    local startSelX, endSelX, startSelY, endSelY

    local selectionBG, selectionFG = colors.lightBlue, colors.black

    base:setSize(30, 12)
    base:setZIndex(5)

    --- Actual Audio Player Routines

    local modem = peripheral.find("modem") or error("No modem found", 0)
    local CHANNEL = 62
    local PROTOCAL = "audio_playback"
    local TIMEOUT = 2
    local ACKNOWLEDGEMENT = "ack"
    local PONG = "pong"

    -------------------

    local currentChunk = 1
    local chunksCount = 0
    local currentURL = ""
    local state = {First = STATE.Uninitialized, Second = BACKGROUNDSTATE.None}
    local clients = {}
    local chunks = {}
    local dfpwm_decoder = dfpwm.make_decoder()

    local playThread = basalt.getActiveFrame():addThread()
    local startThread = basalt.getActiveFrame():addThread()
    local stopThread =  basalt.getActiveFrame():addThread()

    -------------------

    local function downloadChunks(url)
        local handle = assert(http.get(url, nil, true)) -- Binary mode
        local chunks = {}

        for chunk in handle.read, 16 * 1024 do
            table.insert(chunks, chunk)
        end

        handle.close()

        return chunks
    end

    local function waitForAcknowledgements(self)
        if (self:getState().First ~= STATE.Initializing) then
            state.Second = BACKGROUNDSTATE.WaitingForClients
            --[[
            local acknowledgements = {}

            while not table.sameValues(acknowledgements, clients) do
                local id, message = rednet.receive(PROTOCAL, TIMEOUT)

                if id and message.command == ACKNOWLEDGEMENT and table.contains(clients, id) then
                    table.insert(acknowledgements, id)
                end
            end]]--
            --[[local acks = {}
            while #acks < #clients do
                local id, message = rednet.receive(PROTOCAL, 2)
                if id and message.command == "ack" then
                    table.insert(acks, id)
                end
            end]]--

            local acknowledgements = {}

            while #acknowledgements < #clients do
                local id, message = rednet.receive(PROTOCAL, 2)
                if id and message.command == ACKNOWLEDGEMENT then
                    table.insert(acknowledgements, id)
                end
            end

            return table.sameValues(clients, acknowledgements)
        end

        state.Second = BACKGROUNDSTATE.None
    end

    local function decodeChunk(chunkData)
        state.Second = BACKGROUNDSTATE.DecodingChunk

        local chunk = dfpwm_decoder(chunkData)

        state.Second = BACKGROUNDSTATE.None
        
        return chunk
    end

    local function broadcastChunk(chunk)
        rednet.broadcast({command = "chunk", data = chunk}, PROTOCAL)
    end

    local function playLoop(self)
        if (self:getState().First == STATE.Playing and (currentURL ~= nil and currentURL ~= "") and (chunks ~= {} and chunksCount > 0)) then
            while currentChunk <= chunksCount do
                if (self:getState().First == STATE.Playing) then
                    self:print("Broadcasting chunk " .. currentChunk .. "/" .. chunksCount)
                    broadcastChunk(decodeChunk(chunks[currentChunk]))
                    waitForAcknowledgements(self)

                    if (self:getState().First == STATE.Stopping) then
                        break
                    end
                    self:_setChunkPos(currentChunk + 1)
                else
                    break
                end
            end

            self:stop()
        end
    end

    local function isSelected()
        if(startSelX~=nil)and(endSelX~=nil)and(startSelY~=nil)and(endSelY~=nil)then
            return true
        end
        return false
    end

    local function getSelectionCoordinates()
        local sx, ex, sy, ey = startSelX, endSelX, startSelY, endSelY
        if isSelected() then
            if startSelX < endSelX and startSelY <= endSelY then
                sx = startSelX
                ex = endSelX
                if startSelY < endSelY then
                    sy = startSelY
                    ey = endSelY
                else
                    sy = endSelY
                    ey = startSelY
                end
            elseif startSelX > endSelX and startSelY >= endSelY then
                sx = endSelX
                ex = startSelX
                if startSelY > endSelY then
                    sy = endSelY
                    ey = startSelY
                else
                    sy = startSelY
                    ey = endSelY
                end
            elseif startSelY > endSelY then
                sx = endSelX
                ex = startSelX
                sy = endSelY
                ey = startSelY
            end
            return sx, ex, sy, ey
        end
    end

    local function removeSelection(self)
        local sx, ex, sy, ey = getSelectionCoordinates()
        local startLine = lines[sy]
        local endLine = lines[ey]
        lines[sy] = startLine:sub(1, sx - 1) .. endLine:sub(ex + 1, endLine:len())
        bgLines[sy] = bgLines[sy]:sub(1, sx - 1) .. bgLines[ey]:sub(ex + 1, bgLines[ey]:len())
        fgLines[sy] = fgLines[sy]:sub(1, sx - 1) .. fgLines[ey]:sub(ex + 1, fgLines[ey]:len())
    
        for i = ey, sy + 1, -1 do
            if i ~= sy then
                table.remove(lines, i)
                table.remove(bgLines, i)
                table.remove(fgLines, i)
            end
        end
    
        textX, textY = sx, sy
        startSelX, endSelX, startSelY, endSelY = nil, nil, nil, nil
        return self
    end

    local function stringGetPositions(str, word)
        local pos = {}
        if(str:len()>0)then
            for w in gmatch(str, word)do
                local s, e = find(str, w)
                if(s~=nil)and(e~=nil)then
                    table.insert(pos,s)
                    table.insert(pos,e)
                    local startL = sub(str, 1, (s-1))
                    local endL = sub(str, e+1, str:len())
                    str = startL..(":"):rep(w:len())..endL
                end
            end
        end
        return pos
    end

    local function updateColors(self, l)
        l = l or textY
        local fgLine = tHex[self:getForeground()]:rep(fgLines[l]:len())
        local bgLine = tHex[self:getBackground()]:rep(bgLines[l]:len())
        for k,v in pairs(rules)do
            local pos = stringGetPositions(lines[l], v[1])
            if(#pos>0)then
                for x=1,#pos/2 do
                    local xP = x*2 - 1
                    if(v[2]~=nil)then
                        fgLine = fgLine:sub(1, pos[xP]-1)..tHex[v[2]]:rep(pos[xP+1]-(pos[xP]-1))..fgLine:sub(pos[xP+1]+1, fgLine:len())
                    end
                    if(v[3]~=nil)then
                        bgLine = bgLine:sub(1, pos[xP]-1)..tHex[v[3]]:rep(pos[xP+1]-(pos[xP]-1))..bgLine:sub(pos[xP+1]+1, bgLine:len())
                    end
                end
            end
        end
        for k,v in pairs(keyWords)do
            for _,b in pairs(v)do
                local pos = stringGetPositions(lines[l], b)
                if(#pos>0)then
                    for x=1,#pos/2 do
                        local xP = x*2 - 1
                        fgLine = fgLine:sub(1, pos[xP]-1)..tHex[k]:rep(pos[xP+1]-(pos[xP]-1))..fgLine:sub(pos[xP+1]+1, fgLine:len())
                    end
                end
            end
        end
        fgLines[l] = fgLine
        bgLines[l] = bgLine
        self:updateDraw()
    end

    local function updateAllColors(self)
        for n=1,#lines do
            updateColors(self, n)
        end
    end

    local object = {
        getType = function(self)
            return objectType
        end;

        setBackground = function(self, bg)
            base.setBackground(self, bg)
            updateAllColors(self)
            return self
        end,

        setForeground = function(self, fg)
            base.setForeground(self, fg)
            updateAllColors(self)
            return self
        end,

        setSelection = function(self, fg, bg)
            selectionFG = fg or selectionFG
            selectionBG = bg or selectionBG
            return self
        end,

        setSelectionFG = function(self, fg)
            return self:setSelection(fg, nil)
        end,

        setSelectionBG = function(self, bg)
            return self:setSelection(nil, bg)
        end,

        getSelection = function(self)
            return selectionFG, selectionBG
        end,

        getSelectionFG = function(self)
            return selectionFG
        end,

        getSelectionBG = function(self)
            return selectionBG
        end,

        getLines = function(self)
            return lines
        end,

        getLine = function(self, index)
            return lines[index]
        end,

        editLine = function(self, index, text)
            lines[index] = text or lines[index]
            updateColors(self, index)
            self:updateDraw()
            return self
        end,

        clear = function(self)
            lines = {""}
            bgLines = {""}
            fgLines = {""}
            startSelX,endSelX,startSelY,endSelY = nil,nil,nil,nil
            hIndex, wIndex, textX, textY = 1, 1, 1, 1
            self:updateDraw()
            return self
        end,

        addLine = function(self, text, index)
            if(text~=nil)then
                local bgColor = self:getBackground()
                local fgColor = self:getForeground()
                if(#lines==1)and(lines[1]=="")then
                    lines[1] = text
                    bgLines[1] = tHex[bgColor]:rep(text:len())
                    fgLines[1] = tHex[fgColor]:rep(text:len())
                    updateColors(self, 1)
                    return self
                end
                if (index ~= nil) then
                    table.insert(lines, index, text)
                    table.insert(bgLines, index, tHex[bgColor]:rep(text:len()))
                    table.insert(fgLines, index, tHex[fgColor]:rep(text:len()))
                else
                    table.insert(lines, text)
                    table.insert(bgLines, tHex[bgColor]:rep(text:len()))
                    table.insert(fgLines, tHex[fgColor]:rep(text:len()))
                end
            end
            updateColors(self, index or #lines)
            self:updateDraw()
            return self
        end,

        addKeywords = function(self, color, tab)
            if(keyWords[color]==nil)then
                keyWords[color] = {}
            end
            for k,v in pairs(tab)do
                table.insert(keyWords[color], v)
            end
            self:updateDraw()
            return self
        end,

        addRule = function(self, rule, fg, bg)
            table.insert(rules, {rule, fg, bg})
            self:updateDraw()
            return self
        end,

        editRule = function(self, rule, fg, bg)
            for k, v in pairs(rules) do
                if (v[1] == rule)then
                    rules[k][2] = fg
                    rules[k][3] = bg
                end
            end
            self:updateDraw()
            return self
        end,

        removeRule = function(self, rule)
            for k,v in pairs(rules)do
                if(v[1]==rule)then
                    table.remove(rules, k)
                end
            end
            self:updateDraw()
            return self
        end,

        setKeywords = function(self, color, tab)
            keyWords[color] = tab
            self:updateDraw()
            return self
        end,

        removeLine = function(self, index)
            if(#lines>1)then
                table.remove(lines, index or #lines)
                table.remove(bgLines, index or #bgLines)
                table.remove(fgLines, index or #fgLines)
            else
                lines = {""}
                bgLines = {""}
                fgLines = {""}
            end
            self:updateDraw()
            return self
        end,

        getTextCursor = function(self)
            return textX, textY
        end,

        getOffset = function(self)
            return wIndex, hIndex
        end,

        setOffset = function(self, xOff, yOff)
            wIndex = xOff or wIndex
            hIndex = yOff or hIndex
            self:updateDraw()
            return self
        end,

        getXOffset = function(self)
            return wIndex
        end,

        setXOffset = function(self, xOff)
            return self:setOffset(xOff, nil)
        end,

        getYOffset = function(self)
            return hIndex
        end,

        setYOffset = function(self, yOff)
            return self:setOffset(nil, yOff)
        end,

        getFocusHandler = function(self)
            base.getFocusHandler(self)
            local obx, oby = self:getPosition()
            self:getParent():setCursor(true, obx + textX - wIndex, oby + textY - hIndex, self:getForeground())
        end,

        loseFocusHandler = function(self)
            base.loseFocusHandler(self)
            self:getParent():setCursor(false)
        end,

        keyHandler = function(self, key)
            if (base.keyHandler(self, key)) then
                if (key == keys.leftShift or key == keys.rightShift) then
                    isShifting = true
                end

                return true
            end
        end,

        keyUpHandler = function (self, key)
            if (base.keyUpHandler(self, key)) then
                if (key == keys.leftShift or key == keys.rightShift) then
                    isShifting = false
                end
            end

            return true
        end,

        scrollHandler = function(self, dir, x, y)
            if (base.scrollHandler(self, dir, x, y)) then
                local parent = self:getParent()
                local obx, oby = self:getAbsolutePosition()
                local anchx, anchy = self:getPosition()
                local w,h = self:getSize()

                if (not isShifting) then
                    hIndex = hIndex + dir
                    if (hIndex > #lines - (h - 1)) then
                        hIndex = #lines - (h - 1)
                    end

                    if (hIndex < 1) then
                        hIndex = 1
                    end
                elseif (isShifting) then
                    wIndex = wIndex + dir
                    if (wIndex > table.longest(lines) - (w - 1)) then
                        wIndex = table.longest(lines) - (w - 1)
                    end

                    if (wIndex < 1) then
                        wIndex = 1
                    end
                end

                if (obx + textX - wIndex >= obx and obx + textX - wIndex < obx + w) and (anchy + textY - hIndex >= anchy and anchy + textY - hIndex < anchy + h) then
                    parent:setCursor(not isSelected(), anchx + textX - wIndex, anchy + textY - hIndex, self:getForeground())
                else
                    parent:setCursor(false)
                end
                self:updateDraw()
                return true
            end
        end,

        draw = function(self)
            base.draw(self)
            self:addDraw("textfield", function()
                local w, h = self:getSize()
                local bgColor = tHex[self:getBackground()]
                local fgColor = tHex[self:getForeground()]
        
                for n = 1, h do
                    local text = ""
                    local bg = ""
                    local fg = ""
                    if lines[n + hIndex - 1] then
                        text = lines[n + hIndex - 1]
                        fg = fgLines[n + hIndex - 1]
                        bg = bgLines[n + hIndex - 1]
                    end
        
                    text = sub(text, wIndex, w + wIndex - 1)
                    bg = rep(bgColor, w)
                    fg = rep(fgColor, w)
        
                    self:addText(1, n, text)
                    self:addBG(1, n, bg)
                    self:addFG(1, n, fg)
                    self:addBlit(1, n, text, fg, bg)
                end
        
                if startSelX and endSelX and startSelY and endSelY then
                    local sx, ex, sy, ey = getSelectionCoordinates()
                    for n = sy, ey do
                        local line = #lines[n]
                        local xOffset = 0
                        if n == sy and n == ey then
                            xOffset = sx - 1 - (wIndex - 1)
                            line = line - (sx - 1 - (wIndex - 1)) - (line - ex + (wIndex - 1))
                        elseif n == ey then
                            line = line - (line - ex + (wIndex - 1))
                        elseif n == sy then
                            line = line - (sx - 1)
                            xOffset = sx - 1 - (wIndex - 1)
                        end
                        
                        local visible_line_length = math.min(line, w - xOffset)
                
                        self:addBG(1 + xOffset, n, rep(tHex[selectionBG], visible_line_length))
                        self:addFG(1 + xOffset, n, rep(tHex[selectionFG], visible_line_length))
                    end
                end
            end)
        end,

        print = function (self, text)
            if (text ~= nil and text ~= "") then
                local numLinesBefore = #lines

                --table.insert(lines, text)
                table.append(lines, text:newlineSplit(text))

                if (#lines > self:getHeight()) then
                    hIndex = hIndex + (#lines - numLinesBefore)
                end
            end

            self:updateDraw()

            return self
        end,

        getState = function (self)
            return state
        end,

        getURL = function (self)
            return currentURL
        end,

        setURL = function (self, newURL)
            currentURL = newURL

            return self
        end,

        getChunkPos = function (self)
            return currentChunk
        end,

        _setChunkPos = function (self, newPos, shouldPing)
            shouldPing = shouldPing or true
            currentChunk = newPos

            if (self.chunkChangeCallback ~= nil and shouldPing) then
                self:chunkChangeCallback(currentChunk)
            end

            return self
        end,

        setChunkPos = function (self, newPos, shouldPing)
            shouldPing = shouldPing or true
            if (newPos > chunksCount or newPos < 1 or newPos == currentChunk) then
                return self
            end

            if (self:getState().First == STATE.Playing) then
                self:_stop()

                self:_setChunkPos(newPos, shouldPing)

                self:_play()

            else
                self:_setChunkPos(newPos, shouldPing)
            end

            return self
        end,

        chunkChangeCallback = function (self, chunkPos) end,

        onChunkChange = function (self, func)
            self.chunkChangeCallback = func

            return self
        end,

        getChunksCount = function (self)
            return chunksCount
        end,

        setChunks = function (self, newChunks)
            if (type(newChunks) ~= "table") then
                return self
            end

            chunks = newChunks
            chunksCount = #chunks

            if (self.chunksCountCallback ~= nil) then
                self:chunksCountCallback(chunksCount)
            end

            return self
        end,

        chunksCountCallback = function (self, chunksCount) end,

        onChunksCountChange = function (self, func)
            self.chunksCountCallback = func

            return self
        end,

        startAllComputers = function(self)
            if (self:getState().First == STATE.Initializing) then
                state.Second = BACKGROUNDSTATE.FindingClients

                local computers = {peripheral.find("computer")}

                --table.insert(lines, "Turning on " .. tostring(#computers) .. " computers")
                self:print("Turning on " .. tostring(#computers) .. " computers")

                for _, computer in ipairs(computers) do
                    if computer ~= nil then
                        --table.insert(lines, "Computer " .. tostring(computer.getID()) .. " turned on!")
                        self:print("Computer " .. tostring(computer.getID()) .. " turned on!")
                        --table.insert(clients, computer.getID())
                        computer.reboot()
                    end
                end
            end

            state.Second = BACKGROUNDSTATE.None
        end,

        discoverClients = function(self)
            if (self:getState().First == STATE.Initializing) then
                state.Second = BACKGROUNDSTATE.FindingClients

                rednet.broadcast({command = "ping"}, PROTOCAL)

                local clientIds = {}
                local timer = os.startTimer(TIMEOUT)

                while true do
                    local event, id, message = os.pullEvent()

                    if event == "rednet_message" then
                        if message and message.command == PONG then
                            table.insert(clientIds, id)
                        end
                    elseif event == "timer" and id == timer then
                        break
                    end
                    --sleep(0.01)
                    basalt.update()
                end

                if #clientIds == 0 then
                    --table.insert(lines, "No clients found")
                    self:print("No clients found")
                end
                --table.insert(lines, "Found " .. #clientIds .. " clients")
                self:print("Found " .. #clientIds .. " clients")
                clients = clientIds
            end

            state.Second = BACKGROUNDSTATE.None
        end,

        load = function(self)
            self:listenEvent("mouse_scroll")
            self:listenEvent("key")
            self:listenEvent("key_up")
        end,

        setup = function (self)
            if (self:getState().First == STATE.Uninitialized) then
                state.First = STATE.Initializing

                rednet.open(peripheral.getName(modem), CHANNEL)
				if (not shell.resolveProgram("attach")) then
					self:startAllComputers() -- Crashes CraftOS-PC for some reason
				end
				sleep(5)
                self:discoverClients()

                state.First = STATE.Ready
            end
        end,

        stopSpeakers = function (self, wait)
            wait = wait or true
            rednet.broadcast({command = "stop"}, PROTOCAL)

            if (wait) then
                waitForAcknowledgements(self)
            end

            return self
        end,

        _play = function (self)
            if (currentURL ~= nil and currentURL ~= "") then
                state.First = STATE.Playing

                if (self:getState().First == STATE.Ready and (currentURL ~= nil and currentURL ~= "")) then
                    self:_setChunkPos(1)
                end

                self:setChunks(downloadChunks(currentURL))

                playThread:start(function ()
                    playLoop(self)
                end)
            end
        end,

        play = function (self)
            startThread:start(function ()
                if ((self:getState().First == STATE.Ready or self:getState().First == STATE.Stopped) and(currentURL ~= nil and currentURL ~= "")) then
                    self:print("Loading: \n" .. currentURL)
                    self:_play()
                end
            end)
        end,

        _continuePlay = function (self)
                state.First = STATE.Playing

                playThread:start(function ()
                    playLoop(self)
                end)
        end,

        continuePlay = function (self)
            startThread:start(function ()
                self:_continuePlay()
            end)
        end,

        _stop = function (self)
            if (self:getState().First == STATE.Playing) then
                state.First = STATE.Stopping

                playThread:stop()
                self:stopSpeakers()

                state.First = STATE.Stopped
            end
        end,

        stop = function (self)
            stopThread:start(function()
                if (self:getState().First == STATE.Playing) then
                    self:_stop()
                    self:print("Broadcast paused")
                end
            end)
        end,

        reload = function (self)
            state.First = STATE.Stopping

            playThread:stop()
            self:stopSpeakers()

            state.First = STATE.Ready
        end,

        unload = function (self)
            stopThread:start(function()
                if (self:getState().First == STATE.Playing or self:getState().First == STATE.Stopped) then
                    state.First = STATE.Stopping
                    self:setChunkPos(1)
                    currentURL = ""

                    playThread:stop()
                    self:stopSpeakers()
                    self:print("Stopped")

                    state.First = STATE.Ready
                end
            end)
        end
    }

    object.__index = object
    return setmetatable(object, base)
end