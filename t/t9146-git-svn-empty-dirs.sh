#!/bin/sh
#
# Copyright (c) 2009 Eric Wong

test_description='but svn creates empty directories'
. ./lib-but-svn.sh

test_expect_success 'initialize repo' '
	for i in a b c d d/e d/e/f "weird file name"
	do
		svn_cmd mkdir -m "mkdir $i" "$svnrepo"/"$i" || return 1
	done
'

test_expect_success 'clone' 'but svn clone "$svnrepo" cloned'

test_expect_success 'empty directories exist' '
	(
		cd cloned &&
		for i in a b c d d/e d/e/f "weird file name"
		do
			if ! test -d "$i"
			then
				echo >&2 "$i does not exist" &&
				exit 1
			fi
		done
	)
'

test_expect_success 'option automkdirs set to false' '
	(
		but svn init "$svnrepo" cloned-no-mkdirs &&
		cd cloned-no-mkdirs &&
		but config svn-remote.svn.automkdirs false &&
		but svn fetch &&
		for i in a b c d d/e d/e/f "weird file name"
		do
			if test -d "$i"
			then
				echo >&2 "$i exists" &&
				exit 1
			fi
		done
	)
'

test_expect_success 'more emptiness' '
	svn_cmd mkdir -m "bang bang"  "$svnrepo"/"! !"
'

test_expect_success 'but svn rebase creates empty directory' '
	( cd cloned && but svn rebase ) &&
	test -d cloned/"! !"
'

test_expect_success 'but svn mkdirs recreates empty directories' '
	(
		cd cloned &&
		rm -r * &&
		but svn mkdirs &&
		for i in a b c d d/e d/e/f "weird file name" "! !"
		do
			if ! test -d "$i"
			then
				echo >&2 "$i does not exist" &&
				exit 1
			fi
		done
	)
'

test_expect_success 'but svn mkdirs -r works' '
	(
		cd cloned &&
		rm -r * &&
		but svn mkdirs -r7 &&
		for i in a b c d d/e d/e/f "weird file name"
		do
			if ! test -d "$i"
			then
				echo >&2 "$i does not exist" &&
				exit 1
			fi
		done &&

		if test -d "! !"
		then
			echo >&2 "$i should not exist" &&
			exit 1
		fi &&

		but svn mkdirs -r8 &&
		if ! test -d "! !"
		then
			echo >&2 "$i not exist" &&
			exit 1
		fi
	)
'

test_expect_success 'initialize trunk' '
	for i in trunk trunk/a trunk/"weird file name"
	do
		svn_cmd mkdir -m "mkdir $i" "$svnrepo"/"$i" || return 1
	done
'

test_expect_success 'clone trunk' 'but svn clone -s "$svnrepo" trunk'

test_expect_success 'empty directories in trunk exist' '
	(
		cd trunk &&
		for i in a "weird file name"
		do
			if ! test -d "$i"
			then
				echo >&2 "$i does not exist" &&
				exit 1
			fi
		done
	)
'

test_expect_success 'remove a top-level directory from svn' '
	svn_cmd rm -m "remove d" "$svnrepo"/d
'

test_expect_success 'removed top-level directory does not exist' '
	but svn clone "$svnrepo" removed &&
	test ! -e removed/d

'
unhandled=.but/svn/refs/remotes/but-svn/unhandled.log
test_expect_success 'but svn gc-ed files work' '
	(
		cd removed &&
		but svn gc &&
		: Compress::Zlib may not be available &&
		if test -f "$unhandled".gz
		then
			svn_cmd mkdir -m gz "$svnrepo"/gz &&
			but reset --hard $(but rev-list HEAD | tail -1) &&
			but svn rebase &&
			test -f "$unhandled".gz &&
			test -f "$unhandled" &&
			for i in a b c "weird file name" gz "! !"
			do
				if ! test -d "$i"
				then
					echo >&2 "$i does not exist" &&
					exit 1
				fi
			done
		fi
	)
'

test_done
