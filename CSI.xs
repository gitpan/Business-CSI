#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <csi_process_card.h>

static int
not_here(char *s)
{
    croak("%s not implemented on this architecture", s);
    return -1;
}

static double
constant(char *name, int len, int arg)
{
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
	RETVAL = constant(s,len,arg);
    OUTPUT:
	RETVAL

char *
csi_process_card_simple(CC_CONFIG_FILE,CC_KEY_FILE,CC_HOST,CC_PORT,cust_id,order_id,name_on_card,email_addy,card_number,card_expr_m,card_expr_y,sub_total,tax_total,ship_total,grand_total,real)
    char  * CC_CONFIG_FILE
    char  * CC_KEY_FILE
    char  * CC_HOST
    int     CC_PORT
    char  * cust_id
    char  * order_id
    char  * name_on_card
    char  * email_addy
    char  * card_number
    char  * card_expr_m
    char  * card_expr_y
    double  sub_total
    double  tax_total
    double  ship_total
    double  grand_total
    int     real
