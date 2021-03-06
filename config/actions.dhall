let Mode = { modeName : Text, hasButtons : Bool, hasBorders : Bool }
let Direction = <Back | Front>
let Actions = < Insert | RunCommand : Text | ChangeModeTo : Mode | ShowWindow : Text | HideWindow : Text | ZoomInInput | ZoomInMonitor | ZoomOutInput | ZoomOutMonitor | PopTiler | PushTiler | ChangeNamed : Text | Move : Direction | KillActive | ExitNow | ToggleLogging | ZoomMonitorToInput | ZoomInputToMonitor | MoveToFront | MakeEmpty | ChangeToFloating | ChangeToHorizontal | SetFull | SetRotate | SetNoMod | ChangeToTwoCols >
in {Actions = Actions, Mode = Mode, Direction = Direction}
