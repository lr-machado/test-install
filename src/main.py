import argparse
import datetime
import pyodbc
import time

from extractor import Extractor
from envs import Env

MAX_ATTEMPTS = 5

def execute():
    print(f'=> Extraction started at: {datetime.datetime.now().strftime("%d-%m-%y %H:%M:%S")}')
    parser = argparse.ArgumentParser()
    parser.add_argument("-a", "--anonymize", action="store_true", help="extract dataset with anonymize data (e.g., provider and client fields)")
    parser.add_argument("-p", "--password", nargs='?', help="Database Password)")
    parser.add_argument("-f", "--file", nargs='?', help="rename outcome file with custom file name (the .csv extension is optional)")
    args = parser.parse_args()
    password = args.password.split(".")[0]
    env = Env(password)
    credentials = env.read_db_settings()
    extractor = Extractor(credentials, env, args)
    extractor.start()
    print(f'    Extraction finished in  at: {datetime.datetime.now().strftime("%d-%m-%y %H:%M:%S")}')

if __name__ == "__main__":
    attempts = 0
    while (attempts < MAX_ATTEMPTS):
        try:
            execute()
        except pyodbc.OperationalError as error:
            if attempts < MAX_ATTEMPTS:
                print(f"Error: {error.args[1]}")
                print(f"retrying...\n")
                attempts = attempts + 1
                time.sleep(2)
            if attempts == MAX_ATTEMPTS:
                print(f"Please check your database credentials or connection.")
            continue
        break

    print("Lite Extractor finished.")
