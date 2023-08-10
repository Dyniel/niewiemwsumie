#!/bin/bash
source config_bash.ini

echo "skrypt uruchiomiiony"

###opcja bez używania komendy, tylko standalone skrypt
#command=$command
#server=$server
#port=$port
#host=$zabbix_host
#key=$zabbix_key_name

log_file="./logfile.log"

log_with_timestamp() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") $1" >> "$log_file"
}

log_table_header() {
  echo -e "Date\t\tFile Name\t\tSize (bytes)\tMD5" >> "$log_file"
}

log_table_row() {
  echo -e "$(date +"%Y-%m-%d %H:%M:%S")\t$file\t\t$size\t$md5" >> "$log_file"
}
while (( "$#" )); do
  case "$1" in
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
      echo "Błąd: Nieznany argument $1" >&2
      exit 1
  esac
done

touch "$log_file"

while true; do

    total_files=0
    total_size=0
    total_deletions=0
    total_md5_creations=0
    total_zabbix_send=0

    today=$(date +%Y_%m_%d)
    folder="/home/daniel/dump"
    pattern="dump_$today*"

    files_to_delete=$(find "$folder" -maxdepth 1 -name "$pattern" -type f ! -name "*.md5" -printf "%T@ %p\n" | sort -n | cut -d' ' -f2- | head -n -5)

    total_deletions=$(echo "$files_to_delete" | wc -l)
    echo "$files_to_delete" | while read -r file_to_delete; do
        log_with_timestamp "Usunięcie pliku: $file_to_delete"
        rm -f "$file_to_delete"
    done
    echo "=========================koniec usuwania====================================" >> "$log_file"

    files=(/home/daniel/dump/dump_$today* ! -name "*.md5")

    for file in "${files[@]}"; do
        if [ -f "$file" ] && [[ ! "$file" == *.md5 ]]; then
            size=$(stat -c%s "$file")
            md5=$(md5sum "$file" | awk '{print $1}')
            md5_file="$file.md5"
            echo "$md5" > "$md5_file"
            total_md5_creations=$((total_md5_creations + 1))
            total_files=$((total_files + 1))
            total_size=$((total_size + size))
            if [ $size -ne 0 ] && [ -n "$md5" ]; then
                log_with_timestamp "Rozmiar i md5 pliku są prawidłowe: $file"
                zabbix_response=$($command -vv -z $server -p $port -s $host -k $key -o $size)
                log_with_timestamp "Odpowiedź Zabbix: $zabbix_response"
                total_zabbix_send=$((total_zabbix_send + 1))
                log_table_row
            else
                log_with_timestamp "Błąd: Rozmiar lub md5 pliku są nieprawidłowe: $file"
            fi
        fi
    done
    echo "=========================koniec md5====================================" >> "$log_file"


    find "$folder" -maxdepth 1 -name "$pattern.md5" -type f | while read -r md5_file; do
        main_file="${md5_file%.md5}"
        if [ ! -f "$main_file" ]; then
            log_with_timestamp "Usunięcie pliku md5 bez pliku głównego: $md5_file"
            rm -f "$md5_file"
            total_deletions=$((total_deletions + 1))
        fi
    done
    echo "=========================koniec usuwania md5 bez pliku glownego====================================" >> "$log_file"


    if [ $((current_minute % 30)) -eq 0 ] && [ $current_minute -ne $last_summary_minute ]; then
        echo "================== Podsumowanie dnia $today ==================" >> "$log_file"
        echo "Całkowita liczba plików: $total_files" >> "$log_file"
        echo "Całkowity rozmiar plików: $total_size bytes" >> "$log_file"
        echo "Całkowita liczba operacji usunięcia: $total_deletions" >> "$log_file"
        echo "Całkowita liczba operacji utworzenia MD5: $total_md5_creations" >> "$log_file"
        echo "Całkowita liczba operacji wysyłania do Zabbix: $total_zabbix_send" >> "$log_file"
        echo "=============================================================" >> "$log_file"
        log_table_header


        last_summary_minute=$current_minute
    fi


    sleep 60
done