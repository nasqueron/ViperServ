TCLSH=tclsh

all:
	@echo "Nothing to build."

test:
	cd tests && ${TCLSH} all.tcl
