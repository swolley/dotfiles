# Estensioni PHP da abilitare a mano

Le estensioni che Arch compila dentro al pacchetto `php` non si accendono da
sole: il pacchetto spedisce il modulo ma non il file che lo carica. Senza una
riga `extension=` in `/etc/php/conf.d` restano spente, e una macchina nuova
installerebbe tutto il gruppo php ritrovandosi senza gd, intl, pdo_pgsql e il
resto.

Qui dentro ci sono quei file. `configure_php_extensions` in `setup-machine.sh`
li copia in `/etc/php/conf.d`, saltando quelli che un pacchetto porta gia' di
suo: `imagick`, `redis`, `yaml`, `igbinary`, `xdebug`, `ibm_db2` e `oci8` il
proprio file ce l'hanno nel pacchetto e non vanno toccati.

I nomi sono scritti senza `.so`: PHP lo aggiunge da se', e le due forme sono
equivalenti.
