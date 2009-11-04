# If your project uses a database, you can set up database tests
# similar to what you see below. Be sure to set the db_uri to
# an appropriate uri for your testing database. sqlite is a good
# choice for testing, because you can use an in-memory database
# which is very fast.

from turbogears import testutil, database
# from tgoar.model import YourDataClass, User

database.set_db_uri("postgres://oar:oar@faro/oar")
# class TestUser(testutil.DBTest):
#     def get_model(self):
#         return User
#     def test_creation(self):
#         "Object creation should set the name"
#         obj = User(user_name = "creosote",
#                       email_address = "spam@python.not",
#                       display_name = "Mr Creosote",
#                       password = "Wafer-thin Mint")
#         assert obj.display_name == "Mr Creosote"

from tgoar.model import *


class TestResources(testutil.DBTest):
    def get_model(self):
        return resources
    def test_select(self):
        " Fetch all resources "
        r =  resources()
        print r 



