#!/bin/sh

test_description='ls-files tests with relative paths

This test runs but ls-files with various relative path arguments.
'

TEST_PASSES_SANITIZE_LEAK=true
. ./test-lib.sh

test_expect_success 'prepare' '
	: >never-mind-me &&
	but add never-mind-me &&
	mkdir top &&
	(
		cd top &&
		mkdir sub &&
		x="x xa xbc xdef xghij xklmno" &&
		y=$(echo "$x" | tr x y) &&
		touch $x &&
		touch $y &&
		cd sub &&
		but add ../x*
	)
'

test_expect_success 'ls-files with mixed levels' '
	(
		cd top/sub &&
		cat >expect <<-EOF &&
		../../never-mind-me
		../x
		EOF
		but ls-files $(cat expect) >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'ls-files -c' '
	(
		cd top/sub &&
		printf "error: pathspec $SQ%s$SQ did not match any file(s) known to but\n" ../y* >expect.err &&
		echo "Did you forget to ${SQ}but add${SQ}?" >>expect.err &&
		ls ../x* >expect.out &&
		test_must_fail but ls-files -c --error-unmatch ../[xy]* >actual.out 2>actual.err &&
		test_cmp expect.out actual.out &&
		test_cmp expect.err actual.err
	)
'

test_expect_success 'ls-files -o' '
	(
		cd top/sub &&
		printf "error: pathspec $SQ%s$SQ did not match any file(s) known to but\n" ../x* >expect.err &&
		echo "Did you forget to ${SQ}but add${SQ}?" >>expect.err &&
		ls ../y* >expect.out &&
		test_must_fail but ls-files -o --error-unmatch ../[xy]* >actual.out 2>actual.err &&
		test_cmp expect.out actual.out &&
		test_cmp expect.err actual.err
	)
'

test_done
