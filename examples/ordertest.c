#ifndef WIN32
#include <pthread.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include "api_client.h"

int main(int argc, char *argv[]) { 
  int i;
  float total;
  
  struct charge_struct ch;
  struct req_struct req;
  static struct order_struct order;
  struct shipping_struct shipping;
  struct tax_struct tax;
  
  ssl_init_ctx(&req,&order,&ch);
  
  /* if (argc == 2)
     total = (float) atof(argv[1]);
     else */
  total = 1.00;
/* strcpy(order.oid, "176.0.2.10-926450253-6"); */
strcpy(order.userid,"nobody");
strcpy(order.bname,"John Q. Public");
strcpy(order.bcompany,"ClearCommerce");
strcpy(order.baddr1,"9101 Burnet Rd. #207");
strcpy(order.bcity,"Austin");
strcpy(order.bstate,"TX");
strcpy(order.bzip,"78758");
strcpy(order.bcountry,"US");
strcpy(order.sname,"John Q. Company");
strcpy(order.saddr1,"9101 Burnet Rd. #207");
strcpy(order.scity,"Austin");
strcpy(order.sstate,"TX");
strcpy(order.szip,"78758");
strcpy(order.scountry,"US");
strcpy(order.phone,"512-832-0132");
strcpy(order.fax,"512-832-8901");
order.subtotal=total;
strcpy(order.comments,"No comments today");
order.item[0].itemnum=1;
strcpy(order.item[0].itemid,"T-Shirt 001");
strcpy(order.item[0].description,"T-Shirt of ClearCommerce Logo");
order.item[0].price=2.00;
order.item[0].quantity=1;
strcpy(order.item[0].option[0].option,"Color");
strcpy(order.item[0].option[0].choice,"Red");
strcpy(order.item[0].option[1].option,"Size");
strcpy(order.item[0].option[1].choice,"Extra Large");

order.item[1].itemnum=2;
strcpy(order.item[1].itemid,"GAME 033");
strcpy(order.item[1].description,"Blast Em Game Software");
strcpy(order.item[1].softfile,"julief.gif"); 
strcpy(order.item[1].serial,""); 
order.item[1].esdtype=SOFTGOOD;
order.item[1].price=1.00;
order.item[1].quantity=1;


strcpy(req.CardNumber,"4111111111111111");
/* Spaces or dashes will be ignored */

strcpy(req.ExpMonth,"12"); 
/* The numeric value of the expiration month of the card */

strcpy(req.ExpYear,"99");  
/* The 2 digit numeric value of the expiration year of the card. For
   the year 2000 and beyond, use "00", "01", etc. */

strcpy(req.email,"someone@hostname.com");
/* The email address of the person purchasing goods. If the email address
   isn't available, a valid email address needs to be included anyways */

strcpy(req.ConfigFile,"change_me");
/* The name of the configuration file to use. Normally the name of your 
   company. */

 req.ChargeType=SALE;
/* The type of transaction. Normally SALE. See api_client.h for a
   complete list */

strcpy(req.keyfile,"testcert.pem");
/* The full path and filename of the certificate. The certificate that
   comes with the API is for test purposes only. You should receive another
   certificate once you are registered to process transactions. */

strcpy(req.host,"localhost");
/* The name of the server that ssl_server is running on. */

req.port=1139;
/* The port the ssl_server is listening on. The default is 1139. */

/* The next four fields aren't normally used. Just leave them commented out */

strcpy(req.ReferenceNumber,"");
/* The reference number of a previous charge. Used for doing credits */

req.result=GOOD;
/* If you want to test the charge_card routine without actually charging a
   card set this value to GOOD or DECLINE. To really charge the card, either
   set this to 0, or comment out the line. The default is 0.
   Please use with caution until you have been setup with your own
   merchant numbers and have gotten a certificate file from us.*/

strcpy(req.zip,"11111");
/* The zip code of the billing address of the credit card. Used when your
   merchant has address verification turned on. */

strcpy(req.addr,"111");
/* The street address of the billing address of the credit card. Also used
   only when the merchant has address verification turned on. */

strcpy(shipping.country, "US");
strcpy(shipping.state, "TX");
shipping.total = order.subtotal;
shipping.items = 29;
shipping.weight = 2.00;
shipping.carrier = 0;
order.shipping=calculate_shipping(req,shipping);
printf("Shipping is %0.2f\n",order.shipping);fflush(stdout);

strcpy(tax.state, "TX");
strcpy(tax.zip, "78758");
tax.total = order.subtotal+order.shipping;
order.tax=calculate_tax(req,tax);
printf("Tax is %0.2f\n",order.tax);fflush(stdout);
req.ChargeTotal=order.subtotal+order.tax+order.shipping;
/* The total amount you want to charge including any taxes */

/* Process the transaction */
#ifndef WIN32
  ch=process_txn(req,order);
#else
  ch=process_txn(req,&order);
#endif
  
  /* Now print the results so you know what's going on */
  printf("Time - %s\n",ch.time);
  printf("Ref# - %s\n",ch.ref);
  printf("Appr - %s\n",ch.approved);
  printf("Code - %s\n",ch.code);
  if(ch.error)
    printf("Err  - %s\n",ch.error);
  printf("Ord# - %s\n",ch.ordernum);
  
  for (i=0;i<MAX_ITEMS;i++) {
    if (ch.esdname[i]!=NULL) {
      printf("Item %d URL - %s\n",i,ch.esdname[i]);
    }
  }
  
  ssl_free_ctx(&req,&order,&ch);
  return(0);
}

