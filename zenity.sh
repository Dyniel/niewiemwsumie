#!/bin/bash

config_file="zenity.ini"

# Plik do przechowywania PIDów działających skryptów
pid_file="running_scripts.txt"


read_config() {
    local section=$1
    sed -n "/\[$section\]/,/\[.*\]/p" $config_file | sed -e "1d" -e "/^\[.*\]$/d"
}

update_config() {
    local section=$1
    local action=$2
    local value=$3

    if [ "$action" == "add" ]; then
        echo "$value" >> $config_file
    elif [ "$action" == "remove" ]; then
        sed -i "/$value/d" $config_file
    fi
}

scripts=($(read_config "Scripts"))
hosts=($(read_config "Hosts"))

play_game() {
    while true; do
        user_choice=$(zenity --list --title="Kamień, papier, nożyce" --text="Wybierz jeden:" --column="Wybór" --column=" " --hide-header \
            --radiolist TRUE "Kamień" FALSE "Papier" FALSE "Nożyce")

        if [ -z "$user_choice" ]; then
            zenity --info --text="Koniec gry!"
            return
        fi

        # Losowy wybór komputera
        comp_choices=("Kamień" "Papier" "Nożyce")
        comp_choice=${comp_choices[RANDOM % 3]}

        # Sprawdzenie wyniku
        if [ "$user_choice" == "$comp_choice" ]; then
            result="Remis!"
        elif [ "$user_choice" == "Kamień" ] && [ "$comp_choice" == "Nożyce" ] || \
             [ "$user_choice" == "Papier" ] && [ "$comp_choice" == "Kamień" ] || \
             [ "$user_choice" == "Nożyce" ] && [ "$comp_choice" == "Papier" ]; then
            result="Wygrałeś!"
        else
            result="Przegrałeś!"
        fi

        zenity --info --text="Wybrałeś: $user_choice\nKomputer wybrał: $comp_choice\n\n$result"
    done
}

refresh_running_scripts() {
    # Jeśli plik z PIDami nie istnieje, nie rób nic
    if [ ! -f "$pid_file" ]; then
        return
    fi

    # Dla każdego PIDu w pliku sprawdź, czy proces nadal działa
    while IFS= read -r line; do
        pid_to_check=$(echo "$line" | cut -f1)
        if ! kill -0 $pid_to_check 2>/dev/null; then
            # Jeśli proces nie działa, usuń wpis z pliku
            sed -i "/$pid_to_check/d" "$pid_file"
        fi
    done < "$pid_file"
}

while true; do
    # Okno dialogowe na początku
    choice=$(zenity --list --title="Wybór akcji" --column="Akcje" "Rozpocznij nowy skrypt" "Zakończ działający skrypt" "Dodaj nowy skrypt" "Dodaj nowy host" "Pokaż logi" "Usuń skrypt" "Usuń hosta" "Zagraj w Kamień, Papier, Nożyce" )
    # Jeśli użytkownik anuluje wybór, zakończ skrypt
    if [ -z "$choice" ]; then
        exit 1
    fi


    if [ "$choice" == "Dodaj nowy skrypt" ]; then
        new_script=$(zenity --entry --title="Dodaj nowy skrypt" --text="Podaj ścieżkę do skryptu:")
        if [ -n "$new_script" ]; then
            update_config "Scripts" "add" "$new_script"
            scripts=($(read_config "Scripts"))
            zenity --info --text="Dodano nowy skrypt: $new_script"
        fi
        continue
    fi


    if [ "$choice" == "Dodaj nowy host" ]; then
        new_host=$(zenity --entry --title="Dodaj nowy host" --text="Podaj nazwę hosta:")
        if [ -n "$new_host" ]; then
            update_config "Hosts" "add" "$new_host"
            hosts=($(read_config "Hosts"))
            zenity --info --text="Dodano nowy host: $new_host"
        fi
        continue
    fi


    if [ "$choice" == "Usuń skrypt" ]; then
        script_to_remove=$(zenity --list --title="Usuń skrypt" --column="Skrypty" "${scripts[@]}")
        if [ -n "$script_to_remove" ]; then
            update_config "Scripts" "remove" "$script_to_remove"
            scripts=($(read_config "Scripts"))
            zenity --info --text="Usunięto skrypt: $script_to_remove"
        fi
        continue
    fi

    if [ "$choice" == "Usuń hosta" ]; then
        host_to_remove=$(zenity --list --title="Usuń hosta" --column="Hosty" "${hosts[@]}")
        if [ -n "$host_to_remove" ]; then
            update_config "Hosts" "remove" "$host_to_remove"
            hosts=($(read_config "Hosts"))
            zenity --info --text="Usunięto hosta: $host_to_remove"
        fi
        continue
    fi


    if [ "$choice" == "Zakończ działający skrypt" ]; then
        refresh_running_scripts
        # Wybór działających skryptów do zakończenia
        if [ -f "$pid_file" ]; then
            running_scripts=$(cat "$pid_file")
            selected_scripts_to_kill=$(zenity --list --title="Wybierz skrypty do zakończenia" --column="PID" --column="Skrypty" --column="Host" --column="Rozpoczęcie" --multiple --separator=":" $running_scripts)

            if [ -n "$selected_scripts_to_kill" ]; then
                IFS=":" read -ra PIDS_TO_KILL <<< "$selected_scripts_to_kill"
                for pid_entry in "${PIDS_TO_KILL[@]}"; do
                    pid_to_kill=$(echo "$pid_entry" | cut -f1)
                    if kill -0 $pid_to_kill 2>/dev/null; then
                        kill $pid_to_kill
                        # Usuń wpis z pliku
                        sed -i "/$pid_to_kill/d" "$pid_file"
                    else
                        zenity --error --text="Nie można zakończyć skryptu. PID $pid_to_kill nie istnieje."
                    fi
                done
            fi
        else
            zenity --info --text="Brak działających skryptów."
        fi
        continue
    fi

    if [ "$choice" == "Zagraj w Kamień, Papier, Nożyce" ]; then
        play_game
        continue
    fi

    if [ "$choice" == "Pokaż logi" ]; then
        if [ -f "logfile.log" ]; then
            log_content=$(cat logfile.log)
            zenity --text-info --title="Logi" --width=600 --height=400 --filename=logfile.log
        else
            zenity --error --text="Nie znaleziono pliku logfile.log."
        fi
        continue
    fi

    # Wybór skryptu
    selected_script=$(zenity --list --title="Wybierz skrypt" --column="Skrypty" "${scripts[@]}")

    if [ -z "$selected_script" ]; then
        exit 1
    fi

    # Wybór hostów
    selected_hosts=$(zenity --list --title="Wybierz hosty" --column="Hosty" --multiple --separator=":" "${hosts[@]}")

    if [ -z "$selected_hosts" ]; then
        exit 1
    fi

    IFS=":" read -ra HOSTS_ARRAY <<< "$selected_hosts"

    for host in "${HOSTS_ARRAY[@]}"; do
        # Sprawdź, czy skrypt jest wykonywalny
        if [ -x "$script" ]; then
            zenity --error --text="Skrypt $script nie ma uprawnień do uruchamiania. Proszę nadać mu odpowiednie uprawnienia i spróbować ponownie."
            continue
        fi
        # Uruchom wybrany skrypt z wybranym hostem jako argumentem
        bash "$selected_script" -h "$host" &
        script_pid=$!

        # Zapisz PID, nazwę skryptu, hosta i timestamp (bez spacji) do pliku
        echo -e "$script_pid\t$selected_script\t$host\t$(date +"%Y%m%d-%H%M%S")" >> "$pid_file"

        # Odczekaj 3 sekundy przed uruchomieniem kolejnego skryptu
        sleep 3
    done
done

