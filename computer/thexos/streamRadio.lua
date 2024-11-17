-- Import the DFPWM module
local dfpwm = require("cc.audio.dfpwm")

local speaker = peripheral.find("speaker")
if not speaker then
    print("Speaker not found.")
    return
end

-- Replace with your server's IP address and port
local server_ip = "localhost"
local port = 8765
local url = "ws://" .. server_ip .. ":" .. port

-- Function to read user input for stream URL
local function getStreamURL()
    print("Enter the radio stream URL:")
    local stream_url = read()
    return stream_url
end

local stream_url = getStreamURL()

-- Connect to the server
local ws, err = http.websocket(url)
if not ws then
    print("Failed to connect:", err)
    return
end

-- Send the stream URL to the server
local request = { stream_url = stream_url }
ws.send(textutils.serializeJSON(request))

print("Connected to the streaming server.")

local audioBuffer = {}
local BUFFER_SIZE = 10  -- Adjust buffer size as needed

-- Create a DFPWM decoder
local decoder = dfpwm.make_decoder()

-- Function to play audio from the buffer
local function playAudio()
    while true do
        if #audioBuffer > 0 then
            local data = table.remove(audioBuffer, 1)
            print("Playing audio chunk")
            -- Decode the DFPWM data
            local success, decoded_or_error = pcall(decoder, data)
            if success then
                local decoded = decoded_or_error
                -- Play the decoded audio
                local play_success, play_err = pcall(function()
                    while not speaker.playAudio(decoded) do
                        os.pullEvent("speaker_audio_empty")
                    end
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
    while true do
        local data, err = ws.receive()
        if data then
            print("Received data chunk")
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
            break
        end
    end
end

print("Starting audio playback...")
parallel.waitForAny(playAudio, receiveAudio)

print("Audio playback ended.")
ws.close()