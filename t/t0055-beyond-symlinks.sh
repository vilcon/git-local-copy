#!/bin/sh

test_description='update-index and add refuse to add beyond symlinks'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success SYMLINKS setup '
	>a &&
	mkdir b &&
	ln -s b c &&
	>c/d &&
	but update-index --add a b/d
'

test_expect_success SYMLINKS 'update-index --add beyond symlinks' '
	test_must_fail but update-index --add c/d &&
	! ( but ls-files | grep c/d )
'

test_expect_success SYMLINKS 'add beyond symlinks' '
	test_must_fail but add c/d &&
	! ( but ls-files | grep c/d )
'

test_done
