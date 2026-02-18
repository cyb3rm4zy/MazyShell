import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: launcher
    visible: false

    implicitWidth: 700
    implicitHeight: 600

    margins {
        left: screen ? Math.round((screen.width - implicitWidth) / 2) : 0
        top: screen ? Math.round((screen.height - implicitHeight) / 2) : 0
    }

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    focusable: visible
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real contentOpacity: 0
    property real contentScale: 0.9

    Behavior on contentOpacity {
        NumberAnimation {
            duration: launcher.animationDuration || 150
            easing.type: Easing.InOutQuad
        }
    }

    Behavior on contentScale {
        NumberAnimation {
            duration: launcher.animationDuration || 150
            easing.type: Easing.OutCubic
        }
    }

    onVisibleChanged: {
        if (visible) {
            contentOpacity = 1
            contentScale = 1.0
            Qt.callLater(function() {
                searchInput.forceActiveFocus()
            })
        } else {
            contentOpacity = 0
            contentScale = 0.9

        }
    }

    property string bg: "#121212"

    property string bg2: "#1A1A1A"

    property string red: "#B80000"

    property string text: "#E6E6E6"

    property string muted: "#A8A8A8"

    property string borderColor: "#2A2A2A"

    property int borderWidth: 1

    property real barOpacity: 0.90

    property int animationDuration: 150

    signal requestClose()

    Process { id: runner }
    Process { id: usageRecorder }

    ListModel { id: appModel }
    ListModel { id: filteredModel }
    
    property var usageHistory: ({})
    property bool isLoadingApps: false

    property var iconCache: ({})
    property var desktopFileCache: ({})
    property int cacheTimestamp: 0

    function getCurrentScreenName() {

        if (launcher.screen && launcher.screen.name) {
            return launcher.screen.name
        }

        const screens = Quickshell.screens || []
        for (let i = 0; i < screens.length; i++) {
            if (screens[i] === launcher.screen) {
                return screens[i].name || ""
            }
        }
        
        return ""
    }

    function sanitizeScreenName(name) {
        if (!name) return ""

        return name.replace(/[^a-zA-Z0-9_-]/g, "")
    }

    Process {
        id: triggerChecker
        property string currentScreenName: getCurrentScreenName()
        property string safeScreenName: sanitizeScreenName(currentScreenName)
        
        command: ["sh", "-c", 
            "screen_name='" + (safeScreenName || "") + "'; " +
            "trigger_file=''; " +
            "monitor_name=''; " +
            "if [ -n \"$screen_name\" ]; then " +
            "  trigger_file=\"/tmp/quickshell-launcher-trigger-${screen_name}\"; " +
            "  if [ -f \"$trigger_file\" ]; then " +
            "    monitor_name=$(cat \"$trigger_file\" 2>/dev/null || echo ''); " +
            "    rm -f \"$trigger_file\"; " +
            "    if [ -n \"$monitor_name\" ]; then " +
            "      echo \"$monitor_name\"; " +
            "    else " +
            "      echo 'trigger'; " +
            "    fi; " +
            "    exit 0; " +
            "  fi; " +
            "fi; " +
            "if [ -f '/tmp/quickshell-launcher-trigger' ]; then " +
            "  rm -f '/tmp/quickshell-launcher-trigger'; " +
            "  echo 'trigger'; " +
            "else " +
            "  echo ''; " +
            "fi"
        ]
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const text = (this.text || "").trim()
                if (text === 'trigger' || text.length > 0) {

                    if (text.length > 0 && text !== 'trigger') {

                        const monitorFromFile = text.trim()
                        const currentScreenName = triggerChecker.currentScreenName

                        if (monitorFromFile && currentScreenName && 
                            (monitorFromFile === currentScreenName || 
                             monitorFromFile.toLowerCase() === currentScreenName.toLowerCase())) {
                            launcher.visible = !launcher.visible
                        }
                    } else {

                        cursorMonitorDetector.exec(cursorMonitorDetector.command)
                    }
                }
            }
        }
    }

    Process {
        id: cursorMonitorDetector
        command: ["sh", "-c", 
            "if command -v hyprctl >/dev/null 2>&1; then " +
            "  hyprctl monitors -j 2>/dev/null | python3 -c 'import sys,json;d=sys.stdin.read();m=json.loads(d)if d.strip()else[];print(next((x.get(\"name\",\"\")for x in m if x.get(\"focused\")),\"\"))' 2>/dev/null || echo ''; " +
            "elif command -v niri >/dev/null 2>&1; then " +
            "  niri msg focused-output 2>/dev/null | sed -n \"s/.*(\\([^)]*\\)).*/\\1/p\" | head -1 || echo ''; " +
            "else " +
            "  echo ''; " +
            "fi"
        ]
        
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const focusedMonitor = (this.text || "").trim()
                const currentScreenName = getCurrentScreenName()

                if (focusedMonitor && currentScreenName && 
                    (focusedMonitor === currentScreenName || 
                     focusedMonitor.toLowerCase() === currentScreenName.toLowerCase())) {
                    launcher.visible = !launcher.visible
                }
            }
        }
    }
    
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {

            triggerChecker.currentScreenName = getCurrentScreenName()
            triggerChecker.safeScreenName = sanitizeScreenName(triggerChecker.currentScreenName)
            triggerChecker.exec(triggerChecker.command)
        }
    }

    Timer {
        id: scrollResetTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: {
            appFlickable.contentY = 0
        }
    }

    property string searchQuery: ""
    property int selectedIndex: 0
    onSelectedIndexChanged: Qt.callLater(scrollToSelected)

    function scrollToSelected() {
        if (selectedIndex < 0 || selectedIndex >= filteredModel.count) return
        const itemHeight = 48 + 4

        const visibleHeight = appFlickable.height
        const targetY = selectedIndex * itemHeight
        const currentY = appFlickable.contentY

        if (targetY < currentY) {
            appFlickable.contentY = targetY
        } else if (targetY + itemHeight > currentY + visibleHeight) {
            appFlickable.contentY = targetY + itemHeight - visibleHeight
        }
    }

    function recordUsage(exec) {

        const safeExec = exec.replace(/'/g, "'\\''")
        usageRecorder.command = ["sh", "-c", 
            "mkdir -p ~/.cache/quickshell 2>/dev/null || true; " +
            "python3 - <<'PY'\n" +
            "import json, time, os\n" +
            "from pathlib import Path\n" +
            "cache_dir = Path.home() / '.cache' / 'quickshell'\n" +
            "cache_dir.mkdir(parents=True, exist_ok=True)\n" +
            "usage_file = cache_dir / 'app-usage.json'\n" +
            "data = {}\n" +
            "if usage_file.exists():\n" +
            "    try:\n" +
            "        with open(usage_file, 'r') as f:\n" +
            "            data = json.load(f)\n" +
            "    except Exception:\n" +
            "        pass\n" +
            "exec_cmd = '" + safeExec + "'\n" +
            "timestamp = int(time.time())\n" +
            "# Store both exact exec and normalized command name\n" +
            "data[exec_cmd] = timestamp\n" +
            "normalized = os.path.basename(exec_cmd.split()[0]) if exec_cmd else ''\n" +
            "if normalized:\n" +
            "    data[normalized] = timestamp\n" +
            "with open(usage_file, 'w') as f:\n" +
            "    json.dump(data, f, separators=(',', ':'))\n" +
            "PY"
        ]
        usageRecorder.exec(usageRecorder.command)
    }

    function launchApp(exec, name) {
        recordUsage(exec)
        runner.command = ["sh", "-lc", exec + " >/dev/null 2>&1 &"]
        runner.exec(runner.command)
        launcher.visible = false
        searchQuery = ""
        selectedIndex = 0
    }

    function filterApps() {
        filteredModel.clear()
        const query = searchQuery.toLowerCase().trim()
        
        if (!query.length) {
            for (let i = 0; i < appModel.count; i++) {
                filteredModel.append(appModel.get(i))
            }
        } else {
            for (let i = 0; i < appModel.count; i++) {
                const app = appModel.get(i)
                const name = (app.name || "").toLowerCase()
                const keywords = (app.keywords || "").toLowerCase()
                const comment = (app.comment || "").toLowerCase()
                
                if (name.indexOf(query) !== -1 || 
                    keywords.indexOf(query) !== -1 ||
                    comment.indexOf(query) !== -1) {
                    filteredModel.append(app)
                }
            }
        }
        
        selectedIndex = 0
        appFlickable.contentY = 0
        if (filteredModel.count > 0) {
            Qt.callLater(function() {
                appFlickable.contentY = 0
                Qt.callLater(function() {
                    appFlickable.contentY = 0
                })
            })
        }
    }

    Process {
        id: appLoader
        command: ["sh", "-lc",
            "python3 - <<'PY'\n" +
            "import json, os, subprocess, re, time\n" +
            "from pathlib import Path\n" +
            "\n" +
            "# Cache for icon lookups (persists across runs)\n" +
            "cache_dir = Path.home() / '.cache' / 'quickshell'\n" +
            "cache_dir.mkdir(parents=True, exist_ok=True)\n" +
            "icon_cache_file = cache_dir / 'icon-cache.json'\n" +
            "icon_cache = {}\n" +
            "if icon_cache_file.exists():\n" +
            "    try:\n" +
            "        with open(icon_cache_file, 'r') as f:\n" +
            "            icon_cache = json.load(f)\n" +
            "    except Exception:\n" +
            "        icon_cache = {}\n" +
            "\n" +
            "# Cache icon theme lookup (rarely changes)\n" +
            "_icon_theme_cache = None\n" +
            "def get_icon_theme():\n" +
            "    global _icon_theme_cache\n" +
            "    if _icon_theme_cache is not None:\n" +
            "        return _icon_theme_cache\n" +
            "    try:\n" +
            "        result = subprocess.run(['gsettings', 'get', 'org.gnome.desktop.interface', 'icon-theme'],\n" +
            "                              capture_output=True, text=True, timeout=1)\n" +
            "        if result.returncode == 0:\n" +
            "            theme = result.stdout.strip().strip(\"'\\\"\")\n" +
            "            if theme:\n" +
            "                _icon_theme_cache = theme\n" +
            "                return theme\n" +
            "    except Exception:\n" +
            "        pass\n" +
            "    _icon_theme_cache = 'Adwaita'\n" +
            "    return 'Adwaita'\n" +
            "\n" +
            "def find_icon(icon_name):\n" +
            "    if not icon_name:\n" +
            "        return ''\n" +
            "    \n" +
            "    # Check cache first\n" +
            "    if icon_name in icon_cache:\n" +
            "        cached_path = icon_cache[icon_name]\n" +
            "        if cached_path and os.path.exists(cached_path):\n" +
            "            return cached_path\n" +
            "    \n" +
            "    # If it's already a full path, return it\n" +
            "    if os.path.isabs(icon_name) and os.path.exists(icon_name):\n" +
            "        icon_cache[icon_name] = icon_name\n" +
            "        return icon_name\n" +
            "    \n" +
            "    # Get current icon theme (cached)\n" +
            "    current_theme = get_icon_theme()\n" +
            "    \n" +
            "    # Icon themes to search (current theme + hicolor always)\n" +
            "    themes = [current_theme, 'hicolor']\n" +
            "    themes = [t for t in themes if t]\n" +
            "    themes = list(dict.fromkeys(themes))\n" +
            "    \n" +
            "    # Icon directories (most common first)\n" +
            "    icon_dirs = [\n" +
            "        Path('/usr/share/icons'),\n" +
            "        Path.home() / '.local' / 'share' / 'icons',\n" +
            "        Path('/usr/local/share/icons'),\n" +
            "    ]\n" +
            "    \n" +
            "    # Pixmaps directory (no theme structure)\n" +
            "    pixmaps_dirs = [\n" +
            "        Path('/usr/share/pixmaps'),\n" +
            "        Path('/usr/local/share/pixmaps'),\n" +
            "        Path.home() / '.local' / 'share' / 'pixmaps',\n" +
            "    ]\n" +
            "    \n" +
            "    # Sizes to search (reduced set for performance)\n" +
            "    sizes = ['48', '64', 'scalable', '32', '24']\n" +
            "    extensions = ['.png', '.svg', '.xpm']\n" +
            "    \n" +
            "    # First, try pixmaps directories (fastest - direct icon files)\n" +
            "    for pixmaps_dir in pixmaps_dirs:\n" +
            "        if pixmaps_dir.exists():\n" +
            "            for ext in extensions:\n" +
            "                icon_path = pixmaps_dir / (icon_name + ext)\n" +
            "                if icon_path.exists():\n" +
            "                    result = str(icon_path)\n" +
            "                    icon_cache[icon_name] = result\n" +
            "                    return result\n" +
            "    \n" +
            "    # Then search in icon theme directories\n" +
            "    for icon_dir in icon_dirs:\n" +
            "        if not icon_dir.exists():\n" +
            "            continue\n" +
            "        \n" +
            "        # Search each theme\n" +
            "        for theme in themes:\n" +
            "            theme_dir = icon_dir / theme\n" +
            "            if not theme_dir.exists():\n" +
            "                continue\n" +
            "            \n" +
            "            # For hicolor, search all sizes\n" +
            "            if theme == 'hicolor':\n" +
            "                try:\n" +
            "                    for size_dir in theme_dir.iterdir():\n" +
            "                        if not size_dir.is_dir():\n" +
            "                            continue\n" +
            "                        apps_dir = size_dir / 'apps'\n" +
            "                        if apps_dir.exists():\n" +
            "                            for ext in extensions:\n" +
            "                                icon_path = apps_dir / (icon_name + ext)\n" +
            "                                if icon_path.exists():\n" +
            "                                    result = str(icon_path)\n" +
            "                                    icon_cache[icon_name] = result\n" +
            "                                    return result\n" +
            "                except Exception:\n" +
            "                    continue\n" +
            "            else:\n" +
            "                # For other themes, try standard sizes\n" +
            "                for size in sizes:\n" +
            "                    # Try '64x64' format first\n" +
            "                    apps_dir = theme_dir / (size + 'x' + size) / 'apps'\n" +
            "                    if apps_dir.exists():\n" +
            "                        for ext in extensions:\n" +
            "                            icon_path = apps_dir / (icon_name + ext)\n" +
            "                            if icon_path.exists():\n" +
            "                                result = str(icon_path)\n" +
            "                                icon_cache[icon_name] = result\n" +
            "                                return result\n" +
            "                    \n" +
            "                    # Try '64' format\n" +
            "                    apps_dir = theme_dir / size / 'apps'\n" +
            "                    if apps_dir.exists():\n" +
            "                        for ext in extensions:\n" +
            "                            icon_path = apps_dir / (icon_name + ext)\n" +
            "                            if icon_path.exists():\n" +
            "                                result = str(icon_path)\n" +
            "                                icon_cache[icon_name] = result\n" +
            "                                return result\n" +
            "            \n" +
            "            # Try apps directory directly (no size)\n" +
            "            apps_dir = theme_dir / 'apps'\n" +
            "            if apps_dir.exists():\n" +
            "                for ext in extensions:\n" +
            "                    icon_path = apps_dir / (icon_name + ext)\n" +
            "                    if icon_path.exists():\n" +
            "                        result = str(icon_path)\n" +
            "                        icon_cache[icon_name] = result\n" +
            "                        return result\n" +
            "    \n" +
            "    # Cache empty result to avoid repeated searches\n" +
            "    icon_cache[icon_name] = ''\n" +
            "    return ''\n" +
            "\n" +
            "apps = []\n" +
            "desktop_dirs = [\n" +
            "    Path.home() / '.local' / 'share' / 'applications',\n" +
            "    Path('/usr/share/applications'),\n" +
            "    Path('/usr/local/share/applications'),\n" +
            "]\n" +
            "\n" +
            "# Use set for faster lookups\n" +
            "seen_execs = set()\n" +
            "for desktop_dir in desktop_dirs:\n" +
            "    if not desktop_dir.exists():\n" +
            "        continue\n" +
            "    try:\n" +
            "        desktop_files = list(desktop_dir.glob('*.desktop'))\n" +
            "    except Exception:\n" +
            "        continue\n" +
            "    for desktop_file in desktop_files:\n" +
            "        try:\n" +
            "            with open(desktop_file, 'r', encoding='utf-8', errors='ignore') as f:\n" +
            "                content = f.read()\n" +
            "            \n" +
            "            # Skip if NoDisplay or Hidden\n" +
            "            if 'NoDisplay=true' in content or 'Hidden=true' in content:\n" +
            "                continue\n" +
            "            \n" +
            "            # Only include applications\n" +
            "            if 'Type=Application' not in content:\n" +
            "                continue\n" +
            "            \n" +
            "            # Parse desktop file\n" +
            "            name = ''\n" +
            "            exec_cmd = ''\n" +
            "            icon_name = ''\n" +
            "            comment = ''\n" +
            "            keywords = ''\n" +
            "            \n" +
            "            in_desktop_entry = False\n" +
            "            for line in content.split('\\n'):\n" +
            "                line = line.strip()\n" +
            "                if line == '[Desktop Entry]':\n" +
            "                    in_desktop_entry = True\n" +
            "                    continue\n" +
            "                if line.startswith('['):\n" +
            "                    in_desktop_entry = False\n" +
            "                    continue\n" +
            "                if not in_desktop_entry:\n" +
            "                    continue\n" +
            "                \n" +
            "                if line.startswith('Name='):\n" +
            "                    name = line.split('=', 1)[1].strip()\n" +
            "                elif line.startswith('Exec='):\n" +
            "                    exec_cmd = line.split('=', 1)[1].strip()\n" +
            "                    exec_cmd = re.sub(r'%[ufFUdDnNcikvm]', '', exec_cmd).strip()\n" +
            "                elif line.startswith('Icon='):\n" +
            "                    icon_name = line.split('=', 1)[1].strip()\n" +
            "                elif line.startswith('Comment='):\n" +
            "                    comment = line.split('=', 1)[1].strip()\n" +
            "                elif line.startswith('Keywords='):\n" +
            "                    keywords = line.split('=', 1)[1].strip()\n" +
            "            \n" +
            "            if name and exec_cmd:\n" +
            "                # Skip duplicates based on exec\n" +
            "                exec_normalized = exec_cmd.split()[0] if exec_cmd else ''\n" +
            "                if exec_normalized in seen_execs:\n" +
            "                    continue\n" +
            "                seen_execs.add(exec_normalized)\n" +
            "                \n" +
            "                try:\n" +
            "                    icon_path = find_icon(icon_name)\n" +
            "                except Exception:\n" +
            "                    icon_path = ''\n" +
            "                apps.append({\n" +
            "                    'name': name,\n" +
            "                    'exec': exec_cmd,\n" +
            "                    'icon': icon_path,\n" +
            "                    'iconName': icon_name,\n" +
            "                    'comment': comment,\n" +
            "                    'keywords': keywords\n" +
            "                })\n" +
            "        except Exception:\n" +
            "            pass\n" +
            "\n" +
            "# Load usage history\n" +
            "usage_file = cache_dir / 'app-usage.json'\n" +
            "usage_history = {}\n" +
            "if usage_file.exists():\n" +
            "    try:\n" +
            "        with open(usage_file, 'r') as f:\n" +
            "            usage_history = json.load(f)\n" +
            "    except Exception:\n" +
            "        pass\n" +
            "\n" +
            "# Normalize exec command for matching\n" +
            "def normalize_exec(exec_cmd):\n" +
            "    if not exec_cmd:\n" +
            "        return ''\n" +
            "    parts = exec_cmd.split()\n" +
            "    if not parts:\n" +
            "        return ''\n" +
            "    return os.path.basename(parts[0])\n" +
            "\n" +
            "# Add usage timestamp to each app\n" +
            "for app in apps:\n" +
            "    exec_cmd = app.get('exec', '')\n" +
            "    normalized = normalize_exec(exec_cmd)\n" +
            "    app['lastUsed'] = usage_history.get(exec_cmd, usage_history.get(normalized, 0))\n" +
            "\n" +
            "# Sort by last used (most recent first), then by name\n" +
            "apps.sort(key=lambda x: (-x.get('lastUsed', 0), x['name'].lower()))\n" +
            "\n" +
            "# Save icon cache\n" +
            "try:\n" +
            "    with open(icon_cache_file, 'w') as f:\n" +
            "        json.dump(icon_cache, f, separators=(',', ':'))\n" +
            "except Exception:\n" +
            "    pass\n" +
            "\n" +
            "# Output as JSON\n" +
            "print(json.dumps(apps, separators=(',', ':')))\n" +
            "PY"
        ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                launcher.isLoadingApps = false
                const raw = (this.text || "").trim()
                if (!raw) {

                    return
                }

                let apps
                try { 
                    apps = JSON.parse(raw) 
                } catch (e) { 
                    console.log("AppLauncher: JSON parse error:", e)
                    return 
                }
                if (!Array.isArray(apps)) {
                    return
                }
                appModel.clear()
                for (let i = 0; i < apps.length; i++) {
                    const app = apps[i]
                    if (!app || !app.name || !app.exec) continue
                    appModel.append({
                        name: app.name || "",
                        exec: app.exec || "",
                        icon: app.icon || "",
                        iconName: app.iconName || "",
                        comment: app.comment || "",
                        keywords: app.keywords || ""
                    })
                }

                filterApps()
            }
        }
        
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const err = (this.text || "").trim()
                if (err) {
                    console.log("AppLauncher: Python script error:", err)
                }
            }
        }
    }

    Shortcut {
        enabled: launcher.visible
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: {
            launcher.visible = false
            searchQuery = ""
            selectedIndex = 0
        }
    }

    Shortcut {
        enabled: launcher.visible
        sequence: "Return"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (filteredModel.count > 0 && selectedIndex >= 0 && selectedIndex < filteredModel.count) {
                const app = filteredModel.get(selectedIndex)
                launchApp(app.exec, app.name)
            }
        }
    }

    Shortcut {
        enabled: launcher.visible
        sequence: "Up"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (selectedIndex > 0) {
                selectedIndex--
            } else {
                selectedIndex = filteredModel.count - 1
            }
            Qt.callLater(launcher.scrollToSelected)
        }
    }

    Shortcut {
        enabled: launcher.visible
        sequence: "Down"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (selectedIndex < filteredModel.count - 1) {
                selectedIndex++
            } else {
                selectedIndex = 0
            }
            Qt.callLater(launcher.scrollToSelected)
        }
    }

    Item {
        anchors.fill: parent
        opacity: launcher.contentOpacity
        scale: launcher.contentScale
        transformOrigin: Item.Center

        Rectangle {
            anchors.fill: parent
            radius: 14
            antialiasing: true
            color: launcher.bg
            opacity: launcher.barOpacity
            border.color: launcher.red

            border.width: launcher.borderWidth
            z: 0
        }

        Item {
            anchors.fill: parent
            opacity: 1.0
            z: 1
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

            Rectangle {
                width: parent.width
                height: 50
                radius: 12
                color: launcher.bg2
                border.width: launcher.borderWidth
                border.color: launcher.borderColor

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍉"
                        color: launcher.muted
                        font.pixelSize: 20
                    }

                    TextInput {
                        id: searchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        color: launcher.text
                        font.pixelSize: 16
                        selectByMouse: true

                        text: launcher.searchQuery
                        onTextChanged: {
                            launcher.searchQuery = text
                            filterApps()
                        }

                        Keys.onReturnPressed: {
                            if (filteredModel.count > 0 && selectedIndex >= 0 && selectedIndex < filteredModel.count) {
                                const app = filteredModel.get(selectedIndex)
                                launchApp(app.exec, app.name)
                            }
                        }

                        Keys.onEscapePressed: {
                            launcher.visible = false
                            searchQuery = ""
                            selectedIndex = 0
                        }
                    }
                }
            }

            Flickable {
                id: appFlickable
                width: parent.width
                height: parent.height - 66
                clip: true
                contentWidth: width
                contentHeight: appList.implicitHeight

                Column {
                    id: appList
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: filteredModel

                        Rectangle {
                            width: parent.width
                            height: 48
                            radius: 8
                            color: (index === launcher.selectedIndex) ? launcher.bg2 : "transparent"
                            border.width: (index === launcher.selectedIndex) ? launcher.borderWidth : 0
                            border.color: launcher.red

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Item {
                                    width: 24
                                    height: 24
                                    anchors.verticalCenter: parent.verticalCenter

                                    Image {
                                        id: appIcon
                                        anchors.fill: parent
                                        source: model.icon || ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                        visible: model.icon && model.icon.length > 0 && status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰈙"

                                        color: (index === launcher.selectedIndex) ? launcher.red : launcher.text
                                        font.pixelSize: 20
                                        visible: !appIcon.visible || appIcon.status === Image.Error
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 48

                                    Text {
                                        text: model.name || ""
                                        color: (index === launcher.selectedIndex) ? launcher.red : launcher.text
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Text {
                                        text: model.comment || ""
                                        color: launcher.muted
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        width: parent.width
                                        visible: model.comment && model.comment.length > 0
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: launcher.selectedIndex = index
                                onClicked: launchApp(model.exec, model.name)
                            }
                        }
                    }
                }
            }
            }
        }
    }

    Connections {
        target: launcher
        function onVisibleChanged() {
            if (launcher.visible) {
                searchInput.forceActiveFocus()
                selectedIndex = 0

                appFlickable.contentY = 0

                scrollResetTimer.restart()

                if (!isLoadingApps && appModel.count === 0) {
                    isLoadingApps = true
                    appLoader.exec(appLoader.command)
                } else if (!isLoadingApps) {

                    filterApps()
                }
            } else {
                searchQuery = ""
                selectedIndex = 0
                isLoadingApps = false

            }
        }
    }

    Component.onCompleted: {

    }
}

