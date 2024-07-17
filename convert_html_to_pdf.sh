#!/usr/bin/env bash

# Converts an HTML file to a PDF with standard formatting
#
# Usage: convert_html_to_pdf.sh [-r] <html_file>
# -r: remove the HTML file after creating the PDF
# <html_file>: the path to the HTML file to convert to PDF

if ! command -v wkhtmltopdf &> /dev/null
then
    echo "wkhtmltopdf could not be found. Please install it first."
    exit 1
fi

if [ $# -eq 0 ]; then
  echo "No HTML file provided. Usage: $0 [-r] <html_file>"
  exit 1
fi

remove_html=false
while getopts "r" opt; do
  case "$opt" in
    r )
      remove_html=true
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

html_file="$1"
if [ ! -f "$html_file" ]; then
  echo "File not found: $html_file"
  exit 1
fi

output_pdf="${html_file%.html}.pdf"
wkhtmltopdf \
  --page-size "Letter" \
  --margin-top "0mm" \
  --margin-right "0mm" \
  --margin-bottom "0mm" \
  --margin-left "0mm" \
  --quiet \
  "$html_file" "$output_pdf"

if [ $? -eq 0 ]; then
  echo "PDF created successfully: $output_pdf"
  open "$output_pdf"

  if $remove_html; then
    rm "$html_file"
    echo "HTML file removed: $html_file"
  fi
else
  echo "Failed to create PDF."
fi