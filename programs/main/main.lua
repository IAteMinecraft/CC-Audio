local basalt = require("basalt")
local pretty = require("cc.pretty")

---------------------------------------

local main = basalt.createFrame()
main:setBackground(colors.black)
    local mainBarContainer       = main:addFrame()
        local titleLabel         = mainBarContainer:addLabel()
        local closeButton        = mainBarContainer:addImage()
    local mainContent            = main:addFrame()
        local rightSideBar       = mainContent:addFrame()
            local refreshButton  = rightSideBar:addButton()
            local audioFilesList = rightSideBar:addList()
        local bottomBar          = mainContent:addFrame()
            local playButton     = bottomBar:addImage()
            local stopButton     = bottomBar:addImage()
            local pauseButton    = bottomBar:addImage()
            local seekSlider     = bottomBar:addSlider()
        local mainTextField      = mainContent:addAudioPlayer()
        local nowPlayingLabel    = mainContent:addLabel()


---------------------------------------

-- Refresh the Audio File List
local function refreshAudioFilesList(list)
    local filesURL = "https://api.github.com/repos/IAteMinecraft/CC-Audio/contents/"
    if not http.checkURL(filesURL) then
        error("HTTP is disabled or URL is incorrect")
        return
    end

    local response, err = http.get(filesURL, {
        ["User-Agent"] = "ICraft/ComputerCraft"
    })
    if not response then
        error("Failed to fetch URL data: " .. (err or "Unknown Error"))
        return
    end

    local body = response.readAll()
    response.close()

    local success, data = pcall(textutils.unserialiseJSON, body)

    if success then
        list:clear()
        for _, fileInfo in ipairs(data) do
            if fileInfo["type"] == "file" and string.match(fileInfo["name"], "%.dfpwm$") then
                list:addItem(fileInfo["name"], colors.gray, colors.white, fileInfo["download_url"])
            end
        end
        list:selectItem(-1)
    end

    return list
end
audioFilesList.refreshAudioFilesList = refreshAudioFilesList

-- Automatically wraps text for labels
local function wrap(label)
    local currentText = label:getText()
    local firstHalf = currentText:sub(1, label:getWidth())
    local secondHalf = currentText:sub(label:getWidth() + 1, -1)

    if currentText:sub(label:getWidth() - 1, label:getWidth()) == " " then
        label:setText(firstHalf .. secondHalf)
    else
        label:setText(firstHalf .. " " .. secondHalf)
    end

    return label
end
nowPlayingLabel.wrap = wrap

---------------------------------------

mainBarContainer
    :setPosition(1, 1)
    :setSize(main:getWidth(), 1)
    :setBackground(colors.gray)
    :setZIndex(1)

mainContent
    :setPosition(1, mainBarContainer:getY() + mainBarContainer:getHeight())
    :setSize(main:getWidth(), main:getHeight() - mainBarContainer:getHeight())
    :setBackground(colors.black)
    :setZIndex(1)

rightSideBar
    :setPosition(
        math.floor(rightSideBar:getParent():getWidth() * (2/3)),
        1
    )
    :setSize(
        math.floor(rightSideBar:getParent():getWidth()/3)+1,
        rightSideBar:getParent():getHeight()
    )
    :setBackground(colors.lightGray)
    :setZIndex(3)

bottomBar
    :setSize(bottomBar:getParent():getWidth() - rightSideBar:getWidth(), 4)
    :setPosition(1, (bottomBar:getParent():getHeight() + bottomBar:getParent():getY()) - (bottomBar:getY() + bottomBar:getHeight()))
    :setBackground(colors.gray)
    :setZIndex(2)

titleLabel
    :setText("Audio Player")
    :setFontSize(1 )
    :setPosition(1, 1)
    :setForeground(colors.white)
    :setBackground(colors.gray)
    :setZIndex(4)

closeButton
    :setImage({
        [1] = {
            {"X", "0", "e"},
        }
    })
    :setSize(1, 1)
    :setPosition(mainBarContainer:getWidth() - closeButton:getWidth()+1, 1)
    :onClick(function()
        mainTextField:_stop()
        basalt.stop()
    end)
    :setZIndex(4)

refreshButton
    :setText("Refresh")
    :setSize(7, 1)
    :setPosition(refreshButton:getParent():getWidth() - 7 - 1, 2)
    :setBackground(colors.gray)
    :onClick(function()
        refreshButton:setBackground(colors.lightBlue)
        refreshAudioFilesList(audioFilesList)
        refreshButton:setBackground(colors.gray)
    end)
    :setZIndex(4)

audioFilesList
    :setPosition(2, 3)
    :setSize(
        audioFilesList:getParent():getWidth()-1-1,
        math.floor(audioFilesList:getParent():getHeight() * (2/3))
    )
    :setForeground(colors.white)
    :setBackground(colors.gray)
    :setScrollable(true)
    :setZIndex(4)
    :refreshAudioFilesList()
    :onSelect(function ()
        if (audioFilesList:getItemIndex() ~= nil and audioFilesList:getItemIndex() ~= -1) then
            nowPlayingLabel:setText("Now playing: " .. audioFilesList:getItem(audioFilesList:getItemIndex()).text):wrap()

            mainTextField:unload()
            mainTextField:setURL(audioFilesList:getItem(audioFilesList:getItemIndex()).args[1])
            --mainTextField:play()
        end
    end)

nowPlayingLabel
    :setText("Now playing: ")
    :setSize(nowPlayingLabel:getParent():getWidth() - rightSideBar:getWidth(), 2)
    :setPosition(1, 1)
    :wrap()
    :setForeground(colors.black)
    :setBackground(colors.white)
    :setZIndex(4)

playButton
    :setImage({
        [1] = {
            {"    ", "    ", "d0dd"},
            {"    ", "    ", "d00d"},
            {"    ", "    ", "d0dd"}
        },
        [2] = {
            {"    ", "    ", "5055"},
            {"    ", "    ", "5005"},
            {"    ", "    ", "5055"}
        }
    })
    :setSize(4, 3)
    :setPosition(
        (math.floor(playButton:getParent():getWidth()/2)) - 4,
        2
    )
    :setZIndex(4)
    :onClick(function()
        playButton:selectFrame(2)

        mainTextField:play()
    end)
    :onClickUp(function()
        playButton:selectFrame(1)
    end)

stopButton
    :setImage({
        [1] = {
            {"   ", "   ", "eee"},
            {"   ", "   ", "e0e"},
            {"   ", "   ", "eee"}
        },
        [2] = {
            {"   ", "   ", "111"},
            {"   ", "   ", "101"},
            {"   ", "   ", "111"}
        }
    })
    :setSize(3, 3)
    :setPosition(
        (math.floor(stopButton:getParent():getWidth()/2) + math.floor(stopButton:getWidth()/2)),
        2
    )
    :setZIndex(4)
    :onClick(function()
        stopButton:selectFrame(2)

        mainTextField:unload()
        nowPlayingLabel:setText("Now playing: ")
        audioFilesList:selectItem(-1)
    end)
    :onClickUp(function()
        stopButton:selectFrame(1)
    end)

pauseButton
    :setImage({
        [1] = {
            {"     ", "     ", "b0b0b"},
            {"     ", "     ", "b0b0b"},
            {"     ", "     ", "b0b0b"}
        },
        [2] = {
            {"     ", "     ", "30303"},
            {"     ", "     ", "30303"},
            {"     ", "     ", "30303"}
        }
    })
    :setSize(5, 3)
    :setPosition(
        (math.floor(pauseButton:getParent():getWidth()/2)) + 5,
        2
    )
    :setZIndex(4)
    :onClick(function()
        pauseButton:selectFrame(2)

        mainTextField:stop()
    end)
    :onClickUp(function()
        pauseButton:selectFrame(1)
    end)

seekSlider
    :setSize(seekSlider:getParent():getWidth() - 2, 1)
    :setPosition(2, 1)
    :setBarType("horizontal")
    :setSymbolBG(colors.white)
    :setZIndex(4)
    :onChange(function (self, event, value)
        --mainTextField:setChunkPos(value)
        if (not (value == mainTextField:getChunkPos())) then
            mainTextField:stopSpeakers(false)
            --mainTextField:reload()
            mainTextField:_setChunkPos(math.floor(value), false)
            mainTextField:continuePlay()
        end

        seekSlider:setIndex(1 + ((seekSlider:getValue() - 1) / (seekSlider:getMaxValue() - 1)) * (seekSlider:getWidth() - 1))
    end)

mainTextField
    :setSize(
        mainContent:getWidth()  - rightSideBar:getWidth(),
        mainContent:getHeight() - bottomBar:getHeight() -  mainBarContainer:getY() - mainBarContainer:getHeight()
    )
    :setPosition(1, mainBarContainer:getY() + mainBarContainer:getHeight())
    :setBackground(colors.black)
    :setZIndex(3)
    :onChunkChange(function (self, chunkPos)
        seekSlider:setValue(chunkPos)
        seekSlider:draw()
    end)
    :onChunksCountChange(function (self, newChunksCount)
        seekSlider:setMaxValue(newChunksCount)
    end)

main:addThread():start(function ()
    mainTextField:setup()
end)

basalt.autoUpdate()