#!/bin/sh
#
# Copyright (c) 2007 Carlos Rica
#

test_description='but tag

Tests for operations with tags.'

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh
. "$TEST_DIRECTORY"/lib-gpg.sh
. "$TEST_DIRECTORY"/lib-terminal.sh

# creating and listing lightweight tags:

tag_exists () {
	but show-ref --quiet --verify refs/tags/"$1"
}

test_expect_success 'setup' '
	test_oid_cache <<-EOM
	othersigheader sha1:gpgsig-sha256
	othersigheader sha256:gpgsig
	EOM
'

test_expect_success 'listing all tags in an empty tree should succeed' '
	but tag -l &&
	but tag
'

test_expect_success 'listing all tags in an empty tree should output nothing' '
	test $(but tag -l | wc -l) -eq 0 &&
	test $(but tag | wc -l) -eq 0
'

test_expect_success 'sort tags, ignore case' '
	(
		but init sort &&
		cd sort &&
		test_cummit initial &&
		but tag tag-one &&
		but tag TAG-two &&
		but tag -l >actual &&
		cat >expected <<-\EOF &&
		TAG-two
		initial
		tag-one
		EOF
		test_cmp expected actual &&
		but tag -l -i >actual &&
		cat >expected <<-\EOF &&
		initial
		tag-one
		TAG-two
		EOF
		test_cmp expected actual
	)
'

test_expect_success 'looking for a tag in an empty tree should fail' \
	'! (tag_exists mytag)'

test_expect_success 'creating a tag in an empty tree should fail' '
	test_must_fail but tag mynotag &&
	! tag_exists mynotag
'

test_expect_success 'creating a tag for HEAD in an empty tree should fail' '
	test_must_fail but tag mytaghead HEAD &&
	! tag_exists mytaghead
'

test_expect_success 'creating a tag for an unknown revision should fail' '
	test_must_fail but tag mytagnorev aaaaaaaaaaa &&
	! tag_exists mytagnorev
'

# cummit used in the tests, test_tick is also called here to freeze the date:
test_expect_success 'creating a tag using default HEAD should succeed' '
	test_config core.logAllRefUpdates true &&
	test_tick &&
	echo foo >foo &&
	but add foo &&
	but cummit -m Foo &&
	but tag mytag &&
	test_must_fail but reflog exists refs/tags/mytag
'

test_expect_success 'creating a tag with --create-reflog should create reflog' '
	but log -1 \
		--format="format:tag: tagging %h (%s, %cd)%n" \
		--date=format:%Y-%m-%d >expected &&
	test_when_finished "but tag -d tag_with_reflog1" &&
	but tag --create-reflog tag_with_reflog1 &&
	but reflog exists refs/tags/tag_with_reflog1 &&
	test-tool ref-store main for-each-reflog-ent refs/tags/tag_with_reflog1 | sed -e "s/^.*	//" >actual &&
	test_cmp expected actual
'

test_expect_success 'annotated tag with --create-reflog has correct message' '
	but log -1 \
		--format="format:tag: tagging %h (%s, %cd)%n" \
		--date=format:%Y-%m-%d >expected &&
	test_when_finished "but tag -d tag_with_reflog2" &&
	but tag -m "annotated tag" --create-reflog tag_with_reflog2 &&
	but reflog exists refs/tags/tag_with_reflog2 &&
	test-tool ref-store main for-each-reflog-ent refs/tags/tag_with_reflog2 | sed -e "s/^.*	//" >actual &&
	test_cmp expected actual
'

test_expect_success '--create-reflog does not create reflog on failure' '
	test_must_fail but tag --create-reflog mytag &&
	test_must_fail but reflog exists refs/tags/mytag
'

test_expect_success 'option core.logAllRefUpdates=always creates reflog' '
	test_when_finished "but tag -d tag_with_reflog3" &&
	test_config core.logAllRefUpdates always &&
	but tag tag_with_reflog3 &&
	but reflog exists refs/tags/tag_with_reflog3
'

test_expect_success 'listing all tags if one exists should succeed' '
	but tag -l &&
	but tag
'

cat >expect <<EOF
mytag
EOF
test_expect_success 'Multiple -l or --list options are equivalent to one -l option' '
	but tag -l -l >actual &&
	test_cmp expect actual &&
	but tag --list --list >actual &&
	test_cmp expect actual &&
	but tag --list -l --list >actual &&
	test_cmp expect actual
'

test_expect_success 'listing all tags if one exists should output that tag' '
	test $(but tag -l) = mytag &&
	test $(but tag) = mytag
'

# pattern matching:

test_expect_success 'listing a tag using a matching pattern should succeed' \
	'but tag -l mytag'

test_expect_success 'listing a tag with --ignore-case' \
	'test $(but tag -l --ignore-case MYTAG) = mytag'

test_expect_success \
	'listing a tag using a matching pattern should output that tag' \
	'test $(but tag -l mytag) = mytag'

test_expect_success \
	'listing tags using a non-matching pattern should succeed' \
	'but tag -l xxx'

test_expect_success \
	'listing tags using a non-matching pattern should output nothing' \
	'test $(but tag -l xxx | wc -l) -eq 0'

# special cases for creating tags:

test_expect_success \
	'trying to create a tag with the name of one existing should fail' \
	'test_must_fail but tag mytag'

test_expect_success \
	'trying to create a tag with a non-valid name should fail' '
	test $(but tag -l | wc -l) -eq 1 &&
	test_must_fail but tag "" &&
	test_must_fail but tag .othertag &&
	test_must_fail but tag "other tag" &&
	test_must_fail but tag "othertag^" &&
	test_must_fail but tag "other~tag" &&
	test $(but tag -l | wc -l) -eq 1
'

test_expect_success 'creating a tag using HEAD directly should succeed' '
	but tag myhead HEAD &&
	tag_exists myhead
'

test_expect_success '--force can create a tag with the name of one existing' '
	tag_exists mytag &&
	but tag --force mytag &&
	tag_exists mytag'

test_expect_success '--force is moot with a non-existing tag name' '
	test_when_finished but tag -d newtag forcetag &&
	but tag newtag >expect &&
	but tag --force forcetag >actual &&
	test_cmp expect actual
'

# deleting tags:

test_expect_success 'trying to delete an unknown tag should fail' '
	! tag_exists unknown-tag &&
	test_must_fail but tag -d unknown-tag
'

cat >expect <<EOF
myhead
mytag
EOF
test_expect_success \
	'trying to delete tags without params should succeed and do nothing' '
	but tag -l > actual && test_cmp expect actual &&
	but tag -d &&
	but tag -l > actual && test_cmp expect actual
'

test_expect_success \
	'deleting two existing tags in one command should succeed' '
	tag_exists mytag &&
	tag_exists myhead &&
	but tag -d mytag myhead &&
	! tag_exists mytag &&
	! tag_exists myhead
'

test_expect_success \
	'creating a tag with the name of another deleted one should succeed' '
	! tag_exists mytag &&
	but tag mytag &&
	tag_exists mytag
'

test_expect_success \
	'trying to delete two tags, existing and not, should fail in the 2nd' '
	tag_exists mytag &&
	! tag_exists nonexistingtag &&
	test_must_fail but tag -d mytag nonexistingtag &&
	! tag_exists mytag &&
	! tag_exists nonexistingtag
'

test_expect_success 'trying to delete an already deleted tag should fail' \
	'test_must_fail but tag -d mytag'

# listing various tags with pattern matching:

cat >expect <<EOF
a1
aa1
cba
t210
t211
v0.2.1
v1.0
v1.0.1
v1.1.3
EOF
test_expect_success 'listing all tags should print them ordered' '
	but tag v1.0.1 &&
	but tag t211 &&
	but tag aa1 &&
	but tag v0.2.1 &&
	but tag v1.1.3 &&
	but tag cba &&
	but tag a1 &&
	but tag v1.0 &&
	but tag t210 &&
	but tag -l > actual &&
	test_cmp expect actual &&
	but tag > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
a1
aa1
cba
EOF
test_expect_success \
	'listing tags with substring as pattern must print those matching' '
	rm *a* &&
	but tag -l "*a*" > current &&
	test_cmp expect current
'

cat >expect <<EOF
v0.2.1
v1.0.1
EOF
test_expect_success \
	'listing tags with a suffix as pattern must print those matching' '
	but tag -l "*.1" > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
t210
t211
EOF
test_expect_success \
	'listing tags with a prefix as pattern must print those matching' '
	but tag -l "t21*" > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
a1
EOF
test_expect_success \
	'listing tags using a name as pattern must print that one matching' '
	but tag -l a1 > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
v1.0
EOF
test_expect_success \
	'listing tags using a name as pattern must print that one matching' '
	but tag -l v1.0 > actual &&
	test_cmp expect actual
'

cat >expect <<EOF
v1.0.1
v1.1.3
EOF
test_expect_success \
	'listing tags with ? in the pattern should print those matching' '
	but tag -l "v1.?.?" > actual &&
	test_cmp expect actual
'

test_expect_success \
	'listing tags using v.* should print nothing because none have v.' '
	but tag -l "v.*" > actual &&
	test_must_be_empty actual
'

cat >expect <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
EOF
test_expect_success \
	'listing tags using v* should print only those having v' '
	but tag -l "v*" > actual &&
	test_cmp expect actual
'

test_expect_success 'tag -l can accept multiple patterns' '
	but tag -l "v1*" "v0*" >actual &&
	test_cmp expect actual
'

# Between v1.7.7 & v2.13.0 a fair reading of the but-tag documentation
# could leave you with the impression that "-l <pattern> -l <pattern>"
# was how we wanted to accept multiple patterns.
#
# This test should not imply that this is a sane thing to support. but
# since the documentation was worded like it was let's at least find
# out if we're going to break this long-documented form of taking
# multiple patterns.
test_expect_success 'tag -l <pattern> -l <pattern> works, as our buggy documentation previously suggested' '
	but tag -l "v1*" -l "v0*" >actual &&
	test_cmp expect actual
'

test_expect_success 'listing tags in column' '
	COLUMNS=41 but tag -l --column=row >actual &&
	cat >expected <<\EOF &&
a1      aa1     cba     t210    t211
v0.2.1  v1.0    v1.0.1  v1.1.3
EOF
	test_cmp expected actual
'

test_expect_success 'listing tags in column with column.*' '
	test_config column.tag row &&
	test_config column.ui dense &&
	COLUMNS=40 but tag -l >actual &&
	cat >expected <<\EOF &&
a1      aa1   cba     t210    t211
v0.2.1  v1.0  v1.0.1  v1.1.3
EOF
	test_cmp expected actual
'

test_expect_success 'listing tag with -n --column should fail' '
	test_must_fail but tag --column -n
'

test_expect_success 'listing tags -n in column with column.ui ignored' '
	test_config column.ui "row dense" &&
	COLUMNS=40 but tag -l -n >actual &&
	cat >expected <<\EOF &&
a1              Foo
aa1             Foo
cba             Foo
t210            Foo
t211            Foo
v0.2.1          Foo
v1.0            Foo
v1.0.1          Foo
v1.1.3          Foo
EOF
	test_cmp expected actual
'

# creating and verifying lightweight tags:

test_expect_success \
	'a non-annotated tag created without parameters should point to HEAD' '
	but tag non-annotated-tag &&
	test $(but cat-file -t non-annotated-tag) = cummit &&
	test $(but rev-parse non-annotated-tag) = $(but rev-parse HEAD)
'

test_expect_success 'trying to verify an unknown tag should fail' \
	'test_must_fail but tag -v unknown-tag'

test_expect_success \
	'trying to verify a non-annotated and non-signed tag should fail' \
	'test_must_fail but tag -v non-annotated-tag'

test_expect_success \
	'trying to verify many non-annotated or unknown tags, should fail' \
	'test_must_fail but tag -v unknown-tag1 non-annotated-tag unknown-tag2'

# creating annotated tags:

get_tag_msg () {
	but cat-file tag "$1" | sed -e "/BEGIN PGP/q"
}

# run test_tick before cummitting always gives the time in that timezone
get_tag_header () {
cat <<EOF
object $2
type $3
tag $1
tagger C O Mitter <cummitter@example.com> $4 -0700

EOF
}

cummit=$(but rev-parse HEAD)
time=$test_tick

get_tag_header annotated-tag $cummit cummit $time >expect
echo "A message" >>expect
test_expect_success \
	'creating an annotated tag with -m message should succeed' '
	but tag -m "A message" annotated-tag &&
	get_tag_msg annotated-tag >actual &&
	test_cmp expect actual
'

get_tag_header annotated-tag-edit $cummit cummit $time >expect
echo "An edited message" >>expect
test_expect_success 'set up editor' '
	write_script fakeeditor <<-\EOF
	sed -e "s/A message/An edited message/g" <"$1" >"$1-"
	mv "$1-" "$1"
	EOF
'
test_expect_success \
	'creating an annotated tag with -m message --edit should succeed' '
	GIT_EDITOR=./fakeeditor but tag -m "A message" --edit annotated-tag-edit &&
	get_tag_msg annotated-tag-edit >actual &&
	test_cmp expect actual
'

cat >msgfile <<EOF
Another message
in a file.
EOF
get_tag_header file-annotated-tag $cummit cummit $time >expect
cat msgfile >>expect
test_expect_success \
	'creating an annotated tag with -F messagefile should succeed' '
	but tag -F msgfile file-annotated-tag &&
	get_tag_msg file-annotated-tag >actual &&
	test_cmp expect actual
'

get_tag_header file-annotated-tag-edit $cummit cummit $time >expect
sed -e "s/Another message/Another edited message/g" msgfile >>expect
test_expect_success 'set up editor' '
	write_script fakeeditor <<-\EOF
	sed -e "s/Another message/Another edited message/g" <"$1" >"$1-"
	mv "$1-" "$1"
	EOF
'
test_expect_success \
	'creating an annotated tag with -F messagefile --edit should succeed' '
	GIT_EDITOR=./fakeeditor but tag -F msgfile --edit file-annotated-tag-edit &&
	get_tag_msg file-annotated-tag-edit >actual &&
	test_cmp expect actual
'

cat >inputmsg <<EOF
A message from the
standard input
EOF
get_tag_header stdin-annotated-tag $cummit cummit $time >expect
cat inputmsg >>expect
test_expect_success 'creating an annotated tag with -F - should succeed' '
	but tag -F - stdin-annotated-tag <inputmsg &&
	get_tag_msg stdin-annotated-tag >actual &&
	test_cmp expect actual
'

test_expect_success \
	'trying to create a tag with a non-existing -F file should fail' '
	! test -f nonexistingfile &&
	! tag_exists notag &&
	test_must_fail but tag -F nonexistingfile notag &&
	! tag_exists notag
'

test_expect_success \
	'trying to create tags giving both -m or -F options should fail' '
	echo "message file 1" >msgfile1 &&
	! tag_exists msgtag &&
	test_must_fail but tag -m "message 1" -F msgfile1 msgtag &&
	! tag_exists msgtag &&
	test_must_fail but tag -F msgfile1 -m "message 1" msgtag &&
	! tag_exists msgtag &&
	test_must_fail but tag -m "message 1" -F msgfile1 \
		-m "message 2" msgtag &&
	! tag_exists msgtag
'

# blank and empty messages:

get_tag_header empty-annotated-tag $cummit cummit $time >expect
test_expect_success \
	'creating a tag with an empty -m message should succeed' '
	but tag -m "" empty-annotated-tag &&
	get_tag_msg empty-annotated-tag >actual &&
	test_cmp expect actual
'

>emptyfile
get_tag_header emptyfile-annotated-tag $cummit cummit $time >expect
test_expect_success \
	'creating a tag with an empty -F messagefile should succeed' '
	but tag -F emptyfile emptyfile-annotated-tag &&
	get_tag_msg emptyfile-annotated-tag >actual &&
	test_cmp expect actual
'

printf '\n\n  \n\t\nLeading blank lines\n' >blanksfile
printf '\n\t \t  \nRepeated blank lines\n' >>blanksfile
printf '\n\n\nTrailing spaces      \t  \n' >>blanksfile
printf '\nTrailing blank lines\n\n\t \n\n' >>blanksfile
get_tag_header blanks-annotated-tag $cummit cummit $time >expect
cat >>expect <<EOF
Leading blank lines

Repeated blank lines

Trailing spaces

Trailing blank lines
EOF
test_expect_success \
	'extra blanks in the message for an annotated tag should be removed' '
	but tag -F blanksfile blanks-annotated-tag &&
	get_tag_msg blanks-annotated-tag >actual &&
	test_cmp expect actual
'

get_tag_header blank-annotated-tag $cummit cummit $time >expect
test_expect_success \
	'creating a tag with blank -m message with spaces should succeed' '
	but tag -m "     " blank-annotated-tag &&
	get_tag_msg blank-annotated-tag >actual &&
	test_cmp expect actual
'

echo '     ' >blankfile
echo ''      >>blankfile
echo '  '    >>blankfile
get_tag_header blankfile-annotated-tag $cummit cummit $time >expect
test_expect_success \
	'creating a tag with blank -F messagefile with spaces should succeed' '
	but tag -F blankfile blankfile-annotated-tag &&
	get_tag_msg blankfile-annotated-tag >actual &&
	test_cmp expect actual
'

printf '      ' >blanknonlfile
get_tag_header blanknonlfile-annotated-tag $cummit cummit $time >expect
test_expect_success \
	'creating a tag with -F file of spaces and no newline should succeed' '
	but tag -F blanknonlfile blanknonlfile-annotated-tag &&
	get_tag_msg blanknonlfile-annotated-tag >actual &&
	test_cmp expect actual
'

# messages with commented lines:

cat >commentsfile <<EOF
# A comment

############
The message.
############
One line.


# commented lines
# commented lines

Another line.
# comments

Last line.
EOF
get_tag_header comments-annotated-tag $cummit cummit $time >expect
cat >>expect <<EOF
The message.
One line.

Another line.

Last line.
EOF
test_expect_success \
	'creating a tag using a -F messagefile with #comments should succeed' '
	but tag -F commentsfile comments-annotated-tag &&
	get_tag_msg comments-annotated-tag >actual &&
	test_cmp expect actual
'

get_tag_header comment-annotated-tag $cummit cummit $time >expect
test_expect_success \
	'creating a tag with a #comment in the -m message should succeed' '
	but tag -m "#comment" comment-annotated-tag &&
	get_tag_msg comment-annotated-tag >actual &&
	test_cmp expect actual
'

echo '#comment' >commentfile
echo ''         >>commentfile
echo '####'     >>commentfile
get_tag_header commentfile-annotated-tag $cummit cummit $time >expect
test_expect_success \
	'creating a tag with #comments in the -F messagefile should succeed' '
	but tag -F commentfile commentfile-annotated-tag &&
	get_tag_msg commentfile-annotated-tag >actual &&
	test_cmp expect actual
'

printf '#comment' >commentnonlfile
get_tag_header commentnonlfile-annotated-tag $cummit cummit $time >expect
test_expect_success \
	'creating a tag with a file of #comment and no newline should succeed' '
	but tag -F commentnonlfile commentnonlfile-annotated-tag &&
	get_tag_msg commentnonlfile-annotated-tag >actual &&
	test_cmp expect actual
'

# listing messages for annotated non-signed tags:

test_expect_success \
	'listing the one-line message of a non-signed tag should succeed' '
	but tag -m "A msg" tag-one-line &&

	echo "tag-one-line" >expect &&
	but tag -l | grep "^tag-one-line" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l | grep "^tag-one-line" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l tag-one-line >actual &&
	test_cmp expect actual &&

	but tag -n0 | grep "^tag-one-line" >actual &&
	test_cmp expect actual &&
	but tag -n0 tag-one-line >actual &&
	test_cmp expect actual &&

	echo "tag-one-line    A msg" >expect &&
	but tag -n1 -l | grep "^tag-one-line" >actual &&
	test_cmp expect actual &&
	but tag -n -l | grep "^tag-one-line" >actual &&
	test_cmp expect actual &&
	but tag -n1 -l tag-one-line >actual &&
	test_cmp expect actual &&
	but tag -n2 -l tag-one-line >actual &&
	test_cmp expect actual &&
	but tag -n999 -l tag-one-line >actual &&
	test_cmp expect actual
'

test_expect_success 'The -n 100 invocation means -n --list 100, not -n100' '
	but tag -n 100 >actual &&
	test_must_be_empty actual &&

	but tag -m "A msg" 100 &&
	echo "100             A msg" >expect &&
	but tag -n 100 >actual &&
	test_cmp expect actual
'

test_expect_success \
	'listing the zero-lines message of a non-signed tag should succeed' '
	but tag -m "" tag-zero-lines &&

	echo "tag-zero-lines" >expect &&
	but tag -l | grep "^tag-zero-lines" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l | grep "^tag-zero-lines" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l tag-zero-lines >actual &&
	test_cmp expect actual &&

	echo "tag-zero-lines  " >expect &&
	but tag -n1 -l | grep "^tag-zero-lines" >actual &&
	test_cmp expect actual &&
	but tag -n -l | grep "^tag-zero-lines" >actual &&
	test_cmp expect actual &&
	but tag -n1 -l tag-zero-lines >actual &&
	test_cmp expect actual &&
	but tag -n2 -l tag-zero-lines >actual &&
	test_cmp expect actual &&
	but tag -n999 -l tag-zero-lines >actual &&
	test_cmp expect actual
'

echo 'tag line one' >annotagmsg
echo 'tag line two' >>annotagmsg
echo 'tag line three' >>annotagmsg
test_expect_success \
	'listing many message lines of a non-signed tag should succeed' '
	but tag -F annotagmsg tag-lines &&

	echo "tag-lines" >expect &&
	but tag -l | grep "^tag-lines" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l | grep "^tag-lines" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l tag-lines >actual &&
	test_cmp expect actual &&

	echo "tag-lines       tag line one" >expect &&
	but tag -n1 -l | grep "^tag-lines" >actual &&
	test_cmp expect actual &&
	but tag -n -l | grep "^tag-lines" >actual &&
	test_cmp expect actual &&
	but tag -n1 -l tag-lines >actual &&
	test_cmp expect actual &&

	echo "    tag line two" >>expect &&
	but tag -n2 -l | grep "^ *tag.line" >actual &&
	test_cmp expect actual &&
	but tag -n2 -l tag-lines >actual &&
	test_cmp expect actual &&

	echo "    tag line three" >>expect &&
	but tag -n3 -l | grep "^ *tag.line" >actual &&
	test_cmp expect actual &&
	but tag -n3 -l tag-lines >actual &&
	test_cmp expect actual &&
	but tag -n4 -l | grep "^ *tag.line" >actual &&
	test_cmp expect actual &&
	but tag -n4 -l tag-lines >actual &&
	test_cmp expect actual &&
	but tag -n99 -l | grep "^ *tag.line" >actual &&
	test_cmp expect actual &&
	but tag -n99 -l tag-lines >actual &&
	test_cmp expect actual
'

test_expect_success 'annotations for blobs are empty' '
	blob=$(but hash-object -w --stdin <<-\EOF
	Blob paragraph 1.

	Blob paragraph 2.
	EOF
	) &&
	but tag tag-blob $blob &&
	echo "tag-blob        " >expect &&
	but tag -n1 -l tag-blob >actual &&
	test_cmp expect actual
'

# trying to verify annotated non-signed tags:

test_expect_success GPG \
	'trying to verify an annotated non-signed tag should fail' '
	tag_exists annotated-tag &&
	test_must_fail but tag -v annotated-tag
'

test_expect_success GPG \
	'trying to verify a file-annotated non-signed tag should fail' '
	tag_exists file-annotated-tag &&
	test_must_fail but tag -v file-annotated-tag
'

test_expect_success GPG \
	'trying to verify two annotated non-signed tags should fail' '
	tag_exists annotated-tag file-annotated-tag &&
	test_must_fail but tag -v annotated-tag file-annotated-tag
'

# creating and verifying signed tags:

get_tag_header signed-tag $cummit cummit $time >expect
echo 'A signed tag message' >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG 'creating a signed tag with -m message should succeed' '
	but tag -s -m "A signed tag message" signed-tag &&
	get_tag_msg signed-tag >actual &&
	test_cmp expect actual
'

get_tag_header u-signed-tag $cummit cummit $time >expect
echo 'Another message' >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG 'sign with a given key id' '

	but tag -u cummitter@example.com -m "Another message" u-signed-tag &&
	get_tag_msg u-signed-tag >actual &&
	test_cmp expect actual

'

test_expect_success GPG 'sign with an unknown id (1)' '

	test_must_fail but tag -u author@example.com \
		-m "Another message" o-signed-tag

'

test_expect_success GPG 'sign with an unknown id (2)' '

	test_must_fail but tag -u DEADBEEF -m "Another message" o-signed-tag

'

cat >fakeeditor <<'EOF'
#!/bin/sh
test -n "$1" && exec >"$1"
echo A signed tag message
echo from a fake editor.
EOF
chmod +x fakeeditor

get_tag_header implied-sign $cummit cummit $time >expect
./fakeeditor >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG '-u implies signed tag' '
	GIT_EDITOR=./fakeeditor but tag -u CDDE430D implied-sign &&
	get_tag_msg implied-sign >actual &&
	test_cmp expect actual
'

cat >sigmsgfile <<EOF
Another signed tag
message in a file.
EOF
get_tag_header file-signed-tag $cummit cummit $time >expect
cat sigmsgfile >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with -F messagefile should succeed' '
	but tag -s -F sigmsgfile file-signed-tag &&
	get_tag_msg file-signed-tag >actual &&
	test_cmp expect actual
'

cat >siginputmsg <<EOF
A signed tag message from
the standard input
EOF
get_tag_header stdin-signed-tag $cummit cummit $time >expect
cat siginputmsg >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG 'creating a signed tag with -F - should succeed' '
	but tag -s -F - stdin-signed-tag <siginputmsg &&
	get_tag_msg stdin-signed-tag >actual &&
	test_cmp expect actual
'

get_tag_header implied-annotate $cummit cummit $time >expect
./fakeeditor >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG '-s implies annotated tag' '
	GIT_EDITOR=./fakeeditor but tag -s implied-annotate &&
	get_tag_msg implied-annotate >actual &&
	test_cmp expect actual
'

get_tag_header forcesignannotated-implied-sign $cummit cummit $time >expect
echo "A message" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'but tag -s implied if configured with tag.forcesignannotated' \
	'test_config tag.forcesignannotated true &&
	but tag -m "A message" forcesignannotated-implied-sign &&
	get_tag_msg forcesignannotated-implied-sign >actual &&
	test_cmp expect actual
'

test_expect_success GPG \
	'lightweight with no message when configured with tag.forcesignannotated' \
	'test_config tag.forcesignannotated true &&
	but tag forcesignannotated-lightweight &&
	tag_exists forcesignannotated-lightweight &&
	test_must_fail but tag -v forcesignannotated-no-message
'

get_tag_header forcesignannotated-annotate $cummit cummit $time >expect
echo "A message" >>expect
test_expect_success GPG \
	'but tag -a disable configured tag.forcesignannotated' \
	'test_config tag.forcesignannotated true &&
	but tag -a -m "A message" forcesignannotated-annotate &&
	get_tag_msg forcesignannotated-annotate >actual &&
	test_cmp expect actual &&
	test_must_fail but tag -v forcesignannotated-annotate
'

get_tag_header forcesignannotated-disabled $cummit cummit $time >expect
echo "A message" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'but tag --sign enable GPG sign' \
	'test_config tag.forcesignannotated false &&
	but tag --sign -m "A message" forcesignannotated-disabled &&
	get_tag_msg forcesignannotated-disabled >actual &&
	test_cmp expect actual
'

get_tag_header gpgsign-enabled $cummit cummit $time >expect
echo "A message" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'but tag configured tag.gpgsign enables GPG sign' \
	'test_config tag.gpgsign true &&
	but tag -m "A message" gpgsign-enabled &&
	get_tag_msg gpgsign-enabled>actual &&
	test_cmp expect actual
'

get_tag_header no-sign $cummit cummit $time >expect
echo "A message" >>expect
test_expect_success GPG \
	'but tag --no-sign configured tag.gpgsign skip GPG sign' \
	'test_config tag.gpgsign true &&
	but tag -a --no-sign -m "A message" no-sign &&
	get_tag_msg no-sign>actual &&
	test_cmp expect actual
'

test_expect_success GPG \
	'trying to create a signed tag with non-existing -F file should fail' '
	! test -f nonexistingfile &&
	! tag_exists nosigtag &&
	test_must_fail but tag -s -F nonexistingfile nosigtag &&
	! tag_exists nosigtag
'

test_expect_success GPG 'verifying a signed tag should succeed' \
	'but tag -v signed-tag'

test_expect_success GPG 'verifying two signed tags in one command should succeed' \
	'but tag -v signed-tag file-signed-tag'

test_expect_success GPG \
	'verifying many signed and non-signed tags should fail' '
	test_must_fail but tag -v signed-tag annotated-tag &&
	test_must_fail but tag -v file-annotated-tag file-signed-tag &&
	test_must_fail but tag -v annotated-tag \
		file-signed-tag file-annotated-tag &&
	test_must_fail but tag -v signed-tag annotated-tag file-signed-tag
'

test_expect_success GPG 'verifying a forged tag should fail' '
	forged=$(but cat-file tag signed-tag |
		sed -e "s/signed-tag/forged-tag/" |
		but mktag) &&
	but tag forged-tag $forged &&
	test_must_fail but tag -v forged-tag
'

test_expect_success GPG 'verifying a proper tag with --format pass and format accordingly' '
	cat >expect <<-\EOF &&
	tagname : signed-tag
	EOF
	but tag -v --format="tagname : %(tag)" "signed-tag" >actual &&
	test_cmp expect actual
'

test_expect_success GPG 'verifying a forged tag with --format should fail silently' '
	test_must_fail but tag -v --format="tagname : %(tag)" "forged-tag" >actual &&
	test_must_be_empty actual
'

# blank and empty messages for signed tags:

get_tag_header empty-signed-tag $cummit cummit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with an empty -m message should succeed' '
	but tag -s -m "" empty-signed-tag &&
	get_tag_msg empty-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -v empty-signed-tag
'

>sigemptyfile
get_tag_header emptyfile-signed-tag $cummit cummit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with an empty -F messagefile should succeed' '
	but tag -s -F sigemptyfile emptyfile-signed-tag &&
	get_tag_msg emptyfile-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -v emptyfile-signed-tag
'

printf '\n\n  \n\t\nLeading blank lines\n' > sigblanksfile
printf '\n\t \t  \nRepeated blank lines\n' >>sigblanksfile
printf '\n\n\nTrailing spaces      \t  \n' >>sigblanksfile
printf '\nTrailing blank lines\n\n\t \n\n' >>sigblanksfile
get_tag_header blanks-signed-tag $cummit cummit $time >expect
cat >>expect <<EOF
Leading blank lines

Repeated blank lines

Trailing spaces

Trailing blank lines
EOF
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'extra blanks in the message for a signed tag should be removed' '
	but tag -s -F sigblanksfile blanks-signed-tag &&
	get_tag_msg blanks-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -v blanks-signed-tag
'

get_tag_header blank-signed-tag $cummit cummit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with a blank -m message should succeed' '
	but tag -s -m "     " blank-signed-tag &&
	get_tag_msg blank-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -v blank-signed-tag
'

echo '     ' >sigblankfile
echo ''      >>sigblankfile
echo '  '    >>sigblankfile
get_tag_header blankfile-signed-tag $cummit cummit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with blank -F file with spaces should succeed' '
	but tag -s -F sigblankfile blankfile-signed-tag &&
	get_tag_msg blankfile-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -v blankfile-signed-tag
'

printf '      ' >sigblanknonlfile
get_tag_header blanknonlfile-signed-tag $cummit cummit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with spaces and no newline should succeed' '
	but tag -s -F sigblanknonlfile blanknonlfile-signed-tag &&
	get_tag_msg blanknonlfile-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -v blanknonlfile-signed-tag
'

test_expect_success GPG 'signed tag with embedded PGP message' '
	cat >msg <<-\EOF &&
	-----BEGIN PGP MESSAGE-----

	this is not a real PGP message
	-----END PGP MESSAGE-----
	EOF
	but tag -s -F msg confusing-pgp-message &&
	but tag -v confusing-pgp-message
'

# messages with commented lines for signed tags:

cat >sigcommentsfile <<EOF
# A comment

############
The message.
############
One line.


# commented lines
# commented lines

Another line.
# comments

Last line.
EOF
get_tag_header comments-signed-tag $cummit cummit $time >expect
cat >>expect <<EOF
The message.
One line.

Another line.

Last line.
EOF
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with a -F file with #comments should succeed' '
	but tag -s -F sigcommentsfile comments-signed-tag &&
	get_tag_msg comments-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -v comments-signed-tag
'

get_tag_header comment-signed-tag $cummit cummit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with #commented -m message should succeed' '
	but tag -s -m "#comment" comment-signed-tag &&
	get_tag_msg comment-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -v comment-signed-tag
'

echo '#comment' >sigcommentfile
echo ''         >>sigcommentfile
echo '####'     >>sigcommentfile
get_tag_header commentfile-signed-tag $cummit cummit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with #commented -F messagefile should succeed' '
	but tag -s -F sigcommentfile commentfile-signed-tag &&
	get_tag_msg commentfile-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -v commentfile-signed-tag
'

printf '#comment' >sigcommentnonlfile
get_tag_header commentnonlfile-signed-tag $cummit cummit $time >expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag with a #comment and no newline should succeed' '
	but tag -s -F sigcommentnonlfile commentnonlfile-signed-tag &&
	get_tag_msg commentnonlfile-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -v commentnonlfile-signed-tag
'

# listing messages for signed tags:

test_expect_success GPG \
	'listing the one-line message of a signed tag should succeed' '
	but tag -s -m "A message line signed" stag-one-line &&

	echo "stag-one-line" >expect &&
	but tag -l | grep "^stag-one-line" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l | grep "^stag-one-line" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l stag-one-line >actual &&
	test_cmp expect actual &&

	echo "stag-one-line   A message line signed" >expect &&
	but tag -n1 -l | grep "^stag-one-line" >actual &&
	test_cmp expect actual &&
	but tag -n -l | grep "^stag-one-line" >actual &&
	test_cmp expect actual &&
	but tag -n1 -l stag-one-line >actual &&
	test_cmp expect actual &&
	but tag -n2 -l stag-one-line >actual &&
	test_cmp expect actual &&
	but tag -n999 -l stag-one-line >actual &&
	test_cmp expect actual
'

test_expect_success GPG \
	'listing the zero-lines message of a signed tag should succeed' '
	but tag -s -m "" stag-zero-lines &&

	echo "stag-zero-lines" >expect &&
	but tag -l | grep "^stag-zero-lines" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l | grep "^stag-zero-lines" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l stag-zero-lines >actual &&
	test_cmp expect actual &&

	echo "stag-zero-lines " >expect &&
	but tag -n1 -l | grep "^stag-zero-lines" >actual &&
	test_cmp expect actual &&
	but tag -n -l | grep "^stag-zero-lines" >actual &&
	test_cmp expect actual &&
	but tag -n1 -l stag-zero-lines >actual &&
	test_cmp expect actual &&
	but tag -n2 -l stag-zero-lines >actual &&
	test_cmp expect actual &&
	but tag -n999 -l stag-zero-lines >actual &&
	test_cmp expect actual
'

echo 'stag line one' >sigtagmsg
echo 'stag line two' >>sigtagmsg
echo 'stag line three' >>sigtagmsg
test_expect_success GPG \
	'listing many message lines of a signed tag should succeed' '
	but tag -s -F sigtagmsg stag-lines &&

	echo "stag-lines" >expect &&
	but tag -l | grep "^stag-lines" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l | grep "^stag-lines" >actual &&
	test_cmp expect actual &&
	but tag -n0 -l stag-lines >actual &&
	test_cmp expect actual &&

	echo "stag-lines      stag line one" >expect &&
	but tag -n1 -l | grep "^stag-lines" >actual &&
	test_cmp expect actual &&
	but tag -n -l | grep "^stag-lines" >actual &&
	test_cmp expect actual &&
	but tag -n1 -l stag-lines >actual &&
	test_cmp expect actual &&

	echo "    stag line two" >>expect &&
	but tag -n2 -l | grep "^ *stag.line" >actual &&
	test_cmp expect actual &&
	but tag -n2 -l stag-lines >actual &&
	test_cmp expect actual &&

	echo "    stag line three" >>expect &&
	but tag -n3 -l | grep "^ *stag.line" >actual &&
	test_cmp expect actual &&
	but tag -n3 -l stag-lines >actual &&
	test_cmp expect actual &&
	but tag -n4 -l | grep "^ *stag.line" >actual &&
	test_cmp expect actual &&
	but tag -n4 -l stag-lines >actual &&
	test_cmp expect actual &&
	but tag -n99 -l | grep "^ *stag.line" >actual &&
	test_cmp expect actual &&
	but tag -n99 -l stag-lines >actual &&
	test_cmp expect actual
'

# tags pointing to objects different from cummits:

tree=$(but rev-parse HEAD^{tree})
blob=$(but rev-parse HEAD:foo)
tag=$(but rev-parse signed-tag 2>/dev/null)

get_tag_header tree-signed-tag $tree tree $time >expect
echo "A message for a tree" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag pointing to a tree should succeed' '
	but tag -s -m "A message for a tree" tree-signed-tag HEAD^{tree} &&
	get_tag_msg tree-signed-tag >actual &&
	test_cmp expect actual
'

get_tag_header blob-signed-tag $blob blob $time >expect
echo "A message for a blob" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag pointing to a blob should succeed' '
	but tag -s -m "A message for a blob" blob-signed-tag HEAD:foo &&
	get_tag_msg blob-signed-tag >actual &&
	test_cmp expect actual
'

get_tag_header tag-signed-tag $tag tag $time >expect
echo "A message for another tag" >>expect
echo '-----BEGIN PGP SIGNATURE-----' >>expect
test_expect_success GPG \
	'creating a signed tag pointing to another tag should succeed' '
	but tag -s -m "A message for another tag" tag-signed-tag signed-tag &&
	get_tag_msg tag-signed-tag >actual &&
	test_cmp expect actual
'

# usage with rfc1991 signatures
get_tag_header rfc1991-signed-tag $cummit cummit $time >expect
echo "RFC1991 signed tag" >>expect
echo '-----BEGIN PGP MESSAGE-----' >>expect
test_expect_success GPG,RFC1991 \
	'creating a signed tag with rfc1991' '
	echo "rfc1991" >gpghome/gpg.conf &&
	but tag -s -m "RFC1991 signed tag" rfc1991-signed-tag $cummit &&
	get_tag_msg rfc1991-signed-tag >actual &&
	test_cmp expect actual
'

cat >fakeeditor <<'EOF'
#!/bin/sh
cp "$1" actual
EOF
chmod +x fakeeditor

test_expect_success GPG,RFC1991 \
	'reediting a signed tag body omits signature' '
	echo "rfc1991" >gpghome/gpg.conf &&
	echo "RFC1991 signed tag" >expect &&
	GIT_EDITOR=./fakeeditor but tag -f -s rfc1991-signed-tag $cummit &&
	test_cmp expect actual
'

test_expect_success GPG,RFC1991 \
	'verifying rfc1991 signature' '
	echo "rfc1991" >gpghome/gpg.conf &&
	but tag -v rfc1991-signed-tag
'

test_expect_success GPG,RFC1991 \
	'list tag with rfc1991 signature' '
	echo "rfc1991" >gpghome/gpg.conf &&
	echo "rfc1991-signed-tag RFC1991 signed tag" >expect &&
	but tag -l -n1 rfc1991-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -l -n2 rfc1991-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -l -n999 rfc1991-signed-tag >actual &&
	test_cmp expect actual
'

rm -f gpghome/gpg.conf

test_expect_success GPG,RFC1991 \
	'verifying rfc1991 signature without --rfc1991' '
	but tag -v rfc1991-signed-tag
'

test_expect_success GPG,RFC1991 \
	'list tag with rfc1991 signature without --rfc1991' '
	echo "rfc1991-signed-tag RFC1991 signed tag" >expect &&
	but tag -l -n1 rfc1991-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -l -n2 rfc1991-signed-tag >actual &&
	test_cmp expect actual &&
	but tag -l -n999 rfc1991-signed-tag >actual &&
	test_cmp expect actual
'

test_expect_success GPG,RFC1991 \
	'reediting a signed tag body omits signature' '
	echo "RFC1991 signed tag" >expect &&
	GIT_EDITOR=./fakeeditor but tag -f -s rfc1991-signed-tag $cummit &&
	test_cmp expect actual
'

# try to sign with bad user.signingkey
test_expect_success GPG \
	'but tag -s fails if gpg is misconfigured (bad key)' \
	'test_config user.signingkey BobTheMouse &&
	test_must_fail but tag -s -m tail tag-gpg-failure'

# try to produce invalid signature
test_expect_success GPG \
	'but tag -s fails if gpg is misconfigured (bad signature format)' \
	'test_config gpg.program echo &&
	 test_must_fail but tag -s -m tail tag-gpg-failure'

# try to produce invalid signature
test_expect_success GPG 'but verifies tag is valid with double signature' '
	but tag -s -m tail tag-gpg-double-sig &&
	but cat-file tag tag-gpg-double-sig >tag &&
	othersigheader=$(test_oid othersigheader) &&
	sed -ne "/^\$/q;p" tag >new-tag &&
	cat <<-EOM >>new-tag &&
	$othersigheader -----BEGIN PGP SIGNATURE-----
	 someinvaliddata
	 -----END PGP SIGNATURE-----
	EOM
	sed -e "1,/^tagger/d" tag >>new-tag &&
	new_tag=$(but hash-object -t tag -w new-tag) &&
	but update-ref refs/tags/tag-gpg-double-sig $new_tag &&
	but verify-tag tag-gpg-double-sig &&
	but fsck
'

# try to sign with bad user.signingkey
test_expect_success GPGSM \
	'but tag -s fails if gpgsm is misconfigured (bad key)' \
	'test_config user.signingkey BobTheMouse &&
	 test_config gpg.format x509 &&
	 test_must_fail but tag -s -m tail tag-gpg-failure'

# try to produce invalid signature
test_expect_success GPGSM \
	'but tag -s fails if gpgsm is misconfigured (bad signature format)' \
	'test_config gpg.x509.program echo &&
	 test_config gpg.format x509 &&
	 test_must_fail but tag -s -m tail tag-gpg-failure'

# try to verify without gpg:

rm -rf gpghome
test_expect_success GPG \
	'verify signed tag fails when public key is not present' \
	'test_must_fail but tag -v signed-tag'

test_expect_success \
	'but tag -a fails if tag annotation is empty' '
	! (GIT_EDITOR=cat but tag -a initial-comment)
'

test_expect_success \
	'message in editor has initial comment' '
	! (GIT_EDITOR=cat but tag -a initial-comment > actual)
'

test_expect_success 'message in editor has initial comment: first line' '
	# check the first line --- should be empty
	echo >first.expect &&
	sed -e 1q <actual >first.actual &&
	test_cmp first.expect first.actual
'

test_expect_success \
	'message in editor has initial comment: remainder' '
	# remove commented lines from the remainder -- should be empty
	sed -e 1d -e "/^#/d" <actual >rest.actual &&
	test_must_be_empty rest.actual
'

get_tag_header reuse $cummit cummit $time >expect
echo "An annotation to be reused" >> expect
test_expect_success \
	'overwriting an annotated tag should use its previous body' '
	but tag -a -m "An annotation to be reused" reuse &&
	GIT_EDITOR=true but tag -f -a reuse &&
	get_tag_msg reuse >actual &&
	test_cmp expect actual
'

test_expect_success 'filename for the message is relative to cwd' '
	mkdir subdir &&
	echo "Tag message in top directory" >msgfile-5 &&
	echo "Tag message in sub directory" >subdir/msgfile-5 &&
	(
		cd subdir &&
		but tag -a -F msgfile-5 tag-from-subdir
	) &&
	but cat-file tag tag-from-subdir | grep "in sub directory"
'

test_expect_success 'filename for the message is relative to cwd' '
	echo "Tag message in sub directory" >subdir/msgfile-6 &&
	(
		cd subdir &&
		but tag -a -F msgfile-6 tag-from-subdir-2
	) &&
	but cat-file tag tag-from-subdir-2 | grep "in sub directory"
'

# create a few more cummits to test --contains

hash1=$(but rev-parse HEAD)

test_expect_success 'creating second cummit and tag' '
	echo foo-2.0 >foo &&
	but add foo &&
	but cummit -m second &&
	but tag v2.0
'

hash2=$(but rev-parse HEAD)

test_expect_success 'creating third cummit without tag' '
	echo foo-dev >foo &&
	but add foo &&
	but cummit -m third
'

hash3=$(but rev-parse HEAD)

# simple linear checks of --continue

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
v2.0
EOF

test_expect_success 'checking that first cummit is in all tags (hash)' "
	but tag -l --contains $hash1 v* >actual &&
	test_cmp expected actual
"

# other ways of specifying the cummit
test_expect_success 'checking that first cummit is in all tags (tag)' "
	but tag -l --contains v1.0 v* >actual &&
	test_cmp expected actual
"

test_expect_success 'checking that first cummit is in all tags (relative)' "
	but tag -l --contains HEAD~2 v* >actual &&
	test_cmp expected actual
"

# All the --contains tests above, but with --no-contains
test_expect_success 'checking that first cummit is not listed in any tag with --no-contains  (hash)' "
	but tag -l --no-contains $hash1 v* >actual &&
	test_must_be_empty actual
"

test_expect_success 'checking that first cummit is in all tags (tag)' "
	but tag -l --no-contains v1.0 v* >actual &&
	test_must_be_empty actual
"

test_expect_success 'checking that first cummit is in all tags (relative)' "
	but tag -l --no-contains HEAD~2 v* >actual &&
	test_must_be_empty actual
"

cat > expected <<EOF
v2.0
EOF

test_expect_success 'checking that second cummit only has one tag' "
	but tag -l --contains $hash2 v* >actual &&
	test_cmp expected actual
"

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
EOF

test_expect_success 'inverse of the last test, with --no-contains' "
	but tag -l --no-contains $hash2 v* >actual &&
	test_cmp expected actual
"

test_expect_success 'checking that third commit has no tags' "
	but tag -l --contains $hash3 v* >actual &&
	test_must_be_empty actual
"

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
v2.0
EOF

test_expect_success 'conversely --no-contains on the third cummit lists all tags' "
	but tag -l --no-contains $hash3 v* >actual &&
	test_cmp expected actual
"

# how about a simple merge?

test_expect_success 'creating simple branch' '
	but branch stable v2.0 &&
        but checkout stable &&
	echo foo-3.0 > foo &&
	but cummit foo -m fourth &&
	but tag v3.0
'

hash4=$(but rev-parse HEAD)

cat > expected <<EOF
v3.0
EOF

test_expect_success 'checking that branch head only has one tag' "
	but tag -l --contains $hash4 v* >actual &&
	test_cmp expected actual
"

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
v2.0
EOF

test_expect_success 'checking that branch head with --no-contains lists all but one tag' "
	but tag -l --no-contains $hash4 v* >actual &&
	test_cmp expected actual
"

test_expect_success 'merging original branch into this branch' '
	but merge --strategy=ours main &&
        but tag v4.0
'

cat > expected <<EOF
v4.0
EOF

test_expect_success 'checking that original branch head has one tag now' "
	but tag -l --contains $hash3 v* >actual &&
	test_cmp expected actual
"

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
v2.0
v3.0
EOF

test_expect_success 'checking that original branch head with --no-contains lists all but one tag now' "
	but tag -l --no-contains $hash3 v* >actual &&
	test_cmp expected actual
"

cat > expected <<EOF
v0.2.1
v1.0
v1.0.1
v1.1.3
v2.0
v3.0
v4.0
EOF

test_expect_success 'checking that initial cummit is in all tags' "
	but tag -l --contains $hash1 v* >actual &&
	test_cmp expected actual
"

test_expect_success 'checking that --contains can be used in non-list mode' '
	but tag --contains $hash1 v* >actual &&
	test_cmp expected actual
'

test_expect_success 'checking that initial cummit is in all tags with --no-contains' "
	but tag -l --no-contains $hash1 v* >actual &&
	test_must_be_empty actual
"

# mixing modes and options:

test_expect_success 'mixing incompatibles modes and options is forbidden' '
	test_must_fail but tag -a &&
	test_must_fail but tag -a -l &&
	test_must_fail but tag -s &&
	test_must_fail but tag -s -l &&
	test_must_fail but tag -m &&
	test_must_fail but tag -m -l &&
	test_must_fail but tag -m "hlagh" &&
	test_must_fail but tag -m "hlagh" -l &&
	test_must_fail but tag -F &&
	test_must_fail but tag -F -l &&
	test_must_fail but tag -f &&
	test_must_fail but tag -f -l &&
	test_must_fail but tag -a -s -m -F &&
	test_must_fail but tag -a -s -m -F -l &&
	test_must_fail but tag -l -v &&
	test_must_fail but tag -l -d &&
	test_must_fail but tag -l -v -d &&
	test_must_fail but tag -n 100 -v &&
	test_must_fail but tag -l -m msg &&
	test_must_fail but tag -l -F some file &&
	test_must_fail but tag -v -s &&
	test_must_fail but tag --contains tag-tree &&
	test_must_fail but tag --contains tag-blob &&
	test_must_fail but tag --no-contains tag-tree &&
	test_must_fail but tag --no-contains tag-blob &&
	test_must_fail but tag --contains --no-contains &&
	test_must_fail but tag --no-with HEAD &&
	test_must_fail but tag --no-without HEAD
'

for option in --contains --with --no-contains --without --merged --no-merged --points-at
do
	test_expect_success "mixing incompatible modes with $option is forbidden" "
		test_must_fail but tag -d $option HEAD &&
		test_must_fail but tag -d $option HEAD some-tag &&
		test_must_fail but tag -v $option HEAD
	"
	test_expect_success "Doing 'but tag --list-like $option <cummit> <pattern> is permitted" "
		but tag -n $option HEAD HEAD &&
		but tag $option HEAD HEAD &&
		but tag $option
	"
done

# check points-at

test_expect_success '--points-at can be used in non-list mode' '
	echo v4.0 >expect &&
	but tag --points-at=v4.0 "v*" >actual &&
	test_cmp expect actual
'

test_expect_success '--points-at is a synonym for --points-at HEAD' '
	echo v4.0 >expect &&
	but tag --points-at >actual &&
	test_cmp expect actual
'

test_expect_success '--points-at finds lightweight tags' '
	echo v4.0 >expect &&
	but tag --points-at v4.0 >actual &&
	test_cmp expect actual
'

test_expect_success '--points-at finds annotated tags of cummits' '
	but tag -m "v4.0, annotated" annotated-v4.0 v4.0 &&
	echo annotated-v4.0 >expect &&
	but tag -l --points-at v4.0 "annotated*" >actual &&
	test_cmp expect actual
'

test_expect_success '--points-at finds annotated tags of tags' '
	but tag -m "describing the v4.0 tag object" \
		annotated-again-v4.0 annotated-v4.0 &&
	cat >expect <<-\EOF &&
	annotated-again-v4.0
	annotated-v4.0
	EOF
	but tag --points-at=annotated-v4.0 >actual &&
	test_cmp expect actual
'

test_expect_success 'recursive tagging should give advice' '
	sed -e "s/|$//" <<-EOF >expect &&
	hint: You have created a nested tag. The object referred to by your new tag is
	hint: already a tag. If you meant to tag the object that it points to, use:
	hint: |
	hint: 	but tag -f nested annotated-v4.0^{}
	hint: Disable this message with "but config advice.nestedTag false"
	EOF
	but tag -m nested nested annotated-v4.0 2>actual &&
	test_cmp expect actual
'

test_expect_success 'multiple --points-at are OR-ed together' '
	cat >expect <<-\EOF &&
	v2.0
	v3.0
	EOF
	but tag --points-at=v2.0 --points-at=v3.0 >actual &&
	test_cmp expect actual
'

test_expect_success 'lexical sort' '
	but tag foo1.3 &&
	but tag foo1.6 &&
	but tag foo1.10 &&
	but tag -l --sort=refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.10
	foo1.3
	foo1.6
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort' '
	but tag -l --sort=version:refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.3
	foo1.6
	foo1.10
	EOF
	test_cmp expect actual
'

test_expect_success 'reverse version sort' '
	but tag -l --sort=-version:refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.10
	foo1.6
	foo1.3
	EOF
	test_cmp expect actual
'

test_expect_success 'reverse lexical sort' '
	but tag -l --sort=-refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.6
	foo1.3
	foo1.10
	EOF
	test_cmp expect actual
'

test_expect_success 'configured lexical sort' '
	test_config tag.sort "v:refname" &&
	but tag -l "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.3
	foo1.6
	foo1.10
	EOF
	test_cmp expect actual
'

test_expect_success 'option override configured sort' '
	test_config tag.sort "v:refname" &&
	but tag -l --sort=-refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.6
	foo1.3
	foo1.10
	EOF
	test_cmp expect actual
'

test_expect_success 'invalid sort parameter on command line' '
	test_must_fail but tag -l --sort=notvalid "foo*" >actual
'

test_expect_success 'invalid sort parameter in configuratoin' '
	test_config tag.sort "v:notvalid" &&
	test_must_fail but tag -l "foo*"
'

test_expect_success 'version sort with prerelease reordering' '
	test_config versionsort.prereleaseSuffix -rc &&
	but tag foo1.6-rc1 &&
	but tag foo1.6-rc2 &&
	but tag -l --sort=version:refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.3
	foo1.6-rc1
	foo1.6-rc2
	foo1.6
	foo1.10
	EOF
	test_cmp expect actual
'

test_expect_success 'reverse version sort with prerelease reordering' '
	test_config versionsort.prereleaseSuffix -rc &&
	but tag -l --sort=-version:refname "foo*" >actual &&
	cat >expect <<-\EOF &&
	foo1.10
	foo1.6
	foo1.6-rc2
	foo1.6-rc1
	foo1.3
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with prerelease reordering and common leading character' '
	test_config versionsort.prereleaseSuffix -before &&
	but tag foo1.7-before1 &&
	but tag foo1.7 &&
	but tag foo1.7-after1 &&
	but tag -l --sort=version:refname "foo1.7*" >actual &&
	cat >expect <<-\EOF &&
	foo1.7-before1
	foo1.7
	foo1.7-after1
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with prerelease reordering, multiple suffixes and common leading character' '
	test_config versionsort.prereleaseSuffix -before &&
	but config --add versionsort.prereleaseSuffix -after &&
	but tag -l --sort=version:refname "foo1.7*" >actual &&
	cat >expect <<-\EOF &&
	foo1.7-before1
	foo1.7-after1
	foo1.7
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with prerelease reordering, multiple suffixes match the same tag' '
	test_config versionsort.prereleaseSuffix -bar &&
	but config --add versionsort.prereleaseSuffix -foo-baz &&
	but config --add versionsort.prereleaseSuffix -foo-bar &&
	but tag foo1.8-foo-bar &&
	but tag foo1.8-foo-baz &&
	but tag foo1.8 &&
	but tag -l --sort=version:refname "foo1.8*" >actual &&
	cat >expect <<-\EOF &&
	foo1.8-foo-baz
	foo1.8-foo-bar
	foo1.8
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with prerelease reordering, multiple suffixes match starting at the same position' '
	test_config versionsort.prereleaseSuffix -pre &&
	but config --add versionsort.prereleaseSuffix -prerelease &&
	but tag foo1.9-pre1 &&
	but tag foo1.9-pre2 &&
	but tag foo1.9-prerelease1 &&
	but tag -l --sort=version:refname "foo1.9*" >actual &&
	cat >expect <<-\EOF &&
	foo1.9-pre1
	foo1.9-pre2
	foo1.9-prerelease1
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with general suffix reordering' '
	test_config versionsort.suffix -alpha &&
	but config --add versionsort.suffix -beta &&
	but config --add versionsort.suffix ""  &&
	but config --add versionsort.suffix -gamma &&
	but config --add versionsort.suffix -delta &&
	but tag foo1.10-alpha &&
	but tag foo1.10-beta &&
	but tag foo1.10-gamma &&
	but tag foo1.10-delta &&
	but tag foo1.10-unlisted-suffix &&
	but tag -l --sort=version:refname "foo1.10*" >actual &&
	cat >expect <<-\EOF &&
	foo1.10-alpha
	foo1.10-beta
	foo1.10
	foo1.10-unlisted-suffix
	foo1.10-gamma
	foo1.10-delta
	EOF
	test_cmp expect actual
'

test_expect_success 'versionsort.suffix overrides versionsort.prereleaseSuffix' '
	test_config versionsort.suffix -before &&
	test_config versionsort.prereleaseSuffix -after &&
	but tag -l --sort=version:refname "foo1.7*" >actual &&
	cat >expect <<-\EOF &&
	foo1.7-before1
	foo1.7
	foo1.7-after1
	EOF
	test_cmp expect actual
'

test_expect_success 'version sort with very long prerelease suffix' '
	test_config versionsort.prereleaseSuffix -very-looooooooooooooooooooooooong-prerelease-suffix &&
	but tag -l --sort=version:refname
'

test_expect_success ULIMIT_STACK_SIZE '--contains and --no-contains work in a deep repo' '
	i=1 &&
	while test $i -lt 8000
	do
		echo "cummit refs/heads/main
cummitter A U Thor <author@example.com> $((1000000000 + $i * 100)) +0200
data <<EOF
cummit #$i
EOF" &&
		if test $i = 1
		then
			echo "from refs/heads/main^0"
		fi &&
		i=$(($i + 1)) || return 1
	done | but fast-import &&
	but checkout main &&
	but tag far-far-away HEAD^ &&
	run_with_limited_stack but tag --contains HEAD >actual &&
	test_must_be_empty actual &&
	run_with_limited_stack but tag --no-contains HEAD >actual &&
	test_line_count "-gt" 10 actual
'

test_expect_success '--format should list tags as per format given' '
	cat >expect <<-\EOF &&
	refname : refs/tags/v1.0
	refname : refs/tags/v1.0.1
	refname : refs/tags/v1.1.3
	EOF
	but tag -l --format="refname : %(refname)" "v1*" >actual &&
	test_cmp expect actual
'

test_expect_success 'but tag -l with --format="%(rest)" must fail' '
	test_must_fail but tag -l --format="%(rest)" "v1*"
'

test_expect_success "set up color tests" '
	echo "<RED>v1.0<RESET>" >expect.color &&
	echo "v1.0" >expect.bare &&
	color_args="--format=%(color:red)%(refname:short) --list v1.0"
'

test_expect_success '%(color) omitted without tty' '
	TERM=vt100 but tag $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.bare actual
'

test_expect_success TTY '%(color) present with tty' '
	test_terminal but tag $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.color actual
'

test_expect_success '--color overrides auto-color' '
	but tag --color $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.color actual
'

test_expect_success 'color.ui=always overrides auto-color' '
	but -c color.ui=always tag $color_args >actual.raw &&
	test_decode_color <actual.raw >actual &&
	test_cmp expect.color actual
'

test_expect_success 'setup --merged test tags' '
	but tag mergetest-1 HEAD~2 &&
	but tag mergetest-2 HEAD~1 &&
	but tag mergetest-3 HEAD
'

test_expect_success '--merged can be used in non-list mode' '
	cat >expect <<-\EOF &&
	mergetest-1
	mergetest-2
	EOF
	but tag --merged=mergetest-2 "mergetest*" >actual &&
	test_cmp expect actual
'

test_expect_success '--merged is compatible with --no-merged' '
	but tag --merged HEAD --no-merged HEAD
'

test_expect_success '--merged shows merged tags' '
	cat >expect <<-\EOF &&
	mergetest-1
	mergetest-2
	EOF
	but tag -l --merged=mergetest-2 mergetest-* >actual &&
	test_cmp expect actual
'

test_expect_success '--no-merged show unmerged tags' '
	cat >expect <<-\EOF &&
	mergetest-3
	EOF
	but tag -l --no-merged=mergetest-2 mergetest-* >actual &&
	test_cmp expect actual
'

test_expect_success '--no-merged can be used in non-list mode' '
	but tag --no-merged=mergetest-2 mergetest-* >actual &&
	test_cmp expect actual
'

test_expect_success 'ambiguous branch/tags not marked' '
	but tag ambiguous &&
	but branch ambiguous &&
	echo ambiguous >expect &&
	but tag -l ambiguous >actual &&
	test_cmp expect actual
'

test_expect_success '--contains combined with --no-contains' '
	(
		but init no-contains &&
		cd no-contains &&
		test_cummit v0.1 &&
		test_cummit v0.2 &&
		test_cummit v0.3 &&
		test_cummit v0.4 &&
		test_cummit v0.5 &&
		cat >expected <<-\EOF &&
		v0.2
		v0.3
		v0.4
		EOF
		but tag --contains v0.2 --no-contains v0.5 >actual &&
		test_cmp expected actual
	)
'

# As the docs say, list tags which contain a specified *cummit*. We
# don't recurse down to tags for trees or blobs pointed to by *those*
# cummits.
test_expect_success 'Does --[no-]contains stop at cummits? Yes!' '
	cd no-contains &&
	blob=$(but rev-parse v0.3:v0.3.t) &&
	tree=$(but rev-parse v0.3^{tree}) &&
	but tag tag-blob $blob &&
	but tag tag-tree $tree &&
	but tag --contains v0.3 >actual &&
	cat >expected <<-\EOF &&
	v0.3
	v0.4
	v0.5
	EOF
	test_cmp expected actual &&
	but tag --no-contains v0.3 >actual &&
	cat >expected <<-\EOF &&
	v0.1
	v0.2
	EOF
	test_cmp expected actual
'

test_done
