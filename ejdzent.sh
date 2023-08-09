#!/bin/bash
source config_bash.ini

command=$command
server=$server
port=$port
host=$zabbix_host
key=$zabbix_key_name

log_file="./logfile.log"

log_with_timestamp() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") $1" >> "$log_file"
}

#while (( "$#" )); do
#  case "$1" in
#    --file|-f)
#      file=$2
#     shift 2
#      ;;
#    --host|-h)
#      host=$2
#      shift 2
#      ;;
#    --key|-k)
#      key=$2
#      shift 2
##      ;;
#    --)
#      shift
#      break
#      ;;
#    *)
#      echo "Błąd: Nieznany argument $1" >&2
#      exit 1
#  esac
#done

touch "$log_file" # Tworzenie pliku logów, jeśli nie istnieje

while true; do
    today=$(date +%Y_%m_%d)
    folder="/home/daniel/dump" # Ścieżka do folderu z plikami
    pattern="dump_$today*" # Wzorzec nazwy pliku

    # Usuń wszystkie pliki oprócz 5 najnowszych
    find "$folder" -maxdepth 1 -name "$pattern" -type f -printf "%T@ %p\n" | sort -n | cut -d' ' -f2- | head -n -5 | while read -r file_to_delete; do
        log_with_timestamp "Usunięcie pliku: $file_to_delete"
        rm -f "$file_to_delete"
    done

    # Ponowne przypisanie tablicy plików po usunięciu
    files=(/home/daniel/dump/dump_$today*)

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            size=$(stat -c%s "$file")
            md5=$(md5sum "$file" | awk '{print $1}')
            md5_file="$file.md5"
            echo "$md5" > "$md5_file" # Zapisuje wartość MD5 do pliku .md5
            if [ $size -ne 0 ] && [ -n "$md5" ]; then
                log_with_timestamp "Rozmiar i md5 pliku są prawidłowe: $file"
                $command -vv -z $server -p $port -s $host -k $key -o $size
            else
                log_with_timestamp "Błąd: Rozmiar lub md5 pliku są nieprawidłowe: $file"
            fi
        else
            log_with_timestamp "Plik $file nie istnieje."
        fi
    done

    sleep 60
done
