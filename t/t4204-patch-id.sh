#!/bin/sh

test_description='but patch-id'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

test_expect_success 'setup' '
	as="a a a a a a a a" && # eight a
	test_write_lines $as >foo &&
	test_write_lines $as >bar &&
	but add foo bar &&
	but cummit -a -m initial &&
	test_write_lines $as b >foo &&
	test_write_lines $as b >bar &&
	but cummit -a -m first &&
	but checkout -b same main &&
	but cummit --amend -m same-msg &&
	but checkout -b notsame main &&
	echo c >foo &&
	echo c >bar &&
	but cummit --amend -a -m notsame-msg &&
	test_write_lines bar foo >bar-then-foo &&
	test_write_lines foo bar >foo-then-bar
'

test_expect_success 'patch-id output is well-formed' '
	but log -p -1 >log.output &&
	but patch-id <log.output >output &&
	grep "^$OID_REGEX $(but rev-parse HEAD)$" output
'

#calculate patch id. Make sure output is not empty.
calc_patch_id () {
	patch_name="$1"
	shift
	but patch-id "$@" >patch-id.output &&
	sed "s/ .*//" patch-id.output >patch-id_"$patch_name" &&
	test_line_count -eq 1 patch-id_"$patch_name"
}

get_top_diff () {
	but log -p -1 "$@" -O bar-then-foo --
}

get_patch_id () {
	get_top_diff "$1" >top-diff.output &&
	calc_patch_id <top-diff.output "$@"
}

test_expect_success 'patch-id detects equality' '
	get_patch_id main &&
	get_patch_id same &&
	test_cmp patch-id_main patch-id_same
'

test_expect_success 'patch-id detects inequality' '
	get_patch_id main &&
	get_patch_id notsame &&
	! test_cmp patch-id_main patch-id_notsame
'

test_expect_success 'patch-id supports but-format-patch output' '
	get_patch_id main &&
	but checkout same &&
	but format-patch -1 --stdout >format-patch.output &&
	calc_patch_id same <format-patch.output &&
	test_cmp patch-id_main patch-id_same &&
	set $(but patch-id <format-patch.output) &&
	test "$2" = $(but rev-parse HEAD)
'

test_expect_success 'whitespace is irrelevant in footer' '
	get_patch_id main &&
	but checkout same &&
	but format-patch -1 --stdout >format-patch.output &&
	sed "s/ \$//" format-patch.output | calc_patch_id same &&
	test_cmp patch-id_main patch-id_same
'

cmp_patch_id () {
	if
		test "$1" = "relevant"
	then
		! test_cmp patch-id_"$2" patch-id_"$3"
	else
		test_cmp patch-id_"$2" patch-id_"$3"
	fi
}

test_patch_id_file_order () {
	relevant="$1"
	shift
	name="order-${1}-$relevant"
	shift
	get_top_diff "main" >top-diff.output &&
	calc_patch_id <top-diff.output "$name" "$@" &&
	but checkout same &&
	but format-patch -1 --stdout -O foo-then-bar >format-patch.output &&
	calc_patch_id <format-patch.output "ordered-$name" "$@" &&
	cmp_patch_id $relevant "$name" "ordered-$name"

}

# combined test for options: add more tests here to make them
# run with all options
test_patch_id () {
	test_patch_id_file_order "$@"
}

# small tests with detailed diagnostic for basic options.
test_expect_success 'file order is irrelevant with --stable' '
	test_patch_id_file_order irrelevant --stable --stable
'

test_expect_success 'file order is relevant with --unstable' '
	test_patch_id_file_order relevant --unstable --unstable
'

#Now test various option combinations.
test_expect_success 'default is unstable' '
	test_patch_id relevant default
'

test_expect_success 'patchid.stable = true is stable' '
	test_config patchid.stable true &&
	test_patch_id irrelevant patchid.stable=true
'

test_expect_success 'patchid.stable = false is unstable' '
	test_config patchid.stable false &&
	test_patch_id relevant patchid.stable=false
'

test_expect_success '--unstable overrides patchid.stable = true' '
	test_config patchid.stable true &&
	test_patch_id relevant patchid.stable=true--unstable --unstable
'

test_expect_success '--stable overrides patchid.stable = false' '
	test_config patchid.stable false &&
	test_patch_id irrelevant patchid.stable=false--stable --stable
'

test_expect_success 'patch-id supports but-format-patch MIME output' '
	get_patch_id main &&
	but checkout same &&
	but format-patch -1 --attach --stdout >format-patch.output &&
	calc_patch_id <format-patch.output same &&
	test_cmp patch-id_main patch-id_same
'

test_expect_success 'patch-id respects config from subdir' '
	test_config patchid.stable true &&
	mkdir subdir &&

	# copy these because test_patch_id() looks for them in
	# the current directory
	cp bar-then-foo foo-then-bar subdir &&

	(
		cd subdir &&
		test_patch_id irrelevant patchid.stable=true
	)
'

test_expect_success 'patch-id handles no-nl-at-eof markers' '
	cat >nonl <<-\EOF &&
	diff --but i/a w/a
	index e69de29..2e65efe 100644
	--- i/a
	+++ w/a
	@@ -0,0 +1 @@
	+a
	\ No newline at end of file
	diff --but i/b w/b
	index e69de29..6178079 100644
	--- i/b
	+++ w/b
	@@ -0,0 +1 @@
	+b
	EOF
	cat >withnl <<-\EOF &&
	diff --but i/a w/a
	index e69de29..7898192 100644
	--- i/a
	+++ w/a
	@@ -0,0 +1 @@
	+a
	diff --but i/b w/b
	index e69de29..6178079 100644
	--- i/b
	+++ w/b
	@@ -0,0 +1 @@
	+b
	EOF
	calc_patch_id nonl <nonl &&
	calc_patch_id withnl <withnl &&
	test_cmp patch-id_nonl patch-id_withnl
'

test_expect_success 'patch-id handles diffs with one line of before/after' '
	cat >diffu1 <<-\EOF &&
	diff --but a/bar b/bar
	index bdaf90f..31051f6 100644
	--- a/bar
	+++ b/bar
	@@ -2 +2,2 @@
	 b
	+c
	diff --but a/car b/car
	index 00750ed..2ae5e34 100644
	--- a/car
	+++ b/car
	@@ -1 +1,2 @@
	 3
	+d
	diff --but a/foo b/foo
	index e439850..7146eb8 100644
	--- a/foo
	+++ b/foo
	@@ -2 +2,2 @@
	 a
	+e
	EOF
	calc_patch_id diffu1 <diffu1 &&
	test_config patchid.stable true &&
	calc_patch_id diffu1stable <diffu1
'
test_done
