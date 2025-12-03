local modem = peripheral.find("modem") or error("No modem found", 0)

local CHANNEL = 62
local PROTOCOL = "audio_playback"
--local TIMEOUT = 5  -- Increased timeout for reliability
local TIMEOUT = ((16 * 1024) * 8) / 48000  -- Calculate how long a chunk will take to play
local PING = "ping"
local PONG = "pong"
local CHUNK = "chunk"
local ACK = "ack"
local STOP = "stop"

-- State enums
local STATE = {
    Uninitialized = "Uninitialized",
    Initializing = "Initializing",
    Ready = "Ready",
    Playing = "Playing",
    Paused = "Paused",
    Stopping = "Stopping",
    Stopped = "Stopped",
}

-- AudioBroadcaster: Low-level object for broadcasting raw chunks and managing sync via IDs
local AudioBroadcaster = {}
AudioBroadcaster.__index = AudioBroadcaster

function AudioBroadcaster.new()
    local self = setmetatable({}, AudioBroadcaster)
    self.state = STATE.Uninitialized
    self.clients = {}
    self.textBuffer = {}  -- List of log lines
    self.currentChunkId = nil
    self.ackTracker = {}  -- Table to track acks for current chunk_id: {client_id = true}
    self.playThread = nil  -- Placeholder for thread if needed (e.g., in Basalt context)
    rednet.open(peripheral.getName(modem), CHANNEL)
    return self
end

function AudioBroadcaster:log(message)
    table.insert(self.textBuffer, message)
    -- Could fire an event or callback for UI update
end

function AudioBroadcaster:discoverClients()
    if self.state ~= STATE.Initializing then return end
    self:log("Discovering clients...")
    rednet.broadcast({command = PING}, PROTOCOL)
    local timer = os.startTimer(TIMEOUT)
    local discovered = {}
    while true do
        local event, arg1, arg2 = os.pullEvent()
        if event == "rednet_message" and arg2.command == PONG then
            if not discovered[arg1] then
                discovered[arg1] = true
                self:log("Found client: " .. arg1)
            end
        elseif event == "timer" and arg1 == timer then
            break
        end
    end
    self.clients = discovered
    if next(self.clients) == nil then
        self:log("No clients found")
    else
        self:log("Discovered " .. table.maxn(self.clients) .. " clients")
    end
end

function AudioBroadcaster:init()
    if self.state == STATE.Uninitialized then
        self.state = STATE.Initializing
        self:log("Initializing broadcaster...")
        -- Optional: Turn on attached computers if needed
        -- local computers = {peripheral.find("computer")}
        -- for _, comp in ipairs(computers) do comp.turnOn() end
        sleep(2)  -- Wait for boot
        self:discoverClients()
        self.state = STATE.Ready
        self:log("Ready")
    end
end

function AudioBroadcaster:waitForAcks(chunk_id)
    if self.state ~= STATE.Playing then return false end
    self.ackTracker = {}
    local expected = table.maxn(self.clients)
    local received = 0
    local timer = os.startTimer(TIMEOUT)
    while received < expected do
        local event, sender, message = os.pullEvent()
        if event == "rednet_message" and message.command == ACK and message.chunk_id == chunk_id then
            if self.clients[sender] and not self.ackTracker[sender] then
                self.ackTracker[sender] = true
                received = received + 1
                self:log("Ack received from " .. sender .. " for chunk " .. chunk_id)
            end
        elseif event == "timer" and sender == timer then
            self:log("Timeout waiting for acks on chunk " .. chunk_id .. " (received " .. received .. "/" .. expected .. ")")
            return false
        end
    end
    self:log("All acks received for chunk " .. chunk_id .. "\n")
    return true
end

function AudioBroadcaster:CueAudio(chunk_data, chunk_id)
    if self.state ~= STATE.Playing or not chunk_data then return false end
    self.currentChunkId = chunk_id
    self:log("Cueing chunk " .. chunk_id .. " (size: " .. #chunk_data .. " bytes)")
    rednet.broadcast({command = CHUNK, data = chunk_data, chunk_id = chunk_id}, PROTOCOL)
    return self:waitForAcks(chunk_id)
end

function AudioBroadcaster:Start()
    if self.state == STATE.Ready or self.state == STATE.Stopped or self.state == STATE.Paused then
        self.state = STATE.Playing
        self:log("Starting playback")
    end
end

function AudioBroadcaster:Stop()
    if self.state == STATE.Playing or self.state == STATE.Paused then
        self.state = STATE.Stopping
        self:log("Stopping playback")
        rednet.broadcast({command = STOP}, PROTOCOL)
        -- Wait for stop acks if desired, but optional for simplicity
        sleep(1)
        self.state = STATE.Stopped
    end
end

function AudioBroadcaster:getState()
    return self.state
end

function AudioBroadcaster:getTextBuffer()
    return self.textBuffer
end

return AudioBroadcaster