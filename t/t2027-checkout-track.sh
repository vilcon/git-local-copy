#!/bin/sh

test_description='tests for but branch --track'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	test_cummit one &&
	test_cummit two
'

test_expect_success 'checkout --track -b creates a new tracking branch' '
	but checkout --track -b branch1 main &&
	test $(but rev-parse --abbrev-ref HEAD) = branch1 &&
	test $(but config --get branch.branch1.remote) = . &&
	test $(but config --get branch.branch1.merge) = refs/heads/main
'

test_expect_success 'checkout --track -b rejects an extra path argument' '
	test_must_fail but checkout --track -b branch2 main one.t 2>err &&
	test_i18ngrep "cannot be used with updating paths" err
'

test_expect_success 'checkout --track -b overrides autoSetupMerge=inherit' '
	# Set up tracking config on main
	test_config branch.main.remote origin &&
	test_config branch.main.merge refs/heads/some-branch &&
	test_config branch.autoSetupMerge inherit &&
	# With --track=inherit, we copy the tracking config from main
	but checkout --track=inherit -b b1 main &&
	test_cmp_config origin branch.b1.remote &&
	test_cmp_config refs/heads/some-branch branch.b1.merge &&
	# With branch.autoSetupMerge=inherit, we do the same
	but checkout -b b2 main &&
	test_cmp_config origin branch.b2.remote &&
	test_cmp_config refs/heads/some-branch branch.b2.merge &&
	# But --track overrides this
	but checkout --track -b b3 main &&
	test_cmp_config . branch.b3.remote &&
	test_cmp_config refs/heads/main branch.b3.merge &&
	# And --track=direct does as well
	but checkout --track=direct -b b4 main &&
	test_cmp_config . branch.b4.remote &&
	test_cmp_config refs/heads/main branch.b4.merge
'

test_done
