#!/usr/bin/env python3

import psycopg2

# Zmienne środowiskowe dla połączenia z bazą danych
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "celery_db"
DB_USER = "celery"
DB_PASS = "celery"

# Zapytanie SQL do wykonania
SQL_QUERY = "SELECT count(*) FROM client_sizes;"

# Utwórz połączenie z bazą danych
conn = psycopg2.connect(
    host=DB_HOST,
    port=DB_PORT,
    dbname=DB_NAME,
    user=DB_USER,
    password=DB_PASS
)

# Utwórz kursor do wykonywania zapytań
cur = conn.cursor()

# Wykonaj zapytanie
cur.execute(SQL_QUERY)

# Pobierz wynik
result = cur.fetchone()

# Wydrukuj wynik
print(result[0])

# Zamknij połączenie z bazą danych
conn.close()