#include "test.hpp"

#include "logger.h"

int main(void)
{
	logger_initialize();

	test();

	log(INFO, "test");

	logger_destroy();

	return 0;
}
