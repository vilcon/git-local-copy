#!/bin/sh

test_description='Tests performance using midx bitmaps'
. ./perf-lib.sh
. "${TEST_DIRECTORY}/perf/lib-bitmap.sh"

test_perf_large_repo

# we need to create the tag up front such that it is covered by the repack and
# thus by generated bitmaps.
test_expect_success 'create tags' '
	but tag --message="tag pointing to HEAD" perf-tag HEAD
'

test_expect_success 'start with bitmapped pack' '
	but repack -adb
'

test_perf 'setup multi-pack index' '
	but multi-pack-index write --bitmap
'

test_expect_success 'drop pack bitmap' '
	rm -f .but/objects/pack/pack-*.bitmap
'

test_full_bitmap

test_expect_success 'create partial bitmap state' '
	# pick a cummit to represent the repo tip in the past
	cutoff=$(but rev-list HEAD~100 -1) &&
	orig_tip=$(but rev-parse HEAD) &&

	# now pretend we have just one tip
	rm -rf .but/logs .but/refs/* .but/packed-refs &&
	but update-ref HEAD $cutoff &&

	# and then repack, which will leave us with a nice
	# big bitmap pack of the "old" history, and all of
	# the new history will be loose, as if it had been pushed
	# up incrementally and exploded via unpack-objects
	but repack -Ad &&
	but multi-pack-index write --bitmap &&

	# and now restore our original tip, as if the pushes
	# had happened
	but update-ref HEAD $orig_tip
'

test_partial_bitmap

test_done
