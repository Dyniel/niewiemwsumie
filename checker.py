import os
import hashlib
import glob
import time
import configparser
from datetime import datetime, timedelta

deleted_files_count = 0

while True:
    base_dir = '/home/daniel/Desktop/Klienci'
    clients_dirs = [f'{base_dir}/client{i+1}' for i in range(20)]

    for client_dir in clients_dirs:
        print(f"Sprawdzanie katalogu: {client_dir}")

        config = configparser.ConfigParser()
        config.read(f'{client_dir}/config.ini')
        settings = config['settings']

        files = glob.glob(f"{client_dir}/*")
        files = [f for f in files if not f.endswith('config.ini')]
        files.sort(key=os.path.getmtime)

        while len(files) > 4:
            oldest_file = files.pop(0)
            print(f"Usuwanie najstarszego pliku: {oldest_file}")
            os.remove(oldest_file)
            deleted_files_count += 1

        if files:
            file_path = files[-1]
            print(f"Sprawdzanie pliku: {file_path}")

            file_time = datetime.fromtimestamp(os.path.getmtime(file_path))
            if file_time.date() < datetime.now().date() - timedelta(days=1):
                print(f"Plik {file_path} nie został stworzony dzisiaj ani wczoraj")
                continue

            if settings.getboolean('check_file_non_zero') and os.path.getsize(file_path) == 0:
                print(f"Plik {file_path} jest pusty")
                continue

            if settings.getboolean('check_md5'):
                with open(file_path, "rb") as f:
                    file_hash = hashlib.md5()
                    while chunk := f.read(8192):
                        file_hash.update(chunk)
                    print(f"MD5 pliku {file_path}: {file_hash.hexdigest()}")

    print(deleted_files_count)
    deleted_files_count = 0
    time.sleep(1 * 60)