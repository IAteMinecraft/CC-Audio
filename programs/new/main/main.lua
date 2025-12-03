-- Sample Usage: example_main.lua
-- This is a sample file demonstrating how to use the AudioPlayer and AudioBroadcaster.

local AudioPlayer = require("AudioPlayer")  -- Assuming AudioPlayer.lua is in the path

-- Create the player (it will create a broadcaster internally)
local player = AudioPlayer.new()

local lastPrinted = 0

function PrintLogs()
    local logs = player.broadcaster:getTextBuffer()
    for i = lastPrinted + 1, #logs do
        print(logs[i])
    end
    lastPrinted = #logs
end

-- Set a URL and play
player:setURL("https://github.com/IAteMinecraft/CC-Audio/raw/refs/heads/main/Star%20Fox%20-%20Best%20Corneria%20Remixes.dfpwm")

-- To print logs continuously during playback, run playback in parallel with log printing
parallel.waitForAll(
    function()
        player:play()
    end,
    function()
        while true do
            PrintLogs()
            sleep(0.5)  -- Check for new logs every 0.5 seconds
        end
    end
)

-- Example controls
-- player:pause()
-- player:resume()
-- player:seek(5)
-- player:stop()

-- Access logs: player.broadcaster:getTextBuffer()
-- Current position: player:getCurrentPos()
-- Total chunks: player:getChunksCount()