#!/bin/sh

test_description='but am with options and not losing them'
. ./test-lib.sh

tm="$TEST_DIRECTORY/t4252"

test_expect_success setup '
	cp "$tm/file-1-0" file-1 &&
	cp "$tm/file-2-0" file-2 &&
	but add file-1 file-2 &&
	test_tick &&
	but cummit -m initial &&
	but tag initial
'

test_expect_success 'interrupted am --whitespace=fix' '
	rm -rf .but/rebase-apply &&
	but reset --hard initial &&
	test_must_fail but am --whitespace=fix "$tm"/am-test-1-? &&
	but am --skip &&
	grep 3 file-1 &&
	grep "^Six$" file-2
'

test_expect_success 'interrupted am -C1' '
	rm -rf .but/rebase-apply &&
	but reset --hard initial &&
	test_must_fail but am -C1 "$tm"/am-test-2-? &&
	but am --skip &&
	grep 3 file-1 &&
	grep "^Three$" file-2
'

test_expect_success 'interrupted am -p2' '
	rm -rf .but/rebase-apply &&
	but reset --hard initial &&
	test_must_fail but am -p2 "$tm"/am-test-3-? &&
	but am --skip &&
	grep 3 file-1 &&
	grep "^Three$" file-2
'

test_expect_success 'interrupted am -C1 -p2' '
	rm -rf .but/rebase-apply &&
	but reset --hard initial &&
	test_must_fail but am -p2 -C1 "$tm"/am-test-4-? &&
	but am --skip &&
	grep 3 file-1 &&
	grep "^Three$" file-2
'

test_expect_success 'interrupted am --directory="frotz nitfol"' '
	rm -rf .but/rebase-apply &&
	but reset --hard initial &&
	test_must_fail but am --directory="frotz nitfol" "$tm"/am-test-5-? &&
	but am --skip &&
	grep One "frotz nitfol/file-5"
'

test_expect_success 'apply to a funny path' '
	with_sq="with'\''sq" &&
	rm -fr .but/rebase-apply &&
	but reset --hard initial &&
	but am --directory="$with_sq" "$tm"/am-test-5-2 &&
	test -f "$with_sq/file-5"
'

test_expect_success 'am --reject' '
	rm -rf .but/rebase-apply &&
	but reset --hard initial &&
	test_must_fail but am --reject "$tm"/am-test-6-1 &&
	grep "@@ -1,3 +1,3 @@" file-2.rej &&
	test_must_fail but diff-files --exit-code --quiet file-2 &&
	grep "[-]-reject" .but/rebase-apply/apply-opt
'

test_done
