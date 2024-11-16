local wezterm = require 'wezterm'

local config = {}

local resurrect = wezterm.plugin.require("https://github.com/MLFlexer/resurrect.wezterm")

if wezterm.config_builder then
    config = wezterm.config_builder()
end

-- resurrect.wezterm periodic save every 5 minutes
resurrect.periodic_save({
    interval_seconds = 300,
    save_tabs = true,
    save_windows = true,
    save_workspaces = true
})

-- Save only 5000 lines per pane
resurrect.set_max_nlines(5000)
-- カラースキームの設定
config.color_scheme = 'AdventureTime'

-- 透明度
config.window_background_opacity = 0.9

-- Default OS
-- config.default_domain = 'WSL:Ubuntu-22.04'
config.default_prog = {'nu'}

-- タブの設定
config.use_fancy_tab_bar = true
config.show_tabs_in_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false
config.show_close_tab_button_in_tabs = false

-- スクロールバー
config.enable_scroll_bar = true

-- 表示領域
config.initial_rows = 36
config.initial_cols = 120

-- カーソル
config.default_cursor_style = 'BlinkingUnderline'

-- フォントサイズの設定
config.font_size = 14

-- マウス操作の挙動設定
config.mouse_bindings = { -- 右クリックでクリップボードから貼り付け
{
    event = {
        Down = {
            streak = 1,
            button = 'Right'
        }
    },
    mods = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard'
}}

-- リーダーキーの設定
config.leader = {
    key = 'a',
    mods = 'CTRL',
    timeout_milliseconds = 1000
}

-- ショートカットキー設定
local act = wezterm.action
config.keys = { -- Alt(Opt)+Shift+Fでフルスクリーン切り替え
{
    key = 'f',
    mods = 'SHIFT|META',
    action = wezterm.action.ToggleFullScreen
}, -- wslのタブを追加する
{
    key = 't',
    mods = 'SHIFT|ALT',
    action = wezterm.action.SpawnTab {
        DomainName = 'WSL:Ubuntu-22.04'
    }
}, -- タブを垂直分割のタブを追加する
{
    key = '+',
    mods = 'SHIFT|ALT',
    action = wezterm.action {
        SplitVertical = {
            domain = "CurrentPaneDomain"
        }
    }
}, {
    key = '*',
    mods = 'SHIFT|ALT',
    action = wezterm.action {
        SplitHorizontal = {
            domain = "CurrentPaneDomain"
        }
    }
}, -- workspace関連
{
    -- 新しいwindowを作成する
    mods = 'LEADER',
    key = 'w',
    action = act.PromptInputLine {
        description = "(wezterm) Create new workspace:",
        action = wezterm.action_callback(function(window, pane, line)
            if line then
                window:perform_action(act.SwitchToWorkspace {
                    name = line
                }, pane)
            end
        end)
    }
}, {
    mods = 'LEADER',
    key = 'l',
    action = wezterm.action_callback(function(win, pane)
        -- workspace のリストを作成
        local workspaces = {}
        for i, name in ipairs(wezterm.mux.get_workspace_names()) do
            table.insert(workspaces, {
                id = name,
                label = string.format("%d. %s", i, name)
            })
        end
        local current = wezterm.mux.get_active_workspace()
        -- 選択メニューを起動
        win:perform_action(act.InputSelector {
            action = wezterm.action_callback(function(_, _, id, label)
                if not id and not label then
                    wezterm.log_info "Workspace selection canceled" -- 入力が空ならキャンセル
                else
                    win:perform_action(act.SwitchToWorkspace {
                        name = id
                    }, pane) -- workspace を移動
                end
            end),
            title = "Select workspace",
            choices = workspaces,
            fuzzy = true
            -- fuzzy_description = string.format("Select workspace: %s -> ", current), -- requires nightly build
        }, pane)
    end)
}, {
    -- Save current and window state
    -- See https://github.com/MLFlexer/resurrect.wezterm for options around
    -- saving workspace and window state separately
    key = 'S',
    mods = 'LEADER|SHIFT',
    action = wezterm.action_callback(function(win, pane) -- luacheck: ignore 212
        local state = resurrect.workspace_state.get_workspace_state()
        resurrect.save_state(state)
        resurrect.window_state.save_window_action()
    end)
}, {
    -- Load workspace or window state, using a fuzzy finder
    key = 'L',
    mods = 'LEADER|SHIFT',
    action = wezterm.action_callback(function(win, pane)
        resurrect.fuzzy_load(win, pane, function(id, label) -- luacheck: ignore 212
            local type = string.match(id, "^([^/]+)") -- match before '/'
            id = string.match(id, "([^/]+)$") -- match after '/'
            id = string.match(id, "(.+)%..+$") -- remove file extension

            local opts = {
                window = win:mux_window(),
                relative = true,
                restore_text = true,
                on_pane_restore = resurrect.tab_state.default_on_pane_restore
            }
            if type == "workspace" then
                local state = resurrect.load_state(id, "workspace")
                resurrect.workspace_state.restore_workspace(state, opts)
            elseif type == "window" then
                local state = resurrect.load_state(id, "window")
                -- opts.tab = win:active_tab()
                resurrect.window_state.restore_window(pane:window(), state, opts)
            elseif type == "tab" then
                local state = resurrect.load_state(id, "tab")
                resurrect.tab_state.restore_tab(pane:tab(), state, opts)
            end
        end)
    end)
}, {
    -- Delete a saved session using a fuzzy finder
    key = 'd',
    mods = 'LEADER|SHIFT',
    action = wezterm.action_callback(function(win, pane)
        resurrect.fuzzy_load(win, pane, function(id)
            resurrect.delete_state(id)
        end, {
            title = 'Delete State',
            description = 'Select session to delete and press Enter = accept, Esc = cancel, / = filter',
            fuzzy_description = 'Search session to delete: ',
            is_fuzzy = true
        })
    end)
}, {
    -- 次のworkspaceに移動
    key = 'n',
    mods = 'CTRL',
    action = act.SwitchWorkspaceRelative(1)
}, {
    -- 前のworkspaceに移動
    key = 'p',
    mods = 'CTRL',
    action = act.SwitchWorkspaceRelative(-1)
}}

return config

