# PHP extensions to enable by hand

The extensions that Arch compiles into the `php` package do not turn on by
themselves: the package ships the module but not the file that loads it.
Without an `extension=` line in `/etc/php/conf.d` they stay off, and a new
machine would install the whole php group and still end up without gd, intl,
pdo_pgsql and the rest.

The files for those extensions are in this directory.
`configure_php_extensions` in `setup-machine.sh` copies them to
`/etc/php/conf.d`, skipping the ones a package already ships: `imagick`,
`redis`, `yaml`, `igbinary`, `xdebug`, `ibm_db2` and `oci8` have their own
file in the package and must not be touched.

The names are written without `.so`: PHP adds it by itself, and the two forms
are equivalent.
