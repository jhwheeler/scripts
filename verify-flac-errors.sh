#!/usr/bin/env bash

# Verify and fix errors for all .flac files in a directory

verified_dir_name=verified-"$(date +%Y%m%d%H%M%S)"

mkdir "$verified_dir_name"

for entry in "$PWD"/*.flac
do
  echo "$entry"
  filename=$(basename "$entry")
  echo "$filename"
  flac --verify --decode-through-errors --preserve-modtime -o ./"$verified_dir_name"/"$filename" "$entry"
done
