#!/bin/bash
source config_bash.ini

while (( "$#" )); do
  case "$1" in
    --file|-f)
      file=$2
      shift 2
      ;;
    --host|-h)
      host=$2
      shift 2
      ;;
    --key|-k)
      key=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Błąd: Nieznany argument $1"
      exit 1
  esac
done
size=1
while true
do
    $command -vv -z $server -p $port -s $host -k $key -o $size
    sleep 60
done
