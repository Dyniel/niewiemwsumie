import os
import subprocess
import time
import sys
import configparser
import argparse

parser = argparse.ArgumentParser(description='Monitoruj rozmiar pliku i wysyłaj dane do Zabbix.')
parser.add_argument('-f', required=True, help='ścieżka do monitorowanego pliku')
parser.add_argument('--host', required=True, help='host Zabbix')
parser.add_argument('--key', required=True, help='klucz Zabbix')

args = parser.parse_args()

file_name = args.f
zabbix_host = args.host
zabbix_key_name = args.key

config = configparser.ConfigParser()
config.read('config.ini')

command = config.get('DEFAULT', 'command')
verbose = config.get('DEFAULT', 'verbose')
server = config.get('DEFAULT', 'server')
port = config.get('DEFAULT', 'port')

while True:
    if os.path.isfile(file_name):
        file_size = os.path.getsize(file_name)
        subprocess.run([command, verbose, '-z', server, '-p', port, '-s', zabbix_host, '-k', zabbix_key_name, '-o', str(file_size)])

    else:
        print(f"Plik {file_name} nie istnieje.")
    #time.sleep(1 * 60)
    break
