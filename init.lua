-- ============================================================================
-- SpamDetector v1.3.0
-- ============================================================================

local CONFIG = {
    SIMILARITY_THRESHOLD    = 0.70,
    REQUIRED_MATCHES        = 2,
    SCORE_TRIGGER_THRESHOLD = 80,
    WARNING_COOLDOWN_SECS   = 20,
    HISTORY_LIMIT           = 8,
    MIN_MESSAGE_LENGTH      = 3,
    CLEANUP_INTERVAL        = 80,
    USER_INACTIVE_TIMEOUT   = 300,
}

local channel_states      = {}
local registered_channels = {}

-- ============================================================================
-- NORMALIZATION & NOISE FILTER
-- ============================================================================

local function is_pure_laughter(text)
    if type(text) ~= "string" or text == "" then return false end
    local s = text:lower():gsub("[%s%p%c]", "")
    if #s < 2 then return false end
    if #s >= 3 and s:gsub("[ha]", "") == "" then return true end
    if #s >= 3 and s:gsub("[he]", "") == "" then return true end
    if #s >= 2 and s:gsub("[xd]", "") == "" then return true end
    if #s >= 3 and s:gsub("[ja]", "") == "" then return true end
    return false
end

local function strip_mention_tokens(text)
    if type(text) ~= "string" then return "" end
    local s = text:gsub("\226\128[\139\140\141]", ""):gsub("\239\187\191", ""):gsub("\194\173", "")
    s = s:lower()
    s = s:gsub("@[%w_]+", " ")
    s = s:gsub("[%c%p]", " ")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

local function normalize_text(text)
    if type(text) ~= "string" or text == "" then
        return "", {}, 0
    end

    local s = strip_mention_tokens(text)
    s = s:gsub("%s*[%#%-%_]?%d+$", "")
    s = s:gsub("(.)%1%1+", "%1%1")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")

    if #s < CONFIG.MIN_MESSAGE_LENGTH then
        return "", {}, 0
    end

    local words = {}
    local word_count = 0
    for word in s:gmatch("%S+") do
        if #word >= 2 then
            word_count = word_count + 1
            words[word_count] = word
        end
    end

    return s, words, word_count
end

-- ============================================================================
-- SIMILARITY (Levenshtein + Fuzzy Token Metrics & Containment)
-- ============================================================================

local function byte_levenshtein(s1, s2, max_dist)
    local len1, len2 = #s1, #s2
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end

    if len1 > len2 then
        s1, s2     = s2, s1
        len1, len2 = len2, len1
    end

    if (len2 - len1) > max_dist then return max_dist + 1 end

    local b1       = {string.byte(s1, 1, -1)}
    local b2       = {string.byte(s2, 1, -1)}
    local prev_row = {}
    local curr_row = {}

    for j = 0, len1 do prev_row[j] = j end

    for i = 1, len2 do
        curr_row[0]   = i
        local b2_char = b2[i]
        local row_min = i

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

local function word_match(w1, w2)
    if w1 == w2 then return true end
    local l1, l2 = #w1, #w2
    if l1 >= 4 and l2 >= 4 and math.abs(l1 - l2) <= 1 then
        return byte_levenshtein(w1, w2, 1) <= 1
    end
    return false
end

local function token_metrics(words1, words2)
    local c1 = #words1
    local c2 = #words2
    if c1 == 0 or c2 == 0 then return 0.0, 0.0 end

    local matches = 0
    local used2 = {}
    for i = 1, c1 do
        local w1 = words1[i]
        for j = 1, c2 do
            if not used2[j] and word_match(w1, words2[j]) then
                matches = matches + 1
                used2[j] = true
                break
            end
        end
    end

    local union = c1 + c2 - matches
    local jaccard = union > 0 and (matches / union) or 0.0

    -- Containment is ONLY valid for multi-word phrases (at least 3 words match)
    local min_c = math.min(c1, c2)
    local containment = jaccard
    if matches >= 3 and min_c >= 3 then
        containment = matches / min_c
    end

    return jaccard, containment
end

local function calculate_similarity(e1, e2)
    if not e1 or not e2 then return 0.0 end

    -- Pure laughter never matches non-laughter
    if e1.is_laughter ~= e2.is_laughter then
        return 0.0
    end

    -- Pure laughter messages only match if sent in rapid succession (< 15 seconds)
    if e1.is_laughter and e2.is_laughter then
        local gap = math.abs((e1.timestamp or 0) - (e2.timestamp or 0))
        if gap > 15 then
            return 0.0
        end
    end

    if e1.text == e2.text then return 1.0 end

    local stripped1 = strip_mention_tokens(e1.text)
    local stripped2 = strip_mention_tokens(e2.text)
    if stripped1 ~= "" and stripped1 == stripped2 then return 1.0 end

    local max_len = math.max(e1.len, e2.len)
    if max_len < CONFIG.MIN_MESSAGE_LENGTH then return 0.0 end

    local jaccard, containment = token_metrics(e1.words, e2.words)
    local token_sim = (jaccard * 0.5) + (containment * 0.5)

    local max_dist = math.max(1, math.floor(max_len * 0.35))
    local dist = byte_levenshtein(e1.text, e2.text, max_dist)

    if dist <= max_dist then
        local dist_sim = 1.0 - (dist / math.max(1, max_len))
        local min_len  = math.min(e1.len, e2.len)
        local prefix_len = 0

        for i = 1, min_len do
            if string.byte(e1.text, i) == string.byte(e2.text, i) then
                prefix_len = prefix_len + 1
            else
                break
            end
        end

        local prefix_bonus = (prefix_len / math.max(1, max_len)) * 0.15
        local combined     = (dist_sim * 0.55) + (token_sim * 0.45) + prefix_bonus
        if combined < 0.0 then return 0.0 end
        if combined > 1.0 then return 1.0 end
        return combined
    elseif token_sim >= 0.60 then
        return token_sim
    else
        return 0.0
    end
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
            user_color   = nil,
            display_name = nil,
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

local function process_incoming_message(channel, user_key, raw_text, user_color, display_name)
    if not channel or not user_key or not raw_text or raw_text == "" then return end
    if raw_text:find("SPAM WARN", 1, true) then return end

    local is_laugh = is_pure_laughter(raw_text)
    local norm_text, words, word_count = normalize_text(raw_text)
    if norm_text == "" then return end

    local state_ref = get_channel_state(channel)
    if not state_ref or not state_ref.enabled then return end

    local ustate = get_user_state(state_ref, user_key)
    if not ustate then return end

    local now = get_current_timestamp()

    -- Time-based score decay for idle gaps between messages
    if ustate.last_seen and ustate.last_seen > 0 then
        local elapsed = now - ustate.last_seen
        if elapsed > 45 then
            local decay_steps = math.min(10, math.floor(elapsed / 45))
            ustate.score = math.max(0, ustate.score - (decay_steps * 8))
        end
    end

    ustate.last_seen = now
    if user_color and user_color ~= "" then
        ustate.user_color = user_color
    end
    if display_name and display_name ~= "" then
        ustate.display_name = display_name
    end

    state_ref.msg_counter = (state_ref.msg_counter or 0) + 1
    if state_ref.msg_counter >= CONFIG.CLEANUP_INTERVAL then
        state_ref.msg_counter = 0
        cleanup_inactive_users(state_ref, now)
    end

    local entry = {
        text        = norm_text,
        raw         = raw_text,
        words       = words,
        word_count  = word_count,
        len         = #norm_text,
        timestamp   = now,
        is_laughter = is_laugh,
    }

    local best_score      = 0.0
    local similar_matches = 0

    for i = 1, #ustate.history do
        local prev  = ustate.history[i]
        local score = calculate_similarity(entry, prev)
        if score > best_score then best_score = score end
        if score >= CONFIG.SIMILARITY_THRESHOLD then
            similar_matches = similar_matches + 1
        end
    end

    local pattern_match = similar_matches >= CONFIG.REQUIRED_MATCHES
                       and best_score      >= CONFIG.SIMILARITY_THRESHOLD

    -- Score accumulates upon ANY similar/duplicate message and decays on clean messages
    if best_score >= CONFIG.SIMILARITY_THRESHOLD then
        ustate.score = math.min(100, ustate.score + (best_score * 35) + (similar_matches * 15))
    else
        ustate.score = math.max(0, ustate.score - 6)
    end

    -- Score trigger only fires if the current message is ALSO similar to previous messages
    local score_match = (ustate.score >= CONFIG.SCORE_TRIGGER_THRESHOLD)
                     and (best_score >= CONFIG.SIMILARITY_THRESHOLD)

    if pattern_match or score_match then
        local time_since_last_warn = now - ustate.last_warning
        if time_since_last_warn >= CONFIG.WARNING_COOLDOWN_SECS then
            ustate.last_warning = now
            ustate.strikes      = ustate.strikes + 1

            local info_txt
            if pattern_match then
                local percent = math.floor(best_score * 100)
                info_txt = string.format(
                    " (%d%% similarity | %d matches | Score %d/%d | Pattern): \"%s\"",
                    percent,
                    similar_matches + 1,
                    math.floor(ustate.score),
                    CONFIG.SCORE_TRIGGER_THRESHOLD,
                    raw_text
                )
            else
                info_txt = string.format(
                    " (Score %d/%d): \"%s\"",
                    math.floor(ustate.score),
                    CONFIG.SCORE_TRIGGER_THRESHOLD,
                    raw_text
                )
            end

            local mention_display = ustate.display_name or user_key
            local mention_color   = ustate.user_color or "text"

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
                            display_name   = mention_display,
                            login_name     = user_key,
                            fallback_color = "text",
                            user_color     = mention_color,
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
                local ok_add = pcall(function()
                    channel:add_message(warn_msg)
                end)
                if not ok_add then
                    channel:add_system_message(
                        "[⚠️ SPAM WARNING ⚠️] " .. mention_display .. info_txt
                    )
                end
            else
                channel:add_system_message(
                    "[⚠️ SPAM WARNING ⚠️] " .. mention_display .. info_txt
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
-- CHANNEL REGISTRATION & SYNC
-- ============================================================================

local function register_channel(channel, silent)
    if not channel then return end

    local channel_key = get_channel_key(channel)
    if registered_channels[channel_key] then return end

    registered_channels[channel_key] = true
    local state = get_channel_state(channel)
    state.enabled = true

    local chan_name  = get_channel_name(channel)
    local chan_label = chan_name and ("#" .. chan_name) or "this chat"
    if not silent then
        channel:add_system_message(string.format(
            "🛡️ Spam Detector active · Monitoring started for %s. (/sg status | /sg help)",
            chan_label
        ))
    end

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

            local user_color = nil
            if type(msg.username_color) == "string" and msg.username_color ~= "" then
                user_color = msg.username_color
            end

            local display_name = user_key
            if type(msg.display_name) == "string" and msg.display_name ~= "" then
                display_name = msg.display_name
            end

            process_incoming_message(channel, user_key, raw_text, user_color, display_name)
        end)

        if not ok and c2 and c2.log and c2.LogLevel then
            c2.log(c2.LogLevel.Warning, "[SpamDetector] " .. tostring(err))
        end
    end)
end

local function sync_channels()
    pcall(function()
        if c2.windows and c2.windows.all then
            for _, window in pairs(c2.windows:all()) do
                local notebook = window.notebook
                local count = (notebook and notebook.page_count) or 0
                for i = 0, count - 1 do
                    local page = notebook:page_at(i)
                    if page then
                        for _, split in pairs(page:splits()) do
                            local channel = split.channel
                            if channel and channel:is_valid() and channel:get_type() ~= c2.ChannelType.None then
                                local key = get_channel_key(channel)
                                if not registered_channels[key] then
                                    register_channel(channel, true)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    if c2.later then
        c2.later(sync_channels, 3000)
    end
end

-- ============================================================================
-- COMMAND HANDLER (/sg & /spamguard)
-- ============================================================================

local function handle_command(ctx)
    local channel = ctx.channel
    if not channel then return end

    register_channel(channel, true)
    local state = get_channel_state(channel)
    local chan_name = get_channel_name(channel) or "this chat"
    local chan_label = chan_name ~= "this chat" and ("#" .. chan_name) or "this chat"

    local arg = ""
    if ctx.words and #ctx.words >= 2 and type(ctx.words[2]) == "string" then
        arg = ctx.words[2]:lower()
    end

    if arg == "off" or arg == "stop" or arg == "disable" then
        state.enabled = false
        channel:add_system_message(string.format("🛡️ Spam Detector DISABLED for %s.", chan_label))

    elseif arg == "on" or arg == "start" or arg == "enable" then
        state.enabled = true
        channel:add_system_message(string.format("🛡️ Spam Detector ENABLED for %s.", chan_label))

    elseif arg == "status" then
        local user_count    = 0
        local flagged_count = 0
        for _, u in pairs(state.by_user) do
            user_count = user_count + 1
            if u.strikes > 0 then flagged_count = flagged_count + 1 end
        end
        local status_str = state.enabled and "ACTIVE" or "INACTIVE"

        channel:add_system_message(string.format(
            "🛡️ Status: %s (%s) | Monitored users: %d (Flagged: %d) | Threshold: %d%% | Score limit: %d",
            status_str, chan_label, user_count, flagged_count,
            math.floor(CONFIG.SIMILARITY_THRESHOLD * 100),
            CONFIG.SCORE_TRIGGER_THRESHOLD
        ))

    elseif arg == "clear" or arg == "reset" then
        state.by_user = {}
        channel:add_system_message("🛡️ Spam Detector: Detection history and user scores cleared.")

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

        process_incoming_message(channel, "test_spammer", test_text, "#00ff7f", "test_spammer")
        local ustate = state.by_user["test_spammer"]
        channel:add_system_message(string.format(
            "🧪 test_spammer · Score: %d/%d · History: %d/%d entries (Send again to trigger!)",
            ustate and math.floor(ustate.score) or 0,
            CONFIG.SCORE_TRIGGER_THRESHOLD,
            ustate and #ustate.history or 0,
            CONFIG.HISTORY_LIMIT
        ))

    elseif arg == "help" then
        channel:add_system_message(
            "🛡️ Commands: /sg (toggle) · /sg on · /sg off · /sg status · /sg clear · /sg test <text>"
        )

    else
        state.enabled = not state.enabled
        if state.enabled then
            channel:add_system_message(string.format("🛡️ Spam Detector ENABLED for %s.", chan_label))
        else
            channel:add_system_message(string.format("🛡️ Spam Detector DISABLED for %s.", chan_label))
        end
    end
end

c2.register_command("/sg",        handle_command)
c2.register_command("/spamguard", handle_command)

sync_channels()
