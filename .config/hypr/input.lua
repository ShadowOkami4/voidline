-- -----------------------------------------------------
-- Input
-- -----------------------------------------------------

hl.config({ -- Input configuration
    input = {
        kb_layout  = KeyboardLayout,
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = PointerSensitivity,
        scroll_method = ScrollMethod,
        repeat_rate = RepeatRate,
        repeat_delay = RepeatDelay,

        touchpad = {
            natural_scroll = NaturalScroll,
            tap_to_click = TapToClick,
        },
    },
})
-------------------------------------------------------
-- Gestures
-------------------------------------------------------

-- Workspaces
if WorkspaceSwipe then
    hl.gesture({
        fingers = 3,
        direction = "vertical",
        action = "workspace"
    })
end
