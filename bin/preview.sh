#!/usr/bin/env bash

: "${XDG_DATA_HOME:=${HOME}/.local/share}"

REVERSE="\x1b[7m"
RESET="\x1b[m"

if [ -z "$1" ]; then
  echo "usage: $0 [--tag] FILENAME[:LINENO][:IGNORED]"
  exit 1
fi

if [ "$1" = --tag ]; then
  shift
  "$(dirname "${BASH_SOURCE[0]}")/tagpreview.sh" "$@"
  exit $?
fi

IFS=':' read -r -a INPUT <<< "$1"
FILE=${INPUT[0]}
CENTER=${INPUT[1]}

if [[ $1 =~ ^[A-Z]:\\ ]]; then
  FILE=$FILE:${INPUT[1]}
  CENTER=${INPUT[2]}
fi

if [[ -n "$CENTER" && ! "$CENTER" =~ ^[0-9] ]]; then
  exit 1
fi
CENTER=${CENTER/[^0-9]*/}

FILE="${FILE/#\~\//$HOME/}"
if [ ! -r "$FILE" ]; then
  echo "File not found ${FILE}"
  exit 1
fi

FILE_LENGTH=${#FILE}
MIME=$(file --dereference --mime "$FILE")
if [[ "${MIME:FILE_LENGTH}" =~ binary ]]; then
  echo "$MIME"
  exit 0
fi

if [ -z "$CENTER" ]; then
  CENTER=0
fi

_get_highlight_marklines_plugin() {
  HIGHLIGHT_MARKLINES_PLUGIN_FILES=(
    "${XDG_DATA_HOME}/highlight/plugins/mark_lines.lua"
    '/usr/share/highlight/plugins/mark_lines.lua'
  )
  for file in "${HIGHLIGHT_MARKLINES_PLUGIN_FILES[@]}"; do
    if [[ -r "${file}" ]]; then
      printf '%s' "${file}"
      return
    fi
  done
  return 1
}

if [ -z "$FZF_PREVIEW_COMMAND" ] && command -v highlight > /dev/null; then
  HIGHLIGHT_CMD=(highlight --out-format=truecolor --line-numbers
    --line-number-length=0 --quiet --force)
  if mark_lines_plugin="$(_get_highlight_marklines_plugin)" && ((CENTER)); then
    HIGHLIGHT_CMD+=(--plug-in "${mark_lines_plugin}"
      --plug-in-param "${CENTER}")
  fi
  "${HIGHLIGHT_CMD[@]}" -- "$FILE"
  exit $?
fi

# Sometimes bat is installed as batcat.
if command -v batcat > /dev/null; then
  BATNAME="batcat"
elif command -v bat > /dev/null; then
  BATNAME="bat"
fi

if [ -z "$FZF_PREVIEW_COMMAND" ] && [ "${BATNAME:+x}" ]; then
  ${BATNAME} --style="${BAT_STYLE:-numbers}" --color=always --pager=never \
      --highlight-line=$CENTER "$FILE"
  exit $?
fi

DEFAULT_COMMAND="highlight -O ansi -l {} || coderay {} || rougify {} || cat {}"
CMD=${FZF_PREVIEW_COMMAND:-$DEFAULT_COMMAND}
CMD=${CMD//{\}/$(printf %q "$FILE")}

eval "$CMD" 2> /dev/null | awk "{ \
    if (NR == $CENTER) \
        { gsub(/\x1b[[0-9;]*m/, \"&$REVERSE\"); printf(\"$REVERSE%s\n$RESET\", \$0); } \
    else printf(\"$RESET%s\n\", \$0); \
    }"
