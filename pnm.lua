--[[
Dead simple PPM image library to generate the captcha.
]]--

function pnm_new(width, height)
    local pnm = {}
    pnm.width = width
    pnm.height = height
    pnm.max_color = 255
    pnm.pixels = {}
    for i=1, height do
        pnm.pixels[i] = {}
        for j=1, width do
            pnm.pixels[i][j] = {a=255, r=255, g=255, b=255}
        end
    end
    return pnm
end

function pnm_info(pnm)
    local count = 0
    for i=1, #pnm.pixels do
        local row = pnm.pixels[i]
        for j=1, #row do
            count = count+1
        end
    end
    print("PPM Image (P3 format) (w="..pnm.width..",h="..pnm.height
        ..",max_color="..pnm.max_color..") and "..count.." pixel color values")
end

function pnm_read(file_path)
    local fd = io.open(file_path, "r")
    if fd then
        local header = fd:read("*l")
        if header:match("P3") == "P3" then
            -- PPM ASCII file, let's parse it after the first two initial bytes
            fd:seek("set", 2)
            local raw_data = {}
            local width, height, max_color, count = 0, 0, 0, 0
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
            -- Extract the first values to compute the pixel data
            width = table.remove(raw_data, 1)
            height = table.remove(raw_data, 1)
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

function pnm_draw(src, dst, x, y)
    if not src.pixels then error("Invalid PNM for src") end
    if not dst.pixels then error("Invalid PNM for dst") end
    if not x then x = 0 end
    if not y then y = 0 end

    for i=1, src.height do
        for j=1, src.width do
            local px = src.pixels[i][j]
            dst.pixels[i+x][j+y] = px
        end
    end
end

function pnm_encode(src)
    local buff = "P3"
    buff = buff .. " "..src.width.." "..src.height.." "..src.max_color.."\n"
    for i=1,src.height do
        for j=1,src.width do
            local px = src.pixels[i][j]
            if px then
                local r, g, b = px.r, px.g, px.b
                buff = buff .. " "..r.." "..g.." "..b
            end
        end
        buff = buff .. "\n"
    end
    return buff
end

function pnm_write(src, file_path)
    local fd = io.open(file_path, "w+")
    if fd then
        local data = pnm_encode(src)
        fd:write(data)
        fd:close()
    else
        error("Error opening file for write: "..file_path)
    end
end

function pnm_pixel_as_colors(src)
    local buff = {}
    for i=1, src.height do
        for j=1, src.width do
            table.insert(buff, src.pixels[i][j])
        end
    end
    return buff
end