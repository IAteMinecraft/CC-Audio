local VERSION = "1.1.0"

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
local speakers = {peripheral.find("speaker")} or error("No speakers found", 0)
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

local CHANNEL = 62
local PROTOCOL = "audio_playback"
local PING = "ping"
local PONG = "pong"
local CHUNK = "chunk"
local ACK = "ack"
local STOP = "stop"

rednet.open(peripheral.getName(modem), CHANNEL)

local audioQueue = {}

local function playBuffer(buffer)
    for _, speaker in ipairs(speakers) do
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
        -- Wait for this speaker to finish
        --os.pullEvent("speaker_audio_empty")
    end
end

local function audioPlayer()
    while true do
        if #audioQueue > 0 then
            local item = table.remove(audioQueue, 1)
            local sender, data, chunk_id = item[1], item[2], item[3]
            local buffer = decoder(data)

            print("Computer " .. sender .. " requested Chunk: " .. chunk_id)

            playBuffer(buffer)

            print("Sending Acknowledgement with ID: " .. chunk_id)
            rednet.send(sender, {command = ACK, chunk_id = chunk_id}, PROTOCOL)
            print("Acknowledgement sent\n")
        else
            os.pullEvent("audio_queue")
        end
    end
end

local function main()
    while true do
        local sender, message = rednet.receive(PROTOCOL)
        if message.command == PING then
            print("Ping received from computer: " .. sender)
            rednet.send(sender, {command = PONG}, PROTOCOL)
            print("Sending Pong")

        elseif message.command == CHUNK then
            table.insert(audioQueue, {sender, message.data, message.chunk_id})
            os.queueEvent("audio_queue")
        elseif message.command == STOP then
            print("Stopping playback")
            for _, speaker in ipairs(speakers) do speaker.stop() end
            audioQueue = {}  -- Clear queue
        end
    end
end

print("Ready...")

parallel.waitForAny(main, audioPlayer)