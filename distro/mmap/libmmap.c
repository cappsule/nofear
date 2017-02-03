/*
 * The version of Xpra shipped in Ubuntu 16.10 is outdated and the name of the
 * shared memory file can't be specified with --mmap option.
 *
 * This shared library is a dirty workaround.
 */

#define _GNU_SOURCE
#include <err.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>

static typeof(open) *real_open64;
static typeof(__xstat64) *real___xstat64;

static char *host_mmap_file_path;
static char *guest_mmap_file_path;

static int is_mmap_tmp_file(const char *path)
{
	char *p;

	p = strstr(path, "xpra.");
	if (p == NULL)
		return 0;

	if (strstr(p, ".mmap") == NULL)
		return 0;

	return 1;
}

/*
 * From xpra/net/mmap_pipe.py:
 *
 *   #create the mmap file, the mkstemp that is called via NamedTemporaryFile ensures
 *   #that the file is readable and writable only by the creating user ID
 *   temp = tempfile.NamedTemporaryFile(prefix="xpra.", suffix=".mmap", dir=mmap_dir)
 *
 * Hook open64() to control the path of the shared memory file.
 */
int open64(const char *path, int flags, ...)
{
	mode_t mode;
	va_list ap;

	va_start(ap, flags);
	mode = va_arg(ap, mode_t);
	va_end(ap);

	if (host_mmap_file_path != NULL && is_mmap_tmp_file(path)) {
		path = host_mmap_file_path;
		flags &= ~O_EXCL;
	}

	return real_open64(path, flags, mode);
}

/*
 * From xpra/server/source.py:
 *
 *   mmap_filename = c.strget("mmap_file")
 *   mmap_token = c.intget("mmap_token")
 *   log("client supplied mmap_file=%s, mmap supported=%s, token=%s", mmap_filename, self.supports_mmap, mmap_token)
 *   if mmap_filename:
 *     if not self.supports_mmap:
 *       log.warn("client supplied an mmap_file: %s but mmap mode is not supported", mmap_filename)
 *     elif not os.path.exists(mmap_filename):
 *       log.warn("client supplied an mmap_file: %s but we cannot find it", mmap_filename)
 */
int __xstat64(int ver, const char *path, struct stat64 *stat_buf)
{
	if (guest_mmap_file_path != NULL && is_mmap_tmp_file(path)) {
		if (symlink(guest_mmap_file_path, path) != 0)
			warn("symlink failed");
	}

	return real___xstat64(ver, path, stat_buf);
}

static int get_env_helper(const char *name, char **out)
{
	const char *p;

	p = getenv(name);
	if (p == NULL)
		return 0;

	*out= strdup(p);
	if (*out == NULL) {
		warn("libmmap: strdup failed");
		return -1;
	}

	return 0;
}

static int __attribute__ ((constructor)) initfunc(void)
{
	if (unsetenv("LD_PRELOAD") == -1)
		warn("unsetenv(\"LD_PRELOAD\")");

	if (get_env_helper("HOST_MMAP_FILE_PATH", &host_mmap_file_path) != 0)
		return 0;

	if (get_env_helper("GUEST_MMAP_FILE_PATH", &guest_mmap_file_path) != 0)
		return 0;

	real_open64 = dlsym(RTLD_NEXT, "open64");
	if (real_open64 == NULL) {
		warn("libmmap: missing function");
		return 0;
	}

	real___xstat64 = dlsym(RTLD_NEXT, "__xstat64");
	if (real___xstat64 == NULL) {
		warn("libmmap: missing function");
		return 0;
	}

	return 0;
}
