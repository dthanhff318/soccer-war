# Dedicated Soccer War game server (headless Godot). Render sets $PORT.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates wget unzip libfontconfig1 \
	&& rm -rf /var/lib/apt/lists/*
RUN wget -q "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -O /tmp/godot.zip \
	&& unzip -q /tmp/godot.zip -d /tmp \
	&& mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
	&& rm /tmp/godot.zip

WORKDIR /app
COPY . .
# Builds the .godot import cache (class names, imported resources).
RUN godot --headless --import

ENV PORT=9080
EXPOSE 9080
CMD ["godot", "--headless", "--", "--server"]
