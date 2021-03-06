--[[
Dead simple PPM image library in Lua.

Usage:

    local PPM = require("ppm")

    -- Creates an empty image
    local canvas = PPM.new(16, 16)

    -- Read an image from disk
    local src = PPM.read("src.ppm")

    -- Draw one image over another
    PPM.draw(src, canvas, 1, 1)

    -- Encode as string
    local raw_data = PPM.encode(canvas)

    -- Write the data to file
    PPM.write(canvas, "dst.ppm")

    -- Convert the 2D pixel array into 1D array.
    PPM.pixel_array(canvas)

]]--
if not MOD_DIR then
    MOD_DIR = minetest.get_modpath(minetest.get_current_modname())
end
local PNG = dofile(MOD_DIR.."/lib/pngencoder.lua")

local function ppm_new(width, height)
    local ppm = {}
    ppm.width = width
    ppm.height = height
    ppm.max_color = 255
    ppm.pixels = {}
    for i=1, height do
        ppm.pixels[i] = {}
        for j=1, width do
            ppm.pixels[i][j] = {a=255, r=255, g=255, b=255}
        end
    end
    return ppm
end

local function ppm_info(ppm)
    local count = 0
    for i=1, #ppm.pixels do
        local row = ppm.pixels[i]
        for j=1, #row do
            count = count+1
        end
    end
    print("PPM Image (P3 format) (w="..ppm.width..",h="..ppm.height
        ..",max_color="..ppm.max_color..") and "..count.." pixel color values")
end

local function ppm_read(file_path)
    local fd = io.open(file_path, "r")
    if fd then
        local header = fd:read("*l")
        if header:match("P3") == "P3" then
            -- PPM ASCII file, let's parse it after the first two initial bytes
            fd:seek("set", 2)
            local raw_data = {}
            local count = 0
            for line in fd:lines("*l") do
                -- Remove everything after the comment mark
                line = line:gsub("(#.*)", "")
                -- Combines multiple whitespaces into single one
                line = line:gsub("[ \t\n]+", " ")
                -- Merge all values including the first three numbers
                for n in line:gmatch("%d+") do
                    count = count+1
                    raw_data[count] = n
                end
            end
            if #raw_data < 3 then
                error("Missing PPM fields WIDTH, HEIGHT and MAX_COLOR")
            end
            local width, height, max_color
            -- Extract the first values to compute the pixel data
            width = tonumber(table.remove(raw_data, 1))
            height = tonumber(table.remove(raw_data, 1))
            max_color = table.remove(raw_data, 1)
            -- Build the pixel data as expected by Minetest
            local pixels = {}
            for i=1,height do
                pixels[i] = {}
                for j=1,width do
                    -- TODO(ronoaldo): fix color space if < 255
                    local r, g, b
                    r = table.remove(raw_data, 1)
                    g = table.remove(raw_data, 1)
                    b = table.remove(raw_data, 1)
                    pixels[i][j] = {a=255, r=r, g=g, b=b}
                end
            end
            return {
                width = width,
                height = height,
                max_color = max_color,
                pixels = pixels,
            }
        else
            error("File "..file_path.." is not a valid PPM ASCII image (P3 header not found)")
        end
    else
        error("Unable to open file for reading: "..file_path)
    end
end

local function ppm_draw(ppm, src, x, y)
    if not src.pixels then error("Invalid ppm for src") end
    if not ppm.pixels then error("Invalid ppm for dst") end
    if not x then x = 0 end
    if not y then y = 0 end

    for i=1, src.height do
        for j=1, src.width do
            local px = src.pixels[i][j]
            ppm.pixels[i+x][j+y] = px
        end
    end
end

local function ppm_encode(ppm)
    local buff = "P3"
    buff = buff .. " "..ppm.width.." "..ppm.height.." "..ppm.max_color.."\n"
    for i=1,ppm.height do
        for j=1,ppm.width do
            local px = ppm.pixels[i][j]
            if px then
                local r, g, b = px.r, px.g, px.b
                buff = buff .. " "..r.." "..g.." "..b
            end
        end
        buff = buff .. "\n"
    end
    return buff
end

local function ppm_write(ppm, file_path)
    local fd = io.open(file_path, "w+")
    if fd then
        local data = ppm_encode(ppm)
        fd:write(data)
        fd:close()
    else
        error("Error opening file for write: "..file_path)
    end
end

local function ppm_pixel_as_colors(ppm)
    local buff = {}
    for i=1, ppm.height do
        for j=1, ppm.width do
            table.insert(buff, ppm.pixels[i][j])
        end
    end
    return buff
end

local function ppm_encode_png(src)
    local pixels = ppm_pixel_as_colors(src)
    local png = PNG(src.width, src.height)
    for i, px in ipairs(pixels) do
        assert(px.r ~= nil)
        assert(px.g ~= nil)
        assert(px.b ~= nil)
        png:write({px.r, px.g, px.b})
    end
    if not png.done then
        error "Unexpected error: png not done encoding"
    end
    return png.output
end

local function ppm_write_png(ppm, file_path)
    local fd = io.open(file_path, 'wb')
    if fd then
        local encoded_png = ppm_encode_png(ppm)
        for _, b in pairs(encoded_png) do
            fd:write(b)
        end
        fd:close()
    else
        error("Error opening file for write")
    end
end

-- Exported PPM functions
return {
    new = ppm_new,
    info = ppm_info,
    read = ppm_read,
    draw = ppm_draw,
    pixel_array = ppm_pixel_as_colors,
    encode = ppm_encode,
    encode_png = ppm_encode_png,
    write = ppm_write,
    write_png = ppm_write_png,
}