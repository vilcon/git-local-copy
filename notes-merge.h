#ifndef NOTES_MERGE_H
#define NOTES_MERGE_H

#include "notes-utils.h"
#include "strbuf.h"

struct cummit;
struct object_id;
struct repository;

#define NOTES_MERGE_WORKTREE "NOTES_MERGE_WORKTREE"

enum notes_merge_verbosity {
	NOTES_MERGE_VERBOSITY_DEFAULT = 2,
	NOTES_MERGE_VERBOSITY_MAX = 5
};

struct notes_merge_options {
	struct repository *repo;
	const char *local_ref;
	const char *remote_ref;
	struct strbuf cummit_msg;
	int verbosity;
	enum notes_merge_strategy strategy;
	unsigned has_worktree:1;
};

void init_notes_merge_options(struct repository *r,
			      struct notes_merge_options *o);

/*
 * Merge notes from o->remote_ref into o->local_ref
 *
 * The given notes_tree 'local_tree' must be the notes_tree referenced by the
 * o->local_ref. This is the notes_tree in which the object-level merge is
 * performed.
 *
 * The cummits given by the two refs are merged, producing one of the following
 * outcomes:
 *
 * 1. The merge trivially results in an existing cummit (e.g. fast-forward or
 *    already-up-to-date). 'local_tree' is untouched, the OID of the result
 *    is written into 'result_oid' and 0 is returned.
 * 2. The merge successfully completes, producing a merge cummit. local_tree
 *    contains the updated notes tree, the OID of the resulting cummit is
 *    written into 'result_oid', and 1 is returned.
 * 3. The merge results in conflicts. This is similar to #2 in that the
 *    partial merge result (i.e. merge result minus the unmerged entries)
 *    are stored in 'local_tree', and the OID or the resulting cummit
 *    (to be amended when the conflicts have been resolved) is written into
 *    'result_oid'. The unmerged entries are written into the
 *    .but/NOTES_MERGE_WORKTREE directory with conflict markers.
 *    -1 is returned.
 *
 * Both o->local_ref and o->remote_ref must be given (non-NULL), but either ref
 * (although not both) may refer to a non-existing notes ref, in which case
 * that notes ref is interpreted as an empty notes tree, and the merge
 * trivially results in what the other ref points to.
 */
int notes_merge(struct notes_merge_options *o,
		struct notes_tree *local_tree,
		struct object_id *result_oid);

/*
 * Finalize conflict resolution from an earlier notes_merge()
 *
 * The given notes tree 'partial_tree' must be the notes_tree corresponding to
 * the given 'partial_cummit', the partial result cummit created by a previous
 * call to notes_merge().
 *
 * This function will add the (now resolved) notes in .but/NOTES_MERGE_WORKTREE
 * to 'partial_tree', and create a final notes merge cummit, the OID of which
 * will be stored in 'result_oid'.
 */
int notes_merge_cummit(struct notes_merge_options *o,
		       struct notes_tree *partial_tree,
		       struct cummit *partial_cummit,
		       struct object_id *result_oid);

/*
 * Abort conflict resolution from an earlier notes_merge()
 *
 * Removes the notes merge worktree in .but/NOTES_MERGE_WORKTREE.
 */
int notes_merge_abort(struct notes_merge_options *o);

#endif
