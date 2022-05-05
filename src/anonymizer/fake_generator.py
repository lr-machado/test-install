from faker import Faker

def fake(fake, dataframe, column_name, fake_type):
    entities = dataframe
    entities_map = {}
    for _, row in entities.iterrows():
        if fake_type == "company":
            fake_name = fake.unique.company()
        else:
            fake_name = fake.unique.name()
        entities_map[row[column_name]] = fake_name
    return entities_map

class FakeGenerator:
    @staticmethod
    def generate(dataframe, specs):
        faker = Faker()

        results = {}
        for spec in specs:
            results[spec["name"]] = fake(faker, dataframe, spec["name"], spec["fake_type"])
        return results
