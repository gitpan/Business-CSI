# vim:set syntax=perl:

use strict;
use ExtUtils::MakeMaker;

my ($csi_lib, $csi_inc);

if ($ARGV[0] ne "skipme") { # I'll assume you're doing this by hand or something
    $csi_lib = `dirname \`locate libssl_client.a | head -1\``; chomp $csi_lib;
    $csi_inc = `dirname \`locate  ccapi_client.h | head -1\``; chomp $csi_inc;

    print STDERR "Where's your LinkPoint API library dir [$csi_lib]? "; my $l = <STDIN>; chomp $l;
    print STDERR "Where's your LinkPoint API include dir [$csi_inc]? "; my $i = <STDIN>; chomp $i;
    print STDERR << "EOF";

    Newer versions of the API require us to use doubles when we
    set up the totals.  Older versions require floats.  I really
    can't help ya here... closed source, and they type cast from
    a (void *) so the header is useless.

EOF
    print STDERR "Would you like to use floats or doubles [double]? "; my $d = <STDIN>; chomp $d;

    $csi_lib = ($l) ? $l : $csi_lib;
    $csi_inc = ($i) ? $i : $csi_inc;
    $d       = ($d) ? $d : "double";

    symlink "csi_process_card_simple.$d.c", "csi_process_card_simple.c" or die "$!";
    -d $csi_lib or die "couldn't find your $csi_lib dir";
    -d $csi_inc or die "couldn't find your $csi_inc dir";
}

WriteMakefile(
    'NAME'          => 'Business::CSI',
    'VERSION_FROM'  => 'CSI.pm',
    'PREREQ_PM'     => { "Time::HiRes", "Net::DNS", "Net::SMTP" },
    'LIBS'          => [''],
    'DEFINE'        => '',
    'INC'           => "-I$csi_inc -I .",
    'OBJECT'        => "csi_process_card_simple.o CSI.o $csi_lib/libssl_client.a",
    'clean'         => {FILES => "csi_process_card_simple.c"},
);
