#!/usr/bin/env bash

help_text="This script fetches files from a list of URLs or from a URL with an iterator placeholder.
The list of URLs should be provided in a file, with one URL per line, without comments or any other text.
The URL with an iterator should have a placeholder {{iterator}} that will be replaced by an incrementing number for each fetch.
Use --file to provide a file with a list of URLs.
Use --url to provide a URL with an iterator placeholder.
Use --max to specify the maximum number of iterations (only relevant for the --url option). Default is 10000.
Use --dir to specify the directory where the files will be saved. Default is downloaded_files."


dir="downloaded_files" # default name
max_iterations=10000 # to prevent infinite loops

while (( "$#" )); do
  case "$1" in
    --file)
      file=$2
      shift 2
      ;;
    --url)
      url=$2
      shift 2
      ;;
    --max)
      max_iterations=$2
      shift 2
      ;;
    --dir)
      dir=$2
      shift 2
      ;;
    --help)
      echo "$help_text"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

if [[ -n "$file" ]]; then
  playlist=()
  readarray -t playlist < "$file"
elif [[ -n "$url" ]]; then
  iterator=1
  while ((iterator <= max_iterations)); do
    playlist+=(${url//\{\{iterator\}\}/$iterator})
    iterator=$((iterator+1))
  done
else
  echo "Please provide a file with --file or a URL with --url"
  exit 1
fi

# Create directory to save files to
mkdir -p $dir

printf "%s\n" "${playlist[@]}" | xargs -n 1 -P 12 -I {} wget -U "Mozilla/5.0 (X11; U; Linux i686 (x86_64); en-GB; rv:1.9.0.1) Gecko/2008070206 Firefox/3.0.1" -v --no-check-certificate --inet4-only -P $dir {}