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

local AudioBroadcaster = require("AudioBroadcaster")  -- Assuming AudioBroadcaster.lua is in the same directory or path

-- AudioPlayer: High-level wrapper for file management, chunking, seeking
local AudioPlayer = {}
AudioPlayer.__index = AudioPlayer

function AudioPlayer.new(broadcaster)
    local self = setmetatable({}, AudioPlayer)
    self.broadcaster = broadcaster or AudioBroadcaster.new()
    self.url = nil
    self.chunks = {}
    self.chunkSize = 16 * 1024
    self.currentPos = 1
    self.chunksCount = 0
    self.chunkIdCounter = 0  -- Incremental ID for each cue
    return self
end

function AudioPlayer:downloadChunks(url)
    local handle = http.get(url, nil, true)  -- Binary mode
    if not handle then error("Failed to download " .. url) end
    local chunks = {}
    while true do
        local chunk = handle.read(self.chunkSize)
        if not chunk then break end
        table.insert(chunks, chunk)
    end
    handle.close()
    return chunks
end

function AudioPlayer:setURL(new_url)
    self.url = new_url
    self.broadcaster:log("Setting URL: " .. new_url)
    self.chunks = self:downloadChunks(new_url)
    self.chunksCount = #self.chunks
    self.currentPos = 1
    self.broadcaster:log("Downloaded " .. self.chunksCount .. " chunks")
end

function AudioPlayer:play()
    self.broadcaster:init()  -- Ensure initialized
    self.broadcaster:Start()
    while self.currentPos <= self.chunksCount and self.broadcaster:getState() == STATE.Playing do
        self.chunkIdCounter = self.chunkIdCounter + 1
        local success = self.broadcaster:CueAudio(self.chunks[self.currentPos], self.chunkIdCounter)
        if not success then
            self.broadcaster:log("Playback interrupted on chunk " .. self.currentPos)
            break
        end
        self.currentPos = self.currentPos + 1
    end
    self.broadcaster:Stop()
end

function AudioPlayer:pause()
    if self.broadcaster:getState() == STATE.Playing then
        self.broadcaster.state = STATE.Paused
        self.broadcaster:log("Paused at chunk " .. self.currentPos)
    end
end

function AudioPlayer:resume()
    if self.broadcaster:getState() == STATE.Paused then
        self.broadcaster:Start()
        self.broadcaster:log("Resuming from chunk " .. self.currentPos)
    end
end

function AudioPlayer:seek(new_pos)
    if new_pos < 1 or new_pos > self.chunksCount then return end
    self.broadcaster:Stop()
    self.currentPos = new_pos
    self.broadcaster:log("Seeking to chunk " .. new_pos)
    self:play()  -- Restart from new pos
end

function AudioPlayer:stop()
    self.broadcaster:Stop()
    self.currentPos = 1
    self.chunkIdCounter = 0
end

function AudioPlayer:getCurrentPos()
    return self.currentPos
end

function AudioPlayer:getChunksCount()
    return self.chunksCount
end

return AudioPlayer