#ifndef WIN32
#include <pthread.h>
#endif
#include <string.h>
#include <stdio.h>
#include "ccapi_client.h"
#include "ccapi_error.h"
#include <signal.h>

int main(int argc, char *argv[]) { 
  float price, total, shiptotal, taxtotal, subtotal, itemtotal, weight;
  int quantity, esdtype, reqtype, port, result, carrier;
  char buf[1024];
  char **esdfiles;
  int i, maxitems;

  ShippingCtx *shipping;
  OptionCtx *option;
  OrderCtx *order;
  ReqCtx *req;
  ItemCtx *item;
  TaxCtx *tax;

  printf("Using ClearCommerce SSL API Version: %0.2f\n", cc_util_version());
  
  cc_order_alloc(&order);
  cc_item_alloc(&item);
  cc_option_alloc(&option);
  cc_req_alloc(&req);
  cc_shipping_alloc(&shipping);
  cc_tax_alloc(&tax);

  port = 1139;
  cc_req_set(req, ReqField_Configfile, "change_me");
  cc_req_set(req, ReqField_Keyfile, "/usr/local/ssl/certs/testcert.pem");
  cc_req_set(req, ReqField_Host, "localhost");
  cc_req_set(req, ReqField_Port, &port);

  if(cc_order_setrequest(order, req) != Succeed) {
    cc_util_errorstr(cc_order_error(order), buf, sizeof(buf));
    printf("%s\n", buf);
  }

  cc_tax_setrequest(tax, req);
  cc_shipping_setrequest(shipping, req);

  /* Set order parameters */
  result = Result_Decline;
  reqtype = Chargetype_Preauth;

  cc_order_set(order, OrderField_Userid, "nobody");
  cc_order_set(order, OrderField_Bname, "John Q. Public");
  cc_order_set(order, OrderField_Bcompany, "ClearCommerce");
  cc_order_set(order, OrderField_Baddr1, "11500 Metric Blvd. Suite 300");
  cc_order_set(order, OrderField_Bcity, "Austin");
  cc_order_set(order, OrderField_Bstate, "TX");
  cc_order_set(order, OrderField_Bzip, "78758");
  cc_order_set(order, OrderField_Bcountry, "US");
  cc_order_set(order, OrderField_Sname, "John Q. Company");
  cc_order_set(order, OrderField_Saddr1, "11500 Metric Blvd. Suite 300");
  cc_order_set(order, OrderField_Scity, "Austin");
  cc_order_set(order, OrderField_Sstate, "TX");
  cc_order_set(order, OrderField_Szip, "78758");
  cc_order_set(order, OrderField_Scountry, "US");
  cc_order_set(order, OrderField_Phone, "512-832-0132");
  cc_order_set(order, OrderField_Fax, "512-832-8901"); 
  cc_order_set(order, OrderField_Comments, "No comments today");
  cc_order_set(order, OrderField_Cardnumber, "4111111111111111");
  cc_order_set(order, OrderField_Chargetype, &reqtype);
  cc_order_set(order, OrderField_Expmonth, "12"); 
  cc_order_set(order, OrderField_Expyear, "01");
  cc_order_set(order, OrderField_Email, "someone@somehost.com");
  cc_order_set(order, OrderField_Result, &result);
  cc_order_set(order, OrderField_Addrnum,"111");

  price = (float) 10.02;   
  itemtotal = price;
  quantity = 1;
  cc_item_set(item, ItemField_Itemid, "T-Shirt 001");
  cc_item_set(item, ItemField_Description, "T-Shirt of ClearCommerce Logo");
  cc_item_set(item, ItemField_Price, &price);
  cc_item_set(item, ItemField_Quantity, &quantity);

  cc_option_set(option, OptionField_Option, "Color");
  cc_option_set(option, OptionField_Choice, "Blue");

  if(cc_item_addoption(item, option) != Succeed) {
    cc_util_errorstr(cc_item_error(item), buf, sizeof(buf));
    printf("%s\n", buf);
  }
  
  cc_option_drop(option);
  cc_order_additem(order, item); 
  cc_item_clear(item);

  price = 15.00;   
  itemtotal += price;
  quantity = 1;
  esdtype = Esdtype_Softgood;
  cc_item_set(item, ItemField_Itemid, "GAME 033");
  cc_item_set(item, ItemField_Description, "Blast Em Game Software");
  cc_item_set(item, ItemField_Softfile, "file.zip");
  cc_item_set(item, ItemField_Serial, "");
  cc_item_set(item, ItemField_Esdtype, &esdtype); 
  cc_item_set(item, ItemField_Price, &price);
  cc_item_set(item, ItemField_Quantity, &quantity);

  cc_order_additem(order, item);   

  cc_item_drop(item);

  subtotal = itemtotal;
  cc_order_set(order, OrderField_Subtotal, &subtotal);

  quantity = 2;  
  weight = 1.00;
  carrier = 1;
  cc_shipping_set(shipping, ShippingField_Country, "US");
  cc_shipping_set(shipping, ShippingField_State, "TX");
  cc_shipping_set(shipping, ShippingField_Total, &subtotal);
  cc_shipping_set(shipping, ShippingField_Items, &quantity);
  cc_shipping_set(shipping, ShippingField_Weight, &weight);
  cc_shipping_set(shipping, ShippingField_Carrier, &carrier);
  
  if(cc_shipping_process(shipping) != Succeed) {
    cc_util_errorstr(cc_shipping_error(shipping), buf, sizeof(buf));
    printf("%s\n", buf);
  }

#ifndef WIN32
  cc_shipping_get(shipping, ShippingField_R_Total, &shiptotal, Unused);
#else
  cc_shipping_get(shipping, ShippingField_R_Total, &shiptotal, CC_Unused);
#endif
  printf("Shipping: %.2f\n", shiptotal);
  cc_order_set(order, OrderField_Shipping, &shiptotal);
  cc_shipping_drop(shipping); 

  price = shiptotal + subtotal;
  cc_tax_set(tax, TaxField_State, "TX");
  cc_tax_set(tax, TaxField_Zip, "78758");
  cc_tax_set(tax, TaxField_Total, &price);

  if(cc_tax_process(tax) != Succeed) {
    cc_util_errorstr(cc_tax_error(tax), buf, sizeof(buf));
    printf("%s\n", buf);
  }

#ifndef WIN32
  cc_tax_get(tax, TaxField_R_Total, &taxtotal, Unused);
#else
  cc_tax_get(tax, TaxField_R_Total, &taxtotal, CC_Unused);
#endif
  printf("Tax: %.2f\n", taxtotal);
  cc_order_set(order, OrderField_Tax, &taxtotal);   
  cc_tax_drop(tax);

  total = subtotal + taxtotal + shiptotal;
  cc_order_set(order, OrderField_Chargetotal, &total); 
  printf("Charge Total: %.2f\n", total);

  if(cc_order_process(order) != Succeed) {
    cc_util_errorstr(cc_order_error(order), buf, sizeof(buf));
    printf("%s\n", buf);
  }
  else {
    cc_order_get(order, OrderField_R_Time, buf, sizeof(buf));
    printf("Time - %s\n", buf);
    
    cc_order_get(order, OrderField_R_Ref, buf, sizeof(buf));
    printf("Ref# - %s\n", buf);
    
    cc_order_get(order, OrderField_R_Approved, buf, sizeof(buf));
    printf("Appr - %s\n", buf);
    
    cc_order_get(order, OrderField_R_Code, buf, sizeof(buf));
    printf("Code - %s\n", buf); 
    
    cc_order_get(order, OrderField_R_Error, buf, sizeof(buf));
    printf("Err  - %s\n", buf); 
    
    cc_order_get(order, OrderField_R_Ordernum, buf, sizeof(buf));
    printf("Ord# - %s\n", buf); 
    
    printf("\n\nESD:\n");
    
#ifndef WIN32
    cc_order_get(order, OrderField_MaxItems, &maxitems, Unused);
#else
    cc_order_get(order, OrderField_MaxItems, &maxitems, CC_Unused);
#endif
    cc_order_getesd(order, &esdfiles);
    
    for (i=0; i < maxitems ;i++) {
      if (esdfiles[i]) 
	printf("Item %d URL - %s\n", i, esdfiles[i]); 
    }
  }
    
  cc_order_drop(order);
  cc_req_drop(req);  

  return (0);
}

