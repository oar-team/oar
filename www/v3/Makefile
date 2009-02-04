SITE = intra-id:/www-id/sites/oar/www/test
#SITE = intra-id:/www-id/sites/oar/www
#SITE = localhost:/tmp/test
INDEX = output/index.html

all: html

output/%.html: $(MANUALPAGE) 
	export LC_ALL=C;webgen run
	sed s/\<title\>Home/\<title\>OAR/ output/index.html > /tmp/index.html.tmp
	mv /tmp/index.html.tmp  output/index.html 
	cp -r ../../../trunk/Docs/schemas output/
	cp ../../../trunk/Docs/documentation/OAR-DOCUMENTATION-ADMIN.pdf output/admins/
	cp ../../../trunk/Docs/documentation/OAR-DOCUMENTATION-USER.pdf output/users/
	cd output/admins; ln -s ../images; cd -
	cd output/about; ln -s ../images; cd -
	cd output/works; ln -s ../images; cd -
	cd output/users; ln -s ../images; cd -
	
upload: all
	scp -r ../../../trunk/Docs/schemas $(SITE) #must be enhanced rsync png svg
	scp -r output/* $(SITE)
	touch upload

rsync: all
	rsync -avz --rsh="ssh" --exclude '*.svn*' --exclude '*.dia' \
	output/ ../../../trunk/Docs/schemas $(SITE)

#Thanks to Vince 
publish-online: all
	if [ $$(svn st |grep "^?" | wc -l) -ne 0 ]; then \
		echo "'svn status' shows that some files were not added, aborting." ; \
		exit 1 ; \
  fi
	rsync 

html: $(INDEX)

clean:
	\rm -rf output
