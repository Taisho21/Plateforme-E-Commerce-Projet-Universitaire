import psycopg2
import psycopg2.extras

def connect():
    conn = psycopg2.connect(
        host = "localhost",
        dbname = "enjoy", 
        user = "postgres",
        password = '2105',
        cursor_factory = psycopg2.extras.NamedTupleCursor
    )

    conn.set_client_encoding('UTF8')
    conn.autocommit = True
    return conn