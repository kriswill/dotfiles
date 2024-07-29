#!/usr/bin/env bash

# Default delimiter
delimiter=':'

# Function to display help information
show_help() {
  echo "Usage: $(basename "$0") [-h|--help] [-d delimiter]"
  echo "Split input from stdin or the PATH environment variable using a specified delimiter."
  echo
  echo "  -h, --help       Display this help and exit"
  echo "  -d delimiter     Specify a delimiter for splitting input (default is ':')"
}

# Process options
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    -d)
      delimiter="$2"
      shift 2
      continue
      ;;
    *)
      # Ignore unrecognized options
      shift
      ;;
  esac
done

# Check if there is data on stdin
if [[ -t 0 ]]; then
  # No stdin data, use PATH
  input="$PATH"
else
  # Read all input from stdin
  input=$(cat)
fi

# Split the input using the specified delimiter
IFS="$delimiter" read -ra segments <<< "$input"

# Output each segment on a new line
for segment in "${segments[@]}"; do
  echo "$segment"
done
