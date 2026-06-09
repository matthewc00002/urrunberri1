#!/bin/bash
# =============================================================================
#  UrrunBerri OS — Boot Script
#  Debian 13 Trixie — Root user — xfreerdp3
#  Author : Mathieu Cadi — Openema SARL
#  GitHub : https://github.com/matthewc00002/urrunberri1
# =============================================================================

CONFIG="/etc/urrunberri-os/config.conf"
[[ -f "$CONFIG" ]] && source "$CONFIG"

RESOLUTION="${RESOLUTION:-1920x1080}"
DISPLAY=":0"
XAUTHORITY="/var/run/lightdm/root/:0"
export DISPLAY XAUTHORITY

SAVED_FILE="/etc/urrunberri-os/saved_connections.csv"
SERVER_SCRIPT="/opt/urrunberri-os/scripts/urrunberri_server.py"
ACTION_FILE="/tmp/urrunberri_action.txt"
RESULT_FILE="/tmp/urrunberri_login.txt"
RDP_PID=""
SERVER_PID=""

# ── INIT ──────────────────────────────────────────────────────────────────────
pkill -f urrunberri_server.py 2>/dev/null || true
pkill chromium 2>/dev/null || true
pkill zenity 2>/dev/null || true
sleep 1

xhost + 2>/dev/null || true
xsetroot -solid "#eef2f7" 2>/dev/null || true
mkdir -p /etc/urrunberri-os
touch "$SAVED_FILE" 2>/dev/null || true

# ── DETECT XFREERDP ───────────────────────────────────────────────────────────
XFREERDP_BIN=""
for bin in xfreerdp3 /usr/bin/xfreerdp3 xfreerdp2 /usr/bin/xfreerdp2 xfreerdp /usr/local/bin/xfreerdp; do
    if command -v "$bin" &>/dev/null; then
        XFREERDP_BIN="$bin"
        break
    fi
done
[[ -z "$XFREERDP_BIN" ]] && XFREERDP_BIN="xfreerdp3"
echo "[UrrunBerri OS] xfreerdp: $XFREERDP_BIN"

# ── START PYTHON API SERVER ───────────────────────────────────────────────────
python3 "$SERVER_SCRIPT" &
SERVER_PID=$!
sleep 1
echo "[UrrunBerri OS] Serveur Python PID: $SERVER_PID"

# ── ENSURE SERVER IS RUNNING ──────────────────────────────────────────────────
ensure_server() {
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "[UrrunBerri OS] Redemarrage serveur Python..."
        python3 "$SERVER_SCRIPT" &
        SERVER_PID=$!
        sleep 1
    fi
}

# ── WAIT FOR ACTION ───────────────────────────────────────────────────────────
wait_for_action() {
    rm -f "$ACTION_FILE" "$RESULT_FILE"
    while true; do
        if ! kill -0 "$CHROMIUM_PID" 2>/dev/null; then
            return 2
        fi
        sleep 0.3
        [[ -f "$ACTION_FILE" ]] && break
    done
    return 0
}

# ── SHOW LOGIN PAGE ───────────────────────────────────────────────────────────
show_login() {
    rm -f "$ACTION_FILE" "$RESULT_FILE"

    ensure_server

    SCR_W=${RESOLUTION%%x*}
    SCR_H=${RESOLUTION##*x}
    WIN_W=520; WIN_H=820
    POS_X=$(( (SCR_W - WIN_W) / 2 ))
    POS_Y=$(( (SCR_H - WIN_H) / 2 ))

    xsetroot -solid "#eef2f7" 2>/dev/null || true

    chromium \
        --app="http://127.0.0.1:7070/splash/login.html" \
        --window-size=${WIN_W},${WIN_H} \
        --window-position=${POS_X},${POS_Y} \
        2>/dev/null &
    CHROMIUM_PID=$!

    wait_for_action
    local wait_ret=$?

    if [[ $wait_ret -eq 2 ]]; then
        echo "[UrrunBerri OS] Chromium mort — redemarrage..."
        return 1
    fi

    kill $CHROMIUM_PID 2>/dev/null || true
    sleep 0.5

    ACTION=$(cat "$ACTION_FILE" 2>/dev/null)

    if [[ "$ACTION" == "shutdown" ]]; then
        kill $SERVER_PID 2>/dev/null || true
        sleep 1
        systemctl poweroff
        exit 0
    fi

    if [[ "$ACTION" == "reboot" ]]; then
        kill $SERVER_PID 2>/dev/null || true
        sleep 1
        systemctl reboot
        exit 0
    fi

    [[ "$ACTION" == "close" ]] && { kill $SERVER_PID 2>/dev/null; exit 0; }

    if [[ "$ACTION" == "terminal" ]]; then
        xterm -bg "#eef2f7" -fg "#1a2744" -fa "Monospace" -fs 12 \
            -title "UrrunBerri OS — Terminal" 2>/dev/null &
        return 1
    fi

    if [[ "$ACTION" == "connect" && -f "$RESULT_FILE" ]]; then
        local data; data=$(cat "$RESULT_FILE")
        CONN_HOST=$(echo "$data" | cut -d'|' -f1)
        CONN_PORT=$(echo "$data" | cut -d'|' -f2)
        USERNAME=$(echo "$data"  | cut -d'|' -f3)
        PASSWORD=$(echo "$data"  | cut -d'|' -f4)
        DOMAIN=$(echo "$data"    | cut -d'|' -f5)
        PROTOCOL=$(echo "$data"  | cut -d'|' -f7)
        RES=$(echo "$data"       | cut -d'|' -f8)
        MULTIMON=$(echo "$data"  | cut -d'|' -f9)

        [[ -z "$CONN_HOST" || -z "$USERNAME" ]] && return 1
        [[ -z "$CONN_PORT" ]] && CONN_PORT=3389
        [[ -z "$PROTOCOL" ]] && PROTOCOL=rdp
        [[ -n "$RES" && "$RES" != "undefined" && "$RES" != "auto" ]] && RESOLUTION="$RES"

        if [[ "$RES" == "auto" ]]; then
            RESOLUTION=$(DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 xrandr 2>/dev/null | grep '\*' | awk '{print $1}' | head -1)
            [[ -z "$RESOLUTION" ]] && RESOLUTION="1920x1080"
            echo "[UrrunBerri OS] Resolution auto: $RESOLUTION"
        fi

        if [[ -z "$PASSWORD" ]]; then
            PASSWORD=$(zenity --password \
                --title="UrrunBerri OS" \
                --text="Mot de passe pour ${USERNAME}@${CONN_HOST}" \
                2>/dev/null)
            [[ -z "$PASSWORD" ]] && return 1
        fi
        return 0
    fi
    return 1
}

# ── DISCONNECT BUTTON ─────────────────────────────────────────────────────────
show_disconnect_btn() {
    (
        zenity --question \
            --title="UrrunBerri OS" \
            --text="Session active\n${CONN_HOST}:${CONN_PORT}\nUtilisateur : ${USERNAME}\n\nFermer la session ?" \
            --ok-label="Fermer" --cancel-label="Continuer" \
            --width=300 2>/dev/null
        [[ $? -eq 0 ]] && kill "$RDP_PID" 2>/dev/null || true
    ) &
    DISCONNECT_PID=$!
}

# ── MAIN LOOP ─────────────────────────────────────────────────────────────────
while true; do
    xsetroot -solid "#eef2f7" 2>/dev/null || true

    if ! show_login; then
        sleep 1
        continue
    fi

    echo "[UrrunBerri OS] Connexion $PROTOCOL → ${CONN_HOST}:${CONN_PORT} (${USERNAME}) @ ${RESOLUTION}"

    DOMAIN_ARG=""
    [[ -n "$DOMAIN" ]] && DOMAIN_ARG="/d:${DOMAIN}"
    MULTIMON_ARG=""
    [[ "$MULTIMON" == "1" ]] && MULTIMON_ARG="/multimon"

    case "$PROTOCOL" in
        rdp)
            $XFREERDP_BIN \
                /v:${CONN_HOST}:${CONN_PORT} \
                /u:${USERNAME} \
                /p:${PASSWORD} \
                ${DOMAIN_ARG} \
                /size:${RESOLUTION} \
                /cert:ignore \
                /clipboard /fonts \
                ${MULTIMON_ARG} \
                /log-level:ERROR &
            RDP_PID=$!
            ;;
        vnc)
            vncviewer "${CONN_HOST}:${CONN_PORT}" -FullColor -FullScreen 2>/dev/null &
            RDP_PID=$!
            ;;
        ssh)
            xterm -fullscreen -bg "#eef2f7" -fg "#1a2744" \
                -fa "Monospace" -fs 12 \
                -title "SSH — ${CONN_HOST}" \
                -e "ssh ${USERNAME}@${CONN_HOST} -p ${CONN_PORT}" 2>/dev/null &
            RDP_PID=$!
            ;;
    esac

    sleep 3
    show_disconnect_btn
    wait $RDP_PID 2>/dev/null
    kill $DISCONNECT_PID 2>/dev/null || true
    RDP_PID=""
    echo "[UrrunBerri OS] Deconnecte."
    sleep 2
done
