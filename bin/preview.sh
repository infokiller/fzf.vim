#!/usr/bin/env bash

: "${XDG_DATA_HOME:=${HOME}/.local/share}"

REVERSE="\x1b[7m"
RESET="\x1b[m"

if [ -z "$1" ]; then
  echo "usage: $0 FILENAME[:LINENO][:IGNORED]"
  exit 1
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

if [ -z "$FZF_PREVIEW_COMMAND" ] && command -v highlight > /dev/null; then
  HIGHLIGHT_MARKLINES_PLUGIN="${XDG_DATA_HOME}/highlight/plugins/mark_lines.lua"
  HIGHLIGHT_CMD=(highlight --out-format=truecolor --line-numbers
    --line-number-length=0 --quiet --force)
  if [ -f "${HIGHLIGHT_MARKLINES_PLUGIN}" ]; then
    HIGHLIGHT_CMD+=(--plug-in "${HIGHLIGHT_MARKLINES_PLUGIN}"
      --plug-in-param "${CENTER}")
  else
    lines="$(tput lines)" || exit 1
    start_line=$((CENTER - (lines / 2)))
    start_line=$((start_line > 0 ? start_line : 1))
    # Highlight can handle line ranges that are out of bound, so we don't need
    # to verify the end line is in range.
    end_line=$((start_line + lines))
    HIGHLIGHT_CMD+=(--line-number-start="${start_line}"
      --line-range="${start_line}-${end_line}" -- "$FILE")
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
