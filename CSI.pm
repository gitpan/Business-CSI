package Business::CSI;

require 5.005_62;
use strict;
use warnings;
use Carp;

require Exporter;
require DynaLoader;
use AutoLoader;

use Time::HiRes qw/ time /;

our @ISA         = qw(Exporter DynaLoader);
our %EXPORT_TAGS = ( 'all' => [ qw( ) ], 'simple' => [ qw( simple_transaction add_settings ) ] ); 
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} }, @{ $EXPORT_TAGS{'simple'} } );
our @EXPORT      = qw( );
our $VERSION     = '0.26';

sub AUTOLOAD {
    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "& not defined" if $constname eq 'constant';
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
	if ($! =~ /Invalid/ || $!{EINVAL}) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
	    croak "Your vendor has not defined Business::CSI macro $constname";
	}
    }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
	if ($] >= 5.00561) {
	    *$AUTOLOAD = sub () { $val };
	}
	else {
	    *$AUTOLOAD = sub { $val };
	}
    }
    goto &$AUTOLOAD;
}

bootstrap Business::CSI $VERSION;

my %acceptable = (
    csi_config   => 1, csi_key      => 1, csi_host     => 1, csi_port     => 1, cust_id      => 1,
    order_id     => 1, name_on_card => 1, email_addy   => 1, card_number  => 1, card_expr_m  => 1,
    card_expr_y  => 1, sub_total    => 1, tax_total    => 1, ship_total   => 1, grand_total  => 1, real         => 1,
);

my %settings = (  # the defaults
    'csi_host'     => 'secure.linkpt.net',
    'csi_port'     => '1139',
    'cust_id'      => 'imcertainihavenoidea',
    'order_id'     => ('order' . '.'. time . '.' . $$),
    'email_addy'   => 'unknown@aol.com',
    'real'         => 0,

    'ship_total'   => 0,
    'sub_total'    => 0,
    'tax_total'    => 0,
);

return 1;

sub clear_settings {
    foreach my $k (@_) {
        delete $settings{$k};
    }
}

sub add_settings {
    my $set = shift;
    my $ref = ref($set);

    my (undef, $f, $l) = caller;

    if($ref eq 'HASH') {
        foreach my $k (keys %{ $set }) {
            if($acceptable{$k}) {
                $settings{$k} = $set->{$k};
            } else {
                die "unrecognized option used in $f at line $l.\nThis was generated";
            }
        }
        return;
    }

    die "You must pass hashes (not $ref) to the function used in $f at line $l.\nThis was generated";
}

sub simple_transaction {
    &add_settings(@_) if @_ > 0;

    my $die = 0;
    foreach(sort keys %acceptable) {
        if(not defined $settings{$_}) {
            print STDERR "You need to set the $_.\n";
            $die = 1;
        }
    }
    if($die) {
        my (undef, $f, $l) = caller;
        die "simple_transaction was obviously called early in $f at line $l.\nThis was generated";
    }

    $settings{sub_total} = ($settings{sub_total} ? $settings{sub_total} : $settings{grand_total});

    my $result = &csi_process_card_simple( 
        $settings{csi_config},  $settings{csi_key},     $settings{csi_host},     $settings{csi_port},
        $settings{cust_id},     $settings{order_id},    $settings{name_on_card}, $settings{email_addy},
        $settings{card_number}, $settings{card_expr_m}, $settings{card_expr_y},
        $settings{sub_total},   $settings{tax_total},   $settings{ship_total},   $settings{grand_total},
        $settings{real},
    );

    $result =~ s/[\r\n]//xg;

    my @result = split ":~~:", $result;
    my %result;

    if(@result == 6) {
        %result = (
            'approval'  => $result[0],
            'ref'       => $result[1],
            'code'      => $result[2],
            'ordernum'  => $result[3],
            'error'     => $result[4],
            'time'      => $result[5],
            'connected' => 1
        );
    } else {
        %result = (
            'error_type' => $result[0],
            'error'      => $result[1],
            'connected'  => 0
        );
    }

    return %result;
}

__END__

=head1 Name

Business::CSI - Perl extension for Card Services International

=head1 Minimal Example

use strict;
use Business::CSI qw/ :simple /;

my $max_tries = 5;

add_settings({
    'csi_config'=> '666999',
    'csi_host'  => 'secure.linkpt.net',
    'csi_port'  => '1139',
    'csi_key'   => '/etc/keyfile.pem',
});

add_settings({
    'card_number'  => '1234 5678 1234 5678',
    'card_expr_m'  => '07',
    'card_expr_y'  => '07',
    'name_on_card' => 'Some Looser',
    'email_addy'   => 'looser@aol.com',
});

add_settings({
    'grand_total' => 1,
    'real'        => 0,
});

my $count  = 0;
my %result = ();
{
    %result = simple_transaction;

    if(not $result{connected}) {
        print "$result{error_type} => $result{error}\n";
        die "Your order fail'd $max_tries times ... I give up." if $max_tries <= ++$count;
        redo;
    }
}

foreach my $k (keys %result) {
    print "\$result{$k} = $result{$k}\n";
}

=head1 Settings

=head2 Settings:: The available settings

    csi_config   csi_key      csi_host     csi_port     cust_id     
    order_id     name_on_card email_addy   card_number  card_expr_m 
    card_expr_y  sub_total    tax_total    ship_total   grand_total  real        

=head2 Settings:: The defaults

    'csi_host'     => 'secure.linkpt.net',
    'csi_port'     => '1139',
    'cust_id'      => 'imcertainihavenoidea',
    'order_id'     => ('order' . '.'. time . '.' . $$),
    'email_addy'   => 'unknown@aol.com',
    'real'         => 0,

    'ship_total'   => 0,
    'sub_total'    => 0,
    'tax_total'    => 0,

=head2 Settings:: Extra Info

Unless otherwise listed, they all default to undef.
Note that 'csi_config' and 'csi_key' are really really needed.
'csi_config' is your store number (or whatever they call it now).
'csi_key' is your keyfile.pem.

Another important setting is 'real'.  'real' should be set to
0 while you're practicing -- not $real, and 1 when you're ready
to do it for real. ;)

=head1 To do

1. Billing Shipping info

2. Credit card number sanity checks using Business::CreditCard

3. ... I am accepting requests especially if you wanna throw
me code snippits. ;)

4. More documentation.  As people ask me questions, I make 
more and more less not clear. ;)

=head1 Known Bugs

None... they're fixed

=head1 Unknown Bugs

None AFAIK.

=head1 Credits

"David Deppner" <dave@psyber.com>:

1.  The double/float bugfix mentioned in the Changes log.

2.  Insisted on a README.

=head1 Author

  Jettero Heller <jettero@voltar.org>

=head1 See Also

perl(1).

=cut
