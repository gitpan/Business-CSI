#include <ccapi_client.h>
#include <ccapi_error.h>

char * csi_process_card_simple(
    char  * CC_CONFIG_FILE,
    char  * CC_KEY_FILE,
    char  * CC_HOST,
    int     CC_PORT,

    char  * cust_id, 
    char  * order_id,
    char  * name_on_card,
    char  * email_addy,

    char  * card_number,
    char  * card_expr_m,
    char  * card_expr_y,

    double  sub_total,
    double  tax_total,
    double  ship_total,
    double  grand_total,

    int real
);
