--[[
Simple captcha mod for Minetest.
]]--

-- Helper globals
local DIR = minetest.get_modpath(minetest.get_current_modname())

-- Imports
dofile(DIR.."/pnm.lua")

-- Informational log
local function I(msg) minetest.log("action", "[MOD]minecaptcha: "..msg) end

-- Global colors as bytes
local FORM_NAME = "captcha"
local rng = PcgRandom(os.time())

-- Load basic number textures
local numbers = {}
for i=0, 9 do
    numbers[i] = pnm_read(DIR.."/textures/"..i..".ppm")
end
I("Loaded "..#numbers.." numeric textures.")

-- Generates a random captcha image
local function new_captcha()
    -- Let's grab two numbers first
    local n1 = rng:next(0,9)
    local n2 = rng:next(0,9)
    local n3 = rng:next(0,9)
    local n4 = rng:next(0,9)
    I("Creating captcha n1="..n1..", n2="..n2..", n3="..n3..", n4="..n4)
    -- Record the response for current challenge
    local response = n1..""..n2..""..n3..""..n4
    -- Creates a small in-memory captcha
    local canvas = pnm_new(32, 14)
    pnm_draw(numbers[n1], canvas, 3, 1)
    pnm_draw(numbers[n2], canvas, 2, 8)
    pnm_draw(numbers[n3], canvas, 3, 16)
    pnm_draw(numbers[n4], canvas, 2, 22)
    -- TODO(ronoaldo): add some random noise the the image, like a blur effect
    -- Render the challenge as PNG
    local data = pnm_pixel_as_colors(canvas)
    local texture = "[png:"..minetest.encode_base64(minetest.encode_png(32, 14, data))
    return response, texture
end

local challenges = {}

-- Callback to execute when a new player joins the game.
local function show_captcha_to_player(player)
    local name = player:get_player_name()
    local texture
    -- Save the challenges and send the texture inline as a small PNG file.
    challenges[name], texture = new_captcha()
    I("Generated new captcha for player "..name.." texture => "..texture)
    local fs = "formspec_version[5]"
        .."size[8,4]"
        .."image[0.6,0.9;1.6,1.6;"..texture.."]"
        .."field[2.5,1.3;5.2,1.2;captcha_solution;Type the numbers:;]"
        .."button[5.5,2.9;2.2,0.9;captcha_send;Send]"
    minetest.show_formspec(name, FORM_NAME, fs)
end

-- Callback to execute when a form is submited, parsing the captcha response.
local function on_form_submit(player, formname, fields)
    if formname ~= FORM_NAME then return end
    
    local name = player:get_player_name()
    local solution = fields["captcha_solution"] or ""

    I("Parsing captcha response: "..minetest.write_json(fields))
    if solution ~= challenges[name] then
        I("Invalid solution: "..solution)
        show_captcha_to_player(player)
    else
        I("Valid solution: "..solution)
        challenges[name] = nil
        minetest.close_formspec(name, FORM_NAME)
    end

    return true
end

-- Register callbacks
if minetest.settings:get("minecaptcha.on_joinplayer") then
    I("Showing captcha for every new player")
    minetest.register_on_joinplayer(show_captcha_to_player)
end
if minetest.settings:get("minecaptcha.show_captcha_to_player") then
    I("Showing captcha for each player who joins")
    minetest.register_on_newplayer(show_captcha_to_player)
end
minetest.register_on_player_receive_fields(on_form_submit)

-- We're done, show up on server logs.
I("Mod loaded")