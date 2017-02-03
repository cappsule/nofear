CFLAGS += -fPIC -Wall
LDFLAGS += -ldl

all: libmmap.so

libmmap.so: libmmap.o
	$(CC) -o $@ $^ $(LDFLAGS) -fPIC -shared

%.o: %.c
	$(CC) -o $@ -c $< $(CFLAGS)

clean:
	rm -f *.o *.so
