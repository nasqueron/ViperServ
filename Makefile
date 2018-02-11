TCLSH=tclsh8.6

all:
	@echo "Nothing to build."

test:
	cd tests && ${TCLSH} all.tcl

list:
	@ls *.tcl | sed 's/^/      - /' | sort
	@find . -type f -name '*.tcl' | grep -v tests/ | grep -v Maintenance/ \
	| grep -v ForUsers/ | grep -v PreSurfBoard | sed 's@\./@      - @' \
	| grep '/' | sort
