#!/bin/sh

test_description='"but fetch/pull --set-upstream" basic tests.'
GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

check_config () {
	printf "%s\n" "$2" "$3" >"expect.$1" &&
	{
		but config "branch.$1.remote" && but config "branch.$1.merge"
	} >"actual.$1" &&
	test_cmp "expect.$1" "actual.$1"
}

check_config_missing () {
	test_expect_code 1 but config "branch.$1.remote" &&
	test_expect_code 1 but config "branch.$1.merge"
}

clear_config () {
	for branch in "$@"; do
		test_might_fail but config --unset-all "branch.$branch.remote"
		test_might_fail but config --unset-all "branch.$branch.merge"
	done
}

ensure_fresh_upstream () {
	rm -rf parent && but init --bare parent
}

test_expect_success 'setup bare parent fetch' '
	ensure_fresh_upstream &&
	but remote add upstream parent
'

test_expect_success 'setup cummit on main and other fetch' '
	test_cummit one &&
	but push upstream main &&
	but checkout -b other &&
	test_cummit two &&
	but push upstream other
'

# tests for fetch --set-upstream

test_expect_success 'fetch --set-upstream does not set upstream w/o branch' '
	clear_config main other &&
	but checkout main &&
	but fetch --set-upstream upstream &&
	check_config_missing main &&
	check_config_missing other
'

test_expect_success 'fetch --set-upstream upstream main sets branch main but not other' '
	clear_config main other &&
	but fetch --set-upstream upstream main &&
	check_config main upstream refs/heads/main &&
	check_config_missing other
'

test_expect_success 'fetch --set-upstream upstream other sets branch other' '
	clear_config main other &&
	but fetch --set-upstream upstream other &&
	check_config main upstream refs/heads/other &&
	check_config_missing other
'

test_expect_success 'fetch --set-upstream main:other does not set the branch other2' '
	clear_config other2 &&
	but fetch --set-upstream upstream main:other2 &&
	check_config_missing other2
'

test_expect_success 'fetch --set-upstream http://nosuchdomain.example.com fails with invalid url' '
	# main explicitly not cleared, we check that it is not touched from previous value
	clear_config other other2 &&
	test_must_fail but fetch --set-upstream http://nosuchdomain.example.com &&
	check_config main upstream refs/heads/other &&
	check_config_missing other &&
	check_config_missing other2
'

test_expect_success 'fetch --set-upstream with valid URL sets upstream to URL' '
	clear_config other other2 &&
	url="file://$PWD" &&
	but fetch --set-upstream "$url" &&
	check_config main "$url" HEAD &&
	check_config_missing other &&
	check_config_missing other2
'

test_expect_success 'fetch --set-upstream with a detached HEAD' '
	but checkout HEAD^0 &&
	test_when_finished "but checkout -" &&
	cat >expect <<-\EOF &&
	warning: could not set upstream of HEAD to '"'"'main'"'"' from '"'"'upstream'"'"' when it does not point to any branch.
	EOF
	but fetch --set-upstream upstream main 2>actual.raw &&
	grep ^warning: actual.raw >actual &&
	test_cmp expect actual
'

# tests for pull --set-upstream

test_expect_success 'setup bare parent pull' '
	but remote rm upstream &&
	ensure_fresh_upstream &&
	but remote add upstream parent
'

test_expect_success 'setup cummit on main and other pull' '
	test_cummit three &&
	but push --tags upstream main &&
	test_cummit four &&
	but push upstream other
'

test_expect_success 'pull --set-upstream upstream main sets branch main but not other' '
	clear_config main other &&
	but pull --no-rebase --set-upstream upstream main &&
	check_config main upstream refs/heads/main &&
	check_config_missing other
'

test_expect_success 'pull --set-upstream main:other2 does not set the branch other2' '
	clear_config other2 &&
	but pull --no-rebase --set-upstream upstream main:other2 &&
	check_config_missing other2
'

test_expect_success 'pull --set-upstream upstream other sets branch main' '
	clear_config main other &&
	but pull --no-rebase --set-upstream upstream other &&
	check_config main upstream refs/heads/other &&
	check_config_missing other
'

test_expect_success 'pull --set-upstream upstream tag does not set the tag' '
	clear_config three &&
	but pull --no-rebase --tags --set-upstream upstream three &&
	check_config_missing three
'

test_expect_success 'pull --set-upstream http://nosuchdomain.example.com fails with invalid url' '
	# main explicitly not cleared, we check that it is not touched from previous value
	clear_config other other2 three &&
	test_must_fail but pull --set-upstream http://nosuchdomain.example.com &&
	check_config main upstream refs/heads/other &&
	check_config_missing other &&
	check_config_missing other2 &&
	check_config_missing three
'

test_expect_success 'pull --set-upstream upstream HEAD sets branch HEAD' '
	clear_config main other &&
	but pull --no-rebase --set-upstream upstream HEAD &&
	check_config main upstream HEAD &&
	but checkout other &&
	but pull --no-rebase --set-upstream upstream HEAD &&
	check_config other upstream HEAD
'

test_expect_success 'pull --set-upstream upstream with more than one branch does nothing' '
	clear_config main three &&
	but pull --no-rebase --set-upstream upstream main three &&
	check_config_missing main &&
	check_config_missing three
'

test_expect_success 'pull --set-upstream with valid URL sets upstream to URL' '
	clear_config main other other2 &&
	but checkout main &&
	url="file://$PWD" &&
	but pull --set-upstream "$url" &&
	check_config main "$url" HEAD &&
	check_config_missing other &&
	check_config_missing other2
'

test_expect_success 'pull --set-upstream with valid URL and branch sets branch' '
	clear_config main other other2 &&
	but checkout main &&
	url="file://$PWD" &&
	but pull --set-upstream "$url" main &&
	check_config main "$url" refs/heads/main &&
	check_config_missing other &&
	check_config_missing other2
'

test_expect_success 'pull --set-upstream with a detached HEAD' '
	but checkout HEAD^0 &&
	test_when_finished "but checkout -" &&
	cat >expect <<-\EOF &&
	warning: could not set upstream of HEAD to '"'"'main'"'"' from '"'"'upstream'"'"' when it does not point to any branch.
	EOF
	but pull --no-rebase --set-upstream upstream main 2>actual.raw &&
	grep ^warning: actual.raw >actual &&
	test_cmp expect actual
'

test_done
