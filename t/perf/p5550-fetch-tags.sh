#!/bin/sh

test_description='performance of tag-following with many tags

This tests a fairly pathological case, so rather than rely on a real-world
case, we will construct our own repository. The situation is roughly as
follows.

The parent repository has a large number of tags which are disconnected from
the rest of history. That makes them candidates for tag-following, but we never
actually grab them (and thus they will impact each subsequent fetch).

The child repository is a clone of parent, without the tags, and is at least
one cummit behind the parent (meaning that we will fetch one object and then
examine the tags to see if they need followed). Furthermore, it has a large
number of packs.

The exact values of "large" here are somewhat arbitrary; I picked values that
start to show a noticeable performance problem on my machine, but without
taking too long to set up and run the tests.
'
. ./perf-lib.sh
. "$TEST_DIRECTORY/perf/lib-pack.sh"

# make a long nonsense history on branch $1, consisting of $2 cummits, each
# with a unique file pointing to the blob at $2.
create_history () {
	perl -le '
		my ($branch, $n, $blob) = @ARGV;
		for (1..$n) {
			print "cummit refs/heads/$branch";
			print "cummitter nobody <nobody@example.com> now";
			print "data 4";
			print "foo";
			print "M 100644 $blob $_";
		}
	' "$@" |
	but fast-import --date-format=now
}

# make a series of tags, one per cummit in the revision range given by $@
create_tags () {
	but rev-list "$@" |
	perl -lne 'print "create refs/tags/$. $_"' |
	but update-ref --stdin
}

test_expect_success 'create parent and child' '
	but init parent &&
	but -C parent cummit --allow-empty -m base &&
	but clone parent child &&
	but -C parent cummit --allow-empty -m trigger-fetch
'

test_expect_success 'populate parent tags' '
	(
		cd parent &&
		blob=$(echo content | but hash-object -w --stdin) &&
		create_history cruft 3000 $blob &&
		create_tags cruft &&
		but branch -D cruft
	)
'

test_expect_success 'create child packs' '
	(
		cd child &&
		setup_many_packs
	)
'

test_perf 'fetch' '
	# make sure there is something to fetch on each iteration
	but -C child update-ref -d refs/remotes/origin/master &&
	but -C child fetch
'

test_done
