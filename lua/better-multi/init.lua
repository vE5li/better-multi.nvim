local M = {}

--local k = vim.keycode
local k = function(keycode)
    return vim.api.nvim_replace_termcodes(keycode, true, true, true)
end

local ESC = string.char((k '<Esc>'):byte())
local cursor_namespace = vim.api.nvim_create_namespace('multi-cursor')
local old_cursorline
-- TODO: remove
local cursor_text

local function add_normal_cursor(row, col)
    local character = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]

    if string.len(character) == 0 then
        character = " "
    end

    vim.api.nvim_buf_set_extmark(0, cursor_namespace, row, col,
        {
            virt_text = { { character, "Cursor" } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
            priority = 1000,
            end_col = col + 1,
            strict = false
        });

    vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

local function add_visual_cursor(row, col, end_col)
    local text = vim.api.nvim_buf_get_text(0, row, col, row, end_col + 1, {})[1]

    if string.len(text) <= end_col - col then
        text = text .. " "
    end

    local visual = text:sub(1, #text - 1)
    local cursor = text:sub(#text)

    vim.api.nvim_buf_set_extmark(0, cursor_namespace, row, col,
        {
            virt_text = { { visual, "Visual" }, { cursor, "Cursor" } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
            priority = 1000,
            end_col = end_col,
            strict = false,
        });

    vim.api.nvim_win_set_cursor(0, { row + 1, end_col - 1 })
end

local function move_normal_cursor(id, row, col)
    local character = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]

    if string.len(character) == 0 then
        character = " "
    end

    vim.api.nvim_buf_set_extmark(0, cursor_namespace, row, col,
        {
            id = id,
            virt_text = { { character, "Cursor" } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
            priority = 1000,
            end_col = col + 1,
            strict = false
        });
end

local function move_visual_cursor(id, row, col, end_col, cursor_front)
    local text = vim.api.nvim_buf_get_text(0, row, col, row, end_col + 1, {})[1]
    local virt_text

    if string.len(text) <= end_col - col then
        text = text .. " "
    end

    if cursor_front then
        local cursor = text:sub(1, 1)
        local visual = text:sub(2)
        virt_text = { { cursor, "Cursor" }, { visual, "Visual" } }
    else
        local visual = text:sub(1, #text - 1)
        local cursor = text:sub(#text)
        virt_text = { { visual, "Visual" }, { cursor, "Cursor" } }
    end

    vim.api.nvim_buf_set_extmark(0, cursor_namespace, row, col,
        {
            id = id,
            virt_text = virt_text,
            virt_text_pos = "overlay",
            hl_mode = "combine",
            priority = 1000,
            end_col = end_col,
            strict = false
        });
end

local function move_insert_cursor(id, row, col)
    local character = vim.api.nvim_buf_get_text(0, row, col, row, col + 1, {})[1]

    if string.len(character) == 0 then
        character = " "
    end

    vim.api.nvim_buf_set_extmark(0, cursor_namespace, row, col,
        {
            id = id,
            virt_text = { { character, "Cursor" } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
            priority = 1000,
            end_col = col + 1,
            strict = false
        });
end

local function for_each_normal_cursor(callback)
    local extmarks = vim.api.nvim_buf_get_extmarks(0, cursor_namespace, 0, -1, {})

    for _, shadow_mark in ipairs(extmarks) do
        -- Since the callback might change the position of the cursor, we fetch every cursor right before the callback
        local mark_id = shadow_mark[1];
        local mark = vim.api.nvim_buf_get_extmark_by_id(0, cursor_namespace, mark_id, {})
        local cursor = { id = mark_id, row = mark[1], col = mark[2] }

        callback(cursor)
    end
end

local function for_each_visual_cursor(callback)
    local extmarks = vim.api.nvim_buf_get_extmarks(0, cursor_namespace, 0, -1, {})

    for _, shadow_mark in ipairs(extmarks) do
        -- Since the callback might change the position of the cursor, we fetch every cursor right before the callback
        local mark_id = shadow_mark[1];
        local mark = vim.api.nvim_buf_get_extmark_by_id(0, cursor_namespace, mark_id, { details = true })
        local cursor = { id = mark_id, row = mark[1], col = mark[2], end_col = mark[3].end_col }

        callback(cursor)
    end
end

local function for_each_normal_cursor_reposition(callback)
    local extmarks = vim.api.nvim_buf_get_extmarks(0, cursor_namespace, 0, -1, {})

    for _, shadow_mark in ipairs(extmarks) do
        -- Since the callback might change the position of the cursor, we fetch every cursor right before the callback
        local mark_id = shadow_mark[1];
        local mark = vim.api.nvim_buf_get_extmark_by_id(0, cursor_namespace, mark_id, { details = true })
        local cursor = { id = mark_id, row = mark[1], col = mark[2], end_col = mark[3].end_col }

        vim.api.nvim_win_set_cursor(0, { cursor.row + 1, cursor.col })
        callback(cursor)

        local position = vim.api.nvim_win_get_cursor(0)
        move_normal_cursor(cursor.id, position[1] - 1, position[2])
    end
end

local function for_each_visual_cursor_reposition(cursor_front, callback)
    local extmarks = vim.api.nvim_buf_get_extmarks(0, cursor_namespace, 0, -1, {})

    for _, shadow_mark in ipairs(extmarks) do
        -- Since the callback might change the position of the cursor, we fetch every cursor right before the callback
        local mark_id = shadow_mark[1];
        local mark = vim.api.nvim_buf_get_extmark_by_id(0, cursor_namespace, mark_id, { details = true })
        local cursor = { id = mark_id, row = mark[1], col = mark[2], end_col = mark[3].end_col }

        if cursor_front then
            vim.api.nvim_win_set_cursor(0, { cursor.row + 1, cursor.col })
        else
            vim.api.nvim_win_set_cursor(0, { cursor.row + 1, cursor.end_col })
        end

        callback(cursor)

        local position = vim.api.nvim_win_get_cursor(0)

        if cursor_front then
            move_visual_cursor(cursor.id, position[1] - 1, position[2], cursor.end_col, cursor_front)
        else
            -- FIX: very hacky and not proper
            local end_col = math.max(cursor.col, position[2])
            move_visual_cursor(cursor.id, cursor.row, cursor.col, end_col, cursor_front)
        end
    end
end

local function for_each_insert_cursor_reposition(callback)
    local extmarks = vim.api.nvim_buf_get_extmarks(0, cursor_namespace, 0, -1, {})

    for _, shadow_mark in ipairs(extmarks) do
        -- Since the callback might change the position of the cursor, we fetch every cursor right before the callback
        local mark_id = shadow_mark[1];
        local mark = vim.api.nvim_buf_get_extmark_by_id(0, cursor_namespace, mark_id, { details = true })
        local cursor = { id = mark_id, row = mark[1], col = mark[2], end_col = mark[3].end_col }

        vim.api.nvim_win_set_cursor(0, { cursor.row + 1, cursor.col })
        callback(cursor)

        local position = vim.api.nvim_win_get_cursor(0)
        move_insert_cursor(cursor.id, position[1] - 1, position[2])
    end
end

local function for_each_normal_cursor_reposition_single(command)
    for_each_normal_cursor_reposition(function(cursor)
        vim.cmd(command)
    end)
end

local function for_each_visual_cursor_reposition_single(cursor_front, command)
    for_each_visual_cursor_reposition(cursor_front, function(cursor)
        vim.cmd(command)
    end)
end

local function for_each_visual_cursor_redraw(cursor_front)
    for_each_visual_cursor_reposition(cursor_front, function(cursor) end)
end

local function for_each_insert_cursor_reposition_single(command)
    for_each_insert_cursor_reposition(function(cursor)
        vim.cmd(command)
    end)
end

local function remove_cursors()
    vim.api.nvim_buf_clear_namespace(0, cursor_namespace, 0, -1)
end

local function get_line_from_clipboard()
    local input = vim.fn.getreg("+")
    local lines = {}

    for word in input:gmatch("[^" .. ESC .. "]+") do
        table.insert(lines, word)
    end

    return lines
end

local function start_multi_insert(offset)
    local function Leave()
        -- Move cursors back one
        vim.opt_local.virtualedit = ""

        for_each_normal_cursor(function(cursor)
            local clamped_col = math.max(cursor.col - 1, 0)
            move_normal_cursor(cursor.id, cursor.row, clamped_col)
        end)

        vim.g.multiinsertModeExit = true
    end

    -- function which is called whenever the user presses a button
    local function BetterInsert()
        if type(vim.g.multiinsertModeInput) == "string" then
            local code = vim.g.multiinsertModeInput

            if code == k "<BS>" then
                for_each_insert_cursor_reposition_single(k "norm! d<Left>")
            elseif code == k "<Del>" then
                for_each_insert_cursor_reposition_single(k "norm! <Del>")
            elseif code == k "<Right>" then
                for_each_insert_cursor_reposition_single(k "norm! <Right>")
            elseif code == k "<S-Right>" then
                for_each_insert_cursor_reposition_single(k "norm! <S-Right>")
            elseif code == k "<Left>" then
                for_each_insert_cursor_reposition_single(k "norm! <Left>")
            elseif code == k "<S-Left>" then
                for_each_insert_cursor_reposition_single(k "norm! <S-Left>")
            elseif code == k "<Up>" then
                for_each_insert_cursor_reposition_single(k "norm! <Up>")
            elseif code == k "<Down>" then
                for_each_insert_cursor_reposition_single(k "norm! <Down>")
            elseif code == k '<Home>' then
                for_each_insert_cursor_reposition_single(k "norm! <Home>")
            elseif code == k '<End>' then
                for_each_insert_cursor_reposition_single(k "norm! g$")
            end
        else
            local userInput = string.char(vim.g.multiinsertModeInput)

            if userInput == ESC then
                Leave()
            else
                -- Insert character for each cursor
                for_each_insert_cursor_reposition(function(cursor)
                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.col, { userInput })
                    vim.api.nvim_win_set_cursor(0, { cursor.row + 1, cursor.col + 1 })
                end)
            end
        end
    end

    local function Enter()
        vim.opt_local.virtualedit = "onemore"

        -- Move cursors forward offset columns
        if offset ~= nil then
            for_each_normal_cursor(function(cursor)
                local clamped_col = cursor.col + offset
                move_insert_cursor(cursor.id, cursor.row, clamped_col)
            end)
        end

        vim.g.multiinsertModeExit = false
        require('libmodal').mode.enter('MultiInsert', BetterInsert, true)
    end

    Enter()
end

local function start_multi_visual(update_cursors, regex)
    local enter_insert = false
    local appended_character
    -- TODO: we need to somehow store this per cursor
    local cursor_front = false

    local function Leave()
        vim.opt_local.virtualedit = ""

        -- Shrink cursors down to a single character
        for_each_visual_cursor(function(cursor)
            if cursor_front then
                move_normal_cursor(cursor.id, cursor.row, cursor.col)
            else
                move_normal_cursor(cursor.id, cursor.row, cursor.end_col)
            end
        end)

        -- Remove highlighing
        --vim.fn.matchdelete(vim.w.highlight_match)

        -- Tell modal to exit the mode
        vim.g.multivisualModeExit = true
    end

    local function Enter()
        vim.opt_local.virtualedit = "onemore"

        if update_cursors then
            -- From Regex
            if regex ~= nil then
                -- Define the regex pattern
                -- Get the current buffer
                local buf = vim.api.nvim_get_current_buf()

                -- Iterate over each line in the buffer
                for line_num, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
                    local start_offset = 0

                    while true do
                        local match = vim.fn.matchstrpos(line, regex, start_offset)
                        local match_length = match[3] - match[2]

                        -- No match found
                        if match_length == 0 then
                            break
                        end

                        add_visual_cursor(line_num - 1, match[2], match[3] - 1)

                        start_offset = start_offset + match[3]
                    end
                end

                -- From visual selection
            else
                local start_pos = vim.fn.getpos("'<")
                local end_pos = vim.fn.getpos("'>")

                -- Sort start and end position correctly
                -- TODO: this check is not suffisticated enough, e.g. if the selection is multi line
                -- FIX: in general we should probably keep the correct order
                if start_pos[3] > end_pos[3] then
                    start_pos, end_pos = end_pos, start_pos
                end

                local selected_text = vim.api.nvim_buf_get_text(0, start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1,
                    end_pos
                    [3], {})[1]
                --vim.w.highlight_match = vim.fn.matchadd("MultiMatches", selected_text)

                cursor_text = selected_text

                add_visual_cursor(start_pos[2] - 1, start_pos[3] - 1, end_pos[3] - 1)
            end
        else
            for_each_visual_cursor_reposition_single(cursor_front, "norm! h")
        end

        vim.g.multivisualModeExit = false
        require('libmodal').mode.enter('MultiVisual', {
            -- TODO: all 3 the same
            ['d'] = function()
                local appended_text = ""

                for_each_visual_cursor(function(cursor)
                    local text = vim.api.nvim_buf_get_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                    appended_text = appended_text .. text[1] .. ESC
                end)

                --vim.schedule(function()
                --    local last_mark = extmarks[#extmarks]
                --    vim.api.nvim_win_set_cursor(0, { last_mark[2], last_mark[3] })
                --end)

                -- Save to clipboard
                vim.fn.setreg("+", appended_text)

                Leave()
            end,
            -- TODO: all 3 the same
            ['x'] = function()
                local appended_text = ""

                for_each_visual_cursor(function(cursor)
                    local text = vim.api.nvim_buf_get_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                    appended_text = appended_text .. text[1] .. ESC
                end)

                --vim.schedule(function()
                --    local last_mark = extmarks[#extmarks]
                --    vim.api.nvim_win_set_cursor(0, { last_mark[2], last_mark[3] })
                --end)

                -- Save to clipboard
                vim.fn.setreg("+", appended_text)

                Leave()
            end,
            -- TODO: all 3 the same
            [k "<Del>"] = function()
                local appended_text = ""

                for_each_visual_cursor(function(cursor)
                    local text = vim.api.nvim_buf_get_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                    appended_text = appended_text .. text[1] .. ESC
                end)

                --vim.schedule(function()
                --    local last_mark = extmarks[#extmarks]
                --    vim.api.nvim_win_set_cursor(0, { last_mark[2], last_mark[3] })
                --end)

                -- Save to clipboard
                vim.fn.setreg("+", appended_text)

                Leave()
            end,
            -- Change selected text
            ['c'] = function()
                for_each_visual_cursor(function(cursor)
                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                end)

                enter_insert = true
                Leave()
            end,
            ['s'] = function()
                for_each_visual_cursor(function(cursor)
                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                end)

                enter_insert = true
                Leave()
            end,
            -- Yank selected text
            ['y'] = function()
                local appended_text = ""

                for_each_visual_cursor(function(cursor)
                    -- FIX: handle multi line correctly
                    local text = vim.api.nvim_buf_get_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                    appended_text = appended_text .. text[1] .. ESC
                end)

                -- Save to clipboard
                vim.fn.setreg("+", appended_text)

                Leave()
            end,
            -- Move line to the right
            ['>'] = function()
                for_each_visual_cursor_reposition(cursor_front, function(cursor)
                    -- FIX: handle multi line correctly
                    vim.cmd("norm! v>")
                end)

                Leave()
            end,
            -- Move line to the left
            ['<'] = function()
                for_each_visual_cursor_reposition(cursor_front, function(cursor)
                    -- FIX: handle multi line correctly
                    vim.cmd("norm! v<")
                end)

                Leave()
            end,
            ['='] = function()
                for_each_visual_cursor_reposition(cursor_front, function(cursor)
                    -- FIX: handle multi line correctly
                    vim.cmd("norm! v=")
                end)

                Leave()
            end,
            ['~'] = function()
                for_each_visual_cursor_reposition(cursor_front, function(cursor)
                    -- FIX: handle multi line correctly
                    vim.cmd("norm! v~")
                end)

                Leave()
            end,
            ['gq'] = function()
                for_each_visual_cursor_reposition(cursor_front, function(cursor)
                    -- FIX: handle multi line correctly
                    vim.cmd("norm! vgq")
                end)

                Leave()
            end,
            -- Replace selected text with a given character
            ['r'] = function()
                for_each_visual_cursor(function(cursor)
                    -- FIX: handle multi line correctly
                    local new_text = string.rep(appended_character, cursor.end_col + 1 - cursor.col)
                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, { new_text })
                    move_normal_cursor(cursor.id, cursor.row, cursor.col)
                end)

                Leave()
            end,
            -- Delete entire line text and go into insert mode
            ['S'] = function()
                local appended_text = ""

                for_each_visual_cursor(function(cursor)
                    -- FIX: handle multi line correctly
                    local lines = vim.api.nvim_buf_get_lines(0, cursor.row, cursor.row + 1, true);
                    vim.api.nvim_buf_set_lines(0, cursor.row, cursor.row + 1, true, { "" });
                    move_normal_cursor(cursor.id, cursor.row, 0)
                    appended_text = appended_text .. lines[1] .. "\n" .. ESC
                end)

                -- Save to clipboard
                vim.fn.setreg("+", appended_text)

                enter_insert = true
                Leave()
            end,
            ['R'] = function()
                local appended_text = ""

                for_each_visual_cursor(function(cursor)
                    -- FIX: handle multi line correctly
                    local lines = vim.api.nvim_buf_get_lines(0, cursor.row, cursor.row + 1, true);
                    vim.api.nvim_buf_set_lines(0, cursor.row, cursor.row + 1, true, { "" });
                    move_normal_cursor(cursor.id, cursor.row, 0)
                    appended_text = appended_text .. lines[1] .. "\n" .. ESC
                end)

                -- Save to clipboard
                vim.fn.setreg("+", appended_text)

                enter_insert = true
                Leave()
            end,
            -- Delete entire line
            ['D'] = function()
                local appended_text = ""

                for_each_visual_cursor(function(cursor)
                    -- FIX: handle multi line correctly
                    local lines = vim.api.nvim_buf_get_lines(0, cursor.row, cursor.row + 1, true);
                    vim.api.nvim_buf_set_lines(0, cursor.row, cursor.row + 1, true, {});
                    move_normal_cursor(cursor.id, cursor.row, cursor.col)
                    appended_text = appended_text .. lines[1] .. "\n" .. ESC
                end)

                -- Save to clipboard
                vim.fn.setreg("+", appended_text)

                Leave()
            end,
            ['X'] = function()
                local appended_text = ""

                for_each_visual_cursor(function(cursor)
                    -- FIX: handle multi line correctly
                    local lines = vim.api.nvim_buf_get_lines(0, cursor.row, cursor.row + 1, true);
                    vim.api.nvim_buf_set_lines(0, cursor.row, cursor.row + 1, true, {});
                    move_normal_cursor(cursor.id, cursor.row, cursor.col)
                    appended_text = appended_text .. lines[1] .. "\n" .. ESC
                end)

                -- Save to clipboard
                vim.fn.setreg("+", appended_text)

                Leave()
            end,
            -- Yank entire line
            ['Y'] = function()
                local appended_text = ""

                for_each_visual_cursor(function(cursor)
                    -- FIX: handle multi line correctly
                    local lines = vim.api.nvim_buf_get_lines(0, cursor.row, cursor.row + 1, true);
                    move_normal_cursor(cursor.id, cursor.row, cursor.col)
                    appended_text = appended_text .. lines[1] .. "\n" .. ESC
                end)

                -- Save to clipboard
                vim.fn.setreg("+", appended_text)

                Leave()
            end,
            -- Put text in clipboard to seletcion and copy the old text to the clipboard
            ['p'] = function()
                local appended_text = ""
                local lines = get_line_from_clipboard()
                local current_index = 1

                for_each_visual_cursor(function(cursor)
                    local text = vim.api.nvim_buf_get_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                    appended_text = appended_text .. text[1] .. ESC

                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1,
                        { lines[current_index] })

                    local end_position = cursor.col + string.len(lines[current_index])
                    move_normal_cursor(cursor.id, cursor.row, end_position - 1)

                    current_index = (current_index % #lines) + 1
                end)

                -- Save to clipboard
                vim.fn.setreg("+", appended_text)

                Leave()
            end,
            -- Put text in clipboard to seletcion
            ['P'] = function()
                local lines = get_line_from_clipboard()
                local current_index = 1

                for_each_visual_cursor(function(cursor)
                    local text = vim.api.nvim_buf_get_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})

                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1,
                        { lines[current_index] })

                    local end_position = cursor.col + string.len(lines[current_index])
                    move_normal_cursor(cursor.id, cursor.row, end_position - 1)

                    current_index = (current_index % #lines) + 1
                end)

                Leave()
            end,
            -- Make selected text lowercase
            ['u'] = function()
                for_each_visual_cursor(function(cursor)
                    -- FIX: handle multi line correctly
                    local text = vim.api.nvim_buf_get_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                    local uppercase_text = vim.fn.tolower(text[1])
                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1,
                        { uppercase_text })
                    move_normal_cursor(cursor.id, cursor.row, cursor.col - 1)
                end)

                Leave()
            end,
            -- Make selected text uppercase
            ['U'] = function()
                for_each_visual_cursor(function(cursor)
                    -- FIX: handle multi line correctly
                    local text = vim.api.nvim_buf_get_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1, {})
                    local uppercase_text = vim.fn.toupper(text[1])
                    vim.api.nvim_buf_set_text(0, cursor.row, cursor.col, cursor.row, cursor.end_col + 1,
                        { uppercase_text })
                    move_normal_cursor(cursor.id, cursor.row, cursor.col - 1)
                end)

                Leave()
            end,
            -- Add cursor at next occurance
            ['n'] = function()
                local cursor_position = vim.api.nvim_win_get_cursor(0)
                local col_offset = cursor_position[2] + 1
                local next_lines = vim.api.nvim_buf_get_text(0, cursor_position[1] - 1, col_offset, -1, -1, {})

                for line_offset, line in ipairs(next_lines) do
                    local position = string.find(line, cursor_text)

                    if position ~= nil then
                        add_visual_cursor(cursor_position[1] + line_offset - 2, position + col_offset - 1,
                            position + col_offset - 2 + string.len(cursor_text))
                        return
                    end

                    col_offset = 0
                end
            end,
            -- Move cursor to next occurence
            [' '] = function()
                local cursor_position = vim.api.nvim_win_get_cursor(0)
                local col_offset = cursor_position[2] + 1
                local next_lines = vim.api.nvim_buf_get_text(0, cursor_position[1] - 1, col_offset, -1, -1, {})

                for line_offset, line in ipairs(next_lines) do
                    local position = string.find(line, cursor_text)

                    if position ~= nil then
                        vim.api.nvim_win_set_cursor(0,
                            { cursor_position[1] + line_offset - 1, position + col_offset - 2 + string.len(cursor_text) })
                        return
                    end

                    col_offset = 0
                end
            end,
            ['o'] = function()
                cursor_front = not cursor_front
                for_each_visual_cursor_redraw(cursor_front)
            end,
            ['O'] = function()
                cursor_front = not cursor_front
                for_each_visual_cursor_redraw(cursor_front)
            end,
            [k '<BS>'] = function()
                for_each_visual_cursor_reposition_single(cursor_front, "")
            end,
            [k '<Left>'] = function()
                for_each_visual_cursor_reposition_single(cursor_front, k "norm! <Left>")
            end,
            [k '<S-Left>'] = function()
                for_each_visual_cursor_reposition_single(cursor_front, k "norm! <S-Left>")
            end,
            [k '<Right>'] = function()
                for_each_visual_cursor_reposition_single(cursor_front, k "norm! <Right>")
            end,
            [k '<S-Right>'] = function()
                for_each_visual_cursor_reposition_single(cursor_front, k "norm! <S-Right>")
            end,
            [k "<Up>"] = function()
                for_each_visual_cursor_reposition_single(cursor_front, k "norm! <Up>")
            end,
            [k "<Down>"] = function()
                for_each_visual_cursor_reposition_single(cursor_front, k "norm! <Down>")
            end,
            ['w'] = function()
                for_each_visual_cursor_reposition_single(cursor_front, "norm! w")
            end,
            ['W'] = function()
                for_each_visual_cursor_reposition_single(cursor_front, "norm! W")
            end,
            ['e'] = function()
                for_each_visual_cursor_reposition_single(cursor_front, "norm! e")
            end,
            [k '<Home>'] = function()
                for_each_visual_cursor_reposition_single(cursor_front, k "norm! <Home>")
            end,
            [k '<End>'] = function()
                for_each_visual_cursor_reposition_single(cursor_front, k "norm! g$")
            end,
            -- Exit the mode
            [ESC] = Leave
        }, true)
    end

    Enter()
    return enter_insert
end

local function start_multi_normal(start_in_visual, regex)
    local function Leave()
        remove_cursors()

        vim.wo.cursorline = old_cursorline

        vim.g.multinormalModeExit = true
    end

    local function Enter()
        vim.cmd('hi MultiMatches term=underline cterm=underline gui=underline')

        old_cursorline = vim.wo.cursorline
        vim.wo.cursorline = false

        if start_in_visual then
            if start_multi_visual(true, regex) then
                start_multi_insert()
            end
        else
            local position = vim.api.nvim_win_get_cursor(0)
            add_normal_cursor(position[1] - 1, position[2])
        end

        vim.g.multinormalModeExit = false
        require('libmodal').mode.enter('MultiNormal', {
            -- Enter visual mode
            ['v'] = function()
                if start_multi_visual(false) then
                    start_multi_insert()
                end
            end,
            -- Enter insert mode without offset
            ['i'] = function()
                start_multi_insert()
            end,
            -- Enter insert mode with an offset
            ['a'] = function()
                start_multi_insert(1)
            end,
            -- Undo
            ['u'] = function()
                vim.cmd('normal! u')
            end,
            [k '<BS>'] = function()
                for_each_normal_cursor_reposition_single("norm! h")
            end,
            [k '<Del>'] = function()
                for_each_normal_cursor_reposition_single(k "norm! <Del>")
            end,
            [k '<Left>'] = function()
                for_each_normal_cursor_reposition_single(k "norm! <Left>")
            end,
            [k '<S-Left>'] = function()
                for_each_normal_cursor_reposition_single(k "norm! <S-Left>")
            end,
            [k '<Right>'] = function()
                for_each_normal_cursor_reposition_single(k "norm! <Right>")
            end,
            [k '<S-Right>'] = function()
                for_each_normal_cursor_reposition_single(k "norm! <S-Right>")
            end,
            [k "<Up>"] = function()
                for_each_normal_cursor_reposition_single(k "norm! <Up>")
            end,
            [k "<Down>"] = function()
                for_each_normal_cursor_reposition_single(k "norm! <Down>")
            end,
            [k 'U'] = function()
                local cursor_position = vim.api.nvim_win_get_cursor(0)
                local current_line = cursor_position[1]
                -- performance optimization
                --local next = next

                while true do
                    current_line = current_line - 1
                    local preivous_line = vim.api.nvim_buf_get_lines(0, current_line - 1, current_line, false)

                    if next(preivous_line) == nil then
                        return
                    end

                    if string.len(preivous_line[1]) >= cursor_position[2] then
                        add_normal_cursor(current_line - 1, cursor_position[2])
                        return
                    end
                end
            end,
            [k 'E'] = function()
                local cursor_position = vim.api.nvim_win_get_cursor(0)
                local current_line = cursor_position[1]
                -- performance optimization
                --local next = next

                while true do
                    local next_line = vim.api.nvim_buf_get_lines(0, current_line, current_line + 1, false)

                    if next(next_line) == nil then
                        return
                    end

                    if string.len(next_line[1]) >= cursor_position[2] then
                        add_normal_cursor(current_line, cursor_position[2])
                        return
                    end

                    current_line = current_line + 1
                end
            end,
            ['e'] = function()
                for_each_normal_cursor_reposition_single("norm! e")
            end,
            ['W'] = function()
                for_each_normal_cursor_reposition_single("norm! W")
            end,
            [k '<Home>'] = function()
                for_each_normal_cursor_reposition_single(k "norm! <Home>")
            end,
            [k '<End>'] = function()
                for_each_normal_cursor_reposition_single(k "norm! <End>")
            end,
            ['o'] = function()
                for_each_normal_cursor_reposition_single("norm! o")
            end,
            ['O'] = function()
                for_each_normal_cursor_reposition_single("norm! O")
            end,
            -- Exit the mode
            [ESC] = Leave,
        }, true)
    end

    Enter()
end

M.setup = function()
    vim.api.nvim_create_user_command("MultiNormalMode", function() start_multi_normal(false) end,
        { desc = "go into multi normal mode", force = false })
    vim.api.nvim_create_user_command("MultiVisualMode", function() start_multi_normal(true) end,
        { desc = "go into multi visual mode", force = false })
    vim.api.nvim_create_user_command("MultiFromRegex", function(table)
            if string.len(table.args) > 0 then
                start_multi_normal(true, table.args)
            end
        end,
        { desc = "go into multi visual mode based on a regex", force = false, nargs = 1 })
end

return M
