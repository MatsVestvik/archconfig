#!/usr/bin/env sh

set -eu

while :; do
  printf '\033[H\033[2J'
  printf '\n\n'
  printf '        %s\n' "$(date +'%H:%M')"
  printf '\n'
  printf '      %s\n' "$(date +'%A, %d %B')"
  sleep 1
done