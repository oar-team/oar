#include <iostream>
#include <QtSql>
#include <QSqlDatabase>

using namespace std;

/** 
    test of database management in qt sql

    by default, it use a sqlite database for testing purpose right now

*/


int connect()
{
  QSqlDatabase db = QSqlDatabase::addDatabase("sqlitedb");
  db.setDatabaseName("mydb.db");
  bool ok = db.open();

  cout << "connect " << ok;
}

int main(int argc, char **argv)
{

  connect();
}
