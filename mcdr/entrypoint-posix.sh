#!/bin/sh

# Default the TZ environment variable to UTC.
: "${TZ:=UTC}"
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Print Java version
printf '\033[1m\033[33mcontainer@pterodactyl~ \033[0mjava -version\n'
java -version

# Find and process plugin files
find ./plugins -maxdepth 2 \( -name "*.pyz" -o -name "requirements.txt" -o -name "*.mcdr" -o -name "*.zip" \) | while IFS= read -r FILE; do
    case "$FILE" in
        *.pyz|*.mcdr|*.zip)
            # create temp dir (mktemp may not exist or support -d)
            UNZIP_DIR=$(mktemp -d 2>/dev/null || true)
            if [ -z "$UNZIP_DIR" ] || [ ! -d "$UNZIP_DIR" ]; then
                UNZIP_DIR="/tmp/entrypoint.$$.$RANDOM"
                mkdir -p "$UNZIP_DIR" || exit 1
            fi

            unzip -q "$FILE" -d "$UNZIP_DIR"
            if [ -f "$UNZIP_DIR/requirements.txt" ]; then
                printf '\033[1m\033[33mcontainer@pterodactyl~ \033[0mpip install -r %s\n' "$UNZIP_DIR/requirements.txt"
                pip install -r "$UNZIP_DIR/requirements.txt" --break-system-packages
            fi
            rm -rf "$UNZIP_DIR"
            ;;
        *)
            printf '\033[1m\033[33mcontainer@pterodactyl~ \033[0mpip install -r %s\n' "$FILE"
            pip install -r "$FILE" --break-system-packages
            ;;
    esac
done

# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
if [ -n "${STARTUP:-}" ]; then
    PARSED=$(printf '%s' "$STARTUP" | sed -e 's/{{/${/g' -e 's/}}/}/g')
    # Expand variables while preserving whitespace
    PARSED=$(eval "echo \"$PARSED\"")
else
    PARSED=""
fi

# Display the command we're running, and then execute it with the env from the container itself.
printf '\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n' "$PARSED"
# shellcheck disable=SC2086
exec env $PARSED
