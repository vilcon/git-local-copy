#!/bin/sh

test_description='but blame textconv support'
. ./test-lib.sh

find_blame() {
	sed -e 's/^[^(]*//'
}

cat >helper <<'EOF'
#!/bin/sh
grep -q '^bin: ' "$1" || { echo "E: $1 is not \"binary\" file" 1>&2; exit 1; }
"$PERL_PATH" -p -e 's/^bin: /converted: /' "$1"
EOF
chmod +x helper

test_expect_success 'setup ' '
	echo "bin: test number 0" >zero.bin &&
	echo "bin: test 1" >one.bin &&
	echo "bin: test number 2" >two.bin &&
	test_ln_s_add one.bin symlink.bin &&
	but add . &&
	GIT_AUTHOR_NAME=Number1 but cummit -a -m First --date="2010-01-01 18:00:00" &&
	echo "bin: test 1 version 2" >one.bin &&
	echo "bin: test number 2 version 2" >>two.bin &&
	rm -f symlink.bin &&
	test_ln_s_add two.bin symlink.bin &&
	GIT_AUTHOR_NAME=Number2 but cummit -a -m Second --date="2010-01-01 20:00:00"
'

cat >expected <<EOF
(Number2 2010-01-01 20:00:00 +0000 1) bin: test 1 version 2
EOF

test_expect_success 'no filter specified' '
	but blame one.bin >blame &&
	find_blame Number2 <blame >result &&
	test_cmp expected result
'

test_expect_success 'setup textconv filters' '
	echo "*.bin diff=test" >.butattributes &&
	echo "zero.bin eol=crlf" >>.butattributes &&
	but config diff.test.textconv ./helper &&
	but config diff.test.cachetextconv false
'

test_expect_success 'blame with --no-textconv' '
	but blame --no-textconv one.bin >blame &&
	find_blame <blame> result &&
	test_cmp expected result
'

cat >expected <<EOF
(Number2 2010-01-01 20:00:00 +0000 1) converted: test 1 version 2
EOF

test_expect_success 'basic blame on last cummit' '
	but blame one.bin >blame &&
	find_blame  <blame >result &&
	test_cmp expected result
'

cat >expected <<EOF
(Number1 2010-01-01 18:00:00 +0000 1) converted: test number 2
(Number2 2010-01-01 20:00:00 +0000 2) converted: test number 2 version 2
EOF

test_expect_success 'blame --textconv going through revisions' '
	but blame --textconv two.bin >blame &&
	find_blame <blame >result &&
	test_cmp expected result
'

test_expect_success 'blame --textconv with local changes' '
	test_when_finished "but checkout zero.bin" &&
	printf "bin: updated number 0\015" >zero.bin &&
	but blame --textconv zero.bin >blame &&
	expect="(Not cummitted Yet ....-..-.. ..:..:.. +0000 1)" &&
	expect="$expect converted: updated number 0" &&
	expr "$(find_blame <blame)" : "^$expect"
'

test_expect_success 'setup +cachetextconv' '
	but config diff.test.cachetextconv true
'

cat >expected_one <<EOF
(Number2 2010-01-01 20:00:00 +0000 1) converted: test 1 version 2
EOF

test_expect_success 'blame --textconv works with textconvcache' '
	but blame --textconv two.bin >blame &&
	find_blame <blame >result &&
	test_cmp expected result &&
	but blame --textconv one.bin >blame &&
	find_blame  <blame >result &&
	test_cmp expected_one result
'

test_expect_success 'setup -cachetextconv' '
	but config diff.test.cachetextconv false
'

test_expect_success 'make a new cummit' '
	echo "bin: test number 2 version 3" >>two.bin &&
	GIT_AUTHOR_NAME=Number3 but cummit -a -m Third --date="2010-01-01 22:00:00"
'

test_expect_success 'blame from previous revision' '
	but blame HEAD^ two.bin >blame &&
	find_blame <blame >result &&
	test_cmp expected result
'

cat >expected <<EOF
(Number2 2010-01-01 20:00:00 +0000 1) two.bin
EOF

test_expect_success SYMLINKS 'blame with --no-textconv (on symlink)' '
	but blame --no-textconv symlink.bin >blame &&
	find_blame <blame >result &&
	test_cmp expected result
'

test_expect_success SYMLINKS 'blame --textconv (on symlink)' '
	but blame --textconv symlink.bin >blame &&
	find_blame <blame >result &&
	test_cmp expected result
'

# cp two.bin three.bin  and make small tweak
# (this will direct blame -C -C three.bin to consider two.bin and symlink.bin)
test_expect_success 'make another new cummit' '
	cat >three.bin <<\EOF &&
bin: test number 2
bin: test number 2 version 2
bin: test number 2 version 3
bin: test number 3
EOF
	but add three.bin &&
	GIT_AUTHOR_NAME=Number4 but cummit -a -m Fourth --date="2010-01-01 23:00:00"
'

test_expect_success 'blame on last cummit (-C -C, symlink)' '
	but blame -C -C three.bin >blame &&
	find_blame <blame >result &&
	cat >expected <<\EOF &&
(Number1 2010-01-01 18:00:00 +0000 1) converted: test number 2
(Number2 2010-01-01 20:00:00 +0000 2) converted: test number 2 version 2
(Number3 2010-01-01 22:00:00 +0000 3) converted: test number 2 version 3
(Number4 2010-01-01 23:00:00 +0000 4) converted: test number 3
EOF
	test_cmp expected result
'

test_done
