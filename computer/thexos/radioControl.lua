-- radioControl.lua

-- Table of predefined stations
local stations = {
    {name = "Station 1", url = "http://example.com/stream1"},
    {name = "Station 2", url = "http://example.com/stream2"},
    -- Add or remove stations here
}

-- Peripheral setup
local monitor = peripheral.find("monitor")
if not monitor then
    error("Monitor not found!")
end
monitor.setTextScale(0.5)
local monWidth, monHeight = monitor.getSize()

-- Variables
local isPlaying = false
local currentStation = nil
local running = false

-- Functions

local function drawInterface()
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.white)
    monitor.write("=== Radio Control ===")
    monitor.setCursorPos(1, 3)
    monitor.write("Status: ")
    if isPlaying then
        monitor.setTextColor(colors.green)
        monitor.write("Playing - " .. currentStation.name)
    else
        monitor.setTextColor(colors.red)
        monitor.write("Stopped")
    end
    monitor.setTextColor(colors.white)
    
    -- Draw station buttons
    local y = 5
    for i, station in ipairs(stations) do
        monitor.setCursorPos(1, y)
        monitor.write("[" .. station.name .. "]")
        y = y + 2
    end
    -- Draw Custom URL button
    monitor.setCursorPos(1, y)
    monitor.write("[Custom URL]")
    y = y + 2
    -- Draw Stop button
    monitor.setCursorPos(1, y)
    monitor.write("[Stop]")
end

local function playStation(station)
    if isPlaying then
        running = false
        isPlaying = false
        currentStation = nil
        -- Wait a moment for the streaming to stop
        os.sleep(0.1)
    end
    currentStation = station
    isPlaying = true
    running = true
    drawInterface()
end

local function stopPlaying()
    if isPlaying then
        running = false
        isPlaying = false
        currentStation = nil
        drawInterface()
    end
end

local function handleMonitorTouch(x, y)
    local index = math.floor((y - 5) / 2) + 1
    if index >= 1 and index <= #stations then
        playStation(stations[index])
    elseif index == #stations + 1 then
        promptForURL()
    elseif index == #stations + 2 then
        stopPlaying()
    end
end

local function promptForURL()
    term.clear()
    term.setCursorPos(1, 1)
    term.write("Enter Radio URL: ")
    local url = read()
    if url and url ~= "" then
        local customStation = {name = "Custom Station", url = url}
        playStation(customStation)
    else
        drawInterface()
    end
end

local function streamAudio()
    while true do
        if running and currentStation then
            -- Import the DFPWM module
            local dfpwm = require("cc.audio.dfpwm")
            
            -- Find all speakers
            local speakers = { peripheral.find("speaker") }
            if #speakers == 0 then
                print("No speakers found.")
                running = false
                isPlaying = false
                currentStation = nil
                drawInterface()
                return
            end
            
            -- Use provided server_ip:port or default to localhost:8765
            local server_ip_port = "localhost:8765"  -- Adjust as needed
            local url = "ws://" .. server_ip_port
            
            -- Connect to the server
            local ws, err = http.websocket(url)
            if not ws then
                print("Failed to connect to WebSocket server:", err)
                running = false
                isPlaying = false
                currentStation = nil
                drawInterface()
                return
            end
            
            -- Send the stream URL to the server
            local request = { stream_url = currentStation.url }
            ws.send(textutils.serializeJSON(request))
            
            local audioBuffer = {}
            local BUFFER_SIZE = 10  -- Adjust buffer size as needed
            
            -- Create a DFPWM decoder
            local decoder = dfpwm.make_decoder()
            
            -- Function to play audio to all speakers
            local function playToSpeakers(data)
                local pending = {}
                for _, speaker in ipairs(speakers) do
                    pending[speaker] = data
                end
                while next(pending) and running do
                    for speaker, data in pairs(pending) do
                        if speaker.playAudio(data) then
                            pending[speaker] = nil
                        end
                    end
                    if next(pending) then
                        os.pullEvent("speaker_audio_empty")
                    end
                end
            end
            
            -- Function to play audio from the buffer
            local function playAudio()
                while running do
                    if #audioBuffer > 0 then
                        local data = table.remove(audioBuffer, 1)
                        -- Decode the DFPWM data
                        local success, decoded_or_error = pcall(decoder, data)
                        if success then
                            local decoded = decoded_or_error
                            -- Play the decoded audio
                            local play_success, play_err = pcall(function()
                                playToSpeakers(decoded)
                            end)
                            if not play_success then
                                print("Error playing audio:", play_err)
                            end
                        else
                            print("Error decoding audio:", decoded_or_error)
                        end
                    else
                        os.sleep(0.05)
                    end
                end
            end
            
            -- Function to receive audio data
            local function receiveAudio()
                while running do
                    local data, err = ws.receive()
                    if data then
                        table.insert(audioBuffer, data)
                        -- Keep buffer from growing indefinitely
                        if #audioBuffer > BUFFER_SIZE then
                            table.remove(audioBuffer, 1)
                        end
                    else
                        if err then
                            print("WebSocket receive error:", err)
                        else
                            print("WebSocket closed by server.")
                        end
                        running = false
                        break
                    end
                end
            end
            
            -- Start playing audio and receiving data in parallel
            parallel.waitForAny(playAudio, receiveAudio)
            
            -- Ensure the WebSocket is closed
            if ws and not ws.isClosed() then
                ws.close()
            end
            
            -- If streaming stopped, reset variables
            if running == false then
                isPlaying = false
                currentStation = nil
                drawInterface()
            end
        else
            os.sleep(0.1)
        end
    end
end

-- Main Program
term.clear()
term.setCursorPos(1, 1)
drawInterface()

-- Event Loop
local function eventLoop()
    while true do
        local event, param1, param2, param3 = os.pullEvent()
        if event == "monitor_touch" then
            handleMonitorTouch(param2, param3)
        elseif event == "key" and keys.getName(param1) == "enter" then
            promptForURL()
            drawInterface()
        end
    end
end

-- Run the event loop and streaming in parallel
parallel.waitForAny(eventLoop, streamAudio)
