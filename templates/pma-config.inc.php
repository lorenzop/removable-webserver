<?php
// more at: https://docs.phpmyadmin.net/


/* YOU MUST FILL IN THIS FOR COOKIE AUTH! */
$cfg['blowfish_secret'] = 'klgnklfdsgklrngklgnklfdsgklrngsf';


$cfg['ThemeDefault'] = 'original';


$i = 0;


$i++;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['socket'] = '/mnt/ssd/work/build-temp/sockets/mysql.socket';
$cfg['Servers'][$i]['compress'] = false;
$cfg['Servers'][$i]['AllowNoPassword'] = true;


$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
$cfg['ShowAll'] = true;
// Possible values: 25, 50, 100, 250, 500
$cfg['MaxRows'] = 50;
$cfg['DefaultLang'] = 'en';


/**
 * Disallow editing of binary fields
 * valid values are:
 *   false    allow editing
 *   'blob'   allow editing except for BLOB fields
 *   'noblob' disallow editing except for BLOB fields
 *   'all'    disallow editing
 * default = 'blob'
 */
$cfg['ProtectBinary'] = false;


//$cfg['QueryHistoryDB'] = true;
//$cfg['QueryHistoryMax'] = 100;


$cfg['SendErrorReports'] = 'never';

