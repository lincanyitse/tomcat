#!/bin/sh

set -e

entrypoint_log() {
    if [ -z "${ENTRYPOINT_LOG:-}" ]; then
        echo "[entrypoint] $*"
    fi
}

if [ "$1" = "catalina.sh" ]; then
    if /usr/bin/find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
        entrypoint_log "$0: /docker-entrypoint.d/ is not empty, will attempt to perform configuration"
        entrypoint_log "$0: Loading for shell scripts in /docker-entrypoint.d/"
        /usr/bin/find "/docker-entrypoint.d/" -follow -type f -print | sort -V | while read -r f; do
            case "$f" in
            *.sh)
                if [ -x "$f" ]; then
                    entrypoint_log "$0: Launching $f"
                    "$f"
                else
                    # warn on shell scripts without exec bit
                    entrypoint_log "$0: Ignoring $f, not executable"
                fi
                ;;
            *) entrypoint_log "$0: Ignoring $f" ;;
            esac
        done
    fi
fi

exec "$@"
