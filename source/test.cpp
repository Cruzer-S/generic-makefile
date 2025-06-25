#include "test.hpp"

#include <iostream>

extern "C" void test(void)
{
	std::cout << "this is test function" << std::endl;
}
