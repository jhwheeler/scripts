#!/usr/bin/env bash

help_text="This script concatenates .ts files into a single .mp4 file.
Use --dir to specify the directory where the .ts files are located. Default is 'downloaded_files'.
Use --output to specify the output file name. Default is 'output.mp4'."

src_dir="downloaded_files" # default directory
output_file="output.mp4" # default output file name

while (( "$#" )); do
  case "$1" in
    --dir)
      src_dir=$2
      shift 2
      ;;
    --output)
      output_file=$2
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

# Create a list of .ts files
for f in $(ls $src_dir/*.ts | sort -V); do echo "file '$f'" >> mylist.txt; done

# Use ffmpeg to concatenate the .ts files into a single .mp4 file
ffmpeg -f concat -safe 0 -i mylist.txt -c copy -fflags +genpts $output_file

# Remove the list file
rm mylist.txt