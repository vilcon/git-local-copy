#!/bin/sh

test_description='but rm in sparse checked out working trees'

. ./test-lib.sh

test_expect_success 'setup' "
	mkdir -p sub/dir &&
	touch a b c sub/d sub/dir/e &&
	but add -A &&
	but cummit -m files &&

	cat >sparse_error_header <<-EOF &&
	The following paths and/or pathspecs matched paths that exist
	outside of your sparse-checkout definition, so will not be
	updated in the index:
	EOF

	cat >sparse_hint <<-EOF &&
	hint: If you intend to update such entries, try one of the following:
	hint: * Use the --sparse option.
	hint: * Disable or modify the sparsity rules.
	hint: Disable this message with \"but config advice.updateSparsePath false\"
	EOF

	echo b | cat sparse_error_header - >sparse_entry_b_error &&
	cat sparse_entry_b_error sparse_hint >b_error_and_hint
"

for opt in "" -f --dry-run
do
	test_expect_success "rm${opt:+ $opt} does not remove sparse entries" '
		but sparse-checkout set a &&
		test_must_fail but rm $opt b 2>stderr &&
		test_cmp b_error_and_hint stderr &&
		but ls-files --error-unmatch b
	'
done

test_expect_success 'recursive rm does not remove sparse entries' '
	but reset --hard &&
	but sparse-checkout set sub/dir &&
	but rm -r sub &&
	but status --porcelain -uno >actual &&
	cat >expected <<-\EOF &&
	D  sub/dir/e
	EOF
	test_cmp expected actual &&

	but rm --sparse -r sub &&
	but status --porcelain -uno >actual2 &&
	cat >expected2 <<-\EOF &&
	D  sub/d
	D  sub/dir/e
	EOF
	test_cmp expected2 actual2
'

test_expect_success 'recursive rm --sparse removes sparse entries' '
	but reset --hard &&
	but sparse-checkout set "sub/dir" &&
	but rm --sparse -r sub &&
	but status --porcelain -uno >actual &&
	cat >expected <<-\EOF &&
	D  sub/d
	D  sub/dir/e
	EOF
	test_cmp expected actual
'

test_expect_success 'rm obeys advice.updateSparsePath' '
	but reset --hard &&
	but sparse-checkout set a &&
	test_must_fail but -c advice.updateSparsePath=false rm b 2>stderr &&
	test_cmp sparse_entry_b_error stderr
'

test_expect_success 'do not advice about sparse entries when they do not match the pathspec' '
	but reset --hard &&
	but sparse-checkout set a &&
	test_must_fail but rm nonexistent 2>stderr &&
	grep "fatal: pathspec .nonexistent. did not match any files" stderr &&
	! grep -F -f sparse_error_header stderr
'

test_expect_success 'do not warn about sparse entries when pathspec matches dense entries' '
	but reset --hard &&
	but sparse-checkout set a &&
	but rm "[ba]" 2>stderr &&
	test_must_be_empty stderr &&
	but ls-files --error-unmatch b &&
	test_must_fail but ls-files --error-unmatch a
'

test_expect_success 'do not warn about sparse entries with --ignore-unmatch' '
	but reset --hard &&
	but sparse-checkout set a &&
	but rm --ignore-unmatch b 2>stderr &&
	test_must_be_empty stderr &&
	but ls-files --error-unmatch b
'

test_expect_success 'refuse to rm a non-skip-worktree path outside sparse cone' '
	but reset --hard &&
	but sparse-checkout set a &&
	but update-index --no-skip-worktree b &&
	test_must_fail but rm b 2>stderr &&
	test_cmp b_error_and_hint stderr &&
	but rm --sparse b 2>stderr &&
	test_must_be_empty stderr &&
	test_path_is_missing b
'

test_expect_success 'can remove files from non-sparse dir' '
	but reset --hard &&
	but sparse-checkout disable &&
	mkdir -p w x/y &&
	test_cummit w/f &&
	test_cummit x/y/f &&

	but sparse-checkout set w !/x y/ &&
	but rm w/f.t x/y/f.t 2>stderr &&
	test_must_be_empty stderr
'

test_expect_success 'refuse to remove non-skip-worktree file from sparse dir' '
	but reset --hard &&
	but sparse-checkout disable &&
	mkdir -p x/y/z &&
	test_cummit x/y/z/f &&
	but sparse-checkout set !/x y/ !x/y/z &&

	but update-index --no-skip-worktree x/y/z/f.t &&
	test_must_fail but rm x/y/z/f.t 2>stderr &&
	echo x/y/z/f.t | cat sparse_error_header - sparse_hint >expect &&
	test_cmp expect stderr
'

test_done
