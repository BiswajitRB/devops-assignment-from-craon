import os

# Set test environment flag so tests don't hang waiting for external databases
os.environ["TESTING"] = "true"
