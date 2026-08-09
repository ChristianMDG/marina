SOURCES = my.ml prop.ml sat_ifexpr.ml marina.ml main.ml
EXEC = marina

CAMLC = ocamlc
CAMLDEP = ocamldep
CAMLDOC = ocamldoc

LIBS = str.cma
CUSTOM = -custom

all: depend $(EXEC)

OBJS = $(SOURCES:.ml=.cmo)

$(EXEC): $(OBJS)
	$(CAMLC) $(CUSTOM) -o $(EXEC) $(LIBS) $(OBJS)

# Serveur HTTP (module Unix stdlib uniquement, pas de dependance externe)
SERVER_EXEC = marina-server
SERVER_OBJS = my.cmo prop.cmo sat_ifexpr.cmo marina.cmo server.cmo
SERVER_LIBS = unix.cma str.cma

server: depend $(SERVER_EXEC)

$(SERVER_EXEC): $(SERVER_OBJS)
	$(CAMLC) $(CUSTOM) -o $(SERVER_EXEC) $(SERVER_LIBS) $(SERVER_OBJS)

.SUFFIXES: .ml .mli .cmo .cmi

%.cmo: %.ml
	$(CAMLC) -c $<

%.cmi: %.mli
	$(CAMLC) -c $<

doc: all
	mkdir -p doc
	rm -rf doc/*
	$(CAMLDOC) -d doc/ -html *.mli

clean:
	rm -f *.cm[io] *~ .*~ #*#
	rm -f $(EXEC) $(SERVER_EXEC)
	rm -rf doc
	rm .depend

test:
	ocamlfind ocamlc -package ounit2 -linkpkg -o test str.cma my.ml prop.ml sat_ifexpr.ml marina.ml test.ml
	./test

.depend: $(SOURCES)
	$(CAMLDEP) *.mli *.ml > .depend

depend: $(SOURCES)
	$(CAMLDEP) *.mli *.ml > .depend

include .depend