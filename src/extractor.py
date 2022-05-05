import datetime
from db import Db
from anonymizer.fake_generator import FakeGenerator

class Extractor:

    def __init__(self, credentials, env, args):
        self.db = Db(credentials)
        self.env = env
        self.name = "lite"
        self.sql = self.env.read_sql(f"src/sql/{self.name}.sql")
        self.specs = self.env.read_spec("src/anonymizer.json")
        self.args = args
        self.file_name = self.args.file.split(".")[0] if self.args.file else self.name

    def anonymize(self, dataframe):
        replacement_maps = FakeGenerator.generate(dataframe, self.specs)
        for spec in self.specs:
            dataframe = self.apply(dataframe, replacement_maps, spec["name"])
        return dataframe

    def apply(self, dataframe, replacement_maps, column):
        dataframe[column] = dataframe[column].replace(replacement_maps[column])
        return dataframe

    def timestemp(self):
        return datetime.datetime.now().strftime("%d-%m-%y %H:%M:%S")

    def start(self):
        print(f'=> Starting read {self.name} query at: {self.timestemp()}')
        data = self.db.read(self.sql)
        self.db.close()
        print(f'    Load {self.name} query process finished at: {self.timestemp()}')

        if self.args.anonymize:
            print(f'=> Starting anonymizing dataset at: {self.timestemp()}')
            data = self.anonymize(data)
            print(f'    Dataset anonymizing process finished at: {self.timestemp()}')

        print(f'=> Starting saving dataset at: {self.timestemp()}')
        self.env.save(self.file_name, data)
        print(f'    Saving dataset process finished at: {self.timestemp()}')
