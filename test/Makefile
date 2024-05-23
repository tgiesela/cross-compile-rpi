CC=aarch64-rpi-linux-gnu-gcc
GCC=aarch64-rpi-linux-gnu-gcc
CXX=aarch64-rpi-linux-gnu-gcc
CFLAGS=-v
CPPFLAGS=-v
CXXFLAGS=-lstdc++

#OBJECTS=c-hello cpp-hello
OBJDIR=obj
SRCDIR=src
ALLOBJECTS=c-hello cpp-hello
OBJECTS=$(addprefix $(OBJDIR)/,$(ALLOBJECTS))
all: $(OBJECTS)
	@echo 'Executing all'

clean:
	rm $(OBJDIR)/*

$(OBJDIR)/%: $(OBJDIR)/%.o 
	$(CXX) $(CFLAGS) $? -o $@ 
$(OBJDIR)/%: $(OBJDIR)/%.opp 
	$(CXX) $(CXXFLAGS) $? -o $@ 

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	$(CXX) $(CFLAGS) -c -o $@ $<
$(OBJDIR)/%.opp: $(SRCDIR)/%.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

#c-hello.o: c-hello.c
#	@echo '$@'=$@ ${OBJECTS}

#$c-hello: c-hello.c
#	@echo CC=${CC}
#	@echo CPP=${CPP}
#	@echo GCC=${GCC}
#	@echo CXX=${GCC}
#cpp-hello: cpp-hello.cpp
