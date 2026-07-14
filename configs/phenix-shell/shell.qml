//@ pragma UseQApplication
import QtQuick
import Quickshell
import "./services"
import "./utils"

ShellRoot {
    property ShellState shellState: ShellState
    property Stats stats: Stats
    property DevLogger devLogger: DevLogger {}
}
