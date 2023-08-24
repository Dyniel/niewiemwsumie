import pandas as pd
import matplotlib.pyplot as plt

# Wczytanie pliku logów
with open('logfile.log', 'r') as file:
    logs = file.readlines()

# Wyodrębnienie dat z logów i odfiltrowanie nieprawidłowych dat
dates = [log.split()[0] for log in logs if len(log.split()) > 0 and log.split()[0].count('-') == 2]

# Konwersja do DataFrame
df = pd.DataFrame(dates, columns=["Date"])

# Przetworzenie daty
df['Date'] = pd.to_datetime(df['Date'], errors='coerce')

# Usunięcie niewłaściwych dat
df = df.dropna()

# Grupowanie według daty i zliczenie
date_counts = df.groupby('Date').size()

# Wizualizacja
plt.figure(figsize=(15, 7))
date_counts.plot(kind='bar')
plt.title('Liczba logów w zależności od dnia')
plt.xlabel('Data')
plt.ylabel('Liczba logów')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()
