use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'PubSub::Tiny',
    VERSION_FROM      => 'lib/PubSub/Tiny.pm', # finds $VERSION
    PREREQ_PM         => { Moo => 0}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/PubSub/Tiny.pm', # retrieve abstract from module
       AUTHOR         => 'Eskild Hustvedt <zerodogg@>') : ()),
);
