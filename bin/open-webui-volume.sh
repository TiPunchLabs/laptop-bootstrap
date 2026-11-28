#!/usr/bin/env bash
# Back up or restore the Open WebUI data volume, stopping at the first failure.
#
#   open-webui-volume.sh backup <dest-dir>   -> prints the validated archive path (stdout)
#   open-webui-volume.sh restore <archive>   -> replaces the volume content, container left stopped
#
# Helpers run the container's own image (tar, gzip, python3 are in it), so nothing is
# pulled. Archives are root-owned, mode 0600: they hold the secret key and all user data.
# Env: OPEN_WEBUI_CONTAINER, OPEN_WEBUI_VOLUME (default open-webui).
# Single-quoted strings below are scripts for the helper container, expanded there.
# shellcheck disable=SC2016
set -euo pipefail

CONTAINER=${OPEN_WEBUI_CONTAINER:-open-webui}
VOLUME=${OPEN_WEBUI_VOLUME:-open-webui}

log() { echo "open-webui-volume: $*" >&2; }
die() {
	log "FAILED: $*"
	exit 1
}

# Checks run inside a helper on the directory given as $1: database present and
# intact, secret key present and not empty. Prints nothing of their content.
CHECK_DATA='d=$1
test -s "$d/webui.db" || { echo "webui.db missing" >&2; exit 1; }
test -s "$d/.webui_secret_key" || { echo ".webui_secret_key missing" >&2; exit 1; }
python3 -c "import sqlite3,sys; r=sqlite3.connect(\"file:\"+sys.argv[1]+\"?mode=ro&immutable=1\",uri=True).execute(\"pragma integrity_check\").fetchone()[0]; sys.exit(0 if r==\"ok\" else \"integrity_check: \"+r)" "$d/webui.db"'

helper() { # helper <docker run args...> -- <sh script> [args]
	local args=()
	while [ "$1" != -- ]; do
		args+=("$1")
		shift
	done
	shift
	docker run --rm --network none --user 0 --entrypoint sh "${args[@]}" "$IMAGE" -c "$@"
}

# Archive check: gzip stream complete, then the database and key extracted to a
# scratch directory inside the helper and checked there.
check_archive() { # check_archive <dir> <file name>
	helper -v "$1":/backup:ro -- 'set -e
gzip -t "/backup/$1"
mkdir /tmp/x && tar xzf "/backup/$1" -C /tmp/x ./webui.db ./.webui_secret_key
set -- /tmp/x
'"$CHECK_DATA" sh "$2"
}

was_running=false
running() { [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" = true ]; }

IMAGE=$(docker inspect -f '{{.Config.Image}}' "$CONTAINER") || die "container $CONTAINER not found"
docker volume inspect "$VOLUME" >/dev/null || die "volume $VOLUME not found"

backup() {
	local dest name kb_vol kb_free
	dest=$(realpath -e "$1") || die "destination $1 does not exist"
	if [ ! -d "$dest" ] || [ ! -w "$dest" ]; then die "destination $dest is not a writable directory"; fi
	name=open-webui-$(date +%Y%m%d-%H%M%S).tar.gz
	if [ -e "$dest/$name" ] || [ -e "$dest/$name.partial" ]; then die "$dest/$name already exists"; fi

	kb_vol=$(helper -v "$VOLUME":/data:ro -- 'du -sk /data | cut -f1')
	kb_free=$(df -Pk "$dest" | awk 'NR==2{print $4}')
	[ "$kb_free" -gt "$kb_vol" ] || die "not enough space in $dest: ${kb_free} KiB free, volume ${kb_vol} KiB"

	if running; then was_running=true; fi
	# From here on, any exit puts the container back in its previous state.
	trap 'if $was_running && ! running; then docker start "$CONTAINER" >/dev/null || log "FAILED: docker start $CONTAINER"; fi' EXIT
	docker stop "$CONTAINER" >/dev/null || die "docker stop $CONTAINER"
	running && die "$CONTAINER still running after stop"

	log "archiving volume $VOLUME (${kb_vol} KiB) to $dest/$name"
	helper -v "$VOLUME":/data:ro -v "$dest":/backup -- \
		'umask 077 && tar czf "/backup/$1" -C /data .' sh "$name.partial" || die "tar failed, partial file: $dest/$name.partial"
	check_archive "$dest" "$name.partial" || die "archive check failed: $dest/$name.partial"
	mv "$dest/$name.partial" "$dest/$name" || die "rename $dest/$name.partial"
	log "archive checked: gzip complete, webui.db integrity ok, secret key present"
	echo "$dest/$name"
}

restore() {
	local archive dir name stamp staging prerestore
	case "$1" in *'<'* | *'>'*) die "replace the <archive> placeholder with a real file" ;; esac
	archive=$(realpath -e "$1") || die "archive $1 does not exist"
	[ -f "$archive" ] || die "$archive is not a file"
	dir=$(dirname "$archive")
	name=$(basename "$archive")
	stamp=$(date +%Y%m%d-%H%M%S)
	staging=$VOLUME-restore-$stamp
	prerestore=$VOLUME-prerestore-$stamp

	log "checking $archive (live volume untouched)"
	check_archive "$dir" "$name" || die "archive check failed, nothing changed"

	docker volume create "$staging" >/dev/null
	helper -v "$dir":/backup:ro -v "$staging":/data -- \
		'tar xzf "/backup/$1" -C /data' sh "$name" || die "extraction failed, nothing changed (staging volume $staging kept for inspection)"
	helper -v "$staging":/data:ro -- "$CHECK_DATA" sh /data || die "staging check failed, nothing changed (staging volume $staging kept)"
	log "archive extracted and checked in staging volume $staging"

	docker stop "$CONTAINER" >/dev/null || die "docker stop $CONTAINER, nothing changed"
	running && die "$CONTAINER still running after stop, nothing changed"

	# Keep the current content in a separate volume until the new one is in place.
	docker volume create "$prerestore" >/dev/null
	helper -v "$VOLUME":/data:ro -v "$prerestore":/keep -- 'cp -a /data/. /keep/' ||
		die "copy of the current data to $prerestore failed; live volume untouched, container stopped"

	if ! helper -v "$staging":/staging:ro -v "$VOLUME":/data -- \
		'find /data -mindepth 1 -delete && cp -a /staging/. /data/' ||
		! helper -v "$VOLUME":/data:ro -- "$CHECK_DATA" sh /data; then
		log "replacing the live content failed; putting the previous content back from $prerestore"
		helper -v "$prerestore":/keep:ro -v "$VOLUME":/data -- 'find /data -mindepth 1 -delete && cp -a /keep/. /data/' ||
			die "put-back failed: copy $prerestore into $VOLUME by hand; do not start $CONTAINER"
		die "restore failed; previous content put back, container stopped"
	fi

	docker volume rm "$staging" >/dev/null || log "could not remove $staging (remove it by hand)"
	log "restored $archive into $VOLUME; container $CONTAINER left STOPPED"
	log "previous content kept in volume $prerestore (docker volume rm it once the rollback is confirmed)"
	log "next: set open_webui_version to the archive's version, then make play-open-webui; do NOT docker start"
}

case "${1:-}:${2:-}" in
backup:?*) backup "$2" ;;
restore:?*) restore "$2" ;;
*) die "usage: $0 backup <dest-dir> | restore <archive>" ;;
esac
