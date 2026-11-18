#!/bin/bash
# print-booklet.sh BOOKLET.pdf [FIRST-LAST]
#
# Prints an already-imposed A4-landscape booklet PDF double-sided (flip on short edge) on the
# Canon TS5100. Optional page range of the imposed PDF, e.g. 1-2 = first sheet only.
#
# Why this exists: duplex through the normal CUPS queue (lp -o sides=...) does NOT work on this
# printer. The queue sends Apple Raster (image/urf) and the printer then puts every page on its
# own sheet with a blank back. What works (confirmed on paper 2026-11-18) is PWG Raster sent
# straight to the printer over ipp-usb, with the header fields CUPS leaves empty filled in.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
pdf="$1"; range="${2:-}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
src="$pdf"
if [ -n "$range" ]; then qpdf "$pdf" --pages . "$range" -- "$tmp/part.pdf"; src="$tmp/part.pdf"; fi
n=$(pdfinfo "$src" | awk '/^Pages/{print $2}')
if [ $((n % 2)) -ne 0 ]; then echo "page count $n is odd; a duplex booklet needs an even number" >&2; exit 1; fi
cupsfilter -p "$here/canon-ts5100-pwg.ppd" -i application/pdf -m image/pwg-raster \
  -o media=A4 -o orientation-requested=4 -o print-scaling=fit -o sides=two-sided-short-edge \
  "$src" > "$tmp/job.pwg" 2> "$tmp/filter.log" || { tail -20 "$tmp/filter.log" >&2; exit 1; }
python3 -I "$here/pwgfix.py" "$tmp/job.pwg"
python3 -I "$here/pwginfo.py" "$tmp/job.pwg" | grep -c "Duplex=1 Tumble=1" | grep -qx "$n" || { echo "raster check failed" >&2; exit 1; }
name="$(basename "$pdf" .pdf)${range:+ pages $range}"
ipptool -t -d op=Print-Job -d jobname="$name" -f "$tmp/job.pwg" \
  ipp://localhost:60000/ipp/print "$here/print-job-pwg.test"
