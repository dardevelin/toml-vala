VALAC = valac

VAPI = toml-vala.vapi
HEADER = toml-vala.h
LIBRARY = libtoml-vala.so
SOURCES = src/toml_parser.vala
PACKAGES = --pkg gee-0.8 --pkg json-glib-1.0 --pkg gio-2.0
C_FILE = src/toml_parser.c

all: $(VAPI) $(LIBRARY)

$(VAPI): $(SOURCES)
	$(VALAC) --library toml-vala --vapi $(VAPI) --header $(HEADER) --includedir=. $(PACKAGES) $(SOURCES)

$(C_FILE): $(SOURCES)
	$(VALAC) -C --includedir=. $(PACKAGES) $(SOURCES)

$(LIBRARY): $(C_FILE)
	gcc -shared -fPIC -o $(LIBRARY) $(C_FILE) `pkg-config --libs gee-0.8 json-glib-1.0 glib-2.0 gio-2.0`

clean:
	rm -f $(LIBRARY) $(VAPI) $(HEADER) $(C_FILE) *.o

.PHONY: all clean
