#include "test.h"

#include <stdio.h>

#include "gmk-test-static1.h"
#include "gmk-test-shared1.h"
#include "gmk-test-static3.h"

void test(void)
{
	printf("test()\n");

	gmk_test_static1();
	gmk_test_shared1();

	gmk_test_static3();
}
