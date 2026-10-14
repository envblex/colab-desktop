#!/usr/bin/env bash
# ==============================================================================
# colab-desktop: Automated Debian/Ubuntu XFCE4 + noVNC + Native Firefox Setup
# Repository: https://github.com/envblex/colab-desktop
# License: MIT
# ==============================================================================
set -euo pipefail

RESOLUTION="${1:-1280x720}"
LAUNCH_FIREFOX="${2:-true}"

echo "================================================================="
echo "🚀 Initializing colab-desktop (Resolution: ${RESOLUTION})"
echo "================================================================="

# 1. Install base desktop packages (XFCE4, Xvfb, VNC, noVNC) if missing
if ! command -v xfce4-session >/dev/null 2>&1 || ! command -v x11vnc >/dev/null 2>&1; then
    echo "📦 Installing XFCE4, Xvfb, x11vnc, and noVNC packages ..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        xfce4 xfce4-goodies xfce4-terminal \
        xvfb x11vnc novnc websockify dbus-x11 wget bzip2 >/dev/null
    echo "✓ Desktop packages installed."
else
    echo "✓ Desktop packages already installed."
fi

# 2. Install official Mozilla native Firefox (Bypasses Ubuntu container snapd restrictions)
if ! command -v firefox >/dev/null 2>&1; then
    echo "🦊 Installing official Mozilla Firefox (Native DEB, non-snap) ..."
    install -d -m 0755 /etc/apt/keyrings
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee /etc/apt/sources.list.d/mozilla.list > /dev/null

    cat << 'EOF' > /etc/apt/preferences.d/mozilla
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq firefox >/dev/null
    echo "✓ Mozilla Firefox installed."
else
    echo "✓ Firefox already installed."
fi

# 3. Configure noVNC index.html redirect (Prevents web directory listing)
echo "🔧 Configuring noVNC auto-redirect ..."
cat << 'EOF' > /usr/share/novnc/index.html
<!DOCTYPE html>
<html>
<head>
  <meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&resize=scale">
  <script>window.location.href = "vnc.html?autoconnect=true&resize=scale";</script>
</head>
<body>
  <p>Connecting to XFCE4 Desktop... If not redirected, <a href="vnc.html?autoconnect=true&resize=scale">click here</a>.</p>
</body>
</html>
EOF

# 4. Clean up any previous session processes
echo "🧹 Cleaning up previous desktop instances ..."
killall -9 Xvfb x11vnc websockify xfce4-session 2>/dev/null || true
sleep 1

# 5. Launch detached background daemons
echo "🖥️ Starting virtual display and XFCE4 desktop session ..."
nohup Xvfb :1 -screen 0 "${RESOLUTION}x24" >/dev/null 2>&1 &
sleep 1

nohup env DISPLAY=:1 dbus-launch xfce4-session >/dev/null 2>&1 &
sleep 1

nohup x11vnc -display :1 -nopw -listen localhost -xkb -forever -shared -rfbport 5900 >/dev/null 2>&1 &
sleep 1

nohup websockify --web /usr/share/novnc/ 6080 localhost:5900 >/dev/null 2>&1 &
sleep 1

# 6. Launch Firefox if requested
if [ "${LAUNCH_FIREFOX}" = "true" ]; then
    echo "🌐 Launching Firefox inside desktop session ..."
    nohup env DISPLAY=:1 firefox >/dev/null 2>&1 &
fi

echo "================================================================="
echo "🎉 colab-desktop is ready and listening on port 6080!"
echo "================================================================="
