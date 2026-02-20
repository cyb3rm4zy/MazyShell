import Quickshell
import QtQuick

import qs.config
import qs.services as S
import qs.modules.bar
import qs.modules.sidebar
import qs.modules.edge
import qs.modules.wallpaper

ShellRoot {

    Config { id: cfg }

    Variants {
        model: Quickshell.screens

        Scope {
            required property var modelData

            S.SidebarState { id: state; config: cfg }
            WallpaperWindow { config: cfg; screenRef: modelData }

            Bar { config: cfg; sidebarState: state; screenRef: modelData }

            Sidebar { config: cfg; sidebarState: state; screen: modelData }

            OppositeTopCorner { config: cfg; screen: modelData }
        }
    }
}
