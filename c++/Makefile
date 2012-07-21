OBJECTS = xquery-server.o

LIBS = -l jsoncpp -l xqilla -l xerces-c

all: xquery-server

xquery-server: $(OBJECTS)
	g++ -o $@ $< $(LIBS) -g

%.o: %.cc
	g++ -c -o $@ $< -g

clean:
	rm -f xquery-server *.o
