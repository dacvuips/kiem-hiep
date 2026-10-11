# Game server (Godot headless) — chạy gói server/game/game_server.pck (tạo bằng server/build_game_server.sh).
FROM debian:bookworm-slim
ARG GODOT_VERSION=4.7.2
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget unzip libfontconfig1 \
 && wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -O /tmp/godot.zip \
 && unzip -q /tmp/godot.zip -d /opt \
 && mv /opt/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot \
 && rm /tmp/godot.zip \
 && apt-get purge -y wget unzip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
RUN useradd --create-home --uid 10001 game
WORKDIR /game
COPY game_server.pck /game/game_server.pck
USER game
EXPOSE 7777/udp 7778/tcp
ENTRYPOINT ["godot", "--headless", "--main-pack", "/game/game_server.pck", "res://net/server/game_server.tscn"]
