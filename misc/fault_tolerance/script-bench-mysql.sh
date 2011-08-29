#!/bin/bash

echo "Installer en premier les module assistant !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

#echo "Lancer les tests sur cette machine ? (y) or (n)"
ok="y"


#echo 'Is it the master machine ? (y) or (n)'
rep="y"

if [ "$rep" = "y" ]
then
	
	backup="genepi-32.grenoble.grid5000.fr"
elif [ "$rep" = "n" ]
then
	master="genepi-32.grenoble.grid5000.fr"
else
	echo 'erreur'
	exit 1
fi

eth="eth1"

#####-----Test sans DRBD

if [ "$ok" = y ]; then
	mkdir benchtest
        i=5000
        while [ $i -le 640000 ]; 
	do
                for j in $(seq 0 9)
		do
			sysbench --test=oltp --oltp-table-size=200000 --mysql-user=root prepare
			sysbench --test=oltp --num-threads=16 --max-requests=$i --mysql-user=root run > benchtest/max-requests-$i--iteration-$j
			sysbench --test=oltp --mysql-user=root cleanup
		done
                i=$((i*2)) 
	done 
fi


sleep 10



DRBD="drbd8-utils"
MODULEASSITANT="module-assistant"

BD="mysql"


####--Partionnement---#####
#Changer le /dev/loop/0
LOOPBACK=/dev/loop/0
#taille en MegaBytes
TAILLE="2000"


#---------------------------Initialisation--------------------------------------------------------------------#



#On remet la conf de mysql comme au debut
if [ -e /etc/mysql/my.cnf.backup ]; then
	cp /etc/mysql/my.cnf.backup /etc/mysql/my.cnf
fi


#-----------------------Installation on debian---------------------------------------------------
#apt-get update
#apt-get -y install $DRBD $MODULEASSITANT
#module-assistant auto-install drbd8

#-----------------------Arret des services---------------------------------------------------
if [ "$BD" = "mysql" ]; then
	/etc/init.d/$BD stop
elif [ "$BD" = "postgresql" ]; then
	/etc/init.d/$BD"-"$PGVERSION stop
else
	exit 1
fi


#attention, peut beuger si le systeme n'est pas en anglais
if [ "$rep" = "y" ]; then
	iplocal=$(ifconfig $eth | grep "inet "  | cut -d : -f2 | cut -d " " -f1)
	ipdist=$(resolveip $backup -s)

elif [ "$rep" = "n" ]; then
	iplocal=$(resolveip $master -s)
	ipdist=$(ifconfig $eth | grep "inet "  | cut -d : -f2 | cut -d " " -f1)

else
	exit 1
fi



#-----------------------Variable pour configuration de DRBD---------------------------------------------------
if [ "$BD" = "mysql" ]; then
	mysqldirold=$(cat /etc/$BD/my.cnf | grep datadir | cut -d "=" -f2)
elif [ "$BD" = "postgresql" ]; then
	postgresdirold=$(cat /etc/$BD/$PGVERSION/main/postgresql.conf | grep data_directory | cut -d "'" -f2)
else
	exit 1
fi

#-----------------------Configuration de DRBD---------------------------------------------------


echo 'global { usage-count no; }' > /etc/drbd.conf

echo 'resource mysql {' >> /etc/drbd.conf
echo '	# Trois protocoles sont disponibles :' >> /etc/drbd.conf
echo '	# En protocole A, l acquittement d ecriture (sur le maître)' >> /etc/drbd.conf
echo '	# est envoyé dès que les données ont été transmises au' >> /etc/drbd.conf
echo '	# sous volume physique et envoyé à l esclave.' >> /etc/drbd.conf
echo '	# En protocole B, l acquittement d ecriture (sur le maître)' >> /etc/drbd.conf
echo '	# est envoyé dès que les données ont été transmises au' >> /etc/drbd.conf
echo '	# sous volume physique et reçues par l esclave.' >> /etc/drbd.conf
echo '	# En protocole C, l acquittement d écriture (sur le maître)' >> /etc/drbd.conf
echo '	# est envoyé dès que les données ont été transmises au' >> /etc/drbd.conf
echo '	# sous volume physique ET au sous volume physique de' >> /etc/drbd.conf
echo '	# l esclave.' >> /etc/drbd.conf
echo '	protocol C;' >> /etc/drbd.conf

echo '	startup {' >> /etc/drbd.conf
echo '		# Au démarrage du noeud, on attend (cela bloque le' >> /etc/drbd.conf
echo '		# démarrage) le noeud distant pendant 2 minutes.' >> /etc/drbd.conf
echo '		wfc-timeout 120;' >> /etc/drbd.conf
echo '	}' >> /etc/drbd.conf

echo '	# Si une erreur d entrée sortie est rencontrée avec le sous' >> /etc/drbd.conf
echo '	# volume physique, on freeze la machine et' >> /etc/drbd.conf
echo '	# Heartbeat basculera l exploitation sur l autre machine' >> /etc/drbd.conf
echo '	disk {' >> /etc/drbd.conf
echo '		on-io-error detach;' >> /etc/drbd.conf
echo '	}' >> /etc/drbd.conf

echo '	syncer {' >> /etc/drbd.conf
echo '		rate 700000K;' >> /etc/drbd.conf
echo '		# On ne limite pas la vitesse de synchronisation.' >> /etc/drbd.conf
echo '		al-extents 257;' >> /etc/drbd.conf
echo '		# al-extent définit la taille de la « hot-area » : DRBD' >> /etc/drbd.conf
echo '		# stocke en permanence dans les meta-data les zones' >> /etc/drbd.conf
echo '		# actives du volume physique. En cas de crash ces zones' >> /etc/drbd.conf
echo '		# seront ainsi resynchronisées dès le retour du' >> /etc/drbd.conf
echo '		# noeud. Chaque extent définit une zone de 4Mo. Plus al-' >> /etc/drbd.conf
echo '		# extents est grand, plus la resynchronisation après un' >> /etc/drbd.conf
echo '		# crash sera longue, mais il y aura moins d écritures de' >> /etc/drbd.conf
echo '		# meta-data.' >> /etc/drbd.conf
echo '		# Avec 257 on a donc 1giga de « hot aera ».' >> /etc/drbd.conf
echo '	}' >> /etc/drbd.conf

if [ "$rep" = "y" ]; then
	master=$(uname -n)
elif [ "$rep" = "n" ]; then
	backup=$(uname -n)
else
	exit 1
fi

echo "	on $master {" >> /etc/drbd.conf
echo '		device /dev/drbd0;' >> /etc/drbd.conf
echo "		disk $LOOPBACK;" >> /etc/drbd.conf
echo "		address $iplocal:7788;" >> /etc/drbd.conf
echo '		meta-disk internal;' >> /etc/drbd.conf
echo '	}' >> /etc/drbd.conf


echo "	on $backup {" >> /etc/drbd.conf
echo '		device /dev/drbd0;' >> /etc/drbd.conf
echo "		disk $LOOPBACK;" >> /etc/drbd.conf
echo "		address $ipdist:7788;" >> /etc/drbd.conf
echo '		meta-disk internal;' >> /etc/drbd.conf
echo '	}' >> /etc/drbd.conf	

echo '}' >> /etc/drbd.conf		
	

#-----------------------Creation de la partition contenant les donnees BDD---------------------------------------------------



modprobe drbd

dd if=/dev/zero of=/image.img bs=1M count=$TAILLE
losetup $LOOPBACK /image.img
mkfs -t ext2 $LOOPBACK
shred -zvf -n 1 $LOOPBACK

if [ ! -e /dev/drbd0 ]; then
	mknod /dev/drbd0 b 147 0
fi

#Creation des metadata
drbdadm create-md all

drbdadm up all

if [ ! -e /mnt/drbddata ]; then
	mkdir /mnt/drbddata
fi

#a faire que sur le master
if [ "$rep" = "y" ]; then
	#Le master lance la synchro
	drbdadm -- --overwrite-data-of-peer primary all

	mkfs -t ext2 /dev/drbd0	
	mount /dev/drbd0 /mnt/drbddata
	
	if [ "$BD" = "mysql" ]; then
		cp -r $mysqldirold /mnt/drbddata
		chown -R mysql:mysql /mnt/drbddata/mysql
	elif [ "$BD" = "postgresql" ]; then
		cp -r $postgresdirold /mnt/drbddata
		chown -R postgres:postgres /mnt/drbddata/main
	else
		exit 1
	fi
	
fi


#-----------------------On change le repertoire dans la BDD---------------------------------------------------

if [ "$BD" = "mysql" ]; then
	mysqldiroldn=$(echo $mysqldirold | sed 's/\//\\\//g')
	#On fait une sauvegarde du fichier
	cp /etc/mysql/my.cnf /etc/mysql/my.cnf.backup
	sed -e "s/$mysqldiroldn/\/mnt\/drbddata\/mysql/g" /etc/mysql/my.cnf > /etc/mysql/my.cnf.tmp && mv -f /etc/mysql/my.cnf.tmp /etc/mysql/my.cnf 
elif [ "$BD" = "postgresql" ]; then
	postgresdiroldn=$(echo $postgresdirold | sed 's/\//\\\//g')
	#On fait une sauvegarde du fichier
	cp /etc/$BD/$PGVERSION/main/postgresql.conf /etc/$BD/$PGVERSION/main/postgresql.conf.backup
	sed -e "s/$postgresdiroldn/\/mnt\/drbddata\/main/g" /etc/$BD/$PGVERSION/main/postgresql.conf > /etc/$BD/$PGVERSION/main/postgresql.conf.tmp && mv -f /etc/$BD/$PGVERSION/main/postgresql.conf.tmp /etc/$BD/$PGVERSION/main/postgresql.conf
else
	exit 1
fi

if [ "$rep" = "y" ]; then
	/etc/init.d/mysql start
fi
sleep 300


#-----------------------TEST AVEC DRBD------#

if [ "$ok" = y ]; then
        i=5000
        while [ $i -le 640000 ]; 
	do
                for j in $(seq 0 9)
		do
			sysbench --test=oltp --oltp-table-size=200000 --mysql-user=root prepare
			sysbench --test=oltp --num-threads=16 --max-requests=$i --mysql-user=root run > benchtest/max-requests-$i--iteration-$j--DRBD
			sysbench --test=oltp --mysql-user=root cleanup
		done 
                i=$((i*2)) 
	done 
fi



#-----------------------Fin du script---------------------------------------------------

