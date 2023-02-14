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
TEMP_OUTPUT_FILE=$(mktemp /tmp/config.XXXXXX || exit 1)
while read -r FILE; do
  grep -F "remote " < "$FILE" >> "$TEMP_OUTPUT_FILE"
done < "$PATHS_FILE"

# Sort, remove duplicate, and add remote strings
sort "$TEMP_OUTPUT_FILE" | uniq > "$PATHS_FILE"
rm -f "$TEMP_OUTPUT_FILE"
cat "$OUTPUT_CONF" >> "$PATHS_FILE"
mv "$PATHS_FILE" "$OUTPUT_CONF"

# Save number of remotes
NUM_REMOTES=$(grep -cF "remote " < "$OUTPUT_CONF")
# Make sure it isn't more than 64 remotes (openvpn max)
if [[ "$NUM_REMOTES" -gt 64 ]]; then
  # Trim random remotes to achieve 64
  TRIM_NUM=$((NUM_REMOTES - 64))
  TEMP_REMOTES=$(mktemp /tmp/config.XXXXXX || exit 1)
  for i in $( seq 1 ${TRIM_NUM} ); do
    # Delete a remote line
    grep -F "remote " < "$OUTPUT_CONF" > "$TEMP_REMOTES"
    DELETE_LINE=$((RANDOM % $(wc -l < "$TEMP_REMOTES") + 1))
    sed -i "${DELETE_LINE}d" "$OUTPUT_CONF"
  done
  rm -f "$TEMP_REMOTES"
fi

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
if [[ "$TRIM_NUM" -gt 0 ]]; then 
  echo "- Randomly trimmed remotes from $NUM_REMOTES to $(grep -cF "remote " < "$OUTPUT_CONF") (openvpn max=64)"
fi
echo "--------------------------------------------------------------------------------"
