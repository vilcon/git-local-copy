#!/bin/sh

test_description='but repack --geometric works correctly'

. ./test-lib.sh

GIT_TEST_MULTI_PACK_INDEX=0

objdir=.but/objects
midx=$objdir/pack/multi-pack-index

test_expect_success '--geometric with no packs' '
	but init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		but repack --write-midx --geometric 2 >out &&
		test_i18ngrep "Nothing new to pack" out
	)
'

test_expect_success '--geometric with one pack' '
	but init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		test_cummit "base" &&
		but repack -d &&

		but repack --geometric 2 >out &&

		test_i18ngrep "Nothing new to pack" out
	)
'

test_expect_success '--geometric with an intact progression' '
	but init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		# These packs already form a geometric progression.
		test_cummit_bulk --start=1 1 && # 3 objects
		test_cummit_bulk --start=2 2 && # 6 objects
		test_cummit_bulk --start=4 4 && # 12 objects

		find $objdir/pack -name "*.pack" | sort >expect &&
		but repack --geometric 2 -d &&
		find $objdir/pack -name "*.pack" | sort >actual &&

		test_cmp expect actual
	)
'

test_expect_success '--geometric with loose objects' '
	but init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		# These packs already form a geometric progression.
		test_cummit_bulk --start=1 1 && # 3 objects
		test_cummit_bulk --start=2 2 && # 6 objects
		# The loose objects are packed together, breaking the
		# progression.
		test_cummit loose && # 3 objects

		find $objdir/pack -name "*.pack" | sort >before &&
		but repack --geometric 2 -d &&
		find $objdir/pack -name "*.pack" | sort >after &&

		comm -13 before after >new &&
		comm -23 before after >removed &&

		test_line_count = 1 new &&
		test_must_be_empty removed &&

		but repack --geometric 2 -d &&
		find $objdir/pack -name "*.pack" | sort >after &&

		# The progression (3, 3, 6) is combined into one new pack.
		test_line_count = 1 after
	)
'

test_expect_success '--geometric with small-pack rollup' '
	but init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		test_cummit_bulk --start=1 1 && # 3 objects
		test_cummit_bulk --start=2 1 && # 3 objects
		find $objdir/pack -name "*.pack" | sort >small &&
		test_cummit_bulk --start=3 4 && # 12 objects
		test_cummit_bulk --start=7 8 && # 24 objects
		find $objdir/pack -name "*.pack" | sort >before &&

		but repack --geometric 2 -d &&

		# Three packs in total; two of the existing large ones, and one
		# new one.
		find $objdir/pack -name "*.pack" | sort >after &&
		test_line_count = 3 after &&
		comm -3 small before | tr -d "\t" >large &&
		grep -qFf large after
	)
'

test_expect_success '--geometric with small- and large-pack rollup' '
	but init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		# size(small1) + size(small2) > size(medium) / 2
		test_cummit_bulk --start=1 1 && # 3 objects
		test_cummit_bulk --start=2 1 && # 3 objects
		test_cummit_bulk --start=2 3 && # 7 objects
		test_cummit_bulk --start=6 9 && # 27 objects &&

		find $objdir/pack -name "*.pack" | sort >before &&

		but repack --geometric 2 -d &&

		find $objdir/pack -name "*.pack" | sort >after &&
		comm -12 before after >untouched &&

		# Two packs in total; the largest pack from before running "but
		# repack", and one new one.
		test_line_count = 1 untouched &&
		test_line_count = 2 after
	)
'

test_expect_success '--geometric ignores kept packs' '
	but init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		test_cummit kept && # 3 objects
		test_cummit pack && # 3 objects

		KEPT=$(but pack-objects --revs $objdir/pack/pack <<-EOF
		refs/tags/kept
		EOF
		) &&
		PACK=$(but pack-objects --revs $objdir/pack/pack <<-EOF
		refs/tags/pack
		^refs/tags/kept
		EOF
		) &&

		# neither pack contains more than twice the number of objects in
		# the other, so they should be combined. but, marking one as
		# .kept on disk will "freeze" it, so the pack structure should
		# remain unchanged.
		touch $objdir/pack/pack-$KEPT.keep &&

		find $objdir/pack -name "*.pack" | sort >before &&
		but repack --geometric 2 -d &&
		find $objdir/pack -name "*.pack" | sort >after &&

		# both packs should still exist
		test_path_is_file $objdir/pack/pack-$KEPT.pack &&
		test_path_is_file $objdir/pack/pack-$PACK.pack &&

		# and no new packs should be created
		test_cmp before after &&

		# Passing --pack-kept-objects causes packs with a .keep file to
		# be repacked, too.
		but repack --geometric 2 -d --pack-kept-objects &&

		find $objdir/pack -name "*.pack" >after &&
		test_line_count = 1 after
	)
'

test_expect_success '--geometric chooses largest MIDX preferred pack' '
	but init geometric &&
	test_when_finished "rm -fr geometric" &&
	(
		cd geometric &&

		# These packs already form a geometric progression.
		test_cummit_bulk --start=1 1 && # 3 objects
		test_cummit_bulk --start=2 2 && # 6 objects
		ls $objdir/pack/pack-*.idx >before &&
		test_cummit_bulk --start=4 4 && # 12 objects
		ls $objdir/pack/pack-*.idx >after &&

		but repack --geometric 2 -dbm &&

		comm -3 before after | xargs -n 1 basename >expect &&
		test-tool read-midx --preferred-pack $objdir >actual &&

		test_cmp expect actual
	)
'

test_done
