--[[
Simple captcha mod for Minetest.
]]--

-- Helper globals
local DIR = minetest.get_modpath(minetest.get_current_modname())

-- Imports
local PPM = dofile(DIR.."/ppm.lua")

-- Informational log
local function I(msg) minetest.log("action", "[MOD]minecaptcha: "..msg) end
local function D(msg) minetest.log("verbose", "[MOD]minecaptcha: "..msg) end

-- Global colors as bytes
local FORM_NAME = "captcha"
local rng = PcgRandom(os.time())

-- Settings
local cfg = {
    -- Enabled triggers
    on_joinplayer = minetest.settings:get_bool("minecaptcha.on_joinplayer") or false,
    on_newplayer = minetest.settings:get_bool("minecaptcha.on_newplayer") or false,
    -- Enabled actions
    on_newplayer_remove_accounts = minetest.settings:get("minecaptcha.on_newplayer_remove_accounts") or false,
    enable_ban = minetest.settings:get_bool("minecaptcha.enable_ban") or false,
    -- Privileges to manage
    managed_privs = minetest.settings:get("minecaptcha.managed_privs") or "shout, interact, basic_privs",
}
I("Loaded settings: "..dump(cfg))

-- Load basic number textures
local numbers = {}
for i=0, 9 do
    numbers[i] = PPM.read(DIR.."/textures/"..i..".ppm")
end
D("Loaded "..#numbers.." numeric textures.")

-- Generates a random captcha image
local function new_captcha()
    -- Let's grab random numbers first
    local n1 = rng:next(0,9)
    local n2 = rng:next(0,9)
    local n3 = rng:next(0,9)
    local n4 = rng:next(0,9)
    D("Creating captcha n1="..n1..", n2="..n2..", n3="..n3..", n4="..n4)
    -- Record the response for current challenge
    local response = n1..""..n2..""..n3..""..n4
    -- Creates a small in-memory captcha
    local canvas = PPM.new(32, 14)
    PPM.draw(numbers[n1], canvas, 3, 1)
    PPM.draw(numbers[n2], canvas, 2, 8)
    PPM.draw(numbers[n3], canvas, 3, 16)
    PPM.draw(numbers[n4], canvas, 2, 22)
    -- TODO(ronoaldo): add some random noise the the image, like a blur effect
    -- Render the challenge as PNG
    local data = PPM.pixel_array(canvas)
    local texture = "[png:"..minetest.encode_base64(minetest.encode_png(32, 14, data))
    return response, texture
end

-- Sends a text message to the player
local function show_message_to_player(player, msg)
    minetest.chat_send_player(player:get_player_name(), "[minecaptcha] "..msg)
end

-- Sends an error message to the player
local function show_error_to_player(player, msg)
    show_message_to_player(player, minetest.colorize("#F00", msg))
end

-- Sends a success message to the player
local function show_success_to_player(player, msg)
    show_message_to_player(player, minetest.colorize("#0F0", msg))
end

local challenges = {}

-- Callback to execute when a new player joins the game.
local function show_captcha_to_player(player)
    local name = player:get_player_name()
    local texture
    -- Save the challenges and send the texture inline as a small PNG file.
    challenges[name], texture = new_captcha()
    D("Generated new captcha for player "..name.." texture => "..texture)
    show_message_to_player(player, "Are you a robot? Solve the captcha before interacting with the server.")
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

    I("Parsing captcha response from "..name..": "..minetest.write_json(fields))
    if solution ~= challenges[name] then
        I("Player "..name.." sent an invalid solution: "..solution)
        show_error_to_player(player, "The numbers are wrong!")
        show_captcha_to_player(player)
    else
        I("Player "..name.." sent a valid solution: "..solution)
        show_success_to_player(player, "You entered the correct numbers!")
        challenges[name] = nil
        minetest.close_formspec(name, FORM_NAME)
    end

    return true
end

-- Register callbacks
if cfg.on_newplayer then
    I("Showing captcha for every new player")
    minetest.register_on_joinplayer(show_captcha_to_player)
end
if cfg.on_joinplayer then
    I("Showing captcha for each player who joins")
    minetest.register_on_newplayer(show_captcha_to_player)
end
minetest.register_on_player_receive_fields(on_form_submit)

-- We're done, show up on server logs.
I("Mod loaded")
