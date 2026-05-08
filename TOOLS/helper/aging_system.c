#define _GNU_SOURCE
#include "stdio.h"
#include <unistd.h>
#include "stdlib.h"
#include "fcntl.h"
#include <stdint.h>
#include "string.h"
#include "mt19937ar.h"
#include <errno.h>
#include <sys/time.h>

#define IF_ERR_EXIT(err, msg)  \
	if (err < 0) {				\
		perror(msg);		\
		exit(1);			\
	}

extern char *optarg;

void usage()
{
	printf("Aging the system written by deadpool\n");
	printf("Description: write a file in specific size\n");
	printf("             punch several holes in the file randomly\n");
	printf("             write another file to fill the holes\n");
	printf("-d dir  <dirname>\n");
	printf("-s size <GiB>\n");
	printf("-b block size <bytes>\n");
	printf("-o hole <Percentage(e.g. 50, 60)>\n");
	printf("-p phase <1. Create 2. Punching 3. Re-Create 4. All>\n");
	printf("Example: ./aging_system -d /mnt/dir -s 50 -b 4096 -o 50 -p 4\n");
}

#define MAGIC_RAND 2333
#define PAGE_SIZE 4096

static inline void fill_page(char *page, uint64_t v)
{
	uint64_t *buf = (uint64_t *)page;
	uint64_t *limit = (uint64_t *)(page + PAGE_SIZE);
	while (buf != limit) {
		*buf = v;
		buf += 1;
	}
}

double get_ms_diff(struct timeval tvBegin, struct timeval tvEnd)
{
	return 1000 * (tvEnd.tv_sec - tvBegin.tv_sec) + ((tvEnd.tv_usec - tvBegin.tv_usec) / 1000.0);
}

int main(int argc, char **argv)
{
	char *optstring = "d:s:b:o:p:h";
	int opt;
	unsigned long size;
	int hole_percent, phase;
	int fd;
	unsigned long hole_num, fill_num;
	unsigned long pos;
	unsigned long total_4K_blks = 0;
	unsigned long block_size = 0;
	int dirlen = 0;
	char filepath[128] = {0};
	char *buf;
	char *records;
	struct timeval start, end;
	double diff;

	while ((opt = getopt(argc, argv, optstring)) != -1) {
		switch(opt) {
		case 'd':
			dirlen = strlen(optarg);
			if (dirlen > 1 && optarg[dirlen - 1] == '/') {
				dirlen -= 1;
			}
			strcpy(filepath, optarg);
			break;
		case 's':
			size = atol(optarg);
			break;
		case 'o':
			hole_percent = atoi(optarg);
			break;
		case 'p':
			phase = atoi(optarg);
			break;
		case 'b':
			block_size = atol(optarg);
			break;
		case 'h':
			usage();
			exit(1);
		default:
			printf("Bad usage!\n");
			usage();
			exit(1);
		}
	}

	if (block_size == 0) {
		block_size = 2 * 1024 * 1024;
	}

	buf = (char *)malloc(block_size);

	size *= 1024 * 1024 * 1024;
	total_4K_blks = size / PAGE_SIZE;

	init_genrand(MAGIC_RAND + phase);

	if (phase == 1 || phase == 4) {
		unsigned long v = 1 * total_4K_blks;
		strcpy(filepath + dirlen, "/file1");
		fd = open(filepath, O_RDWR | O_CREAT | O_TRUNC, 0644);
		if (fd < 0) {
			printf("Create file %s error: %s\n", filepath, strerror(errno));
			exit(1);
		}

		printf("Phase 1: Filling file %s with %lu %ldK blocks...\n",
			filepath, size / block_size, block_size / 1024);
		gettimeofday(&start, NULL);
		for (size_t i = 0; i < size / block_size; i++) {
			for (size_t j = 0; j < block_size; j += PAGE_SIZE) {
				fill_page(buf + j, v);
				v += 1;
			}
			int ret = write(fd, buf, block_size);
			IF_ERR_EXIT(ret, "write");
			if ((unsigned long)ret != block_size) {
				printf("Write failed with return code %d\n", ret);
				return 1;
			}
		}
		fsync(fd);
		gettimeofday(&end, NULL);
		diff = get_ms_diff(start, end);
		printf("NewlyWriteTime: %.6f ms\n", diff);
		close(fd);
	}

	if (phase == 2 || phase == 4) {
		strcpy(filepath + dirlen, "/file1");
		fd = open(filepath, O_RDWR);
		if (fd < 0) {
			printf("Open file %s error: %s\n", filepath, strerror(errno));
			exit(1);
		}

		hole_num = total_4K_blks * hole_percent / 100;
		printf("Phase 2: Punching %lu 4K hole in %s randomly...\n", hole_num, filepath);
		records = (char *)calloc(total_4K_blks, sizeof(char));
		gettimeofday(&start, NULL);
		while (hole_num) {
			pos = (genrand_int32() % total_4K_blks);
			if (records[pos] == 0) {
				records[pos] = 1;
				if (fallocate(fd, FALLOC_FL_PUNCH_HOLE | FALLOC_FL_KEEP_SIZE, pos * 4096, 4096) < 0) {
					perror("could not deallocate");
				}

				hole_num--;
			}
		}
		fsync(fd);
		gettimeofday(&end, NULL);
		diff = get_ms_diff(start, end);
		printf("PunchingTime: %.2f ms\n", diff);
		free(records);
		close(fd);
	}

	if (phase == 3 || phase == 4) {
		unsigned long v = 3 * total_4K_blks;
		strcpy(filepath + dirlen, "/file2");
		fill_num = size / block_size * hole_percent / 100;
		printf("Phase 3: Filling holes by %s with %lu %ldK blocks...\n",
			filepath, fill_num, block_size / 1024);
		fd = open(filepath, O_RDWR | O_CREAT | O_TRUNC, 0644);
		if (fd < 0) {
			printf("Create file %s error: %s\n", filepath, strerror(errno));
			exit(1);
		}
		gettimeofday(&start, NULL);
		for (size_t i = 0; i < fill_num; ++i) {
			for (size_t j = 0; j < block_size; j += PAGE_SIZE) {
				fill_page(buf + j, v);
				v += 1;
			}
			int ret = write(fd, buf, block_size);
			IF_ERR_EXIT(ret, "write");
			if ((unsigned long)ret != block_size) {
				printf("Write failed with return code %d\n", ret);
				return 1;
			}
		}
		fsync(fd);
		gettimeofday(&end, NULL);
		diff = get_ms_diff(start, end);
		printf("AgingWriteTime: %.6f ms\n", diff);
		close(fd);
	}

	free(buf);

	return 0;
}
