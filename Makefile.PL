# Makefile.PL
#
# $Id: Makefile.PL,v 1.3 2005/01/02 12:48:23 lolo Exp $

use 5.008004;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Palm::SMS',
    VERSION           => '0.01',
    EXE_FILES         => ['bin/smsdump'],
    NO_META           => 1, ## META.yml manually maintained
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Palm/SMS.pm', # retrieve abstract from module
       AUTHOR         => 'Lorenzo Cappelletti <lorenzo.cappelletti@email.it>')
     : ()),
);
