import os
import subprocess
import time


base_dir = '/home/daniel/Desktop/Klienci/'
clients_dirs = [f'{base_dir}/client{i + 1}' for i in range(20)]
while True:
    for client_dir in clients_dirs:
        total_size = 0
        for dirpath, dirnames, filenames in os.walk(client_dir):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                total_size += os.path.getsize(fp)
        subprocess.run(
            ['zabbix_sender', '-vv', '-z', '127.0.0.1', '-p', '10051', '-s', 'Daniel', '-k', 'trap', '-o', str(total_size)])
    time.sleep(1 * 10)