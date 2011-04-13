
clean:
	@cd man/man1/ && for i in `ls *.pod`; do rm -f `basename $$i .pod`.1; done

build:
	@cd man/man1/ && for i in `ls *.pod | sed -ne 's/.pod//p'`; do pod2man --section=1 --release=$$1 --center "OAR commands" --name $$i "$$i.pod" > $$i.1 ; done

