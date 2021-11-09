#!/usr/bin/env bash

# this script requires a file as input
# the file should just be a simple list of urls,
# without comments or any other text
file=$1

playlist=()
readarray -t playlist < "$file"

for i in "${playlist[@]}"
do
  # for reference on improving `wget` speeds:
  # https://stackoverflow.com/a/94100/1629099

  # summary:
  # forge headers so wget doesn't get throttled
  # don't check certificate b/c this takes more time
  # don't use ipv6
  wget -U "Mozilla/5.0 (X11; U; Linux i686 (x86_64); en-GB; rv:1.9.0.1) Gecko/2008070206 Firefox/3.0.1" -v --no-check-certificate --inet4-only $i
done

