local VERSION = "1.0.6"

-- Function to compare version strings (e.g., "1.0.0" < "1.0.1")
local function compareVersions(current, remote)
    local function parseVersion(v)
        local parts = {}
        for part in v:gmatch("%d+") do
            table.insert(parts, tonumber(part))
        end
        return parts
    end

    local currParts = parseVersion(current)
    local remParts = parseVersion(remote)

    for i = 1, math.max(#currParts, #remParts) do
        local c = currParts[i] or 0
        local r = remParts[i] or 0
        if r > c then return true end
        --if c > r then return false end
    end
    return false
end

-- Auto-updater function
local function checkForUpdate()
    local url = "https://github.com/IAteMinecraft/CC-Audio/raw/refs/heads/main/programs/client/audio_player_client.lua"
    local response = http.get(url)
    if not response then
        print("Failed to fetch update from " .. url)
        return false
    end

    local content = response.readAll()
    response.close()

    -- Extract the version from the first line (local VERSION = "x.y.z")
    local remoteVersion = content:match('local%s+VERSION%s*=%s*["\'](%d+%.%d+%.%d+)["\']')
    if not remoteVersion then
        print("Failed to parse remote version: " .. remoteVersion)
        return false
    end

    print("Current version: " .. VERSION .. ", Remote version: " .. remoteVersion)

    if compareVersions(VERSION, remoteVersion) then
        print("Newer version found. Updating...")
        local file = fs.open(shell.getRunningProgram(), "w")
        file.write(content)
        file.close()
        print("Update complete. Rebooting...")
        os.reboot()
    else
        print("No update needed.")
    end
    return true
end

term.clear()
term.setCursorPos(1, 1)

print("Checking for updates...")
checkForUpdate()
sleep(2)

local modem = peripheral.find("modem") or error("No modem found", 0)
local speakers = {peripheral.find("speaker")} or error("No speakers connected", 0)
--local dfpwm = require("cc.audio.dfpwm")
--local decoder = dfpwm.make_decoder()
local CHANNEL = 62 -- Must match main computer
local PROTOCOL = "audio_playback" -- Must match main computer

-- Open rednet on wired modem
rednet.open(peripheral.getName(modem), CHANNEL)

-- Queue for audio buffers to play asynchronously
local audioQueue = {}

local function playBuffer(buffer)
    for _, speaker in ipairs(speakers) do
        --speaker.stop()
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end
end

local function stopAllSpeakers()
    for _, speaker in ipairs(speakers) do
        speaker.stop()
    end
end

-- Async audio playback handler
local function audioPlayer()
    while true do
        if #audioQueue > 0 then
            local buffer = table.remove(audioQueue, 1) -- Get next buffer
            playBuffer(buffer[2]) -- Play it
            print("Chunk played on all speakers")
            rednet.send(buffer[1], {command = "ack"}, PROTOCOL) -- Send acknowledgment
        else
            os.pullEvent("audio_queue") -- Wait for a new buffer to be added
        end
    end
end

local function main()
    term.clear()
    term.setCursorPos(1, 1)
    print("Client computer: Waiting for messages:\nChannel: " .. CHANNEL .. ",\nProtocol: " .. PROTOCOL)
    while true do
        local id, message = rednet.receive(PROTOCOL)
        print("Received message from computer " .. id .. ": command = " .. (message.command or "nil"))
        if message.command == "ping" then
            print("Sending pong to computer " .. id)

            rednet.send(id, {command = "pong"}, PROTOCOL)
        elseif message.command == "chunk" then
            print("Received chunk, length: " .. #message.data .. " bytes")

            --local buffer = decoder(message.data) -- Decode the DFPWM chunk
            --playBuffer(message.data) -- Play on all speakers

            table.insert(audioQueue, {[1] = id, [2] = message.data}) -- Queue the buffer
            os.queueEvent("audio_queue") -- Signal audioPlayer to process queue

            --print("Chunk played on all speakers")

            --rednet.send(id, {command = "ack"}, PROTOCOL) -- Send acknowledgment
        elseif message.command == "stop" then
            print("Received stop command")

            rednet.send(id, {command = "ack"}, PROTOCOL)
            -- Stop all speakers on terminate
            stopAllSpeakers()
            --break  -- Don't break because we want the script to run continuosly
        end
    end
end

--main()
-- Run main and audioPlayer concurrently
parallel.waitForAny(main, audioPlayer)

rednet.close(peripheral.getName(modem))
stopAllSpeakers()