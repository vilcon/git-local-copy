#include "builtin.h"
#include "config.h"
#include "dir.h"
#include "lockfile.h"
#include "parse-options.h"
#include "repository.h"
#include "cummit-graph.h"
#include "object-store.h"
#include "progress.h"
#include "tag.h"

#define BUILTIN_CUMMIT_GRAPH_VERIFY_USAGE \
	N_("but cummit-graph verify [--object-dir <objdir>] [--shallow] [--[no-]progress]")

#define BUILTIN_CUMMIT_GRAPH_WRITE_USAGE \
	N_("but cummit-graph write [--object-dir <objdir>] [--append] " \
	   "[--split[=<strategy>]] [--reachable|--stdin-packs|--stdin-cummits] " \
	   "[--changed-paths] [--[no-]max-new-filters <n>] [--[no-]progress] " \
	   "<split options>")

static const char * builtin_cummit_graph_verify_usage[] = {
	BUILTIN_CUMMIT_GRAPH_VERIFY_USAGE,
	NULL
};

static const char * builtin_cummit_graph_write_usage[] = {
	BUILTIN_CUMMIT_GRAPH_WRITE_USAGE,
	NULL
};

static char const * const builtin_cummit_graph_usage[] = {
	BUILTIN_CUMMIT_GRAPH_VERIFY_USAGE,
	BUILTIN_CUMMIT_GRAPH_WRITE_USAGE,
	NULL,
};

static struct opts_cummit_graph {
	const char *obj_dir;
	int reachable;
	int stdin_packs;
	int stdin_cummits;
	int append;
	int split;
	int shallow;
	int progress;
	int enable_changed_paths;
} opts;

static struct option common_opts[] = {
	OPT_STRING(0, "object-dir", &opts.obj_dir,
		   N_("dir"),
		   N_("the object directory to store the graph")),
	OPT_END()
};

static struct option *add_common_options(struct option *to)
{
	return parse_options_concat(common_opts, to);
}

static int graph_verify(int argc, const char **argv)
{
	struct cummit_graph *graph = NULL;
	struct object_directory *odb = NULL;
	char *graph_name;
	int open_ok;
	int fd;
	struct stat st;
	int flags = 0;

	static struct option builtin_cummit_graph_verify_options[] = {
		OPT_BOOL(0, "shallow", &opts.shallow,
			 N_("if the cummit-graph is split, only verify the tip file")),
		OPT_BOOL(0, "progress", &opts.progress,
			 N_("force progress reporting")),
		OPT_END(),
	};
	struct option *options = add_common_options(builtin_cummit_graph_verify_options);

	trace2_cmd_mode("verify");

	opts.progress = isatty(2);
	argc = parse_options(argc, argv, NULL,
			     options,
			     builtin_cummit_graph_verify_usage, 0);
	if (argc)
		usage_with_options(builtin_cummit_graph_verify_usage, options);

	if (!opts.obj_dir)
		opts.obj_dir = get_object_directory();
	if (opts.shallow)
		flags |= CUMMIT_GRAPH_VERIFY_SHALLOW;
	if (opts.progress)
		flags |= CUMMIT_GRAPH_WRITE_PROGRESS;

	odb = find_odb(the_repository, opts.obj_dir);
	graph_name = get_cummit_graph_filename(odb);
	open_ok = open_cummit_graph(graph_name, &fd, &st);
	if (!open_ok && errno != ENOENT)
		die_errno(_("Could not open cummit-graph '%s'"), graph_name);

	FREE_AND_NULL(graph_name);
	FREE_AND_NULL(options);

	if (open_ok)
		graph = load_cummit_graph_one_fd_st(the_repository, fd, &st, odb);
	else
		graph = read_cummit_graph_one(the_repository, odb);

	/* Return failure if open_ok predicted success */
	if (!graph)
		return !!open_ok;

	UNLEAK(graph);
	return verify_cummit_graph(the_repository, graph, flags);
}

extern int read_replace_refs;
static struct cummit_graph_opts write_opts;

static int write_option_parse_split(const struct option *opt, const char *arg,
				    int unset)
{
	enum cummit_graph_split_flags *flags = opt->value;

	BUG_ON_OPT_NEG(unset);

	opts.split = 1;
	if (!arg)
		return 0;

	if (!strcmp(arg, "no-merge"))
		*flags = CUMMIT_GRAPH_SPLIT_MERGE_PROHIBITED;
	else if (!strcmp(arg, "replace"))
		*flags = CUMMIT_GRAPH_SPLIT_REPLACE;
	else
		die(_("unrecognized --split argument, %s"), arg);

	return 0;
}

static int read_one_cummit(struct oidset *cummits, struct progress *progress,
			   const char *hash)
{
	struct object *result;
	struct object_id oid;
	const char *end;

	if (parse_oid_hex(hash, &oid, &end))
		return error(_("unexpected non-hex object ID: %s"), hash);

	result = deref_tag(the_repository, parse_object(the_repository, &oid),
			   NULL, 0);
	if (!result)
		return error(_("invalid object: %s"), hash);
	else if (object_as_type(result, OBJ_CUMMIT, 1))
		oidset_insert(cummits, &result->oid);

	display_progress(progress, oidset_size(cummits));

	return 0;
}

static int write_option_max_new_filters(const struct option *opt,
					const char *arg,
					int unset)
{
	int *to = opt->value;
	if (unset)
		*to = -1;
	else {
		const char *s;
		*to = strtol(arg, (char **)&s, 10);
		if (*s)
			return error(_("option `%s' expects a numerical value"),
				     "max-new-filters");
	}
	return 0;
}

static int but_cummit_graph_write_config(const char *var, const char *value,
					 void *cb)
{
	if (!strcmp(var, "cummitgraph.maxnewfilters"))
		write_opts.max_new_filters = but_config_int(var, value);
	/*
	 * No need to fall-back to 'but_default_config', since this was already
	 * called in 'cmd_cummit_graph()'.
	 */
	return 0;
}

static int graph_write(int argc, const char **argv)
{
	struct string_list pack_indexes = STRING_LIST_INIT_DUP;
	struct strbuf buf = STRBUF_INIT;
	struct oidset cummits = OIDSET_INIT;
	struct object_directory *odb = NULL;
	int result = 0;
	enum cummit_graph_write_flags flags = 0;
	struct progress *progress = NULL;

	static struct option builtin_cummit_graph_write_options[] = {
		OPT_BOOL(0, "reachable", &opts.reachable,
			N_("start walk at all refs")),
		OPT_BOOL(0, "stdin-packs", &opts.stdin_packs,
			N_("scan pack-indexes listed by stdin for cummits")),
		OPT_BOOL(0, "stdin-cummits", &opts.stdin_cummits,
			N_("start walk at cummits listed by stdin")),
		OPT_BOOL(0, "append", &opts.append,
			N_("include all cummits already in the cummit-graph file")),
		OPT_BOOL(0, "changed-paths", &opts.enable_changed_paths,
			N_("enable computation for changed paths")),
		OPT_CALLBACK_F(0, "split", &write_opts.split_flags, NULL,
			N_("allow writing an incremental cummit-graph file"),
			PARSE_OPT_OPTARG | PARSE_OPT_NONEG,
			write_option_parse_split),
		OPT_INTEGER(0, "max-cummits", &write_opts.max_cummits,
			N_("maximum number of cummits in a non-base split cummit-graph")),
		OPT_INTEGER(0, "size-multiple", &write_opts.size_multiple,
			N_("maximum ratio between two levels of a split cummit-graph")),
		OPT_EXPIRY_DATE(0, "expire-time", &write_opts.expire_time,
			N_("only expire files older than a given date-time")),
		OPT_CALLBACK_F(0, "max-new-filters", &write_opts.max_new_filters,
			NULL, N_("maximum number of changed-path Bloom filters to compute"),
			0, write_option_max_new_filters),
		OPT_BOOL(0, "progress", &opts.progress,
			 N_("force progress reporting")),
		OPT_END(),
	};
	struct option *options = add_common_options(builtin_cummit_graph_write_options);

	opts.progress = isatty(2);
	opts.enable_changed_paths = -1;
	write_opts.size_multiple = 2;
	write_opts.max_cummits = 0;
	write_opts.expire_time = 0;
	write_opts.max_new_filters = -1;

	trace2_cmd_mode("write");

	but_config(but_cummit_graph_write_config, &opts);

	argc = parse_options(argc, argv, NULL,
			     options,
			     builtin_cummit_graph_write_usage, 0);
	if (argc)
		usage_with_options(builtin_cummit_graph_write_usage, options);

	if (opts.reachable + opts.stdin_packs + opts.stdin_cummits > 1)
		die(_("use at most one of --reachable, --stdin-cummits, or --stdin-packs"));
	if (!opts.obj_dir)
		opts.obj_dir = get_object_directory();
	if (opts.append)
		flags |= CUMMIT_GRAPH_WRITE_APPEND;
	if (opts.split)
		flags |= CUMMIT_GRAPH_WRITE_SPLIT;
	if (opts.progress)
		flags |= CUMMIT_GRAPH_WRITE_PROGRESS;
	if (!opts.enable_changed_paths)
		flags |= CUMMIT_GRAPH_NO_WRITE_BLOOM_FILTERS;
	if (opts.enable_changed_paths == 1 ||
	    but_env_bool(GIT_TEST_CUMMIT_GRAPH_CHANGED_PATHS, 0))
		flags |= CUMMIT_GRAPH_WRITE_BLOOM_FILTERS;

	odb = find_odb(the_repository, opts.obj_dir);

	if (opts.reachable) {
		if (write_cummit_graph_reachable(odb, flags, &write_opts))
			return 1;
		return 0;
	}

	if (opts.stdin_packs) {
		while (strbuf_getline(&buf, stdin) != EOF)
			string_list_append_nodup(&pack_indexes,
						 strbuf_detach(&buf, NULL));
	} else if (opts.stdin_cummits) {
		oidset_init(&cummits, 0);
		if (opts.progress)
			progress = start_delayed_progress(
				_("Collecting cummits from input"), 0);

		while (strbuf_getline(&buf, stdin) != EOF) {
			if (read_one_cummit(&cummits, progress, buf.buf)) {
				result = 1;
				goto cleanup;
			}
		}

		stop_progress(&progress);
	}

	if (write_cummit_graph(odb,
			       opts.stdin_packs ? &pack_indexes : NULL,
			       opts.stdin_cummits ? &cummits : NULL,
			       flags,
			       &write_opts))
		result = 1;

cleanup:
	FREE_AND_NULL(options);
	string_list_clear(&pack_indexes, 0);
	strbuf_release(&buf);
	return result;
}

int cmd_cummit_graph(int argc, const char **argv, const char *prefix)
{
	struct option *builtin_cummit_graph_options = common_opts;

	but_config(but_default_config, NULL);
	argc = parse_options(argc, argv, prefix,
			     builtin_cummit_graph_options,
			     builtin_cummit_graph_usage,
			     PARSE_OPT_STOP_AT_NON_OPTION);
	if (!argc)
		goto usage;

	read_replace_refs = 0;
	save_cummit_buffer = 0;

	if (!strcmp(argv[0], "verify"))
		return graph_verify(argc, argv);
	else if (argc && !strcmp(argv[0], "write"))
		return graph_write(argc, argv);

	error(_("unrecognized subcommand: %s"), argv[0]);
usage:
	usage_with_options(builtin_cummit_graph_usage,
			   builtin_cummit_graph_options);
}
