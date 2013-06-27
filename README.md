MGtools
=======

Metagenomics tools

This is a set of tools being developed, tested and used at CNB/CSIC by the
Scientific Computing Service. The main goal in developing them was to
provide support for metagenomics tasks, but some of the tools (e. g.
psplit) are generic tools that can be applied in general-purpose problems.

Organization:

	- psplit	A variant of split(1) that allows for selection
		of "records" based on a regex line. This is different
		from csplit(1) in that counts in csplit(1) are taken in
		terms of actual lines before or after a regex match,
		while in psplit, counts are taken in terms of regex
		matches. This is a general-purpose tool

	- nblastall	A parallel wrapper for NCBI blastall. It does
		trivial parallelism but can speed up searches almost
		linearly on the number of used CPUs.

	- scripts	A series of scripts in bash, perl and python to
		carry out many metagenomics tasks, automate workflows or
		parts of workflows, generate mock datasets and analyse
		output from other programs.

	- extras	Small utilities to carry out various common
		tasks when dealing with sequences and identifiers.

