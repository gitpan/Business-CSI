END   { print "Business::CSI loaded ok :)\n" if $loaded;}

use Business::CSI qw/ :simple /;

$loaded = 1;
