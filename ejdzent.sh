#!/bin/bash
source config_bash.ini

echo "Skrypt zarządzajacy archiwami v51.1.2.4. final koncowy FINAL.FINAL"

###opcja bez używania komendy, tylko standalone skrypt
#command=$command
#server=$server
#port=$port
#host=$zabbix_host
#key=$zabbix_key_name

# Inicjalizacja pliku logów
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

# Obsługa argumentów wejściowych
while (( "$#" )); do
  case "$1" in
    --host|-h)
      host=$2
      key="${host}_dump"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      log_with_timestamp "Błąd: Nieznany argument $1"
      exit 1
  esac
done

# Sprawdzenie czy wymagane zmienne konfiguracyjne są dostępne
if [[ -z "$command" || -z "$server" || -z "$port" || -z "$host" ]]; then
    log_with_timestamp "Błąd: Brak wymaganych zmiennych konfiguracyjnych."
    exit 1
fi

touch "$log_file"

# Funkcja usuwająca wszystkie pliki oprócz 5 najnowszych
remove_all_but_latest_five() {
    folder="/home/daniel/dump"
    pattern="dump_*"  # Usuwam filtr daty

    # Lista plików posortowana od najstarszego do najnowszego
    mapfile -t sorted_files < <(find "$folder" -maxdepth 1 -name "$pattern" -type f ! -name "*.md5" -printf "%T@ %p\n" | sort -n | cut -d' ' -f2-)

    # Usuń wszystkie pliki poza 5 najnowszymi
    if [ ${#sorted_files[@]} -gt 5 ]; then
        for ((i=0; i < ${#sorted_files[@]} - 5; i++)); do
            file="${sorted_files[$i]}"
            log_with_timestamp "Usunięcie pliku: $file"
            rm -f "$file"
            total_deletions=$((total_deletions + 1))
        done
    fi
    log_with_timestamp "Zakończono usuwanie starych plików."
}


# Funkcja sprawdzająca pliki MD5
check_md5_files() {
    folder="/home/daniel/dump"
    pattern="dump_*"  # Usuwam filtr daty

    while IFS= read -r -d '' file; do
        if [[ "$file" != *.md5 ]]; then
            md5_file="$file.md5"
            current_md5=$(md5sum "$file" | awk '{print $1}')

            # Update total_files and total_size here
            total_files=$((total_files + 1))
            total_size=$((total_size + $(stat -c%s "$file")))

            if [[ -f $md5_file ]]; then
                old_md5=$(cat "$md5_file")
                if [[ "$old_md5" != "$current_md5" ]]; then
                    log_with_timestamp "Błąd: MD5 dla pliku $file się różni. Stary MD5: $old_md5, Nowy MD5: $current_md5"
                    echo "$current_md5" > "$md5_file"
                    total_md5_creations=$((total_md5_creations + 1))
                    log_with_timestamp "Zaktualizowano plik MD5 dla: $file"
                    send_to_zabbix "$file"
                else
                    log_with_timestamp "MD5 dla pliku $file jest aktualne."
                fi
            else
                echo "$current_md5" > "$md5_file"
                total_md5_creations=$((total_md5_creations + 1))
                log_with_timestamp "Utworzono nowy plik MD5 dla: $file"
                send_to_zabbix "$file"
            fi
        fi
    done < <(find "$folder" -maxdepth 1 -type f -name "$pattern" ! -name "*.md5" -print0)
}

# Funkcja wysyłająca dane do Zabbix
send_to_zabbix() {
    file=$1
    size=$(stat -c%s "$file")
    md5=$(md5sum "$file" | awk '{print $1}')
    log_with_timestamp "Wysyłanie do Zabbix: Rozmiar pliku $file to $size, MD5 to $md5"
    zabbix_response=$($command -vv -z $server -p $port -s $host -k $key -o $size)
    log_with_timestamp "Odpowiedź Zabbix: $zabbix_response"
    total_zabbix_send=$((total_zabbix_send + 1))
}

main_operations_counter=0

while true; do
    # Resetowanie zmiennych podsumowania
    total_files=0
    total_size=0
    total_deletions=0
    total_md5_creations=0
    total_zabbix_send=0

    if [ $main_operations_counter -eq 0 ]; then
        remove_all_but_latest_five
        check_md5_files

        today=$(date +%Y_%m_%d)
        folder="/home/daniel/dump"
        pattern="dump_$today*"

        # Usuwanie plików MD5 bez odpowiadających im głównych plików
        find "$folder" -maxdepth 1 -name "$pattern.md5" -type f | while read -r md5_file; do
            main_file="${md5_file%.md5}"
            if [ ! -f "$main_file" ]; then
                log_with_timestamp "Usunięcie pliku md5 bez pliku głównego: $md5_file"
                rm -f "$md5_file"
                total_deletions=$((total_deletions + 1))
            fi
        done

        # Podsumowanie operacji
        echo "================== Podsumowanie dnia $today ==================" >> "$log_file"
        echo "Całkowita liczba plików: $total_files" >> "$log_file"
        echo "Całkowity rozmiar plików: $total_size bytes" >> "$log_file"
        echo "Całkowita liczba operacji usunięcia: $total_deletions" >> "$log_file"
        echo "Całkowita liczba operacji utworzenia MD5: $total_md5_creations" >> "$log_file"
        echo "Całkowita liczba operacji wysyłania do Zabbix: $total_zabbix_send" >> "$log_file"
        echo "=============================================================" >> "$log_file"
        echo " ">> "$log_file"
        echo "<---Koniec petli dziennej skryptu--->">> "$log_file"
        echo " ">> "$log_file"
    fi

    main_operations_counter=$(( (main_operations_counter + 1) % 12 ))  # Reset co 60 sekund
    sleep 5
done