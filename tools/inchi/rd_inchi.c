/* Reactio Draw: InChI and InChIKey of a molfile (V2000 text), via the InChI library (MIT, InChI Trust / IUPAC) */
#include <stdlib.h>
#include <string.h>
#include "inchi_api.h"
static char *out_buf=0;
__attribute__((export_name("rd_alloc"))) void* rd_alloc(int n){return malloc(n);}
__attribute__((export_name("rd_free"))) void rd_free(void*p){free(p);}
/* returns "code\nInChI\nInChIKey\nmessage" (static buffer, valid until the next call) */
__attribute__((export_name("rd_inchi"))) const char* rd_inchi(const char* mol,const char* opts){
  inchi_Output o;memset(&o,0,sizeof o);char op[256];strncpy(op,opts?opts:"",255);op[255]=0;
  int r=MakeINCHIFromMolfileText(mol,op,&o);
  char key[32]={0},x1[66]={0},x2[66]={0};
  if(o.szInChI&&(r==inchi_Ret_OKAY||r==inchi_Ret_WARNING))GetINCHIKeyFromINCHI(o.szInChI,0,0,key,x1,x2);
  const char*a=o.szInChI?o.szInChI:"",*m=o.szMessage?o.szMessage:"";
  free(out_buf);out_buf=malloc(strlen(a)+strlen(m)+64);
  char code[8];int n=r;int i=0;if(n<0){code[i++]='-';n=-n;}char t[8];int k=0;do{t[k++]='0'+n%10;n/=10;}while(n);while(k)code[i++]=t[--k];code[i]=0;
  strcpy(out_buf,code);strcat(out_buf,"\n");strcat(out_buf,a);strcat(out_buf,"\n");strcat(out_buf,key);strcat(out_buf,"\n");strcat(out_buf,m);
  FreeINCHI(&o);return out_buf;}
