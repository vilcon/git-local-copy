#!/bin/sh

test_description='merge-recursive rename options

Test rename detection by examining rename/delete conflicts.

* (HEAD -> rename) rename
| * (main) delete
|/
* base

but diff --name-status base main
D	0-old
D	1-old
D	2-old
D	3-old

but diff --name-status -M01 base rename
R025    0-old   0-new
R050    1-old   1-new
R075    2-old   2-new
R100    3-old   3-new

Actual similarity indices are parsed from diff output. We rely on the fact that
they are rounded down (see, e.g., Documentation/diff-generate-patch.txt, which
mentions this in a different context).
'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

get_expected_stages () {
	but checkout rename -- $1-new &&
	but ls-files --stage $1-new >expected-stages-undetected-$1 &&
	sed "s/ 0	/ 2	/" <expected-stages-undetected-$1 \
		>expected-stages-detected-$1 &&
	but read-tree -u --reset HEAD
}

rename_detected () {
	but ls-files --stage $1-old $1-new >stages-actual-$1 &&
	test_cmp expected-stages-detected-$1 stages-actual-$1
}

rename_undetected () {
	but ls-files --stage $1-old $1-new >stages-actual-$1 &&
	test_cmp expected-stages-undetected-$1 stages-actual-$1
}

check_common () {
	but ls-files --stage >stages-actual &&
	test_line_count = 4 stages-actual
}

check_threshold_0 () {
	check_common &&
	rename_detected 0 &&
	rename_detected 1 &&
	rename_detected 2 &&
	rename_detected 3
}

check_threshold_1 () {
	check_common &&
	rename_undetected 0 &&
	rename_detected 1 &&
	rename_detected 2 &&
	rename_detected 3
}

check_threshold_2 () {
	check_common &&
	rename_undetected 0 &&
	rename_undetected 1 &&
	rename_detected 2 &&
	rename_detected 3
}

check_exact_renames () {
	check_common &&
	rename_undetected 0 &&
	rename_undetected 1 &&
	rename_undetected 2 &&
	rename_detected 3
}

check_no_renames () {
	check_common &&
	rename_undetected 0 &&
	rename_undetected 1 &&
	rename_undetected 2 &&
	rename_undetected 3
}

test_expect_success 'setup repo' '
	cat <<-\EOF >3-old &&
	33a
	33b
	33c
	33d
	EOF
	sed s/33/22/ <3-old >2-old &&
	sed s/33/11/ <3-old >1-old &&
	sed s/33/00/ <3-old >0-old &&
	but add [0-3]-old &&
	but cummit -m base &&
	but rm [0-3]-old &&
	but cummit -m delete &&
	but checkout -b rename HEAD^ &&
	cp 3-old 3-new &&
	sed 1,1s/./x/ <2-old >2-new &&
	sed 1,2s/./x/ <1-old >1-new &&
	sed 1,3s/./x/ <0-old >0-new &&
	but add [0-3]-new &&
	but rm [0-3]-old &&
	but cummit -m rename &&
	get_expected_stages 0 &&
	get_expected_stages 1 &&
	get_expected_stages 2 &&
	get_expected_stages 3 &&
	check_50="false" &&
	tail="HEAD^ -- HEAD main"
'

test_expect_success 'setup thresholds' '
	but diff --name-status -M01 HEAD^ HEAD >diff-output &&
	test_debug "cat diff-output" &&
	test_line_count = 4 diff-output &&
	grep "R[0-9][0-9][0-9]	\([0-3]\)-old	\1-new" diff-output \
		>grep-output &&
	test_cmp diff-output grep-output &&
	th0=$(sed -n "s/R\(...\)	0-old	0-new/\1/p" <diff-output) &&
	th1=$(sed -n "s/R\(...\)	1-old	1-new/\1/p" <diff-output) &&
	th2=$(sed -n "s/R\(...\)	2-old	2-new/\1/p" <diff-output) &&
	th3=$(sed -n "s/R\(...\)	3-old	3-new/\1/p" <diff-output) &&
	test "$th0" -lt "$th1" &&
	test "$th1" -lt "$th2" &&
	test "$th2" -lt "$th3" &&
	test "$th3" = 100 &&
	if test 50 -le "$th0"
	then
		check_50=check_threshold_0
	elif test 50 -le "$th1"
	then
		check_50=check_threshold_1
	elif test 50 -le "$th2"
	then
		check_50=check_threshold_2
	fi &&
	th0="$th0%" &&
	th1="$th1%" &&
	th2="$th2%" &&
	th3="$th3%"
'

test_expect_success 'assumption for tests: rename detection with diff' '
	but diff --name-status -M$th0 --diff-filter=R HEAD^ HEAD \
		>diff-output-0 &&
	but diff --name-status -M$th1 --diff-filter=R HEAD^ HEAD \
		>diff-output-1 &&
	but diff --name-status -M$th2 --diff-filter=R HEAD^ HEAD \
		>diff-output-2 &&
	but diff --name-status -M100% --diff-filter=R HEAD^ HEAD \
		>diff-output-3 &&
	test_line_count = 4 diff-output-0 &&
	test_line_count = 3 diff-output-1 &&
	test_line_count = 2 diff-output-2 &&
	test_line_count = 1 diff-output-3
'

test_expect_success 'default similarity threshold is 50%' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive $tail &&
	$check_50
'

test_expect_success 'low rename threshold' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --find-renames=$th0 $tail &&
	check_threshold_0
'

test_expect_success 'medium rename threshold' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --find-renames=$th1 $tail &&
	check_threshold_1
'

test_expect_success 'high rename threshold' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --find-renames=$th2 $tail &&
	check_threshold_2
'

test_expect_success 'exact renames only' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --find-renames=100% $tail &&
	check_exact_renames
'

test_expect_success 'rename threshold is truncated' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --find-renames=200% $tail &&
	check_exact_renames
'

test_expect_success 'disabled rename detection' '
	but read-tree --reset -u HEAD &&
	but merge-recursive --no-renames $tail &&
	check_no_renames
'

test_expect_success 'last wins in --find-renames=<m> --find-renames=<n>' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive \
		--find-renames=$th0 --find-renames=$th2 $tail &&
	check_threshold_2
'

test_expect_success '--find-renames resets threshold' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive \
		--find-renames=$th0 --find-renames $tail &&
	$check_50
'

test_expect_success 'last wins in --no-renames --find-renames' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --no-renames --find-renames $tail &&
	$check_50
'

test_expect_success 'last wins in --find-renames --no-renames' '
	but read-tree --reset -u HEAD &&
	but merge-recursive --find-renames --no-renames $tail &&
	check_no_renames
'

test_expect_success 'assumption for further tests: trivial merge succeeds' '
	but read-tree --reset -u HEAD &&
	but merge-recursive HEAD -- HEAD HEAD &&
	but diff --quiet --cached &&
	but merge-recursive --find-renames=$th0 HEAD -- HEAD HEAD &&
	but diff --quiet --cached &&
	but merge-recursive --find-renames=$th2 HEAD -- HEAD HEAD &&
	but diff --quiet --cached &&
	but merge-recursive --find-renames=100% HEAD -- HEAD HEAD &&
	but diff --quiet --cached &&
	but merge-recursive --no-renames HEAD -- HEAD HEAD &&
	but diff --quiet --cached
'

test_expect_success '--find-renames rejects negative argument' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --find-renames=-25 \
		HEAD -- HEAD HEAD &&
	but diff --quiet --cached
'

test_expect_success '--find-renames rejects non-numbers' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --find-renames=0xf \
		HEAD -- HEAD HEAD &&
	but diff --quiet --cached
'

test_expect_success 'rename-threshold=<n> is a synonym for find-renames=<n>' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --rename-threshold=$th0 $tail &&
	check_threshold_0
'

test_expect_success 'last wins in --no-renames --rename-threshold=<n>' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --no-renames --rename-threshold=$th0 $tail &&
	check_threshold_0
'

test_expect_success 'last wins in --rename-threshold=<n> --no-renames' '
	but read-tree --reset -u HEAD &&
	but merge-recursive --rename-threshold=$th0 --no-renames $tail &&
	check_no_renames
'

test_expect_success '--rename-threshold=<n> rejects negative argument' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --rename-threshold=-25 \
		HEAD -- HEAD HEAD &&
	but diff --quiet --cached
'

test_expect_success '--rename-threshold=<n> rejects non-numbers' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive --rename-threshold=0xf \
		HEAD -- HEAD HEAD &&
	but diff --quiet --cached
'

test_expect_success 'last wins in --rename-threshold=<m> --find-renames=<n>' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive \
		--rename-threshold=$th0 --find-renames=$th2 $tail &&
	check_threshold_2
'

test_expect_success 'last wins in --find-renames=<m> --rename-threshold=<n>' '
	but read-tree --reset -u HEAD &&
	test_must_fail but merge-recursive \
		--find-renames=$th2 --rename-threshold=$th0 $tail &&
	check_threshold_0
'

test_expect_success 'merge.renames disables rename detection' '
	but read-tree --reset -u HEAD &&
	but -c merge.renames=false merge-recursive $tail &&
	check_no_renames
'

test_expect_success 'merge.renames defaults to diff.renames' '
	but read-tree --reset -u HEAD &&
	but -c diff.renames=false merge-recursive $tail &&
	check_no_renames
'

test_expect_success 'merge.renames overrides diff.renames' '
	but read-tree --reset -u HEAD &&
	test_must_fail but -c diff.renames=false -c merge.renames=true merge-recursive $tail &&
	$check_50
'

test_done
