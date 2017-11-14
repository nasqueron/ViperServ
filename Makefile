TCLSH=tclsh8.6

all:
	@echo "Nothing to build."

test:
	cd tests && ${TCLSH} all.tcl
