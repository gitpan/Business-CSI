END { print "Business::CSI loaded ok :)\n" if $loaded;}

use Business::CSI qw/ :simple /;

$loaded = 1;

require "../csi_test.pl" if -f "../csi_test.pl";
