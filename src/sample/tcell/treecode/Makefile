########################################################################
# Makefile
#   created by Ken Matsui <kmatsui@kuis.kyoto-u.ac.jp>
# 
# This Tascell program is implemented based on a Barnes-Hut simulation
# program called treecode created by Joshua E. Barnes. To refer to the
# original program, please visit here:
#   http://www.ifa.hawaii.edu/~barnes/treecode/treeguide.html
########################################################################

EXENAME = treecode

########################################################################
# Compiler options for Tascell framework:

OS       = ${shell uname}
SC2C     = sc2c
SC2C_OPT =
GCC      = gcc
XCC      = xcc
ICC      = icc
OPT      = -O2 -g $(MOPT)
XCCOPT   = -DCT=lightweight
XCCCLOPT = -DCT=closure

ifeq ($(OS),SunOS)
    SC2C_OPT += -D USE_AFFINITY=PBIND
else
    SC2C_OPT += -D USE_AFFINITY=SCHED
endif

ifeq ($(OS),SunOS)
    THROPTS=-lthread
else
    THROPTS=-lpthread
endif
LIBOPTS=$(THROPTS) -lm
ifeq ($(OS),SunOS)
    LIBOPTS += -lsocket -lnsl
endif

ifeq ($(OS),SunOS)
    OPT += -DNO_VASPRINTF
endif

########################################################################
# Compiler options for treecode:

# LINUX:
CCFLAGS = -D LINUX
LDFLAGS =            # Currently ignored
OPTFLAG = -O3        # Currently ignored

# Sun:
# CCFLAGS =
# LDFLAGS =
# OPTFLAG = -xO3

# SGI:
# CCFLAGS = -n32
# LDFLAGS = -n32
# OPTFLAG = -O3


# Precision.  Possible values are SINGLEPREC, MIXEDPREC, and DOUBLEPREC.

PREC = SINGLEPREC


# Variations:

# Uncomment the next line to report calculation result
# FORCEREPORT = -D FORCEREPORT=1

# Uncomment the next line to build treecode for distributed memory environemnts
# BROADCAST = -D BROADCAST=1

# Uncomment the next line to use locks for tree construction
# USELOCK = -D USELOCK=1

# Uncomment the next line to use freq instead of dtime:
# USEFREQ = -D USEFREQ=1

# Uncomment the next line to use binary I/O:
# BINARYIO = -D BINARYIO=1

# Uncomment the next line to make quick-scan treecode
# QUICKSCAN = -D QUICKSCAN=1

TREEFLAGS = -D $(PREC)=1 $(FORCEREPORT) $(BROADCAST) $(USELOCK) $(USEFREQ) \
            $(BINARYIO) $(QUICKSCAN)

########################################################################

.PHONY: all clean

# NFTYPE = one of these: gcc, lw, xcc, xcccl

ifndef NFTYPE
    NFTYPE = gcc
endif

ifeq ($(NFTYPE), lw)
    NFMACRO  = -D NF-TYPE=LW-SC
    C_LIBS += nestfunc.c
else
ifeq ($(NFTYPE), xcc)
    NFMACRO = -D NF-TYPE=XCC
else
ifeq (%(NFTYPE), xcccl)
    NFMACRO = -D NF-TYPE=XCCCL
else
    NFMACRO = -D NF-TYPE=GCC
endif
endif
endif

C_LIBS  = sendrecv.c sock.c
TREEOBJ = treecode.o treeio.o treeload.o treegrav.o libZeno.a
TCELL   = worker-$(NFTYPE).c cmd-serial-$(NFTYPE).c treecode-$(NFTYPE).c

all: $(TCELL) $(TREEOBJ)
	$(GCC) $(OPT) $(LIBOPTS) $(CCFLAGS) $(TREEFLAGS) $(C_LIBS) $(TCELL) \
	$(TREEOBJ) -o $(EXENAME)-$(NFTYPE)

########################################################################

worker-$(NFTYPE).c: worker.sc worker.sh
	$(SC2C) $(SC2C_OPT) $(NFMACRO) worker.sc

cmd-serial-$(NFTYPE).c: cmd-serial.sc worker.sh
	$(SC2C) $(SC2C_OPT) $(NFMACRO) cmd-serial.sc

treecode-$(NFTYPE).c: treecode.tcell treeload.tcell treegrav-shared.tcell treegrav-distributed.tcell treecomm.tcell
	$(SC2C) $(SC2C_OPT) $(NFMACRO) $(TREEFLAGS) treecode.tcell

########################################################################
# Vanila treecode:

treecode.o: treecode.c treecode.h treedefs.h
	$(GCC) $(CCFLAGS) $(TREEFLAGS) -c treecode.c

treeio.o: treeio.c treecode.h treedefs.h
	$(GCC) $(CCFLAGS) $(TREEFLAGS) -c treeio.c

ifdef BROADCAST
    ENV_SUFFIX=distributed
else
    ENV_SUFFIX=shared
endif

treeload.o: treeload-$(ENV_SUFFIX).c treedefs.h
	$(GCC) $(CCFLAGS) -O2 $(TREEFLAGS) -o treeload.o -c treeload-$(ENV_SUFFIX).c

treegrav.o: treegrav.c treedefs.h
	$(GCC) $(CCFLAGS) -O3 $(TREEFLAGS) -o treegrav.o -c treegrav.c

########################################################################
# Zeno library:

libZeno.a: clib.o getparam.o mathfns.o
	ar ruv libZeno.a clib.o getparam.o mathfns.o

clib.o: clib.c stdinc.h
	$(GCC) $(CCFLAGS) -D$(PREC) -c clib.c

getparam.o: getparam.c stdinc.h getparam.h
	$(GCC) $(CCFLAGS) -D$(PREC) -c getparam.c

mathfns.o: mathfns.c stdinc.h mathfns.h
	$(GCC) $(CCFLAGS) -D$(PREC) -c mathfns.c

########################################################################

clean:
	rm -f *.o libZeno.a treecode-*.c worker-*.c cmd-serial-*.c $(EXENAME)-*

