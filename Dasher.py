import dash
from dash import dcc, html, Input, Output, State
import dash_bootstrap_components as dbc
import plotly.express as px
import pandas as pd
import base64
import io

# Inicjacja aplikacji
app = dash.Dash(__name__, external_stylesheets=[dbc.themes.BOOTSTRAP])
server = app.server

# Layout aplikacji
app.layout = dbc.Container([
    html.H1('Analiza Dziennika'),
    dcc.Upload(
        id='upload-data',
        children=html.Button('Wczytaj plik dziennika'),
        multiple=False
    ),
    dbc.Row([
        dbc.Col(
            dcc.Dropdown(
                id='analysis-type',
                options=[
                    {'label': 'Rozkład komunikatów', 'value': 'message_distribution'},
                    {'label': 'Histogram długości komunikatów', 'value': 'message_length_histogram'},
                    {'label': 'Heatmapa aktywności', 'value': 'activity_heatmap'},
                    {'label': 'Grupowanie komunikatów według tokenów', 'value': 'group_by_tokens'}
                ],
                value='message_distribution',
                clearable=False
            ),
        ),
        dbc.Col(
            dcc.Input(id='search-term', type='text', placeholder='Wyszukaj słowo kluczowe...'),
        ),
        dbc.Col(
            dcc.Dropdown(
                id='log-level',
                options=[
                    {'label': 'Wszystkie', 'value': 'ALL'},
                    {'label': 'INFO', 'value': 'INFO'},
                    {'label': 'WARNING', 'value': 'WARNING'},
                    {'label': 'ERROR', 'value': 'ERROR'}
                ],
                value='ALL',
                clearable=False
            ),
        )
    ]),
    dcc.Graph(id='log-analysis'),
    html.Div(id='analysis-output')
])

def parse_log(contents):
    content_type, content_string = contents.split(',')
    decoded = base64.b64decode(content_string).decode('utf-8')
    lines = decoded.split('\n')
    data = {
        'Date': [],
        'Message': []
    }

    for line in lines:
        parts = line.split()
        if len(parts) >= 3:
            data['Date'].append(parts[0] + " " + parts[1])
            data['Message'].append(" ".join(parts[2:]))

    return pd.DataFrame(data)

def group_messages_by_tokens(df):
    tokens = [
        "Usunięcie pliku", "Zakończono usuwanie", "MD5 dla pliku",
        "Wysyłanie do Zabbix", "Całkowita liczba", "Błąd"
    ]

    df['Group'] = 'Inne'  # Default group
    for token in tokens:
        df.loc[df['Message'].str.contains(token, case=False, regex=False), 'Group'] = token

    return df

@app.callback(
    [Output('log-analysis', 'figure'),
     Output('analysis-output', 'children')],
    [Input('upload-data', 'contents'),
     Input('analysis-type', 'value'),
     Input('search-term', 'value'),
     Input('log-level', 'value')],
    [State('upload-data', 'filename')]
)
def update_analysis(contents, analysis_type, search_term, log_level, filename):
    if not contents:
        return dash.no_update, dash.no_update

    df = parse_log(contents)
    df['Date'] = pd.to_datetime(df['Date'], errors='coerce')
    df = df.dropna()

    # Filtrowanie na podstawie wyszukiwania i poziomu ważności
    if search_term:
        df = df[df['Message'].str.contains(search_term, case=False, na=False)]
    if log_level != 'ALL':
        df = df[df['Message'].str.contains(log_level, case=True, na=False)]

    if analysis_type == 'message_distribution':
        fig = px.histogram(df, x='Message', title='Rozkład komunikatów')
        return fig, f'Analiza dla pliku: {filename}'

    elif analysis_type == 'message_length_histogram':
        df['Message Length'] = df['Message'].apply(len)
        fig = px.histogram(df, x='Message Length', title='Histogram długości komunikatów')
        return fig, f'Analiza dla pliku: {filename}'

    elif analysis_type == 'activity_heatmap':
        df['Hour'] = df['Date'].dt.hour
        df['Minute'] = df['Date'].dt.minute
        heatmap_data = df.groupby(['Hour', 'Minute']).size().reset_index(name='Count')
        fig = px.density_heatmap(heatmap_data, x='Minute', y='Hour', z='Count', histfunc='sum',
                                 title='Heatmapa aktywności')
        return fig, f'Analiza dla pliku: {filename}'

    elif analysis_type == 'group_by_tokens':
        df_grouped = group_messages_by_tokens(df)
        fig = px.histogram(df_grouped, x='Group', title='Komunikaty pogrupowane według tokenów')
        return fig, f'Analiza dla pliku: {filename}'

if __name__ == '__main__':
    app.run_server(debug=True)
