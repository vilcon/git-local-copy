#!/bin/sh

test_description='cummit graph with 64-bit timestamps'
. ./test-lib.sh

if ! test_have_prereq TIME_IS_64BIT || ! test_have_prereq TIME_T_IS_64BIT
then
	skip_all='skipping 64-bit timestamp tests'
	test_done
fi

. "$TEST_DIRECTORY"/lib-cummit-graph.sh

UNIX_EPOCH_ZERO="@0 +0000"
FUTURE_DATE="@4147483646 +0000"

GIT_TEST_CUMMIT_GRAPH_CHANGED_PATHS=0

test_expect_success 'lower layers have overflow chunk' '
	rm -f .but/objects/info/cummit-graph &&
	test_cummit --date "$FUTURE_DATE" future-1 &&
	test_cummit --date "$UNIX_EPOCH_ZERO" old-1 &&
	but cummit-graph write --reachable &&
	test_cummit --date "$FUTURE_DATE" future-2 &&
	test_cummit --date "$UNIX_EPOCH_ZERO" old-2 &&
	but cummit-graph write --reachable --split=no-merge &&
	test_cummit extra &&
	but cummit-graph write --reachable --split=no-merge &&
	but cummit-graph write --reachable &&
	graph_read_expect 5 "generation_data generation_data_overflow" &&
	mv .but/objects/info/cummit-graph cummit-graph-upgraded &&
	but cummit-graph write --reachable &&
	graph_read_expect 5 "generation_data generation_data_overflow" &&
	test_cmp .but/objects/info/cummit-graph cummit-graph-upgraded
'

graph_but_behavior 'overflow' '' HEAD~2 HEAD

test_expect_success 'set up and verify repo with generation data overflow chunk' '
	mkdir repo &&
	cd repo &&
	but init &&
	test_cummit --date "$UNIX_EPOCH_ZERO" 1 &&
	test_cummit 2 &&
	test_cummit --date "$UNIX_EPOCH_ZERO" 3 &&
	but cummit-graph write --reachable &&
	graph_read_expect 3 generation_data &&
	test_cummit --date "$FUTURE_DATE" 4 &&
	test_cummit 5 &&
	test_cummit --date "$UNIX_EPOCH_ZERO" 6 &&
	but branch left &&
	but reset --hard 3 &&
	test_cummit 7 &&
	test_cummit --date "$FUTURE_DATE" 8 &&
	test_cummit 9 &&
	but branch right &&
	but reset --hard 3 &&
	test_merge M left right &&
	but cummit-graph write --reachable &&
	graph_read_expect 10 "generation_data generation_data_overflow" &&
	but cummit-graph verify
'

graph_but_behavior 'overflow 2' repo left right

test_done
