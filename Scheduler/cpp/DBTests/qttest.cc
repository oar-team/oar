#include <iostream>
#include <QtSql>
#include <QSqlDatabase>

#include "../Oar_iolib.H"

using namespace std;

/** 
    test of database management in qt sql

    by default, it use a sqlite database for testing purpose right now

*/


int miniconnect()
{
  QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE");
  db.setDatabaseName("mydb.db");
  bool ok = db.open();

  cout << "connect " << ok;
}

int main(int argc, char **argv)
{

  miniconnect();
}
