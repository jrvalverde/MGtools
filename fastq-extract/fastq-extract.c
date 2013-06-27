/*
 *  fastq-extract
 *
 *  	Identify all reads from a fastq file that match an extended 
 *  	regular expression pattern within their sequence and remove
 *  	the sequence and corresponding quality codes up to and including
 *  	the pattern before printing said matching read to standard output.
 *
 *  	Usage:	fastq-extract -p pattern -a -d < IN.fastq > OUT.fastq
 *
 *  	pattern is an extended regular expression, which makes it easy
 *  	to specify combinations of barcodes and primers
 *
 *  	Intended use is to identify barcode/primer combinations and
 *  	select only those reads containing adequate combinations to
 *  	extract the actual sequence (without barcode/primer).
 *
 *  	Using regexp for this purpose is very easy: each group of
 *  	items to be matched is enclosed in parentheses (), and
 *  	groups can be combined with | (or), or just concatenated.
 *
 *  	For instance: if you want to identify reads which have been
 *  	labelled with barcodes ATG or GCA, to amplify a sequence with
 *  	primer ATGCATGC, the process would be:
 *  	    1. barcode ATG is composed by A, T and G. So we concatenate
 *  	    	them: ATG
 *
 *  	    2. barcode GCA is composed by the series G, C and A. So we
 *  	    	concatenate them: GCA
 *
 *  	    3. To check for any of those two barcodes, we need to combine 
 *  	    	them with | (or): to avoid ambiguities, we first group
 *  	    	each barcode with parentheses: (ATG), (GCA) and then
 *  	    	combine them: (ATG)|(GCA) means match either barcode ATG
 *  	    	or barcode GCA. If we didn't use the parenthesis, we
 *  	    	would have ATG|GCA, which can be interpreted as match
 *  	    	AT[G or C]CA, and which is not what we want.
 *
 *  	    4. To require that any of these barcodes be followed immediately
 *  	    	by the primer ATGCATGC, we simply concatenate them. Again,
 *  	    	it is better if we group each tag: first the two alternative
 *  	    	are grouped using parentheses: ((ATG)|(GCA)), then we enclose
 *  	    	in parentheses the primer (ATGCATGC) and finally we 
 *  	    	concatenate them: ((ATG)|(GCA))(ATGCATGC)
 *
 *  	    5. We could anchor the pattern to be at the beginning of the
 *  	    	sequence by prepending it with "^" (meaning begininng of line)
 *  	    	as ^((ATG)|(GCA))(ATGCATGC)
 *
 *  	    6. Illumina reads have for some reason a high error rate in the
 *  	    	first position, which is sometimes removed. We could add a
 *  	    	"?" after the first residue of each barcode (meaning match
 *  	    	it zero or one times), or use .? instead (meaning zero or
 *  	    	one of any residue to allow for full ambiguity in the first
 *  	    	position which might also be absent).
 *
 *  (C) Jose R Valverde, EMBnet/CNB, CSIC, 2012
 *
 *  Released under EUPL (http://www.osor.eu/eupl).
 *
 * Licensed under the EUPL, Version 1.1 or - as soon they
 * will be approved by the European Commission - subsequent
 * versions of the EUPL (the "Licence").
 *
 * You may not use this work except in compliance with the
 * Licence.
 *
 * You may obtain a copy of the Licence at:
 *
 *  	    http://ec.europa.eu/idabc/eupl5
 *
 * Unless required by applicable law or agreed to in
 * writing, software distributed under the Licence is
 * distributed on an "AS IS" basis,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied.
 *
 * See the Licence for the specific language governing
 * permissions and limitations under the Licence.
 *
 *  $Id: fastq-extract.c,v 1.9 2012/08/01 15:05:11 jr Exp $
 *
 *  $Log: fastq-extract.c,v $
 *  Revision 1.9  2012/08/01 15:05:11  jr
 *  Fixed typo [jr]
 *
 *  Revision 1.8  2012/08/01 15:03:16  jr
 *  Added command line options [j]
 *
 *  Revision 1.7  2012/08/01 13:18:36  jr
 *  Use extended regular expressions [jr]
 *
 *  Revision 1.6  2012/08/01 12:47:37  jr
 *  Changed to only output matching reads [jr]
 *
 *  Revision 1.5  2012/08/01 12:27:26  jr
 *  Expanded info on EUPL license [jr]
 *
 *  Revision 1.4  2012/08/01 11:18:09  jr
 *  Corrected to accept SRA fastq with description repeated in '+' line [jr]
 *
 *  Revision 1.3  2012/08/01 11:10:55  jr
 *  Added tags. [jr]
 *
 *  Revision 1.2  2012/08/01 11:10:11  jr
 *  Initial version [jr]
 *
 *  Revision 1.1  2012/08/01 09:58:37  jr
 *  Initial revision

 *
 */

#include <sys/types.h>
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define GNU_SOURCE
#include <getopt.h>


#define MAXLINE	8192
/* I know, it's ugly, and I should use dynamic memory allocation. */
/* And I will eventually do... */

typedef struct {
    char id[MAXLINE];		/* ID line */
    char sq[MAXLINE];		/* Sequence */
    char pl[MAXLINE];		/* + */
    char qc[MAXLINE];		/* Quality */
} read_t;

/*
 *	getread
 *		get a read from the specified input file
 *	return
 *		read
 *		-1	EOF
 *		 0	LOST SYNC (no read read)
 *		 1	OK (1 read read)
 */
int getread(FILE * file, read_t * read)
{
    char *line;

    /* seek to first line starting with an '@' */
    do {
	line = fgets(read->id, MAXLINE, file);
	if (line == NULL)
	    return -1;
    } while (line[0] != '@');

    /*
     * That line might come from a quality line, so we need
     * to ensure we use the last line with an '@' and that
     * the next after is used for the sequence
     */
    do {
	line = fgets(read->sq, MAXLINE, file);
	if (line == NULL)
	    return -1;
	if (line[0] == '@')
	    strncpy(read->id, line, MAXLINE);
    } while (line[0] == '@');
    /* if (!isseq(line)) return 0; */

    /* Now get the '+' line */
    line = fgets(read->pl, MAXLINE, file);
    if (line == NULL)
	return -1;
    /* SRA includes the description again in the + line!
    if ((line[0] != '+') && (line[1] != '\n')) */
    if (line[0] != '+')
	return 0;

    /* finally get the quality line */
    line = fgets(read->qc, MAXLINE, file);
    if (line == NULL)
	return -1;
    return 1;
}

void usage(char *name)
{
    fprintf(stderr, "\n\tUsage: %s -p pattern -a -d < IN.fastq > OUT.fastq\n\n",
	    name);
    fprintf(stderr,
	    "\tPattern example: \"^((ATG)|(GCT))(ATGCATGCATGCATGC)\"\n\
	    Would pick sequences beginning ^ with barcodes (ATG) or (GCT)\n\
	    followed by primer (ATGCATGCATGCATGC)\n\n");
    fprintf(stderr, "See man page for more details\n\n");
}

int main(int argc, char **argv)
{
    regex_t preg;
    char *string = "";
    char *pattern = "";
    int rc;
    size_t nmatch = 2;
    regmatch_t pmatch[2];
    read_t read;
    int i, pos, delete, all;

    static struct option opts[] = {
    	{"pattern", 1, NULL, 'p'},
	{"delete", 0, NULL, 'd'},
	{"all", 0, NULL, 'a'},
	{"help", 0, NULL, 'h'},
	{NULL, 0, NULL, 0}
    };
    delete = all = i = 0;
    do {
    	i = getopt_long(argc, argv, "p:dah", opts, NULL);
	switch (i) {
	case 'p':
	    pattern = optarg;
	    break;
	case 'd':
	    delete = 1;
	    break;
	case 'a':
	    all = 1;
	    break;
	case 'h':
	    usage(argv[0]);
	    break;
	case '?':
	    usage(argv[0]);
	    return -1;
	    break;
	default:
	    break;
	}
    } while (i != -1);

    if (pattern == NULL) { 
    	usage(argv[0]); 
	return -1; 
    }
    fprintf(stderr, "%s -p %s -d %d -a %d\n", argv[0], pattern, delete, all); 

    /* Compile pattern */
    /* use extended regular expressions and ignore case */
    /* case should always be upper, but just 'in case'... :-) */
    if (0 != (rc = regcomp(&preg, pattern, REG_EXTENDED|REG_ICASE))) {
	printf("regcomp() failed, returning nonzero (%d)\n", rc);
	exit(EXIT_FAILURE);
    }

    /* process standard input */
    do {
    	i = getread(stdin, &read);
	if (i == 0) {
	    fprintf(stderr, "LOST SYNC: check input for validity\n");
	    continue;
	}
	if (i == 1) {
    	    string = read.sq;
	    /* we got one read, test it for presence of the pattern in the sequence */
	    if ((rc = regexec(&preg, string, nmatch, pmatch, 0)) == 0) {
	    	/* this read matches the pattern */
		if (delete == 1) 
		    pos = pmatch[0].rm_eo;
		else
		    pos = 0;
	    	fprintf(stdout, "%s%s%s%s", read.id, &read.sq[pos], read.pl, &read.qc[pos]);
	    } else {
	    	pos = 0;
    	    	if (all == 1)
		    fprintf(stdout, "%s%s%s%s", read.id, &read.sq[pos], read.pl, &read.qc[pos]);
    	    }
	}
    } while (i != -1);	    /* until EOF */

    regfree(&preg);
    return 0;

}
