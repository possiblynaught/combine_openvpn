#!/bin/bash

# Debug
#set -x
set -Eeo pipefail

################################################################################
# Where to save the resulting combined file
OUTPUT_CONF="/tmp/combined.ovpn"
################################################################################

# Check for passed folder
INPUT_CONFS="$1"
if [ -z "$INPUT_CONFS" ]; then
  echo "Error, no openvpn config directory passed, please pass a directory to run"
  exit 1
elif [ ! -d "$INPUT_CONFS" ]; then
  echo "Error, no folder of configs found: $INPUT_CONFS"
  exit 1
fi

# If second arg is passed, use it as a search filter to use only configs matching it
[ -n "$2" ] && SEARCH_TERM_1="$2"

# If third arg is passed, use it as a search filter to use only configs matching it
[ -n "$3" ] && SEARCH_TERM_2="$3"

# Check for '/' at end of name
if [[ "$(echo "$INPUT_CONFS" | rev | head -c 1)" != "/" ]]; then
  INPUT_CONFS="$INPUT_CONFS/"
fi

# Find configs
PATHS_FILE=$(mktemp /tmp/config.XXXXXX || exit 1)
find "$INPUT_CONFS" -maxdepth 1 -type f \( -name "*.conf" -o -name "*.ovpn" \) > "$PATHS_FILE"
# Check for additional search restrictions and select configs from input folder
if [ -n "$SEARCH_TERM_1" ]; then
  TEMP_FILE=$(mktemp /tmp/config.XXXXXX || exit 1)
  grep -F "$SEARCH_TERM_1" < "$PATHS_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$PATHS_FILE"
fi
if [ -n "$SEARCH_TERM_2" ]; then
  TEMP_FILE=$(mktemp /tmp/config.XXXXXX || exit 1)
  grep -F "$SEARCH_TERM_2" < "$PATHS_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$PATHS_FILE"
fi

NUM_CONFS="$(wc -l < "$PATHS_FILE")"
# Check for non-zero list
if [[ "$NUM_CONFS" -eq 0 ]]; then
  echo "Error, no $SEARCH_TERM_1/.ovpn/.conf/$SEARCH_TERM_2 configs found in the directory: $INPUT_CONFS"
  exit 1
fi

# Create output file template
sed 's/\#.*//' "$(head -n 1 "$PATHS_FILE")" | sed '/^$/d' | sed '/^remote/d' > "$OUTPUT_CONF"
# Get remote conf strings
TEMP_FILE=$(mktemp /tmp/config.XXXXXX || exit 1)
while read -r FILE; do
  grep -F "remote " < "$FILE" >> "$TEMP_FILE"
done < "$PATHS_FILE"
# Sort, remove duplicate, and add remote strings
sort "$TEMP_FILE" | uniq > "$PATHS_FILE"
rm -f "$TEMP_FILE"
cat "$OUTPUT_CONF" >> "$PATHS_FILE"
mv "$PATHS_FILE" "$OUTPUT_CONF"

# Notify of completion
echo "
--------------------------------------------------------------------------------
Finished, combined $NUM_CONFS openvpn configs into one config
- Config saved to: $OUTPUT_CONF"
if [ -n "$SEARCH_TERM_1" ] && [ -n "$SEARCH_TERM_2" ]; then
  echo "- Only sourced from configs with '$SEARCH_TERM_1' and '$SEARCH_TERM_2' in name"
elif [ -n "$SEARCH_TERM_1" ]; then 
  echo "- Only sourced from configs with '$SEARCH_TERM_1' in name"
fi
echo "--------------------------------------------------------------------------------"
