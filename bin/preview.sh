#!/usr/bin/env bash

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

_maybe_run_highlight() {
  HIGHLIGHT_CMD=(highlight --out-format=truecolor --line-numbers
    --line-number-length=0 --quiet --force)
  MARKLINES_PLUGIN='/usr/share/highlight/plugins/mark_lines.lua'
  if ((CENTER)); then
    if [[ -r "${MARKLINES_PLUGIN}" ]]; then
      HIGHLIGHT_CMD+=(--plug-in "${MARKLINES_PLUGIN}"
        --plug-in-param "${CENTER}")
    # If highlight doesn't support line highlighting and bat is available, fall
    # back to bat.
    elif command -v bat > /dev/null; then
      return 1
    fi
  fi
  "${HIGHLIGHT_CMD[@]}" -- "$FILE"
}

if [ -z "$FZF_PREVIEW_COMMAND" ] && _maybe_run_highlight; then
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
