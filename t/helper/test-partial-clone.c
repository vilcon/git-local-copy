#include "cache.h"
#include "test-tool.h"
#include "repository.h"
#include "object-store.h"

/*
 * Prints the size of the object corresponding to the given hash in a specific
 * butdir. This is similar to "but -C butdir cat-file -s", except that this
 * exercises the code that accesses the object of an arbitrary repository that
 * is not the_repository. ("but -C butdir" makes it so that the_repository is
 * the one in butdir.)
 */
static void object_info(const char *butdir, const char *oid_hex)
{
	struct repository r;
	struct object_id oid;
	unsigned long size;
	struct object_info oi = {.sizep = &size};
	const char *p;

	if (repo_init(&r, butdir, NULL))
		die("could not init repo");
	if (parse_oid_hex(oid_hex, &oid, &p))
		die("could not parse oid");
	if (oid_object_info_extended(&r, &oid, &oi, 0))
		die("could not obtain object info");
	printf("%d\n", (int) size);
}

int cmd__partial_clone(int argc, const char **argv)
{
	setup_but_directory();

	if (argc < 4)
		die("too few arguments");

	if (!strcmp(argv[1], "object-info"))
		object_info(argv[2], argv[3]);
	else
		die("invalid argument '%s'", argv[1]);

	return 0;
}
