#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdint.h>
#include <errno.h>

struct subheader {
	uint32_t magic_number;
	char version[4];
	uint64_t index_offset;
	uint32_t index_length;
	uint32_t number_of_reads;
};

int main(int argc, char **argv)
{
	int in;
	int n;
	struct subheader buffer;
	

	if (argc != 3) {
		printf("usage: sfffixrn file number\n");
		printf("got %d args\n", argc);
		exit(1);
	}

	if ((in=open(argv[1], O_RDWR)) == -1) {
		printf("cannot open %s\n", argv[1]);
		exit(1);
	}
	/* read subheader */
	n=read(in, &buffer, sizeof(buffer));
	if (n != sizeof(buffer)) {
		printf("Cannot read subheader: got %d bytes\n", n);
		strerror(errno);
		exit(1);
	}
	printf("magic number:    %0xd\nversion:         %d%d%d%d\nindex offset:    %lld\nindex length:    %d\nnumber of reads: %d\n",
		be32toh(buffer.magic_number),
		buffer.version[0],buffer.version[1],buffer.version[2],buffer.version[3],
		be64toh(buffer.index_offset),
		be32toh(buffer.index_length),
		be32toh(buffer.number_of_reads));
	
	printf("\nSetting number_of_reads to %d\n", atoi(argv[2]));
	buffer.number_of_reads=htobe32(atoi(argv[2]));
	lseek(in, (off_t) 0, SEEK_SET);
	n=write(in, &buffer, sizeof(buffer));
	close(in);
}

            
