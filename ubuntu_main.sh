#!/bin/bash

# Default values
DEPTH=3
DETAILED=false
MIN_SIZE_GB=0
MIN_SIZE_KB=$((MIN_SIZE_GB * 1024 * 1024))
LOG_FILE=""

# Function to print the folder structure in a tree-like format
print_tree() {
  local folder="$1"
  local depth="$2"
  local indent="$3"
  local size_kb
  local size

  size_kb=$(du -sk "$folder" 2>/dev/null | cut -f1)
  # Set size_kb to 0 if it's empty
  size_kb=${size_kb:-0}
  size=$(du -sh "$folder" 2>/dev/null | cut -f1)

  if [ "$size_kb" -ge "$MIN_SIZE_KB" ]; then
    if [ -z "$LOG_FILE" ]; then
      printf "%s%s %s\n" "$indent" "$size" "$folder"
    else
      printf "%s%s %s\n" "$indent" "$size" "$folder" | tee -a "$LOG_FILE"
    fi
    if [ "$depth" -gt 0 ]; then
      find "$folder" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | while read -r subfolder; do
        print_tree "$subfolder" $((depth - 1)) "${indent}  "
      done
    fi
  fi
}

# Function to process each day's folders
process_day() {
  local DATE="$1"
  local TOTAL_SIZE=0

  # Find the folders modified on the specific date
  while read -d $'\0' folder; do
    SIZE=$(du -sk "$folder" 2>/dev/null | cut -f1)
    SIZE=${SIZE:-0}
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
  done < <(find / -type d -maxdepth $DEPTH -newermt "${DATE} 00:00:00" ! -newermt "${DATE} 23:59:59" -print0 2>/dev/null)

  # Convert the total size to a human-readable format
  HUMAN_TOTAL_SIZE=$(numfmt --to=iec --suffix=B --format="%.2f" $((TOTAL_SIZE * 1024)))

  # Write the total size to the log file and standard output
  if [ -z "$LOG_FILE" ]; then
    echo "${DATE} - ${HUMAN_TOTAL_SIZE}"
  else
    echo "${DATE} - ${HUMAN_TOTAL_SIZE}" | tee -a "$LOG_FILE"
  fi
  
  if [ "$DETAILED" == "true" ]; then
    while read -d $'\0' folder; do
      print_tree "$folder" $DEPTH ""
    done < <(find / -type d -maxdepth $DEPTH -newermt "${DATE} 00:00:00" ! -newermt "${DATE} 23:59:59" -print0 2>/dev/null)
  fi
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -d|--depth)
      DEPTH="$2"
      shift
      shift
      ;;
    --detailed)
      DETAILED=true
      shift
      ;;
    -s|--min-size)
      MIN_SIZE_GB="$2"
      MIN_SIZE_KB=$((MIN_SIZE_GB * 1024 * 1024))
      shift
      shift
      ;;
    --log)
      LOG_FILE="$2"
      shift
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Calculate date range
END_DATE=$(date +%Y-%m-%d)
START_DATE=$(date -d "30 days ago" +%Y-%m-%d)

# Process each day in the date range
while [[ "$START_DATE" < "$END_DATE" ]]; do
  process_day "$START_DATE"
  START_DATE=$(date -d "$START_DATE + 1 day" +%Y-%m-%d)
done

