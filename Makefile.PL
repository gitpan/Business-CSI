use ExtUtils::MakeMaker;

my $csi     = "/usr/local/csi";
my $csi_inc = "$csi/src";
my $csi_lib = "$csi/lib";

WriteMakefile(
    'NAME'          => 'Business::CSI',
    'VERSION_FROM'  => 'CSI.pm',
    'PREREQ_PM'     => { "Business::CreditCard", "Time::HiRes" },
    'LIBS'          => [''],
    'DEFINE'        => '',
    'INC'           => '-I/usr/local/csi/src -I .',
    'OBJECT'        => "csi_process_card_simple.o $csi_lib/libssl_client.a CSI.o"
);
