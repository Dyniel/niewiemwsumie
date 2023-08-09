import os
import time
from datetime import datetime


base_dir = '/home/daniel/Desktop/Klienci/'
clients_dirs = [f'{base_dir}/client{i+1}' for i in range(1)]

for client_dir in clients_dirs:
    os.makedirs(client_dir, exist_ok=True)

file_size = 1

while True:
    for client_dir in clients_dirs:
        for i in range(5):
            timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
            file_name = f'{client_dir}/archive_{timestamp}_{i+1}.txt'
            with open(file_name, 'w') as f:
                f.write('Test data' * file_size)

    file_size *= 2
    time.sleep(1 * 10)
