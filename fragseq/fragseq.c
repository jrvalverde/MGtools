#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <ctype.h>
#include <float.h>
#include <getopt.h>

/* Valid nucleotide codes as characters */
char *nt = "ATGCRYMKSWBDHVN";

void read_sequence(char *infile, char **seq, int *slen);
void fix_fragment(char *seq, int ssize, int nfrag, int fsize);
void rnd_fragment(char *seq, int ssize, int nfrag, int fsize);

void usage()
{
    printf("\nUsage: fragment -s #size -c #coverage -r -i sequence\n");
    printf("        -r ==> randomize (pos/mut/siz)\n\n");
    exit(1);
}

int main(int argc, char **argv)
{
    int opt;
    char *infile;
    int size, coverage, ssize, randomize, nfrag;
    char *seqname;
    char *seq;

    while ((opt = getopt(argc, argv, "s:c:ri:")) != -1) {
	switch (opt) {
	case 'i':
	    infile = optarg;
	    break;
	case 's':
	    size = atoi(optarg);
	    break;
	case 'c':
	    coverage = atoi(optarg);
	    break;
	case 'r':
	    randomize = 1;
	    break;
	case ':':
	default:
	    usage();
	    exit(1);
	    break;
	}
    }
    read_sequence(infile, &seq, &ssize);
    
    /* compute number of fragments we need */
    nfrag = ((ssize * coverage) / size);
    if (randomize) {
	rnd_fragment(seq, ssize, nfrag, size);
    } else {
	fix_fragment(seq, ssize, nfrag, size);
    }
    free(seq);
    exit(0);
    return 0;
}

/**
 * read input sequence from the specified file.
 *
 *	This function opens the specified input file and reads in
 * the sequence in FASTA format, allocating memory as needed to
 * hold it.
 *
 *	On exit, seq will contain a newly allocated array with the
 * sequence, and slen the sequence length.
 */
void read_sequence(char *infile, char **seq, int *slen)
{
    char *s;
    int sl, i, memsize;
    char line[BUFSIZ+1];
    FILE *in;
        
    if ((infile[0] == '-') && (infile[1] == '\0'))
      in = stdin;
    else
      if ((in = fopen(infile, "r")) == NULL)
          error("Could not open input file");

    do {
      s = fgets(line, BUFSIZ, in);
      if (s == NULL) error("No  FASTA sequences in input file");
    } while ((line[0] != '>') && (line[0] != ';'));

    /* we'll ignore sequence name for the time being */
    
    /* we are ready to read in the sequence */
    memsize = BUFSIZ;
    s = malloc(memsize+1 * sizeof(char));
    sl = 0; s[sl] = '\0';
    if (s == NULL) error("Not enough memory");
    
    while (fgets(line, BUFSIZ, in) != NULL) {
    	if (line[0] == ';')	/* comment line */
	    continue;
	if (line[0] == '>')	/* new sequence */
	    break;
	/* add line to sequence */
	for (i = 0; line[i] != '\0'; i++) {
	    if (index(nt, line[i]) != NULL) {
	      if (sl >= memsize) {
	          memsize += BUFSIZ;
		  if ((s = realloc(s, memsize+1 * sizeof(char))) == NULL)
		      error("Not enough memory");
	      }
	      s[sl++] = line[i];
	    }
	}
    }
    s[sl] = '\0';
    *seq = s;
    *slen = sl;
    if (in != stdin) fclose(in);
}

/*
 *  fragment a sequence in fixed-size, full quality pieces
 */
void fix_fragment(char *seq, int ssize, int nfrag, int fsize)
{
    float offset;
    float pos;
    int ipos, frgno, res;
    FILE *out;

    /* compute offset */
    offset = (float)(ssize - fsize) / (float)nfrag;
    
    if ((out = fopen("output.nt", "w+")) == NULL) {
    	printf("Error: could not open output file\n");
	exit(1);
    }
    
    pos = 0.0;
    for (frgno = 1; frgno <= nfrag; frgno++) {
    	/* write fragment header */
    	fprintf(out, ">S%09d length=%d region=1 run=01\n", frgno, fsize);
	ipos = floor(pos);
	pos += offset;
	/* write fragment */
	for (res = 0; res < fsize; res++) {
	    fprintf(out, "%c", seq[ipos+res]);
	    if (((res+1) % 60) == 0) fprintf(out, "\n");
	}
	fprintf(out, "\n");
    } 
    fclose(out);
}

void rnd_fragment(char *seq, int ssize, int nfrag, int fsize)
{
    fix_fragment(seq, ssize, nfrag, fsize);
}
