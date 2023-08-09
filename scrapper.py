import os
import psycopg2
from datetime import datetime
import random
import time

base_dir = '/home/zabbix/Klienci'
clients_dirs = [f'{base_dir}/client{i+1}' for i in range(20)]

conn = psycopg2.connect(database="celery_db", user="celery", password="celery", host="127.0.0.1", port="5432")
cur = conn.cursor()
while True:
    for client_dir in clients_dirs:
        total_size_bytes = sum(os.path.getsize(f'{client_dir}/{f}') for f in os.listdir(client_dir) if os.path.isfile(f'{client_dir}/{f}'))
        total_size_bytes *= 1 + (random.random() - 0.5) / 2.5
        cur.execute("INSERT INTO client_sizes (client_dir, total_size_mb, timestamp) VALUES (%s, %s, %s)", (client_dir, total_size_bytes, datetime.now()))
        conn.commit()
    time.sleep(1 * 60)


cur.close()
conn.close()
