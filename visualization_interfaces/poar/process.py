#!/usr/bin/python
import os,sys,re;
from mod_python import apache
from mod_python import Session
def sub(req,lorder='',Node='',Cpu='',lpath='',Sorder='',Spath='',qorder='',tpe='',porder='',snumber='',rorder='',Date='',Hours='',Minutes='',Seconds='',torder='',ttype='',dorder='',dpath='',norder='',nname='',aorder='',ajid='',anmethod='',arsubmit='',korder='',iorder='',kfile='',kjkey='',eorder='',ejfile='',Oorder='',Ofile=''):
	Command='oarsub '
	lcommand=''
	Scommand=''
	qcommand=''
	pcommand=''
	rcommand=''
	tcommand=''
	dcommand=''
	ncommand=''
	acommand=''
	kcommand=''
	icommand=''
	ecommand=''
	Ocommand=''
	order={}
	if (lorder!=''):
		lcommand='-l '
		if(Node!=''):
			lcommand+="/node="+Node+" "
		if (Cpu!=''):
			lcommand+="/cpu="+Cpu+" "
		lcommand+=lpath+" "
		order[int(lorder)]=lcommand

	if(Sorder!=''):
		Scommand='-S ' 
		Scommand+=Spath+" "
		order[int(Sorder)]=Scommand


	if(qorder!=''):
		qcommand='-q '
		qcommand+=tpe+" "
		order[int(qorder)]=qcommand

	if(porder!=''):
		pcommand='-p '
		pcommand+=snumber+" "
		order[int(porder)]=pcommand


	if(rorder!=''):
		f=open("/var/www/new_poar1/b.txt",'a')	
		f.write('\n')
		f.write("in "+rorder)
		f.close()
		rcommand='-r '
		d=Date.split('/')
		t=d[2]+":"+d[1]+":"+d[0]
		rcommand+=t+" "+Hours+":"+Minutes+":"+Seconds
		rcommand=' " '+rcommand+' " '
		order[int(rorder)]=rcommand

	if(torder!=''):
		tcommand='-t '
		tcommand+=ttype+" "
		order[int(torder)]=tcommand

	if(dorder!=''):
		dcommand='-d '
		dcommand+=dpath+" "
		order[int(dorder)]=dcommand

	if(norder!=''):
		ncommand='-n '
		ncommand+=nname+" "
		order[int(norder)]=ncommand

	if(aorder!=''):
		acommand='-a '
		if(ajid!=''):
			acommand+=" --anterior "+ajid+" "
		if(anmethod!=''):
			acommand+=" --notify "+'" '+anmethod+' " '
		if(arsubmit!=''):
			acommand+=" --resubmit "+ arsubmit+" "

		order[int(aorder)]=acommand

	if(korder!=''):
		kcommand='-k '
		order[int(korder)]=kcommand

	if(iorder!=''):
		icommand='-i '
		if(kfile!=''):
			icommand+=" --import-job-key-from-file "+kfile+" "
		if(kjkey!=''):
			icommand+=" --import-job-key-inline "+kjkey+" "
		order[int(iorder)]=icommand

	if(eorder!=''):
		ecommand='-e '
		ecommand+=ejfile+" "
		order[int(eorder)]=ecommand

	if(Oorder!=''):
		Ocommand='-O '
		Ocommand+=Ofile+" "
		order[int(Oorder)]=Ocommand

	for i in order.keys():
		Command+=order[i]
	os.system(Command)
