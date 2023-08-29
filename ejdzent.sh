log_file="./logfile.log"
touch "$log_file"
instance_id="$(basename $0)_${host}_$(date +"%H_%M_%S_%3N")"

log_with_timestamp() {
    local level="$1"
    shift
    echo "$(date +"%Y-%m-%d %H:%M:%S") [$instance_id] [$level] $@" >> "$log_file"
}


    source config_bash.ini
    echo "Skrypt zarządzajacy archiwami v51.1.2.4. final koncowy FINAL.FINAL"

clean_old_logs() {
    find "$log_file" -mtime +30 -exec rm {} \;
    log_with_timestamp "INFO""Usunięto logi starsze niż 30 dni."
}

# Przetwarzanie argumentów
while (( "$#" )); do
    case "$1" in
        --host|-h)
            host=$2
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            log_with_timestamp "ERROR" "Nieznany argument $1"
            exit 1
    esac
done

# Loguj jedynie informację o tym, jaki skrypt działa dla jakiego hosta
log_with_timestamp "START" "Skrypt $(basename $0) działa dla hosta: $host"
echo "$command $server $port $host"

if [[ -z "$command" || -z "$server" || -z "$port" || -z "$host" ]]; then
    log_with_timestamp "ERROR" "Brak wymaganych zmiennych konfiguracyjnych."
    exit 1
fi

# Jeśli klucz nie jest dostarczony jako argument, tworzymy go na podstawie wartości hosta
if [[ -z "$key" ]]; then
    key="${host}_dump"
fi


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
            log_with_timestamp "INFO" "Usunięcie pliku: $file"
            rm -f "$file"
            total_deletions=$((total_deletions + 1))
        done
    fi
    log_with_timestamp "INFO" "Zakończono usuwanie starych plików."
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
                    log_with_timestamp "ERROR" "Błąd: MD5 dla pliku $file się różni. Stary MD5: $old_md5, Nowy MD5: $current_md5"
                    echo "$current_md5" > "$md5_file"
                    total_md5_creations=$((total_md5_creations + 1))
                    log_with_timestamp "WARNING" "Zaktualizowano plik MD5 dla: $file"
                    send_to_zabbix "$file"
                else
                    log_with_timestamp "INFO" "MD5 dla pliku $file jest aktualne."
                fi
            else
                echo "$current_md5" > "$md5_file"
                total_md5_creations=$((total_md5_creations + 1))
                log_with_timestamp "WARNING" "Utworzono nowy plik MD5 dla: $file"
                send_to_zabbix "$file"
            fi
        fi
    done < <(find "$folder" -maxdepth 1 -type f -name "$pattern" ! -name "*.md5" -print0)
}

# Funkcja wysyłająca dane do Zabbix
send_to_zabbix() {
    folder="/home/daniel/dump"
    total_size=$(du -sb "$folder" | cut -f1)
    log_with_timestamp "INFO" "Wysyłanie do Zabbix: Całkowity rozmiar folderu to $total_size"
    zabbix_response=$($command -vv -z $server -p $port -s $host -k $key -o $total_size)
    log_with_timestamp "INFO" "Odpowiedź Zabbix: $zabbix_response"
    total_zabbix_send=$((total_zabbix_send + 1))

    # Sprawdzenie odpowiedzi od Zabbix
    if [[ ! "$zabbix_response" =~ "success" ]]; then  # Zakładając, że "success" to pozytywna odpowiedź od Zabbix
        log_with_timestamp "ERROR" "Błąd przesyłania danych do Zabbix dla hosta $host. Skrypt zostanie zatrzymany."
        exit 1
    fi
}


# Funkcja sprawdzająca, czy pojawił się nowy plik główny z dzisiejszą datą
check_for_new_file_today() {
    folder="/home/daniel/dump"
    today=$(date +%Y_%m_%d)
    pattern="dump_$today*"
    files_today=$(find "$folder" -maxdepth 1 -name "$pattern" ! -name "*.md5")
    if [ ! -z "$files_today" ]; then
        log_with_timestamp "INFO" "Znaleziono nowy plik główny z datą $today."
    else
        log_with_timestamp "WARNING" "Brak nowego pliku głównego z datą $today."
    fi
}

test_zabbix_connection() {
    # Testuj połączenie z Zabbix za pomocą pustej wiadomości
    zabbix_response=$($command -vv -z $server -p $port -s $host -k $key -o "")

    # Wyciągnij wartość dla "failed" z odpowiedzi
    failed_value=$(echo "$zabbix_response" | grep -o "failed: [0-9]*" | awk '{print $2}' | head -1)

    if [[ -n "$failed_value" && "$failed_value" -ge 1 ]]; then
        log_with_timestamp "ERROR" "Nie można nawiązać połączenia lub przesłać danych do serwera Zabbix dla hosta $host. Skrypt zostanie zatrzymany."
        exit 1
    else
        log_with_timestamp "INFO" "Pomyślnie nawiązano połączenie z serwerem Zabbix dla hosta $host."
    fi
}

remove_orphaned_md5() {
    folder="/home/daniel/dump"
    pattern="dump_*.md5"
    find "$folder" -maxdepth 1 -name "$pattern" -type f | while read -r md5_file; do
        main_file="${md5_file%.md5}"
        if [ ! -f "$main_file" ]; then
            log_with_timestamp "WARNING" "Usunięcie pliku md5 bez pliku głównego: $md5_file"
            rm -f "$md5_file"
        fi
    done
}

# Główna funkcja
main() {

    while true; do


        total_files=0
        total_size=0
        total_deletions=0
        total_md5_creations=0
        total_zabbix_send=0

        test_zabbix_connection
        check_for_new_file_today
        remove_all_but_latest_five
        check_md5_files
        remove_orphaned_md5

        # Dodajemy wywołanie funkcji czyszczenia starych logów
        if [ $(date +%H:%M) == "00:00" ]; then
            clean_old_logs
        fi

        today=$(date +%Y_%m_%d)
        folder="/home/daniel/dump"
        pattern="dump_$today*"
        # Podsumowanie operacji
        echo "================== Podsumowanie dnia $today dla $host==================" >> "$log_file"
        echo "Całkowita liczba plików: $total_files" >> "$log_file"
        echo "Całkowity rozmiar plików: $total_size bytes" >> "$log_file"
        echo "Całkowita liczba operacji usunięcia: $total_deletions" >> "$log_file"
        echo "Całkowita liczba operacji utworzenia MD5: $total_md5_creations" >> "$log_file"
        echo "Całkowita liczba operacji wysyłania do Zabbix: $total_zabbix_send" >> "$log_file"
        echo "=============================================================" >> "$log_file"
        echo " ">> "$log_file"
        echo "<---Koniec petli dziennej skryptu--->">> "$log_file"
        echo " ">> "$log_file"
        if [ $? -ne 0 ]; then
          log_with_timestamp "ERROR" "ERROR: Skrypt napotkał błąd. Restartowanie..."
          exec "$0" "$@"
        fi
        sleep 60  # Czekaj jedną minutę przed ponownym wykonaniem operacji
    done
}


# Uruchom główną funkcję
main
