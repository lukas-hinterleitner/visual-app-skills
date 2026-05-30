# Driving the UI without writing tests

For iterate-fast visual verification you usually don't need an instrumentation
test — `adb shell input` is enough to reach the screen under test. All commands
take `-s <id>` when more than one device is attached.

```bash
adb -s <id> shell input tap <x> <y>                       # tap
adb -s <id> shell input swipe <x1> <y1> <x2> <y2> 300     # swipe over 300ms
adb -s <id> shell input text "hello"                      # type into focused field
adb -s <id> shell input keyevent KEYCODE_BACK             # system back
adb -s <id> shell input keyevent KEYCODE_ENTER            # enter/submit
adb -s <id> shell input keyevent 82                       # open the dev menu (RN/Expo)
```

## Finding tap coordinates

Coordinates are **physical pixels**. Get the device resolution first:

```bash
adb -s <id> shell wm size        # e.g. "Physical size: 1080x2400"
```

Then the practical loop: take a screenshot, read the PNG, eyeball the target,
tap. This is faster than parsing a UI tree for a one-shot manual check.

If you do need exact bounds (small or ambiguous targets), dump the view tree:

```bash
adb -s <id> exec-out uiautomator dump /dev/tty   # XML with bounds="[l,t][r,b]"
```

Tap the center of a `bounds` rectangle. Note that `uiautomator dump` reflects
the native accessibility tree — it sees native Views and (with semantics
enabled) Compose/Flutter/RN nodes, but custom-painted canvases may expose
little, so fall back to screenshot-and-eyeball there.

## Text entry caveats

`input text` doesn't handle spaces or special characters well in one call —
use `%s` for a space, or send words separately. For anything beyond trivial
input, tap the field first so it has focus, then type.

## Permission dialogs

A first-launch camera/mic/location/photos prompt will steal focus and sit on
top of your screen. Either pre-grant before launching:

```bash
adb -s <id> shell pm grant <applicationId> android.permission.CAMERA
```

or screenshot the prompt and tap "Allow" / "While using the app" by
coordinate. (Avoid triggering system dialogs you then have to dismiss blindly.)
