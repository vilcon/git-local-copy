#!/bin/sh

test_description="merge cases"

# The setup for all of them, pictorially, is:
#
#      A
#      o
#     / \
#  O o   ?
#     \ /
#      o
#      B
#
# To help make it easier to follow the flow of tests, they have been
# divided into sections and each test will start with a quick explanation
# of what cummits O, A, and B contain.
#
# Notation:
#    z/{b,c}   means  files z/b and z/c both exist
#    x/d_1     means  file x/d exists with content d1.  (Purpose of the
#                     underscore notation is to differentiate different
#                     files that might be renamed into each other's paths.)

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-merge.sh


# Testcase basic, conflicting changes in 'numerals'

test_setup_numerals () {
	test_create_repo numerals_$1 &&
	(
		cd numerals_$1 &&

		>README &&
		test_write_lines I II III >numerals &&
		but add README numerals &&
		test_tick &&
		but cummit -m "O" &&

		but branch O &&
		but branch A &&
		but branch B &&

		but checkout A &&
		test_write_lines I II III IIII >numerals &&
		but add numerals &&
		test_tick &&
		but cummit -m "A" &&

		but checkout B &&
		test_write_lines I II III IV >numerals &&
		but add numerals &&
		test_tick &&
		but cummit -m "B" &&

		cat <<-EOF >expected-index &&
		H README
		M numerals
		M numerals
		M numerals
		EOF

		cat <<-EOF >expected-merge
		I
		II
		III
		<<<<<<< HEAD
		IIII
		=======
		IV
		>>>>>>> B^0
		EOF

	)
}

test_expect_success 'conflicting entries written to worktree even if sparse' '
	test_setup_numerals plain &&
	(
		cd numerals_plain &&

		but checkout A^0 &&

		test_path_is_file README &&
		test_path_is_file numerals &&

		but sparse-checkout init &&
		but sparse-checkout set README &&

		test_path_is_file README &&
		test_path_is_missing numerals &&

		test_must_fail but merge -s recursive B^0 &&

		but ls-files -t >index_files &&
		test_cmp expected-index index_files &&

		test_path_is_file README &&
		test_path_is_file numerals &&

		test_cmp expected-merge numerals &&

		# 4 other files:
		#   * expected-merge
		#   * expected-index
		#   * index_files
		#   * others
		but ls-files -o >others &&
		test_line_count = 4 others
	)
'

test_expect_success 'present-despite-SKIP_WORKTREE handled reasonably' '
	test_setup_numerals in_the_way &&
	(
		cd numerals_in_the_way &&

		but checkout A^0 &&

		test_path_is_file README &&
		test_path_is_file numerals &&

		but sparse-checkout init &&
		but sparse-checkout set README &&

		test_path_is_file README &&
		test_path_is_missing numerals &&

		echo foobar >numerals &&

		test_must_fail but merge -s recursive B^0 &&

		test_path_is_missing .but/MERGE_HEAD &&

		test_path_is_file numerals &&

		# numerals should still have "foobar" in it
		echo foobar >expect &&
		test_cmp expect numerals
	)
'

test_done
