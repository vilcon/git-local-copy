#!/bin/sh
#
# Copyright (C) 2012
#     Charles Roussel <charles.roussel@ensimag.imag.fr>
#     Simon Cathebras <simon.cathebras@ensimag.imag.fr>
#     Julien Khayat <julien.khayat@ensimag.imag.fr>
#     Guillaume Sasdy <guillaume.sasdy@ensimag.imag.fr>
#     Simon Perrat <simon.perrat@ensimag.imag.fr>
#
# License: GPL v2 or later

# tests for but-remote-mediawiki

test_description='Test but-mediawiki with special characters in filenames'

. ./test-butmw-lib.sh
. $TEST_DIRECTORY/test-lib.sh


test_check_precond


test_expect_success 'Git clone works for a wiki with accents in the page names' '
	wiki_reset &&
	wiki_editpage féé "This page must be délétéd before clone" false &&
	wiki_editpage kèè "This page must be deleted before clone" false &&
	wiki_editpage hàà "This page must be deleted before clone" false &&
	wiki_editpage kîî "This page must be deleted before clone" false &&
	wiki_editpage foo "This page must be deleted before clone" false &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_1 &&
	wiki_getallpage ref_page_1 &&
	test_diff_directories mw_dir_1 ref_page_1
'


test_expect_success 'Git pull works with a wiki with accents in the pages names' '
	wiki_reset &&
	wiki_editpage kîî "this page must be cloned" false &&
	wiki_editpage foo "this page must be cloned" false &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_2 &&
	wiki_editpage éàîôû "This page must be pulled" false &&
	(
		cd mw_dir_2 &&
		but pull
	) &&
	wiki_getallpage ref_page_2 &&
	test_diff_directories mw_dir_2 ref_page_2
'


test_expect_success 'Cloning a chosen page works with accents' '
	wiki_reset &&
	wiki_editpage kîî "this page must be cloned" false &&
	but clone -c remote.origin.pages=kîî \
		mediawiki::'"$WIKI_URL"' mw_dir_3 &&
	wiki_check_content mw_dir_3/Kîî.mw Kîî &&
	test_path_is_file mw_dir_3/Kîî.mw &&
	rm -rf mw_dir_3
'


test_expect_success 'The shallow option works with accents' '
	wiki_reset &&
	wiki_editpage néoà "1st revision, should not be cloned" false &&
	wiki_editpage néoà "2nd revision, should be cloned" false &&
	but -c remote.origin.shallow=true clone \
		mediawiki::'"$WIKI_URL"' mw_dir_4 &&
	test_contains_N_files mw_dir_4 2 &&
	test_path_is_file mw_dir_4/Néoà.mw &&
	test_path_is_file mw_dir_4/Main_Page.mw &&
	(
		cd mw_dir_4 &&
		test $(but log --oneline Néoà.mw | wc -l) -eq 1 &&
		test $(but log --oneline Main_Page.mw | wc -l ) -eq 1
	) &&
	wiki_check_content mw_dir_4/Néoà.mw Néoà &&
	wiki_check_content mw_dir_4/Main_Page.mw Main_Page
'


test_expect_success 'Cloning works when page name first letter has an accent' '
	wiki_reset &&
	wiki_editpage îî "this page must be cloned" false &&
	but clone -c remote.origin.pages=îî \
		mediawiki::'"$WIKI_URL"' mw_dir_5 &&
	test_path_is_file mw_dir_5/Îî.mw &&
	wiki_check_content mw_dir_5/Îî.mw Îî
'


test_expect_success 'Git push works with a wiki with accents' '
	wiki_reset &&
	wiki_editpage féé "lots of accents : éèàÖ" false &&
	wiki_editpage foo "this page must be cloned" false &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_6 &&
	(
		cd mw_dir_6 &&
		echo "A wild Pîkächû appears on the wiki" >Pîkächû.mw &&
		but add Pîkächû.mw &&
		but cummit -m "A new page appears" &&
		but push
	) &&
	wiki_getallpage ref_page_6 &&
	test_diff_directories mw_dir_6 ref_page_6
'

test_expect_success 'Git clone works with accentsand spaces' '
	wiki_reset &&
	wiki_editpage "é à î" "this page must be délété before the clone" false &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_7 &&
	wiki_getallpage ref_page_7 &&
	test_diff_directories mw_dir_7 ref_page_7
'

test_expect_success 'character $ in page name (mw -> but)' '
	wiki_reset &&
	wiki_editpage file_\$_foo "expect to be called file_$_foo" false &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_8 &&
	test_path_is_file mw_dir_8/File_\$_foo.mw &&
	wiki_getallpage ref_page_8 &&
	test_diff_directories mw_dir_8 ref_page_8
'



test_expect_success 'character $ in file name (but -> mw) ' '
	wiki_reset &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_9 &&
	(
		cd mw_dir_9 &&
		echo "this file is called File_\$_foo.mw" >File_\$_foo.mw &&
		but add . &&
		but cummit -am "file File_\$_foo.mw" &&
		but pull &&
		but push
	) &&
	wiki_getallpage ref_page_9 &&
	test_diff_directories mw_dir_9 ref_page_9
'


test_expect_failure 'capital at the beginning of file names' '
	wiki_reset &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_10 &&
	(
		cd mw_dir_10 &&
		echo "my new file foo" >foo.mw &&
		echo "my new file Foo... Finger crossed" >Foo.mw &&
		but add . &&
		but cummit -am "file foo.mw" &&
		but pull &&
		but push
	) &&
	wiki_getallpage ref_page_10 &&
	test_diff_directories mw_dir_10 ref_page_10
'


test_expect_failure 'special character at the beginning of file name from mw to but' '
	wiki_reset &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_11 &&
	wiki_editpage {char_1 "expect to be renamed {char_1" false &&
	wiki_editpage [char_2 "expect to be renamed [char_2" false &&
	(
		cd mw_dir_11 &&
		but pull
	) &&
	test_path_is_file mw_dir_11/{char_1 &&
	test_path_is_file mw_dir_11/[char_2
'

test_expect_success 'Pull page with title containing ":" other than namespace separator' '
	wiki_editpage Foo:Bar content false &&
	(
		cd mw_dir_11 &&
		but pull
	) &&
	test_path_is_file mw_dir_11/Foo:Bar.mw
'

test_expect_success 'Push page with title containing ":" other than namespace separator' '
	(
		cd mw_dir_11 &&
		echo content >NotANameSpace:Page.mw &&
		but add NotANameSpace:Page.mw &&
		but cummit -m "add page with colon" &&
		but push
	) &&
	wiki_page_exist NotANameSpace:Page
'

test_expect_success 'test of correct formatting for file name from mw to but' '
	wiki_reset &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_12 &&
	wiki_editpage char_%_7b_1 "expect to be renamed char{_1" false &&
	wiki_editpage char_%_5b_2 "expect to be renamed char{_2" false &&
	(
		cd mw_dir_12 &&
		but pull
	) &&
	test_path_is_file mw_dir_12/Char\{_1.mw &&
	test_path_is_file mw_dir_12/Char\[_2.mw &&
	wiki_getallpage ref_page_12 &&
	mv ref_page_12/Char_%_7b_1.mw ref_page_12/Char\{_1.mw &&
	mv ref_page_12/Char_%_5b_2.mw ref_page_12/Char\[_2.mw &&
	test_diff_directories mw_dir_12 ref_page_12
'


test_expect_failure 'test of correct formatting for file name beginning with special character' '
	wiki_reset &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_13 &&
	(
		cd mw_dir_13 &&
		echo "my new file {char_1" >\{char_1.mw &&
		echo "my new file [char_2" >\[char_2.mw &&
		but add . &&
		but cummit -am "cummitting some exotic file name..." &&
		but push &&
		but pull
	) &&
	wiki_getallpage ref_page_13 &&
	test_path_is_file ref_page_13/{char_1.mw &&
	test_path_is_file ref_page_13/[char_2.mw &&
	test_diff_directories mw_dir_13 ref_page_13
'


test_expect_success 'test of correct formatting for file name from but to mw' '
	wiki_reset &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_14 &&
	(
		cd mw_dir_14 &&
		echo "my new file char{_1" >Char\{_1.mw &&
		echo "my new file char[_2" >Char\[_2.mw &&
		but add . &&
		but cummit -m "cummitting some exotic file name..." &&
		but push
	) &&
	wiki_getallpage ref_page_14 &&
	mv mw_dir_14/Char\{_1.mw mw_dir_14/Char_%_7b_1.mw &&
	mv mw_dir_14/Char\[_2.mw mw_dir_14/Char_%_5b_2.mw &&
	test_diff_directories mw_dir_14 ref_page_14
'


test_expect_success 'but clone with /' '
	wiki_reset &&
	wiki_editpage \/fo\/o "this is not important" false -c=Deleted &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_15 &&
	test_path_is_file mw_dir_15/%2Ffo%2Fo.mw &&
	wiki_check_content mw_dir_15/%2Ffo%2Fo.mw \/fo\/o
'


test_expect_success 'but push with /' '
	wiki_reset &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_16 &&
	echo "I will be on the wiki" >mw_dir_16/%2Ffo%2Fo.mw &&
	(
		cd mw_dir_16 &&
		but add %2Ffo%2Fo.mw &&
		but cummit -m " %2Ffo%2Fo added" &&
		but push
	) &&
	wiki_page_exist \/fo\/o &&
	wiki_check_content mw_dir_16/%2Ffo%2Fo.mw \/fo\/o

'


test_expect_success 'but clone with \' '
	wiki_reset &&
	wiki_editpage \\ko\\o "this is not important" false -c=Deleted &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_17 &&
	test_path_is_file mw_dir_17/\\ko\\o.mw &&
	wiki_check_content mw_dir_17/\\ko\\o.mw \\ko\\o
'


test_expect_success 'but push with \' '
	wiki_reset &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_18 &&
	echo "I will be on the wiki" >mw_dir_18/\\ko\\o.mw &&
	(
		cd mw_dir_18 &&
		but add \\ko\\o.mw &&
		but cummit -m " \\ko\\o added" &&
		but push
	) &&
	wiki_page_exist \\ko\\o &&
	wiki_check_content mw_dir_18/\\ko\\o.mw \\ko\\o

'

test_expect_success 'but clone with \ in format control' '
	wiki_reset &&
	wiki_editpage \\no\\o "this is not important" false &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_19 &&
	test_path_is_file mw_dir_19/\\no\\o.mw &&
	wiki_check_content mw_dir_19/\\no\\o.mw \\no\\o
'


test_expect_success 'but push with \ in format control' '
	wiki_reset &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_20 &&
	echo "I will be on the wiki" >mw_dir_20/\\fo\\o.mw &&
	(
		cd mw_dir_20 &&
		but add \\fo\\o.mw &&
		but cummit -m " \\fo\\o added" &&
		but push
	) &&
	wiki_page_exist \\fo\\o &&
	wiki_check_content mw_dir_20/\\fo\\o.mw \\fo\\o

'


test_expect_success 'fast-import meta-characters in page name (mw -> but)' '
	wiki_reset &&
	wiki_editpage \"file\"_\\_foo "expect to be called \"file\"_\\_foo" false &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_21 &&
	test_path_is_file mw_dir_21/\"file\"_\\_foo.mw &&
	wiki_getallpage ref_page_21 &&
	test_diff_directories mw_dir_21 ref_page_21
'


test_expect_success 'fast-import meta-characters in page name (but -> mw) ' '
	wiki_reset &&
	but clone mediawiki::'"$WIKI_URL"' mw_dir_22 &&
	(
		cd mw_dir_22 &&
		echo "this file is called \"file\"_\\_foo.mw" >\"file\"_\\_foo &&
		but add . &&
		but cummit -am "file \"file\"_\\_foo" &&
		but pull &&
		but push
	) &&
	wiki_getallpage ref_page_22 &&
	test_diff_directories mw_dir_22 ref_page_22
'


test_done
