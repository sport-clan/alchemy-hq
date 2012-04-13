OBJECTS = xquery-server.o

LIBS = -l zmq -l jsoncpp -l xqilla -l xerces-c

all: xquery-server

xquery-server: $(OBJECTS)
	g++ -o $@ $< $(LIBS)

%.o: %.cc
	g++ -c -o $@ $<

clean:
	rm -f xquery-server *.o
