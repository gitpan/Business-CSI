#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <csi_process_card.h>

#include <ccapi_client.h>
#include <ccapi_error.h>

static int not_here(char *s) {
    croak("%s not implemented on this architecture", s);
    return -1;
}

static double constant(char *name, int len, int arg) {
    errno = EINVAL;
    return 0;
}

MODULE = Business::CSI		PACKAGE = Business::CSI		

double
constant(sv,arg)
    PREINIT:
	STRLEN		len;
    INPUT:
	SV *		sv
	char *		s = SvPV(sv, len);
	int		arg
    CODE:
	RETVAL = constant(s, len, arg);
    OUTPUT:
	RETVAL

char *
csi_process_card_simple(CC_CONFIG_FILE,CC_KEY_FILE,CC_HOST,CC_PORT,cust_id,order_id,name_on_card,email_addy,card_number,card_expr_m,card_expr_y,sub_total,tax_total,ship_total,grand_total,real,items,...)
    CODE:
        // I go ahead and do these by hand cuz they're a handy reference.
        // I used it alot when I was doing my line item voodoo.
	char *	CC_CONFIG_FILE = (char *) SvPV( ST(  0 ), PL_na);
	char *	CC_KEY_FILE    = (char *) SvPV( ST(  1 ), PL_na);
	char *	CC_HOST        = (char *) SvPV( ST(  2 ), PL_na);
	int	CC_PORT        = (int)    SvIV( ST(  3 ) );
	char *	cust_id        = (char *) SvPV( ST(  4 ), PL_na);
	char *	order_id       = (char *) SvPV( ST(  5 ), PL_na);
	char *	name_on_card   = (char *) SvPV( ST(  6 ), PL_na);
	char *	email_addy     = (char *) SvPV( ST(  7 ), PL_na);
	char *	card_number    = (char *) SvPV( ST(  8 ), PL_na);
	char *	card_expr_m    = (char *) SvPV( ST(  9 ), PL_na);
	char *	card_expr_y    = (char *) SvPV( ST( 10 ), PL_na);
	double	sub_total      = (double) SvNV( ST( 11 ) );
	double	tax_total      = (double) SvNV( ST( 12 ) );
	double	ship_total     = (double) SvNV( ST( 13 ) );
	double	grand_total    = (double) SvNV( ST( 14 ) );
	int	real           = (int)    SvIV( ST( 15 ) );
	int	items          = (int)    SvIV( ST( 16 ) );

        int    m = items;
        int    i;
        double d;

        OrderCtx *order; 
        ItemCtx  *item;

        cc_order_alloc(&order);
        cc_item_alloc(&item);

        while(items>0) {
            i = 16 + (m - --items); items--;

            d = (double) SvNV( ST(i+1) );

            cc_item_set(item, ItemField_Description, (char *) SvPV( ST(i), PL_na ) );
            cc_item_set(item, ItemField_Price, &d );

            cc_order_additem(order, item);   

            cc_item_clear(item);
        }

        cc_item_drop(item);

	RETVAL = csi_process_card_simple(
            order,
            CC_CONFIG_FILE, CC_KEY_FILE, CC_HOST, CC_PORT, cust_id, order_id, name_on_card, email_addy, 
            card_number, card_expr_m, card_expr_y, sub_total, tax_total, ship_total, grand_total, real
        );

	sv_setpv(TARG, RETVAL);
        XSprePUSH; 
        PUSHTARG;
