import QtQuick
import Quickshell.Io

Row {
    id: root
    spacing: 6

    property string themeRed:   "#B80000"
    property string themeBg:    "#141414"
    property string themeText:  "#E6E6E6"
    property string themeMuted: "#A8A8A8"
    property string themeIdle:  "#1A1A1A"
    property string focusedText:"#0B0B0B"
    property int borderWidth: 1

    property string backend: "none"

    ListModel { id: wsModel }

    Process { id: focusProc }

    Process {
        id: wsProc
        command: ["sh", "-lc",
            "command -v python3 >/dev/null 2>&1 || { echo '{\"backend\":\"none\",\"workspaces\":[]}'; exit 0; }; " +
            "python3 - <<'PY'\n" +
            "import json, shutil, subprocess, sys\n" +
            "\n" +
            "def run(cmd):\n" +
            "    try:\n" +
            "        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, check=False)\n" +
            "        return (p.returncode, (p.stdout or '').strip())\n" +
            "    except Exception:\n" +
            "        return (1, '')\n" +
            "\n" +
            "def emit(backend, workspaces):\n" +
            "    sys.stdout.write(json.dumps({\"backend\": backend, \"workspaces\": workspaces}, separators=(',', ':')))\n" +
            "\n" +
            "# Prefer niri when available and responsive\n" +
            "if shutil.which('niri'):\n" +
            "    rc, out = run(['niri', 'msg', '--json', 'workspaces'])\n" +
            "    if rc == 0 and out:\n" +
            "        try:\n" +
            "            data = json.loads(out)\n" +
            "            if isinstance(data, list):\n" +
            "                wss = []\n" +
            "                for w in data:\n" +
            "                    if not isinstance(w, dict):\n" +
            "                        continue\n" +
            "                    idx = w.get('idx')\n" +
            "                    try:\n" +
            "                        idx = int(idx)\n" +
            "                    except Exception:\n" +
            "                        continue\n" +
            "                    # Keep indices >= 1 (common convention)\n" +
            "                    if idx < 1:\n" +
            "                        continue\n" +
            "                    wss.append({\n" +
            "                        \"idx\": idx,\n" +
            "                        \"name\": (w.get('name') or ''),\n" +
            "                        \"is_focused\": bool(w.get('is_focused')),\n" +
            "                        \"is_active\":  bool(w.get('is_active')),\n" +
            "                        \"is_urgent\":  bool(w.get('is_urgent')),\n" +
            "                    })\n" +
            "                wss.sort(key=lambda x: x.get('idx', 0))\n" +
            "                emit('niri', wss)\n" +
            "                sys.exit(0)\n" +
            "        except Exception:\n" +
            "            pass\n" +
            "\n" +
            "# Fallback: Hyprland\n" +
            "if shutil.which('hyprctl'):\n" +
            "    rcw, outw = run(['hyprctl', '-j', 'workspaces'])\n" +
            "    rca, outa = run(['hyprctl', '-j', 'activeworkspace'])\n" +
            "    try:\n" +
            "        wdata = json.loads(outw) if outw else []\n" +
            "    except Exception:\n" +
            "        wdata = []\n" +
            "    try:\n" +
            "        adata = json.loads(outa) if outa else {}\n" +
            "    except Exception:\n" +
            "        adata = {}\n" +
            "\n" +
            "    active_id = None\n" +
            "    if isinstance(adata, dict):\n" +
            "        aid = adata.get('id')\n" +
            "        try:\n" +
            "            active_id = int(aid)\n" +
            "        except Exception:\n" +
            "            active_id = None\n" +
            "\n" +
            "    wss = []\n" +
            "    if isinstance(wdata, list):\n" +
            "        for w in wdata:\n" +
            "            if not isinstance(w, dict):\n" +
            "                continue\n" +
            "            wid = w.get('id')\n" +
            "            try:\n" +
            "                idx = int(wid)\n" +
            "            except Exception:\n" +
            "                continue\n" +
            "            # Ignore special/negative workspace ids by default\n" +
            "            if idx < 1:\n" +
            "                continue\n" +
            "            name = (w.get('name') or '')\n" +
            "            windows = w.get('windows', 0)\n" +
            "            try:\n" +
            "                windows = int(windows)\n" +
            "            except Exception:\n" +
            "                windows = 0\n" +
            "            is_focused = (active_id is not None and idx == active_id)\n" +
            "            is_active = (windows > 0) or is_focused\n" +
            "            wss.append({\n" +
            "                \"idx\": idx,\n" +
            "                \"name\": name,\n" +
            "                \"is_focused\": bool(is_focused),\n" +
            "                \"is_active\":  bool(is_active),\n" +
            "                \"is_urgent\":  False,\n" +
            "            })\n" +
            "\n" +
            "    wss.sort(key=lambda x: x.get('idx', 0))\n" +
            "    emit('hyprland', wss)\n" +
            "    sys.exit(0)\n" +
            "\n" +
            "emit('none', [])\n" +
            "PY"
        ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const raw = (this.text || "").trim()
                if (!raw) return

                let payload
                try { payload = JSON.parse(raw) } catch (e) { return }
                if (!payload || typeof payload !== "object") return

                const be = (payload.backend || "none")
                const arr = payload.workspaces
                if (!Array.isArray(arr)) return

                root.backend = be

                wsModel.clear()
                for (let i = 0; i < arr.length; i++) {
                    const w = arr[i]
                    if (!w || typeof w !== "object") continue
                    wsModel.append({
                        idx: w.idx,
                        name: w.name ?? "",
                        is_focused: !!w.is_focused,
                        is_active:  !!w.is_active,
                        is_urgent:  !!w.is_urgent
                    })
                }
            }
        }
    }

    Timer {
        interval: 500

        running: true
        repeat: true
        onTriggered: wsProc.exec(wsProc.command)
    }

    Component.onCompleted: wsProc.exec(wsProc.command)

    Repeater {
        model: wsModel

        Rectangle {
            width: 18
            height: 18
            radius: 5
            antialiasing: true

            color: (model.is_focused || model.is_urgent) ? root.themeRed
                  : model.is_active ? root.themeBg
                  : root.themeIdle

            border.width: root.borderWidth
            border.color: (model.is_focused || model.is_urgent) ? root.themeMuted : root.themeMuted

            Text {
                anchors.centerIn: parent
                text: (model.name && model.name.length) ? model.name : String(model.idx)

                color: (model.is_focused || model.is_urgent) ? "#FFFFFF" : root.themeText
                font.pixelSize: 10
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.backend === "niri") {
                        focusProc.command = ["niri", "msg", "action", "focus-workspace", String(model.idx)]
                        focusProc.exec(focusProc.command)
                    } else if (root.backend === "hyprland") {
                        focusProc.command = ["hyprctl", "dispatch", "workspace", String(model.idx)]
                        focusProc.exec(focusProc.command)
                    }
                }
            }
        }
    }
}

