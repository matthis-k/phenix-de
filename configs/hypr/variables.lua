hl.config({
    general = {
        border_size = 2,
        gaps_in = 0,
        gaps_out = 0,
        layout = "scrolling",
    },

    input = {
        kb_layout = "de",
        numlock_by_default = true,

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
        },
    },

    gestures = {
        workspace_swipe_distance = 300,
        workspace_swipe_touch = true,
        workspace_swipe_invert = true,
        workspace_swipe_touch_invert = true,
        workspace_swipe_min_speed_to_force = 30,
        workspace_swipe_cancel_ratio = 0.5,
        workspace_swipe_create_new = true,
        workspace_swipe_direction_lock = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_forever = false,
        workspace_swipe_use_r = false,
        close_max_timeout = 1000,
    },

    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
    },

    scrolling = {
        fullscreen_on_one_column = true,
        column_width = 0.9,
        follow_focus = true,
        direction = "right",
    },

    render = {
        ctm_animation = 2,
    },
})
