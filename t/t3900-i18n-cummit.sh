#!/bin/sh
#
# Copyright (c) 2006 Junio C Hamano
#

test_description='cummit and log output encodings'

. ./test-lib.sh

compare_with () {
	but show -s $1 | sed -e '1,/^$/d' -e 's/^    //' >current &&
	case "$3" in
	'')
		test_cmp "$2" current ;;
	?*)
		iconv -f "$3" -t UTF-8 >current.utf8 <current &&
		iconv -f "$3" -t UTF-8 >expect.utf8 <"$2" &&
		test_cmp expect.utf8 current.utf8
		;;
	esac
}

test_expect_success setup '
	: >F &&
	but add F &&
	T=$(but write-tree) &&
	C=$(but cummit-tree $T <"$TEST_DIRECTORY"/t3900/1-UTF-8.txt) &&
	but update-ref HEAD $C &&
	but tag C0
'

test_expect_success 'no encoding header for base case' '
	E=$(but cat-file cummit C0 | sed -ne "s/^encoding //p") &&
	test z = "z$E"
'

test_expect_success 'UTF-16 refused because of NULs' '
	echo UTF-16 >F &&
	test_must_fail but cummit -a -F "$TEST_DIRECTORY"/t3900/UTF-16.txt
'

test_expect_success 'UTF-8 invalid characters refused' '
	test_when_finished "rm -f \"\$HOME/stderr\" \"\$HOME/invalid\"" &&
	echo "UTF-8 characters" >F &&
	printf "cummit message\n\nInvalid surrogate:\355\240\200\n" \
		>"$HOME/invalid" &&
	but cummit -a -F "$HOME/invalid" 2>"$HOME"/stderr &&
	test_i18ngrep "did not conform" "$HOME"/stderr
'

test_expect_success 'UTF-8 overlong sequences rejected' '
	test_when_finished "rm -f \"\$HOME/stderr\" \"\$HOME/invalid\"" &&
	rm -f "$HOME/stderr" "$HOME/invalid" &&
	echo "UTF-8 overlong" >F &&
	printf "\340\202\251ommit message\n\nThis is not a space:\300\240\n" \
		>"$HOME/invalid" &&
	but cummit -a -F "$HOME/invalid" 2>"$HOME"/stderr &&
	test_i18ngrep "did not conform" "$HOME"/stderr
'

test_expect_success 'UTF-8 non-characters refused' '
	test_when_finished "rm -f \"\$HOME/stderr\" \"\$HOME/invalid\"" &&
	echo "UTF-8 non-character 1" >F &&
	printf "cummit message\n\nNon-character:\364\217\277\276\n" \
		>"$HOME/invalid" &&
	but cummit -a -F "$HOME/invalid" 2>"$HOME"/stderr &&
	test_i18ngrep "did not conform" "$HOME"/stderr
'

test_expect_success 'UTF-8 non-characters refused' '
	test_when_finished "rm -f \"\$HOME/stderr\" \"\$HOME/invalid\"" &&
	echo "UTF-8 non-character 2." >F &&
	printf "cummit message\n\nNon-character:\357\267\220\n" \
		>"$HOME/invalid" &&
	but cummit -a -F "$HOME/invalid" 2>"$HOME"/stderr &&
	test_i18ngrep "did not conform" "$HOME"/stderr
'

for H in ISO8859-1 eucJP ISO-2022-JP
do
	test_expect_success "$H setup" '
		but config i18n.cummitencoding $H &&
		but checkout -b $H C0 &&
		echo $H >F &&
		but cummit -a -F "$TEST_DIRECTORY"/t3900/$H.txt
	'
done

for H in ISO8859-1 eucJP ISO-2022-JP
do
	test_expect_success "check encoding header for $H" '
		E=$(but cat-file cummit '$H' | sed -ne "s/^encoding //p") &&
		test "z$E" = "z'$H'"
	'
done

test_expect_success 'config to remove customization' '
	but config --unset-all i18n.cummitencoding &&
	if Z=$(but config --get-all i18n.cummitencoding)
	then
		echo Oops, should have failed.
		false
	else
		test z = "z$Z"
	fi &&
	but config i18n.cummitencoding UTF-8
'

test_expect_success 'ISO8859-1 should be shown in UTF-8 now' '
	compare_with ISO8859-1 "$TEST_DIRECTORY"/t3900/1-UTF-8.txt
'

for H in eucJP ISO-2022-JP
do
	test_expect_success "$H should be shown in UTF-8 now" '
		compare_with '$H' "$TEST_DIRECTORY"/t3900/2-UTF-8.txt
	'
done

test_expect_success 'config to add customization' '
	but config --unset-all i18n.cummitencoding &&
	if Z=$(but config --get-all i18n.cummitencoding)
	then
		echo Oops, should have failed.
		false
	else
		test z = "z$Z"
	fi
'

for H in ISO8859-1 eucJP ISO-2022-JP
do
	test_expect_success "$H should be shown in itself now" '
		but config i18n.cummitencoding '$H' &&
		compare_with '$H' "$TEST_DIRECTORY"/t3900/'$H'.txt
	'
done

test_expect_success 'config to tweak customization' '
	but config i18n.logoutputencoding UTF-8
'

test_expect_success 'ISO8859-1 should be shown in UTF-8 now' '
	compare_with ISO8859-1 "$TEST_DIRECTORY"/t3900/1-UTF-8.txt
'

for H in eucJP ISO-2022-JP
do
	test_expect_success "$H should be shown in UTF-8 now" '
		compare_with '$H' "$TEST_DIRECTORY"/t3900/2-UTF-8.txt
	'
done

for J in eucJP ISO-2022-JP
do
	if test "$J" = ISO-2022-JP
	then
		ICONV=$J
	else
		ICONV=
	fi
	but config i18n.logoutputencoding $J
	for H in eucJP ISO-2022-JP
	do
		test_expect_success "$H should be shown in $J now" '
			compare_with '$H' "$TEST_DIRECTORY"/t3900/'$J'.txt $ICONV
		'
	done
done

for H in ISO8859-1 eucJP ISO-2022-JP
do
	test_expect_success "No conversion with $H" '
		compare_with "--encoding=none '$H'" "$TEST_DIRECTORY"/t3900/'$H'.txt
	'
done

test_cummit_autosquash_flags () {
	H=$1
	flag=$2
	test_expect_success "cummit --$flag with $H encoding" '
		but config i18n.cummitencoding $H &&
		but checkout -b $H-$flag C0 &&
		echo $H >>F &&
		but cummit -a -F "$TEST_DIRECTORY"/t3900/$H.txt &&
		test_tick &&
		echo intermediate stuff >>G &&
		but add G &&
		but cummit -a -m "intermediate cummit" &&
		test_tick &&
		echo $H $flag >>F &&
		but cummit -a --$flag HEAD~1 &&
		E=$(but cat-file cummit '$H-$flag' |
			sed -ne "s/^encoding //p") &&
		test "z$E" = "z$H" &&
		but config --unset-all i18n.cummitencoding &&
		but rebase --autosquash -i HEAD^^^ &&
		but log --oneline >actual &&
		test_line_count = 3 actual
	'
}

test_cummit_autosquash_flags eucJP fixup

test_cummit_autosquash_flags ISO-2022-JP squash

test_cummit_autosquash_multi_encoding () {
	flag=$1
	old=$2
	new=$3
	msg=$4
	test_expect_success "cummit --$flag into $old from $new" '
		but checkout -b $flag-$old-$new C0 &&
		but config i18n.cummitencoding $old &&
		echo $old >>F &&
		but cummit -a -F "$TEST_DIRECTORY"/t3900/$msg &&
		test_tick &&
		echo intermediate stuff >>G &&
		but add G &&
		but cummit -a -m "intermediate cummit" &&
		test_tick &&
		but config i18n.cummitencoding $new &&
		echo $new-$flag >>F &&
		but cummit -a --$flag HEAD^ &&
		but rebase --autosquash -i HEAD^^^ &&
		but rev-list HEAD >actual &&
		test_line_count = 3 actual &&
		iconv -f $old -t UTF-8 "$TEST_DIRECTORY"/t3900/$msg >expect &&
		but cat-file commit HEAD^ >raw &&
		(sed "1,/^$/d" raw | iconv -f $new -t utf-8) >actual &&
		test_cmp expect actual
	'
}

test_cummit_autosquash_multi_encoding fixup UTF-8 ISO-8859-1 1-UTF-8.txt
test_cummit_autosquash_multi_encoding squash ISO-8859-1 UTF-8 ISO8859-1.txt
test_cummit_autosquash_multi_encoding squash eucJP ISO-2022-JP eucJP.txt
test_cummit_autosquash_multi_encoding fixup ISO-2022-JP UTF-8 ISO-2022-JP.txt

test_done
