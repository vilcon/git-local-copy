#!/bin/sh

test_description='Clone repositories and map users'

. ./lib-but-p4.sh

test_expect_success 'start p4d' '
	start_p4d
'

test_expect_success 'Create a repo with different users' '
	client_view "//depot/... //client/..." &&
	(
		cd "$cli" &&

		>author.txt &&
		p4 add author.txt &&
		p4 submit -d "Add file author\\n" &&

		P4USER=mmax &&
		>max.txt &&
		p4 add max.txt &&
		p4 submit -d "Add file max" &&

		P4USER=eri &&
		>moritz.txt &&
		p4 add moritz.txt &&
		p4 submit -d "Add file moritz" &&

		P4USER=no &&
		>nobody.txt &&
		p4 add nobody.txt &&
		p4 submit -d "Add file nobody"
	)
'

test_expect_success 'Clone repo root path with all history' '
	client_view "//depot/... //client/..." &&
	test_when_finished cleanup_but &&
	(
		cd "$but" &&
		but init . &&
		but config --add but-p4.mapUser "mmax = Max Musterman   <max@example.com> "  &&
		but config --add but-p4.mapUser "  eri=Erika Musterman <erika@example.com>" &&
		but p4 clone --use-client-spec --destination="$but" //depot@all &&
		cat >expect <<-\EOF &&
			no <no@client>
			Erika Musterman <erika@example.com>
			Max Musterman <max@example.com>
			Dr. author <author@example.com>
		EOF
		but log --format="%an <%ae>" >actual &&
		test_cmp expect actual
	)
'

test_done
