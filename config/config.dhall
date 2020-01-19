let Action = ./actions.dhall
in let Tiler = ./tilers.dhall
in {
  startupScript = "~/.config/xest/startup.sh",
  keyBindings = [
    {key = "t", mode = "Normal", actions = [Action.RunCommand "kitty"]},
    {key = "d", mode = "Normal", actions = [Action.RunCommand "rofi -show drun"]},
    {key = "v", mode = "Normal", actions = [Action.Insert Tiler.Rotate]},
    {key = "f", mode = "Normal", actions = [Action.Insert Tiler.FullScreen]},
    {key = "h", mode = "Normal", actions = [Action.Insert Tiler.Hovering]},
    {key = "n", mode = "Normal", actions = [Action.Insert Tiler.Horizontal]},
    {key = "i", mode = "NormalS", actions = [Action.ZoomInInput]},
    {key = "i", mode = "Normal", actions = [Action.ZoomInInput]},
    {key = "Super_L", mode = "Insert", actions = [Action.ChangeModeTo "Normal"]},
    {key = "Shift_L", mode = "Normal", actions = [Action.ChangeModeTo "NormalS"]},
    {key = "Escape", mode = "NormalS", actions = [Action.ChangeModeTo "Normal"]},
    {key = "Escape", mode = "Normal", actions = [Action.ChangeModeTo "Insert"]},
    {key = "Escape", mode = "Resize", actions = [Action.ChangeModeTo "Normal"]},
    {key = "o", mode = "Normal", actions = [Action.ZoomOutInput]},
    {key = "o", mode = "NormalS", actions = [Action.ZoomOutInput]},
    {key = "Left", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.Move True, Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "Right", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.Move False, Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "Left", mode = "NormalS", actions = [Action.Move True]},
    {key = "Right", mode = "NormalS", actions = [Action.Move False]},
    {key = "1", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.ChangeNamed "1", Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "2", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.ChangeNamed "2", Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "3", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.ChangeNamed "3", Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "4", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.ChangeNamed "4", Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "5", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.ChangeNamed "5", Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "6", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.ChangeNamed "6", Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "7", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.ChangeNamed "7", Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "8", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.ChangeNamed "8", Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "9", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.ChangeNamed "9", Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "1", mode = "NormalS", actions = [Action.ChangeNamed "1"]},
    {key = "2", mode = "NormalS", actions = [Action.ChangeNamed "2"]},
    {key = "3", mode = "NormalS", actions = [Action.ChangeNamed "3"]},
    {key = "4", mode = "NormalS", actions = [Action.ChangeNamed "4"]},
    {key = "5", mode = "NormalS", actions = [Action.ChangeNamed "5"]},
    {key = "6", mode = "NormalS", actions = [Action.ChangeNamed "6"]},
    {key = "7", mode = "NormalS", actions = [Action.ChangeNamed "7"]},
    {key = "8", mode = "NormalS", actions = [Action.ChangeNamed "8"]},
    {key = "9", mode = "NormalS", actions = [Action.ChangeNamed "9"]},
    {key = "y", mode = "Normal", actions = [Action.PopTiler]},
    -- {key = "u", mode = "Normal", actions = [Action.ChangeLayoutTo Tiler.Floating]},
    {key = "p", mode = "Normal", actions = [Action.PushTiler]},
    {key = "r", mode = "Normal", actions = [Action.ChangeModeTo "Resize"]},
    {key = "s", mode = "Normal", actions = [Action.ZoomOutMonitor, Action.ZoomOutInput Action.MakeSpecial, Action.ZoomInInput, Action.ZoomMonitorToInput]},
    {key = "s", mode = "NormalS", actions = [Action.MakeSpecial]},
    {key = "m", mode = "Normal", actions = [Action.KillActive]},
    {key = "z", mode = "Normal", actions = [Action.ZoomMonitorToInput]},
    {key = "z", mode = "NormalS", actions = [Action.ZoomInMonitor]},
    {key = "b", mode = "NormalS", actions = [Action.Exit]},
    {key = "w", mode = "Normal", actions = [Action.ToggleLogging]},
    {key = "q", mode = "Normal", actions = [Action.ZoomOutMonitor]}
  ],
  definedModes = [
    { modeName = "Insert", introActions = [Action.HideWindow "Polybar", Action.ZoomInputToMonitor], exitActions = [Action.ShowWindow "Polybar"], hasButtons = False, hasBorders = False },
    { modeName = "Resize", introActions = [] : List ./actions.dhall, exitActions = [] : List ./actions.dhall, hasButtons = True, hasBorders = True },
    { modeName = "NormalS", introActions = [] : List ./actions.dhall, exitActions = [] : List ./actions.dhall, hasButtons = False, hasBorders = True },
    { modeName = "Normal", introActions = [] : List ./actions.dhall, exitActions = [] : List ./actions.dhall, hasButtons = False, hasBorders = True}
  ]
}
