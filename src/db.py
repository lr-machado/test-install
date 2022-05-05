import pyodbc
import pandas.io.sql as sqlio

class Db:
    def __init__(self, credentials):
        self.credentials = credentials
        self.connector = self.connect()

    def connect(self):
        conn = pyodbc.connect(
            driver=f"ODBC Driver 18 for SQL Server",
            server=f"{self.credentials['host']}, {self.credentials['port']}",
            database=f"{self.credentials['name']}",
            uid=f"{self.credentials['user']}",
            pwd=f"{self.credentials['password']}",
            TrustServerCertificate='yes',
            Encrypt='yes',
        )

        return conn

    def close(self):
        self.connector.close()
        print(f"    Database connection closed.")

    def execute(self, sql):
        cursor = self.connector.cursor()
        cursor.execute(sql)
        self.connector.commit()
        result = None
        try:
            result = cursor.fetchall()
        except:
            pass
        cursor.close()
        return result

    def read(self, sql):
        return sqlio.read_sql_query(sql, self.connector)
