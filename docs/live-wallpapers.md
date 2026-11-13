# Live wallpapers

A Voidline live wallpaper is a small folder with a QML scene. QML is drawn by
the same GPU renderer as the rest of the shell, so a live wallpaper needs no
browser engine and costs far less than an HTML wallpaper, while being just as
free-form: shapes, images, gradients, particles, text, shaders, anything Qt
Quick can draw.

```
~/.local/share/voidline/wallpapers/live/
  my-wallpaper/
    wallpaper.qml     the scene (required)
    wallpaper.json    name and options (optional)
    preview.png       still image for the picker and the colour palette (optional)
    ...               any other files your scene uses (images, more .qml)
```

The folder name is the wallpaper's id. Pick it in Settings → Wallpaper &
colours, or set `"wallpaper": "live:my-wallpaper"` in the config.

> A live wallpaper is a program that runs inside the shell with your user's
> permissions. Only install wallpapers from people you trust.

## wallpaper.qml

The root must be an `Item`; Voidline makes it fill the screen. Declare only the
parts of this contract you need:

| Member | Kind | Meaning |
| --- | --- | --- |
| `property var theme` | set by the shell | Current colours: `primary`, `secondary`, `tertiary`, `primaryContainer`, `tertiaryContainer`, `surface`, `ink` and `dark` (bool). Updates when the theme changes. |
| `property var options` | set by the shell | Values of the options from `wallpaper.json`, by key. Updates live while the user moves a slider. |
| `function advance(dt)` | called by the shell | Called for every frame Voidline wants drawn, with the seconds since the last call. Move your animation forward here. |

Drive all motion from `advance(dt)` rather than from your own `Timer`,
`NumberAnimation` or `FrameAnimation`. That is what lets Voidline cap the frame
rate, pause the wallpaper on battery and stop it completely while windows cover
the desktop. A wallpaper that animates on its own keeps using power when nobody
can see it.

Minimal example:

```qml
import QtQuick

Item {
    id: root
    property var theme: ({})
    property var options: ({})

    property real t: 0
    function advance(dt) { t += dt * (options.speed ?? 1) }

    Rectangle { anchors.fill: parent; color: theme.surface ?? "#101014" }

    Rectangle {
        width: 200; height: 200; radius: 60
        color: theme.primary ?? "#8E6BFF"
        x: root.width / 2 - 100 + Math.sin(root.t) * root.width * 0.3
        y: root.height / 2 - 100
        rotation: root.t * 40
    }
}
```

Tips for cheap wallpapers:

- Paint complex shapes once (a `Canvas` that never repaints, or an image) and
  then only change `x`, `y`, `rotation`, `scale` or `opacity`. Moving a painted
  item is nearly free; repainting a full-screen canvas every frame is not.
- Size things relative to `width` and `height` so the wallpaper works on any
  screen.
- Use repeatable pseudo-random numbers (see `drift/wallpaper.qml`) rather than
  `Math.random()` in bindings, or shapes jump whenever a binding re-evaluates.

## wallpaper.json

```json
{
    "name": "My wallpaper",
    "author": "You",
    "description": "One line shown in Settings.",
    "options": [
        { "key": "speed", "label": "Speed", "type": "slider", "min": 0.1, "max": 3, "step": 0.1, "default": 1 },
        { "key": "rings", "label": "Show rings", "type": "toggle", "default": true },
        { "key": "tint", "label": "Colour", "type": "choice", "default": "theme",
          "choices": [ { "value": "theme", "label": "Theme" }, { "value": "void", "label": "Void" } ] }
    ]
}
```

Every option gets a control in Settings automatically and arrives in
`options.<key>`. `default` is required and decides the value's type (number,
boolean or text). Option types: `slider` (`min`, `max`, `step`), `toggle`,
`choice` (`choices`).

## Performance settings

Under Settings → Wallpaper & colours, for whichever live wallpaper is in use:

| Setting | Config key | Default |
| --- | --- | --- |
| Smoothness | `liveFps` | 30 |
| Pause behind windows | `livePauseWhenCovered` | on |
| Pause on battery | `livePauseOnBattery` | on |

Measured on a Ryzen 7 7840HS at 2560 x 1600, as a share of one CPU core for the
shell process: a still wallpaper 0%, a bundled live wallpaper about 7-8% at
30 fps and about 4% at 15 fps, and 0% while paused.
