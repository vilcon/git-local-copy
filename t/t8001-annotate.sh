#!/bin/sh

test_description='but annotate'
GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

PROG='but annotate'
. "$TEST_DIRECTORY"/annotate-tests.sh

test_expect_success 'annotate old revision' '
	but annotate file main >actual &&
	awk "{ print \$3; }" <actual >authors &&
	test 2 = $(grep A <authors | wc -l) &&
	test 2 = $(grep B <authors | wc -l)
'

test_done
