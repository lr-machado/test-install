import os
import json

class Env:
    def __init__(self, password):
        self.file_path = os.path.abspath(os.curdir)
        self.config = self.read_config()
        self.output = os.path.join(self.file_path, f"output/")
        self.password = password
        self.clear()

    def clear(self):
        try:
            if os.path.isdir(self.output):
                for file in os.listdir(self.output):
                    os.remove(os.path.join(self.output, file))
        except Exception as e:
            print(f"Failed to find {self.output}. Reason: {e}")

    def read_db_settings(self):
        credentials = {
            "user": self.config["dbUser"],
            "host": self.config["dbHost"],
            "port": self.config["dbPort"],
            "name": self.config["dbName"],
            "password": self.password,
        }
        return credentials

    def read_sql(self, spec):
        file  = open(os.path.join(self.file_path, spec))
        sql = file.read()
        file.close()
        return sql

    def read_spec(self, spec):
        return json.load(open(os.path.join(self.file_path, spec)))

    def read_config(self):
        file = open(os.path.join(self.file_path, f".ghrc"))
        return json.load(file)

    def save(self, name, dataframe):
        file_name = os.path.join(self.output, f"{name}.csv")
        dataframe.to_csv(file_name, index=False)
