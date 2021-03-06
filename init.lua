-- Simple captcha mod for Minetest.

-- Helper globals
local MOD_DIR = minetest.get_modpath(minetest.get_current_modname())
local FORM_NAME = "captcha"
local rng = PcgRandom(os.time())

-- Imports
local PPM = dofile(MOD_DIR.."/lib/ppm.lua")

-- Informational log
local function _log_prefix(msg)
	local buff = ""
	for l in msg:gmatch("[^\r\n]+") do
		buff = buff..l.." "
	end
	return "[MOD]minecaptcha: "..buff
end
local function I(msg) minetest.log("action", _log_prefix(msg)) end
local function D(msg) minetest.log("verbose", _log_prefix(msg)) end

-- Settings
local cfg = {
	-- Enabled triggers
	on_joinplayer = minetest.settings:get_bool("minecaptcha.on_joinplayer") or false,
	on_newplayer = minetest.settings:get_bool("minecaptcha.on_newplayer") or true,
	-- Enabled actions
	on_newplayer_remove_accounts = minetest.settings:get_bool("minecaptcha.on_newplayer_remove_accounts") or true,
	enable_ban = minetest.settings:get_bool("minecaptcha.enable_ban") or false,
	-- Before and after privs
	privs_during = minetest.settings:get("minecaptcha.privs_during_captcha") or "",
	privs_after = minetest.settings:get("minecaptcha.privs_on_success") or "",
	-- Time limit before kicking player
	time_limit = tonumber(minetest.settings:get("minecaptcha.time_limit") or 300)
}

-- Ranks settings
-- Using this method, lua will validate all conditions are nonzero and
--    non-nil and set the variable to the result of the last expression
local ranks = minetest.settings:get_bool("minecaptcha.use_ranks") and minetest.get_modpath("ranks") and ranks

if ranks then
	I("Ranks detected and support enabled!")
	if cfg.privs_during == "" then
		ranks.register("minecaptcha_none", {
			strict_privs = true,
			revoke_extra = true,
			privs = {}
		})
		cfg.privs_during = "minecaptcha_none"
	end
	cfg.bypass_ranks = {}
	local bypass = minetest.settings:get("minecaptcha.bypass_ranks")
	if bypass and bypass ~= "" then
		for str in string.gmatch(bypass, "([^,]+)") do
			local r = str:trim()
			D("> Rank "..r.." can bypass captcha")
			cfg.bypass_ranks[r] = true
		end
	end
else
	if cfg.privs_during then cfg.privs_during = minetest.string_to_privs(cfg.privs_during) end
	if cfg.privs_after then cfg.privs_after = minetest.string_to_privs(cfg.privs_after) end
end

-- Split bypass_users
cfg.bypass_users = {}
local bypass = minetest.settings:get("minecaptcha.bypass_users")
if bypass and bypass ~= "" then
	for str in string.gmatch(bypass, "([^,]+)") do
		local p = str:trim()
		D("> User "..p.." can bypass captcha")
		cfg.bypass_users[p] = true
	end
end

I("Loaded settings: "..dump(cfg))

-- If privs_after is empty then we need to store privs/rank while waiting for captcha verifications

local player_privs
if cfg.privs_after == "" then
	D("Creating table to hold player privs during captcha verifications")
	player_privs = {}
end

-- Load basic number textures
local numbers = {}
for i=0, 9 do
    numbers[i] = PPM.read(MOD_DIR.."/ppm-textures/"..i..".ppm")
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

local function validate_storage(name, i)
	if minetest.get_player_ip(name) == nil then
		player_privs[name] = nil
	else
		if i < 30 then	-- Give up after 300 seconds
			minetest.after(10, validate_storage, i+1)
		end
	end
end

local function manage_privileges(name, enable)
	D("managing privs for "..name)
	if ranks then
		D("using ranks, enable is "..tostring(enable))
		if enable then
			if player_privs and player_privs[name] then
				ranks.set_rank(name, player_privs[name])
				player_privs[name] = nil
			else
				ranks.set_rank(name, cfg.privs_after)
			end
		else
			if player_privs then
				player_privs[name] = ranks.get_rank(name)
				minetest.after(10, validate_storage, 0)
			end
			ranks.set_rank(name, cfg.privs_during)
		end
	else
		D("without ranks, enable is "..tostring(enable))
		if enable then
			if player_privs and player_privs[name] then
				minetest.set_player_privs(name, player_privs[name])
				player_privs[name] = nil
			else
				minetest.set_player_privs(name, cfg.privs_after)
			end
		else
			if player_privs then
				player_privs[name] = minetest.get_player_privs(name)
				minetest.after(10, validate_storage, 0)
			end
			minetest.set_player_privs(name, cfg.privs_during)
		end
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
		local meta = player:get_meta()
		meta:set_int("captcha_solved", 1)
		meta:set_string("captcha_newplayer", "")	-- Remove newplayer var from meta
		challenges[name] = nil
		show_success_to_player(player, "You entered the correct numbers!")
		minetest.close_formspec(name, FORM_NAME)
		-- If minenews is installed, show the form
		if minetest.global_exists("minenews") then
			minenews.on_joinplayer(player)
		end
	end

	return true
end

local function remove_player_data(name)
	I("Removing new player account who hasn't solved the captcha: '"..name.."'")
	local res = minetest.remove_player(name)
	I("Player account '"..name.."' removal result: "..dump(res))
	res = minetest.remove_player_auth(name)
	I("Player auth '"..name.."' removal result: "..dump(res))
end

local function on_joinplayer(player, is_new)

	if not player then return end
	local name = player:get_player_name()

	D("Player "..name.." joined")
	D("Checking for name in bypass_users")
	if cfg.bypass_users and cfg.bypass_users[name] then return end
	if ranks and cfg.bypass_ranks then
		local user_rank = ranks.get_rank(name)
		if cfg.bypass_ranks[user_rank] then return end
	end

	local meta = player:get_meta()
	if is_new then
		meta:set_int("captcha_newplayer", 1)
	else
		meta:set_string("captcha_newplayer", "")
	end

	if cfg.on_joinplayer or (is_new and meta:get_int("captcha_newplayer") == 1 and
			meta:get_int("captcha_solved") ~= 1) then
		D("Revoking privileges")
		manage_privileges(name, false)
		meta:set_int("captcha_solved", 0)
	else
		return
	end

	if cfg.time_limit then
		D("Scheduling time_limit of "..cfg.time_limit.." to player "..name)
		minetest.after(cfg.time_limit, function(playername)
			D("Checking for captcha timeout ... playername="..dump(playername))
			local p = minetest.get_player_by_name(playername)
			if not p then
				D("Player "..playername.." seems to be disconnected")
				return
			end
			local m = player:get_meta()
			if m:get_int("captcha_solved") == 0 then
				I("Player "..playername.." failed to solve captcha, kicking ...")
				minetest.kick_player(playername, "Failed to complete captcha")
			end
		end, name)	-- need to pass name to it after defining the function
	end
	show_captcha_to_player(player)
end

local function on_leaveplayer(player)
	if not player then return end
	local name = player:get_player_name()
	D("Player "..name.." is leaving, running checks")
	if player_privs then player_privs[name] = nil end
	local m = player:get_meta()
	D("Player meta: "..dump(m:to_table()))
	if m:get_int("captcha_newplayer") == 1 and m:get_int("captcha_solved") == 0 then
		if cfg.on_newplayer and cfg.on_newplayer_remove_accounts then
				minetest.after(1, remove_player_data, name)
		else
			-- This is needed because if privs_after is not defined then
			--     we need to give back the privs that were taken away
			-- If privs_after IS defined, then we need to leave privs as
			--     they are so that client reconnects with the 'during' privs
			if cfg.privs_after == "" then manage_privileges(name, true) end
			player:get_meta():set_string("captcha_newplayer", "")
			if cfg.enable_ban and (cfg.on_joinplayer or cfg.on_newplayer) then
				D("Captcha not solved, banning player")
				if not minetest.ban_player(name) then
					-- Maybe add support here for other ban mods?
					-- I don't know if they use the builtin ban methods so this may already be complete?
					D("Failed to ban player")
				end
			end
		end
	end
end

-- Register callbacks
if cfg.on_newplayer then
	D("Register minetest.register_on_newplayer")
	minetest.register_on_newplayer(function(player) on_joinplayer(player, true) end)
end
if cfg.on_joinplayer then
	D("Register minetest.register_on_joinplayer")
	minetest.register_on_joinplayer(function(player) on_joinplayer(player, false) end)
end
minetest.register_on_leaveplayer(on_leaveplayer)
minetest.register_on_player_receive_fields(on_form_submit)

-- We're done, show up on server logs.
I("Mod loaded")

-- For testing
if minetest.is_mock_server then
	D("Returning values from test execution")
	return { cfg = cfg }
end