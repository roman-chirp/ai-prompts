#!/usr/bin/env sh
# Clone all services from services-list.txt; optionally update existing clones with git pull.

set -eu

UPDATE=false
LIST_FILE="services-list.txt"
BASE_DIR=$(pwd)
LIST_SET=0
BASE_SET=0

usage() {
  echo "Usage: $0 [-u|--update] [services-list.txt] [target_dir]" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -u|--update)
      UPDATE=true
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [ "$LIST_SET" -eq 0 ]; then
        LIST_FILE="$1"
        LIST_SET=1
      elif [ "$BASE_SET" -eq 0 ]; then
        BASE_DIR="$1"
        BASE_SET=1
      else
        usage
      fi
      ;;
  esac
  shift
done

if [ ! -f "$LIST_FILE" ]; then
  echo "Service list not found: $LIST_FILE" >&2
  exit 1
fi

while IFS= read -r line; do
  url=$(printf "%s" "$line" | sed 's/[[:space:]]*$//')
  [ -z "$url" ] && continue
  case "$url" in \#*) continue ;; esac

  repo=$(basename "$url" .git)
  target="$BASE_DIR/$repo"

  if [ -d "$target/.git" ]; then
    if [ "$UPDATE" = true ]; then
      echo "Updating: $repo"
      git -C "$target" pull --ff-only
    else
      echo "Exists, skipping: $repo"
    fi
    continue
  fi

  echo "Cloning $url -> $target"
  git clone "$url" "$target"
done < "$LIST_FILE"
