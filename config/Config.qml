import QtQuick
import "."
import "../services" as S

QtObject {
    property Appearance appearance: Appearance {}
    property SidebarConfig sidebar: SidebarConfig {}
    property QtObject bar: BarConfig {}

    property S.Wallpapers wallpapers: S.Wallpapers {}
}
