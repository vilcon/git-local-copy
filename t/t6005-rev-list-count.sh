#!/bin/sh

test_description='but rev-list --max-count and --skip test'

. ./test-lib.sh

test_expect_success 'setup' '
    for n in 1 2 3 4 5 ; do
	echo $n > a &&
	but add a &&
	but cummit -m "$n" || return 1
    done
'

test_expect_success 'no options' '
	test_stdout_line_count = 5 but rev-list HEAD
'

test_expect_success '--max-count' '
	test_stdout_line_count = 0 but rev-list HEAD --max-count=0 &&
	test_stdout_line_count = 3 but rev-list HEAD --max-count=3 &&
	test_stdout_line_count = 5 but rev-list HEAD --max-count=5 &&
	test_stdout_line_count = 5 but rev-list HEAD --max-count=10
'

test_expect_success '--max-count all forms' '
	test_stdout_line_count = 1 but rev-list HEAD --max-count=1 &&
	test_stdout_line_count = 1 but rev-list HEAD -1 &&
	test_stdout_line_count = 1 but rev-list HEAD -n1 &&
	test_stdout_line_count = 1 but rev-list HEAD -n 1
'

test_expect_success '--skip' '
	test_stdout_line_count = 5 but rev-list HEAD --skip=0 &&
	test_stdout_line_count = 2 but rev-list HEAD --skip=3 &&
	test_stdout_line_count = 0 but rev-list HEAD --skip=5 &&
	test_stdout_line_count = 0 but rev-list HEAD --skip=10
'

test_expect_success '--skip --max-count' '
	test_stdout_line_count = 0 but rev-list HEAD --skip=0 --max-count=0 &&
	test_stdout_line_count = 5 but rev-list HEAD --skip=0 --max-count=10 &&
	test_stdout_line_count = 0 but rev-list HEAD --skip=3 --max-count=0 &&
	test_stdout_line_count = 1 but rev-list HEAD --skip=3 --max-count=1 &&
	test_stdout_line_count = 2 but rev-list HEAD --skip=3 --max-count=2 &&
	test_stdout_line_count = 2 but rev-list HEAD --skip=3 --max-count=10 &&
	test_stdout_line_count = 0 but rev-list HEAD --skip=5 --max-count=10 &&
	test_stdout_line_count = 0 but rev-list HEAD --skip=10 --max-count=10
'

test_done
