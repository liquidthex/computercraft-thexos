-- update.lua
-- Update script for ComputerCraft using GitHub API to download all files

-- Configuration
local githubUser = 'liquidthex'
local githubRepo = 'computercraft-thexos'
local githubBranch = 'main'  -- Change if using a different branch
local folderPath = 'computer' -- Path to the 'computer' folder in your repo

-- Ensure HTTP API is enabled
if not http then
    error('HTTP API is not enabled in ComputerCraft. Enable it by setting "http_enable = true" in the mod config.')
end

-- Function to recursively download files from GitHub
local function downloadFiles(path, savePath)
    local apiURL = 'https://api.github.com/repos/' .. githubUser .. '/' .. githubRepo .. '/contents/' .. path .. '?ref=' .. githubBranch
    local response = http.get(apiURL)
    if not response then
        error('Failed to fetch directory listing for ' .. path)
    end

    local jsonResponse = response.readAll()
    response.close()

    -- Parse JSON response
    local content = textutils.unserializeJSON(jsonResponse)
    if not content then
        error('Failed to parse JSON for ' .. path)
    end

    for _, item in ipairs(content) do
        if item.type == 'file' then
            -- Download the file
            local fileURL = item.download_url
            local relativePath = savePath .. '/' .. item.name

            -- Remove leading slashes
            relativePath = relativePath:gsub('^/', '')

            local fileResponse = http.get(fileURL)
            if not fileResponse then
                error('Failed to download ' .. item.path)
            end

            -- Create necessary directories
            local dir = fs.getDir(relativePath)
            if dir and dir ~= '' then
                fs.makeDir(dir)
            end

            -- Save the file
            local file = fs.open(relativePath, 'w')
            file.write(fileResponse.readAll())
            file.close()
            fileResponse.close()
            print('Downloaded ' .. relativePath)
        elseif item.type == 'dir' then
            -- Recursively download the directory
            downloadFiles(item.path, savePath .. '/' .. item.name)
        end
    end
end

-- Main update logic

-- Delete existing files before downloading new ones
local function deleteDirectory(path)
    if fs.exists(path) then
        fs.delete(path)
    end
end

-- Delete 'thexos' directory
deleteDirectory('thexos')

-- Download files starting from the 'computer' directory
downloadFiles(folderPath, '')

print('Update complete.')