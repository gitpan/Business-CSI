package Business::CSI;

require 5.005_62;
use strict;
use warnings;
use Carp;

require Exporter;
require DynaLoader;
use AutoLoader;

our @ISA         = qw(Exporter DynaLoader);
our %EXPORT_TAGS = ( 'all'    => [ qw( :simple :mail ) ], 
                     'simple' => [ qw( simple_transaction add_settings add_item calc_total ) ],
                     'mail'   => [ qw( customer_notification_mail_settings customer_notification_mail ) ] ); 
our @EXPORT_OK   = ( @{ $EXPORT_TAGS{'all'} }, @{ $EXPORT_TAGS{'simple'} }, @{ $EXPORT_TAGS{'mail'} } );
our @EXPORT      = qw( );
our $VERSION     = '0.76';

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

use Time::HiRes qw/ time /;
use Net::DNS;
use Net::SMTP;
use Sys::Hostname;

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

my %cnm_s = (
    'from'      => "order_processing",
    'from_full' => "Order Processing Center",
    'subject'   => "Your order (#X)",
    'ref'       => "",
    'template'  => "",
    'BCC'       => "",
);

my @items = ();

return 1;

sub customer_notification_mail_settings {
    my $set = shift;
    my $ref = ref($set);

    my (undef, $f, $l) = caller;

    if($ref eq 'HASH') {
        foreach my $k (keys %{ $set }) {
            if(defined $cnm_s{$k}) {
                $cnm_s{$k} = $set->{$k};
            } else {
                die "unrecognized option used in $f at line $l.\nThis was generated";
            }
        }
        return;
    }

    die "You must pass hashes (not $ref) to the function used in $f at line $l.\nThis was generated";
}

sub customer_notification_mail {
    my $smtp = &determin_mailer(shift);

    $cnm_s{subject} =~ s/X/$settings{order_id}/e if $cnm_s{subject} eq "Your order (#X)";

    $cnm_s{from} .= "\@" . hostname if $cnm_s{from} !~ /[@]/;

    if($smtp) {
        my   @TO;
        push @TO, $settings{email_addy};
        push @TO, $cnm_s{BCC} if length($cnm_s{BCC});

        $smtp->mail($cnm_s{from});
        $smtp->to(@TO);

        $smtp->data();
        $smtp->datasend("From:    $cnm_s{from_full} <$cnm_s{from}>\n");
        $smtp->datasend("To:      $settings{name_on_card} <$settings{email_addy}>\n");
        $smtp->datasend("Subject: $cnm_s{subject}\n\n");
        $smtp->datasend("\n\n");
        if(-f $cnm_s{template} and (open IN, "$cnm_s{template}") ) {
            while(<IN>) {
                if(m/SUMMARY/) {
                    $smtp->datasend( &summary );
                } elsif (m/ITEMIZED_LIST/) {
                    $smtp->datasend( &itemized_list );
                } else {
                    $smtp->datasend($_);
                }
            }
            close IN;
        } else {
            $smtp->datasend( &itemized_list );
            $smtp->datasend( "\n\n" );
            $smtp->datasend( &summary );
        }
        $smtp->dataend();

        $smtp->quit;
    }
}

sub itemized_list {
    my $total  = 0;
    my $string = "";

    $string .= "<pre>\n";
    $string .= sprintf " %-40s | %10s\n", "Item", "Price (USD)";
    $string .= "-" x 42 . "+" . "-" x 13 . "\n";

    my $i;
    for( my $i = 0; $i<@items; $i += 2) {
        $string .= sprintf " %-40s | %11.2f\n", @items[$i..$i+1];
    }

    $string .= "-" x 42 . "+" . "-" x 13 . "\n";

    if($settings{sub_total} or $settings{tax_total} or $settings{ship_total}) {
        if($settings{sub_total}) {
            $total   = sprintf "\$%0.2f\n", $settings{sub_total};
            $total   = " " x (12-length($total)) . "$total";
            $string .= " " x 30 . "  sub total | $total";
        }

        if($settings{tax_total}) {
            $total   = sprintf "\$%0.2f\n", $settings{tax_total};
            $total   = " " x (12-length($total)) . "$total";
            $string .= " " x 30 . "  tax total | $total";
        }

        if($settings{ship_total}) {
            $total   = sprintf "\$%0.2f\n", $settings{ship_total};
            $total   = " " x (12-length($total)) . "$total";
            $string .= " " x 27 . " shipping cost | $total";
        }

        $string .= "-" x 42 . "+" . "-" x 13 . "\n";
    }

    $total   = sprintf "\$%0.2f\n", $settings{grand_total};
    $total   = " " x (12-length($total)) . "$total";
    $string .= " " x 30 . "grand total | $total";
    $string .= "</pre>\n";

    return $string;
}

sub summary {
    my $string = "Your transaction reference number was '$cnm_s{ref}'.\n";
    $string   .= "BTW, this order was only a simulated transaction.\n" if not $settings{real};

    return $string;
}

sub determin_mailer {
    my $smtp_connection;

    if($_[0]) {
        my $dns   = new Net::DNS::Resolver;

        if($dns) {
            $settings{email_addy} =~ m/\w+[@].+/;
            my $realm = $1;
            my @mx = mx($dns, $realm);
            foreach(@mx) {
                $smtp_connection = Net::SMTP->new($_->exchange, Hello => "hacker.bitch.net", Timeout => 20, Debug => 0) or next;
                last;
            }
        }
    }

    if(not $smtp_connection) {
        $smtp_connection = Net::SMTP->new("localhost", Hello => "hacker.bitch.net", Timeout => 20, Debug => 0);
    }

    return $smtp_connection;
}

sub add_item {
    my ($desc, $amount) = @_;

    die "stupid amount" if $amount       <0;
    die "stupid desc"   if length($desc) <1;

    push @items, ( @_ );
}

sub calc_total {
    my $i;
    my $total = 0;

    for( my $i = 1; $i<@items; $i += 2) {
        $total += $items[$i];
    }

    return $total;
}

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
                if($k =~ /card_expr_m/) {
                    $set->{$k} = sprintf("%02d", $set->{$k});
                } elsif($k =~ /card_expr_y/) {
                    $set->{$k} = substr(sprintf("%04d", $set->{$k}), 2);
                }
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
        int(@items), @items
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
        $cnm_s{'ref'} = $result[1];
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

=head1 The Example

 use strict;
 use Business::CSI qw/ :simple :mail /;

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
 
 add_item("A happy meal", 0.5);  # you don't need to use these.
 add_item("A sad   meal", 0.5);  # but it makes the line items show
                                 # in the admin/customer e-mail
 
 add_settings({
     'grand_total' => calc_total, # note that calc_total does not account
     'real'        => 0,          # for or affect the ship/sub/tax totals
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
 
 # at this point, we're successfull

 customer_notification_mail_settings({
     # see the documentation below if you want to use templates.
     'template' => "filename.txt", 
     'BCC'      => "sales@our.downtown.com",
 });

 customer_notification_mail(1); # generally you wouldn't use the 1, see below
 
 foreach my $k (keys %result) {
     print "\$result{$k} = $result{$k}\n";
 }

=head1 %results population

=head2 Success

    These are all retrieved from a cc_order_get(order,
    OrderField_R_Something ...  function call.  These values are well
    documented in the linkpoint api so if you're wondering what values
    these can take on, consult the aforementioned documentation.

    'approval'  => $result[0], # OrderField_R_Approved
    'ref'       => $result[1], # OrderField_R_Ref
    'code'      => $result[2], # OrderField_R_Code
    'ordernum'  => $result[3], # OrderField_R_Ordernum
    'error'     => $result[4], # OrderField_R_Error
    'time'      => $result[5], # OrderField_R_Time
    'connected' => 1

=head2 Failure

    'error_type' => $result[0], # any of process or setrequest
    'error'      => $result[1], # the error returned from CSI
    'connected'  => 0

    The error_type is the stage of the order process, either 'process' or
    'setrequest'.  Again, consult the linkpoint api docs to see what 
    values can be returned.
 
=head1 Settings

=head2 Settings - The available settings

    csi_config   csi_key      csi_host     csi_port     cust_id     
    order_id     name_on_card email_addy   card_number  card_expr_m 
    card_expr_y  sub_total    tax_total    ship_total   grand_total  real        

=head2 Settings - The defaults

    'csi_host'     => 'secure.linkpt.net',
    'csi_port'     => '1139',
    'cust_id'      => 'imcertainihavenoidea',
    'order_id'     => ('order' . '.'. time . '.' . $$),
    'email_addy'   => 'unknown@aol.com',
    'real'         => 0,

    'ship_total'   => 0,
    'sub_total'    => 0,
    'tax_total'    => 0,

=head2 Settings - Extra Info

  Unless otherwise listed, they all default to undef.
  Note that 'csi_config' and 'csi_key' are really really needed.
  'csi_config' is your store number (or whatever they call it now).
  'csi_key' is your keyfile.pem.

  Another important setting is 'real'.  'real' should be set to
  0 while you're practicing -- not $real, and 1 when you're ready
  to do it for real. ;)

=head1 Email settings

   Note that in order ot use the Email functions, you must put a ':mail' in
   your use line -- as seen in the example.

=head2 customer_notification_mail;

   This is the function that actually sends a mail to the customer.
   If you want it to use the localhost mail gateway (sendmail?), then
   call it like it was called in the example above. 

   If (for some reason) you wish to use the customers own mail gateway,
   as discovered through the MX records for the domain, call the function
   with a 1 as the argument:

   customer_notification_mail(1);

=head2 template => "filename.txt"

  If this funciton is used, the customer_notification_mail function will
  use the named template to do the notification.  SUMMARY and ITEMIZED_LIST
  should appear on a line by themselves somewhere in the template.  They
  get replaced appropriately.

=head2 from => "someone", from => "someone@something.tld"

  Use this to set the email address the mail comes from (postmaster by
  default).  Business::CSI will attempt to appened a logical fqdn if
  it can't find an [@] in the address.

=head2 from_full => "Some Dude Department"

  With this you can set the Full Name for the from: header.
  This is reccomended ... for asthetic reasons.

=head2 subject => "Your Order with Some Damn Co."

  The subject line (if not specified) will be:
  'Subject: Your order (#X)'
  Where X will get replaced with the order # you specified.

=head2  BCC => "someoneelse@at.our.co"

  Our sales department keeps track of all our orders in a spreadsheet.
  I think that's kinda dumb, and offered to do a database thing.
  *shrug*  They'd rather get a copy of this.  That's what this is 
  for.

=head1 To do

  1. Billing Shipping info
  2. Credit card number sanity checks using Business::CreditCard
  3. ... I am accepting requests especially if you wanna throw me 
      code snippits. ;)
  4. More documentation.  As people ask me questions, I make more and more 
     less not clear. ;)

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
