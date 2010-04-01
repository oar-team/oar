#ifndef TESTRESOURCETREE_H
#define TESTRESOURCETREE_H

#include <cppunit/extensions/HelperMacros.h>

class TestResourceTree : public CppUnit::TestFixture
{
  CPPUNIT_TEST_SUITE( TestResourceTree );
  CPPUNIT_TEST( testConstructor );
  CPPUNIT_TEST( testAccessor );
  CPPUNIT_TEST( testTreeManipulation );
  CPPUNIT_TEST_SUITE_END();

public:
  void setUp();
  void tearDown();

  void testConstructor();
  void testAccessor();
  void testTreeManipulation();
};

#endif
