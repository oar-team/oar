
sources=$(wildcard man/man1/*.pod)
targets=$(patsubst %.pod,%.1,$(sources))

clean:
	rm -f $(targets)

build: $(targets)

%.1: %.pod
	pod2man --section=1 --release="$(notdir $(basename $<))" --center "OAR commands" --name="$(notdir $(basename $<))" "$<" > $@


