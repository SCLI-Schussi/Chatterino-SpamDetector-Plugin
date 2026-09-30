-- ============================================================================
-- SpamDetector Release
-- ============================================================================

local CONFIG = {
    SIMILARITY_THRESHOLD    = 0.75,
    REQUIRED_MATCHES        = 2,
    SCORE_TRIGGER_THRESHOLD = 80,
    WARNING_COOLDOWN_SECS   = 20,
    HISTORY_LIMIT           = 8,
    MIN_MESSAGE_LENGTH      = 4,
    CLEANUP_INTERVAL        = 80,
    USER_INACTIVE_TIMEOUT   = 300,
}

local channel_states     = {}
local registered_channels = {}

-- ============================================================================
-- NORMALIZATION & NOISE FILTER
-- ============================================================================

local function normalize_text(text)
    if type(text) ~= "string" or text == "" then
        return "", {}, 0
    end

    local s = text:lower()
    s = s:gsub("[%c%p]", " ")
    s = s:gsub("%s*[%#%-%_]?%d+$", "")
    s = s:gsub("(.)%1%1+", "%1%1")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")

    if #s < CONFIG.MIN_MESSAGE_LENGTH then
        return "", {}, 0
    end

    local word_set   = {}
    local word_count = 0
    for word in s:gmatch("%S+") do
        if #word >= 2 then
            word_set[word] = (word_set[word] or 0) + 1
            word_count     = word_count + 1
        end
    end

    return s, word_set, word_count
end

-- ============================================================================
-- SIMILARITY (Levenshtein + Jaccard)
-- ============================================================================

local function token_jaccard(set1, count1, set2, count2)
    if count1 == 0 or count2 == 0 then return 0.0 end

    local intersection = 0
    for word, ca in pairs(set1) do
        local cb = set2[word]
        if cb then
            intersection = intersection + math.min(ca, cb)
        end
    end

    local union = count1 + count2 - intersection
    return union > 0 and (intersection / union) or 0.0
end

local function byte_levenshtein(s1, s2, max_dist)
    local len1, len2 = #s1, #s2
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end

    if len1 > len2 then
        s1, s2   = s2, s1
        len1, len2 = len2, len1
    end

    if (len2 - len1) > max_dist then return max_dist + 1 end

    local b1       = {string.byte(s1, 1, -1)}
    local b2       = {string.byte(s2, 1, -1)}
    local prev_row = {}
    local curr_row = {}

    for j = 0, len1 do prev_row[j] = j end

    for i = 1, len2 do
        curr_row[0]    = i
        local b2_char  = b2[i]
        local row_min  = i

        for j = 1, len1 do
            local cost = (b1[j] == b2_char) and 0 or 1
            local val  = prev_row[j] + 1
            if curr_row[j - 1] + 1 < val then val = curr_row[j - 1] + 1 end
            if prev_row[j - 1] + cost < val then val = prev_row[j - 1] + cost end
            curr_row[j] = val
            if val < row_min then row_min = val end
        end

        if row_min > max_dist then return max_dist + 1 end

        for j = 0, len1 do prev_row[j] = curr_row[j] end
    end

    return prev_row[len1]
end

local function calculate_similarity(e1, e2)
    if not e1 or not e2 then return 0.0 end
    if e1.text == e2.text   then return 1.0 end

    local max_len  = math.max(e1.len, e2.len)
    if max_len < CONFIG.MIN_MESSAGE_LENGTH then return 0.0 end

    local len_diff = math.abs(e1.len - e2.len)
    if (len_diff / max_len) > 0.45 then return 0.0 end

    local jaccard     = token_jaccard(e1.word_set, e1.word_count, e2.word_set, e2.word_count)
    local max_dist    = math.max(1, math.floor(max_len * 0.35))
    local dist        = byte_levenshtein(e1.text, e2.text, max_dist)

    if dist > max_dist then return 0.0 end

    local dist_sim    = 1.0 - (dist / math.max(1, max_len))
    local min_len     = math.min(e1.len, e2.len)
    local prefix_len  = 0

    for i = 1, min_len do
        if string.byte(e1.text, i) == string.byte(e2.text, i) then
            prefix_len = prefix_len + 1
        else
            break
        end
    end

    local prefix_bonus = (prefix_len / math.max(1, max_len)) * 0.15
    local combined     = (dist_sim * 0.7) + (jaccard * 0.3) + prefix_bonus

    if combined < 0.0 then return 0.0 end
    if combined > 1.0 then return 1.0 end
    return combined
end

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

local function get_channel_name(channel)
    if not channel then return nil end
    if type(channel) == "string" then return channel:lower() end

    local ok, name = pcall(function()
        if channel.is_valid and not channel:is_valid() then return nil end
        return channel:get_name()
    end)

    if ok and type(name) == "string" and name ~= "" then return name:lower() end
    return nil
end

local function get_channel_key(channel)
    local name = get_channel_name(channel)
    if name then return name end
    if channel then return tostring(channel) end
    return "default"
end

local function get_channel_state(channel)
    local key = get_channel_key(channel)

    if not channel_states[key] then
        channel_states[key] = {
            enabled     = true,
            channel     = channel,
            msg_counter = 0,
            by_user     = {},
        }
    end

    return channel_states[key]
end

local function get_current_timestamp()
    if c2 and c2.DateTime and c2.DateTime.current_utc then
        local ok, dt = pcall(c2.DateTime.current_utc)
        if ok and dt then
            local ok_s, s = pcall(function() return dt:to_unix_seconds() end)
            if ok_s and type(s) == "number" then return s end
        end
    end
    return 0
end

local function get_user_state(state, user_key)
    if not state or not user_key then return nil end

    if not state.by_user[user_key] then
        state.by_user[user_key] = {
            score        = 0,
            last_seen    = get_current_timestamp(),
            last_warning = 0,
            strikes      = 0,
            history      = {},
        }
    end

    return state.by_user[user_key]
end

local function cleanup_inactive_users(state, now)
    for ukey, ustate in pairs(state.by_user) do
        local idle = now - (ustate.last_seen or 0)
        if idle > CONFIG.USER_INACTIVE_TIMEOUT and ustate.score <= 5 and ustate.strikes == 0 then
            state.by_user[ukey] = nil
        elseif idle > (CONFIG.USER_INACTIVE_TIMEOUT * 3) then
            state.by_user[ukey] = nil
        end
    end
end

-- ============================================================================
-- MESSAGE EXTRACTION
-- ============================================================================

local function extract_message_text(msg)
    if not msg then return "" end

    local text = ""
    pcall(function()
        if type(msg.message_text) == "string" and msg.message_text ~= "" then
            text = msg.message_text
        elseif type(msg.search_text) == "string" and msg.search_text ~= "" then
            text = msg.search_text
        end
    end)

    if text ~= "" then return text end

    local words = {}
    local ok, elements = pcall(function() return msg:elements() end)
    if ok and elements then
        pcall(function()
            for i = 1, #elements do
                local elem = elements[i]
                if elem and elem.words then
                    for j = 1, #elem.words do
                        local word = elem.words[j]
                        if type(word) == "string" and word ~= "" then
                            words[#words + 1] = word
                        end
                    end
                end
            end
        end)
    end

    return table.concat(words, " ")
end

-- ============================================================================
-- SPAM DETECTION
-- ============================================================================

local function process_incoming_message(channel, user_key, raw_text)
    if not channel or not user_key or not raw_text or raw_text == "" then return end
    if raw_text:find("SPAM WARNING", 1, true) then return end

    local norm_text, word_set, word_count = normalize_text(raw_text)
    if norm_text == "" then return end

    local state_ref = get_channel_state(channel)
    if not state_ref or not state_ref.enabled then return end

    local ustate = get_user_state(state_ref, user_key)
    if not ustate then return end

    local now = get_current_timestamp()

    -- FIX: update last_seen on every message so cleanup doesn't evict active users
    ustate.last_seen = now

    state_ref.msg_counter = (state_ref.msg_counter or 0) + 1
    if state_ref.msg_counter >= CONFIG.CLEANUP_INTERVAL then
        state_ref.msg_counter = 0
        cleanup_inactive_users(state_ref, now)
    end

    local entry = {
        text       = norm_text,
        raw        = raw_text,
        word_set   = word_set,
        word_count = word_count,
        len        = #norm_text,
        timestamp  = now,
    }

    local best_score     = 0.0
    local similar_matches = 0

    for i = 1, #ustate.history do
        local prev  = ustate.history[i]
        local score = calculate_similarity(entry, prev)
        if score > best_score then best_score = score end
        if score >= CONFIG.SIMILARITY_THRESHOLD then
            similar_matches = similar_matches + 1
        end
    end

    -- Pattern match: enough similar messages with high confidence
    local pattern_match = similar_matches >= CONFIG.REQUIRED_MATCHES
                       and best_score      >= CONFIG.SIMILARITY_THRESHOLD

    -- FIX: score accumulates when spamming, decays when normal → becomes a second trigger path
    if pattern_match then
        ustate.score = math.min(100, ustate.score + (best_score * 35) + (similar_matches * 12))
    else
        ustate.score = math.max(0, ustate.score - 6)
    end

    -- FIX: score threshold is now a real second trigger (catches slow/paced spammers)
    local score_match = ustate.score >= CONFIG.SCORE_TRIGGER_THRESHOLD

    if pattern_match or score_match then
        local time_since_last_warn = now - ustate.last_warning
        if time_since_last_warn >= CONFIG.WARNING_COOLDOWN_SECS then
            ustate.last_warning = now
            ustate.strikes      = ustate.strikes + 1

            local info_txt
            if pattern_match then
                info_txt = string.format(
                    " (%d%% similarity | %d matches | Score %d | %d | Pattern): \"%s\"",
                    math.floor(best_score * 100), similar_matches + 1,
                    math.floor(ustate.score), CONFIG.SCORE_TRIGGER_THRESHOLD, raw_text
                )
            else
                info_txt = string.format(
                    " (Score %d | %d): \"%s\"",
                    math.floor(ustate.score), CONFIG.SCORE_TRIGGER_THRESHOLD, raw_text
                )
            end

            -- Try to build a rich message with a clickable username (opens user popup)
            local ok_msg, warn_msg = pcall(function()
                return c2.Message.new({
                    message_text = "SPAM WARNING",
                    elements = {
                        {
                            type  = "text",
                            text  = "[⚠️ SPAM WARNING ⚠️] ",
                            color = "system",
                        },
                        {
                            type           = "mention",
                            display_name   = user_key,
                            login_name     = user_key,
                            fallback_color = "text",
                            user_color     = "#ff0000",
                        },
                        {
                            type  = "text",
                            text  = info_txt,
                            color = "system",
                        },
                    },
                })
            end)

            if ok_msg and warn_msg then
                local ok_add, add_err = pcall(function()
                    channel:add_message(warn_msg)
                end)
                if not ok_add then
                    -- Fallback if add_message fails
                    channel:add_system_message(
                        "[⚠️ SPAM WARNING ⚠️] " .. user_key .. info_txt
                    )
                end
            else
                channel:add_system_message(
                    "[⚠️ SPAM WARNING ⚠️] " .. user_key .. info_txt
                )
            end
        end
    end

    table.insert(ustate.history, 1, entry)
    if #ustate.history > CONFIG.HISTORY_LIMIT then
        table.remove(ustate.history)
    end
end

-- ============================================================================
-- CHANNEL REGISTRATION
-- ============================================================================

local function register_channel(channel)
    if not channel then return end

    local channel_key = get_channel_key(channel)
    if registered_channels[channel_key] then return end

    registered_channels[channel_key] = true
    local state = get_channel_state(channel)
    state.enabled = true

    local chan_name  = get_channel_name(channel)
    local chan_label = chan_name and ("#" .. chan_name) or "this chat"
    channel:add_system_message(string.format(
        "🛡️ Spam Detector active · Monitoring started for %s. (/sg status | /sg help)",
        chan_label
    ))

    channel:on_message_appended(function(msg)
        if not msg then return end

        local ok, err = pcall(function()
            local user_key = nil
            if type(msg.login_name) == "string" and msg.login_name ~= "" then
                user_key = msg.login_name:lower()
            elseif type(msg.display_name) == "string" and msg.display_name ~= "" then
                user_key = msg.display_name:lower()
            end

            if not user_key or user_key == "" then return end

            local raw_text = extract_message_text(msg)
            if raw_text == "" then return end

            process_incoming_message(channel, user_key, raw_text)
        end)

        if not ok and c2 and c2.log and c2.LogLevel then
            c2.log(c2.LogLevel.Warning, "[SpamDetector] " .. tostring(err))
        end
    end)
end

-- ============================================================================
-- COMMAND HANDLER (/sg & /spamguard)
-- ============================================================================

local function handle_command(ctx)
    local channel = ctx.channel
    if not channel then return end

    register_channel(channel)
    local state = get_channel_state(channel)

    local arg = ""
    if ctx.words and #ctx.words >= 2 and type(ctx.words[2]) == "string" then
        arg = ctx.words[2]:lower()
    end

    if arg == "off" or arg == "stop" or arg == "disable" then
        state.enabled = false
        channel:add_system_message("🛡️ Spam Detector disabled.")

    elseif arg == "on" or arg == "start" or arg == "enable" then
        state.enabled = true
        channel:add_system_message("🛡️ Spam Detector enabled.")

    elseif arg == "status" then
        local user_count    = 0
        local flagged_count = 0
        for _, u in pairs(state.by_user) do
            user_count = user_count + 1
            if u.strikes > 0 then flagged_count = flagged_count + 1 end
        end
        local status_str = state.enabled and "AKTIV" or "INAKTIV"
        local chan_name  = get_channel_name(channel)
        local chan_label = chan_name and ("#" .. chan_name) or "Channel"
        channel:add_system_message(string.format(
            "🛡️ Status: %s (%s) | Users: %d (Flagged: %d) | Threshold: %d%% | Score limit: %d",
            status_str, chan_label, user_count, flagged_count,
            math.floor(CONFIG.SIMILARITY_THRESHOLD * 100),
            CONFIG.SCORE_TRIGGER_THRESHOLD
        ))

    elseif arg == "clear" or arg == "reset" then
        state.by_user = {}
        channel:add_system_message("🛡️ Spam Detector: detection history cleared.")

    elseif arg == "test" then
        local test_words = {}
        if ctx.words and #ctx.words >= 3 then
            for i = 3, #ctx.words do
                test_words[#test_words + 1] = ctx.words[i]
            end
        end
        local test_text = table.concat(test_words, " ")
        if test_text == "" then
            test_text = "This is a test message for the Spam Detector!"
        end

        process_incoming_message(channel, "test_spammer", test_text)
        local ustate = state.by_user["test_spammer"]
        channel:add_system_message(string.format(
            "🧪 test_spammer · Score: %d/%d · History: %d/%d entries",
            ustate and math.floor(ustate.score) or 0,
            CONFIG.SCORE_TRIGGER_THRESHOLD,
            ustate and #ustate.history or 0,
            CONFIG.HISTORY_LIMIT
        ))

    elseif arg == "help" then
        channel:add_system_message(
            "🛡️ Commands: /sg · /sg on · /sg off · /sg status · /sg clear · /sg test <text>"
        )

    else
        state.enabled = not state.enabled
        if state.enabled then
            channel:add_system_message("🛡️ Spam Detector enabled. (/sg help for commands)")
        else
            channel:add_system_message("🛡️ Spam Detector disabled.")
        end
    end
end

c2.register_command("/sg",        handle_command)
c2.register_command("/spamguard", handle_command)
