#!/bin/sh

# Helper functions for testing cummit-graphs.

# Initialize OID cache with oid_version
test_oid_cache <<-EOF
oid_version sha1:1
oid_version sha256:2
EOF

graph_but_two_modes() {
	but -c core.cummitGraph=true $1 >output &&
	but -c core.cummitGraph=false $1 >expect &&
	test_cmp expect output
}

graph_but_behavior() {
	MSG=$1
	DIR=$2
	BRANCH=$3
	COMPARE=$4
	test_expect_success "check normal but operations: $MSG" '
		cd "$TRASH_DIRECTORY/$DIR" &&
		graph_but_two_modes "log --oneline $BRANCH" &&
		graph_but_two_modes "log --topo-order $BRANCH" &&
		graph_but_two_modes "log --graph $COMPARE..$BRANCH" &&
		graph_but_two_modes "branch -vv" &&
		graph_but_two_modes "merge-base -a $BRANCH $COMPARE"
	'
}

graph_read_expect() {
	OPTIONAL=""
	NUM_CHUNKS=3
	if test -n "$2"
	then
		OPTIONAL=" $2"
		NUM_CHUNKS=$((3 + $(echo "$2" | wc -w)))
	fi
	GENERATION_VERSION=2
	if test -n "$3"
	then
		GENERATION_VERSION=$3
	fi
	OPTIONS=
	if test $GENERATION_VERSION -gt 1
	then
		OPTIONS=" read_generation_data"
	fi
	cat >expect <<- EOF
	header: 43475048 1 $(test_oid oid_version) $NUM_CHUNKS 0
	num_cummits: $1
	chunks: oid_fanout oid_lookup cummit_metadata$OPTIONAL
	options:$OPTIONS
	EOF
	test-tool read-graph >output &&
	test_cmp expect output
}
