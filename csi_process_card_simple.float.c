#include <csi_process_card.h>

char * csi_process_card_simple(
    OrderCtx *order,

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
) {
    ReqCtx *req;

    char buff[1024];
    char * temp = (char *) malloc(4096);
    int  reqtype = Chargetype_Sale;

    int result = (real) ? Result_Live : Result_Good;

    float sut=(float)sub_total, tt=(float)tax_total, sht=(float)ship_total, gt=(float)grand_total;

    cc_req_alloc(  &req  );

    cc_req_set(req, ReqField_Configfile, CC_CONFIG_FILE );
    cc_req_set(req, ReqField_Keyfile,    CC_KEY_FILE    );
    cc_req_set(req, ReqField_Host,       CC_HOST        );
    cc_req_set(req, ReqField_Port,      &CC_PORT        );

    if (cc_order_setrequest(order, req) != Succeed) {
        cc_util_errorstr(cc_order_error(order), buff, 1024);
        sprintf(temp, "setrequest:~~:%s", buff);

        cc_order_drop(order);
        cc_req_drop(req);

        return(temp);
    }

    cc_order_set(order, OrderField_Userid,       cust_id      );
    cc_order_set(order, OrderField_Oid,          order_id     );
    cc_order_set(order, OrderField_Bname,        name_on_card );
    cc_order_set(order, OrderField_Email,        email_addy   );
    cc_order_set(order, OrderField_Chargetype,  &reqtype      );
    cc_order_set(order, OrderField_Cardnumber,   card_number  );
    cc_order_set(order, OrderField_Expmonth,     card_expr_m  );
    cc_order_set(order, OrderField_Expyear,      card_expr_y  );
    cc_order_set(order, OrderField_Result,      &result       );

    cc_order_set(order, OrderField_Subtotal,    &sut );
    cc_order_set(order, OrderField_Tax,         &tt  );
    cc_order_set(order, OrderField_Shipping,    &sht );
    cc_order_set(order, OrderField_Chargetotal, &gt  );

    if (cc_order_process(order) != Succeed) {
        cc_util_errorstr(cc_order_error(order), buff, 1024);

        sprintf(temp, "process:~~:%s", buff);

        cc_order_drop(order);
        cc_req_drop(req);

        return(temp);
    } else {
        strcpy(temp, "");
        cc_order_get(order, OrderField_R_Approved, buff, 1024); strcat(temp, buff); strcat(temp, ":~~:");
        cc_order_get(order, OrderField_R_Ref,      buff, 1024); strcat(temp, buff); strcat(temp, ":~~:");
        cc_order_get(order, OrderField_R_Code,     buff, 1024); strcat(temp, buff); strcat(temp, ":~~:");
        cc_order_get(order, OrderField_R_Ordernum, buff, 1024); strcat(temp, buff); strcat(temp, ":~~:");
        cc_order_get(order, OrderField_R_Error,    buff, 1024); strcat(temp, buff); strcat(temp, ":~~:");
        cc_order_get(order, OrderField_R_Time,     buff, 1024); strcat(temp, buff); //strcat(temp, ":~~:");
    }

    cc_order_drop(order);
    cc_req_drop(req);

    return(temp);
}

