-- Simple captcha mod for Minetest.

-- Helper globals
local MOD_DIR = minetest.get_modpath(minetest.get_current_modname())
local FORM_NAME = "captcha"
local rng = PcgRandom(os.time())

-- Imports
local PPM = dofile(MOD_DIR.."/lib/ppm.lua")

-- Informational log
local function I(msg) minetest.log("action", "[MOD]minecaptcha: "..msg) end
local function D(msg) minetest.log("verbose", "[MOD]minecaptcha: "..msg) end

-- Settings
local cfg = {
    -- Enabled triggers
    on_joinplayer = minetest.settings:get_bool("minecaptcha.on_joinplayer") or false,
    on_newplayer = minetest.settings:get_bool("minecaptcha.on_newplayer") or false,
    -- Enabled actions
    on_newplayer_remove_accounts = minetest.settings:get_bool("minecaptcha.on_newplayer_remove_accounts") or false,
    enable_ban = minetest.settings:get_bool("minecaptcha.enable_ban") or false,
    -- Privileges to manage
    managed_privs = minetest.settings:get("minecaptcha.managed_privs") or "shout, interact, basic_privs",
}
I("Loaded settings: "..dump(cfg))

-- Load basic number textures
local numbers = {}
for i=0, 9 do
    numbers[i] = PPM.read(MOD_DIR.."/textures/"..i..".ppm")
end
D("Loaded "..#numbers.." numeric textures.")

-- Generates a random captcha image
local function async_make_captcha(callback)
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
    PPM.draw(canvas, numbers[n1], 3, 1)
    PPM.draw(canvas, numbers[n2], 2, 8)
    PPM.draw(canvas, numbers[n3], 3, 16)
    PPM.draw(canvas, numbers[n4], 2, 22)
    -- TODO(ronoaldo): add some random noise the the image, like a blur effect
    -- Render the challenge as PNG
    D("Using dynamic_media_add to send captcha image to client.")
    -- Save temp file to world dir
    local texture = "captcha_".. rng:next(1000, 9999)..".png"
    local temp_file = minetest.get_worldpath().."/"..texture
    PPM.write_png(canvas, temp_file)
    local options = {
        filepath = temp_file,
        ephemeral = true,
    }
    minetest.dynamic_add_media(options, function(name)
        D("Showing captcha to "..name)
        callback(response, texture)
        D("Removing temporary file from server, "..name.." already downloaded it")
        os.remove(temp_file)
    end)
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
    async_make_captcha(function(challenge, texture)
        challenges[name] = challenge
        D("Generated new captcha for player "..name.." texture => "..texture)
        show_message_to_player(player, "Are you a robot? Solve the captcha before interacting with the server.")
        local fs = "formspec_version[5]"
            .."size[8,4]"
            .."image[0.6,0.9;1.6,1.6;"..texture.."]"
            .."field[2.5,1.3;5.2,1.2;captcha_solution;Type the numbers:;]"
            .."button[5.5,2.9;2.2,0.9;captcha_send;Send]"
        minetest.show_formspec(name, FORM_NAME, fs)
    end)
end

local function manage_privileges(name, enable)
    local managed_privs = minetest.string_to_privs(cfg.managed_privs)
    D("Managed privs: "..cfg.managed_privs.. " enabling? "..dump(enable))
    local player_privs = minetest.get_player_privs(name)
    D("Current privs"..dump(player_privs))
    local need_to_set = false
    for k, v in pairs(managed_privs) do
        if enable then
            if not player_privs[k] then
                D("> Granting "..k)
                player_privs[k] = true
                need_to_set = true
            end
        else
            if player_privs[k] then
                D("> Revoking "..k)
                player_privs[k] = nil
                need_to_set = true
            end
        end
    end
    if need_to_set then
        D("Updating player privs (privs changed) ...")
        minetest.set_player_privs(name, player_privs)
        D("Managed privs revoked")
    end
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
        D("Setting player privs")
        manage_privileges(name, true)
        D("Cleaning up server variables")
        player:get_meta():set_int("captcha_solved", 1)
        challenges[name] = nil
        show_success_to_player(player, "You entered the correct numbers!")
        minetest.close_formspec(name, FORM_NAME)
    end

    return true
end

local function on_authplayer(name, ip, is_success)
    if not is_success then
        return
    end

    local player = minetest.get_player_by_name(name)
    if not player then return end

    D("Player "..name.." is trying to join")
    if cfg.on_joinplayer then
        D("Revoking privileges before join...")
        manage_privileges(name, false)
        player:get_meta():set_int("captcha_solved", 0)
    end

    if cfg.on_newplayer then
        if player:get_meta():get_int("captcha_solved") == 0 then
            D("Player has not solved the captcha yet, revoking privs")
            manage_privileges(name, false)
        end
    end
end

local function on_leaveplayer(player, timed_out)
    if not player then return end
    local name = player:get_player_name()
    D("Player "..name.." is leaving, running checks")
    local m = player:get_meta()
    D("Player meta: "..dump(m:to_table()))
    if cfg.on_joinplayer or cfg.on_newplayer then
        if cfg.enable_ban then
            D("Checking if we need to ban the player")
            if m:get_int("captcha_solved") == 0 then
                D("Captcha not solved, banning player")
                if not minetest.ban_player(name) then
                    D("Failed to ban player")
                end
            end
        end
    end
    if cfg.on_newplayer and cfg.on_newplayer_remove_accounts then
        D("Checking if we need to remove the account")
        if m:get_int("captcha_newplayer") == 1 then
            D("Is new player, checking if captcha was solved")
            if m:get_int("captcha_solved") == 0 then
                I("Removing new player account who hasn't solved the captcha: '"..name.."'")
                minetest.after(1, function()
                    local res = minetest.remove_player(name)
                    I("Player account '"..name.."' removal result: "..dump(res))
                end)
            end
        end
    end
end

local function on_joinplayer(player)
    D("Showing captcha for player that just joined the server")
    show_captcha_to_player(player)
end

local function on_newplayer(player)
    D("Player "..player:get_player_name().." is a new player")
    player:get_meta():set_int("captcha_newplayer", 1)
    show_captcha_to_player(player)
end

-- Register callbacks
if cfg.on_newplayer then
    I("Showing captcha for every new player")
    minetest.register_on_newplayer(on_newplayer)
end
if cfg.on_joinplayer then
    I("Showing captcha for each player who joins")
    minetest.register_on_joinplayer(on_joinplayer)
end
minetest.register_on_authplayer(on_authplayer)
minetest.register_on_leaveplayer(on_leaveplayer)
minetest.register_on_player_receive_fields(on_form_submit)

-- We're done, show up on server logs.
I("Mod loaded")
