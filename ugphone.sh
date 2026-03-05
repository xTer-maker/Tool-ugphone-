#!/bin/bash

# 1. Kiểm tra và cài đặt môi trường
for pkg in wget jq curl python; do
    if ! command -v $pkg &> /dev/null; then
        echo -e "\e[1;30m[Hệ thống]\e[0m Đang chuẩn bị: $pkg..."
        pkg install $pkg -y > /dev/null 2>&1
    fi
done

# 2. Cấu hình
PKG_NAME="net.christianbeier.droidvnc_ng"
INPUT_SVC="net.christianbeier.droidvnc_ng.InputService"
APK_URL="https://github.com/bk138/droidVNC-NG/releases/download/v2.18.0/droidvnc-ng-2.18.0.apk"
NGROK_TOKEN="37sHv5ZlN6vRsRnXK8hrfMPfpIB_2DJ1JAwN3ff2QcHYYuYug"
WEB_PROXY_URL="https://raw.githubusercontent.com/novnc/websockify/v0.10.0/websockify/websocket.py"

clear
echo -e "\e[1;32m●\e[0m \e[1;37mBắt đầu thiết lập VNC Engine...\e[0m"

# 3. Tải và cài đặt (Nếu chưa có)
if ! pm list packages | grep -q "$PKG_NAME"; then
    echo -e "  \e[1;30m- Đang tải ứng dụng VNC...\e[0m"
    wget -q -O vnc.apk $APK_URL
    su -c "pm install -r $PWD/vnc.apk && sync" > /dev/null 2>&1
    rm vnc.apk
fi

# 4. Ép quyền hệ thống (Root)
su -c "
  settings put secure accessibility_enabled 1 && \
  settings put secure enabled_accessibility_services $PKG_NAME/$INPUT_SVC && \
  appops set $PKG_NAME PROJECT_MEDIA allow && \
  appops set $PKG_NAME SYSTEM_ALERT_WINDOW allow
" > /dev/null 2>&1

echo -e "\e[1;32m●\e[0m \e[1;37mThiết lập hoàn tất!\e[0m"
echo -e "\e[1;33m⚠️  Bây giờ bạn hãy tự mở ứng dụng VNC ngoài màn hình chính.\e[0m"

# --- PHẦN NHẬP LIỆU CHUẨN (KHÔNG TỰ THOÁT) ---
# Xả sạch bộ đệm rác để không bị trôi lệnh
while read -t 0.1 -n 10000; do :; done

while true; do
    echo -ne "\n    \033[1;36m❯\033[0m \033[1;37mGõ \033[1;32mopen\033[1;37m để khởi chạy Ngrok & lấy link:\033[0m "
    # Đọc trực tiếp từ tty để cưỡng ép script đứng đợi bàn phím
    read -r DATA </dev/tty
    
    # Làm sạch dữ liệu nhập (xóa dấu cách, chuyển chữ thường)
    DATA=$(echo "$DATA" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    
    if [[ "$DATA" == "open" ]]; then 
        break 
    elif [[ -z "$DATA" ]]; then
        continue # Nếu nhấn Enter trống thì hiện lại dòng nhắc
    else
        echo -e "    \033[1;31m✘ Lệnh '$DATA' không đúng. Vui lòng nhập 'open'.\033[0m"
    fi
done
# ---------------------------------------------

echo -e "    \e[1;32m●\e[0m \e[1;37mĐang kích hoạt cổng truyền tải...\e[0m"

# 5. Chạy Websockify & Ngrok
[ ! -f "websockify.py" ] && wget -q -O websockify.py $WEB_PROXY_URL
python websockify.py --daemon 8080 localhost:5900 > /dev/null 2>&1

./ngrok config add-authtoken $NGROK_TOKEN > /dev/null 2>&1
cat <<EOF > ngrok_vnc.yml
authtoken: $NGROK_TOKEN
tunnels:
  vnc_app: { proto: tcp, addr: 5900 }
  vnc_web: { proto: http, addr: 8080 }
EOF

(./ngrok start --all --config=ngrok_vnc.yml > /dev/null 2>&1 &)

echo -ne "    \e[1;32m●\e[0m \e[1;37mĐang lấy link từ máy chủ...\r"
sleep 7

# Lấy Link Public từ API Ngrok
APP_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[] | select(.name=="vnc_app") | .public_url')
WEB_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[] | select(.name=="vnc_web") | .public_url')

clear
echo -e "\n    \033[1;38;5;141m[KẾT NỐI SẴN SÀNG]\033[0m"
echo -e "    \033[1;32m✅ App:\033[0m \033[1;36m$APP_URL\033[0m"
echo -e "    \033[1;32m✅ Web:\033[0m \033[1;36m$WEB_URL/vnc.html\033[0m"
echo -e "\n    \033[1;30m(Hãy đảm bảo bạn đã nhấn START trong App VNC)\033[0m"

rm ngrok_vnc.yml
