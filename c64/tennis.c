// Precomputes the Matrix A
//
#include <stdio.h>
#include <math.h>

int tab_a[256];
int tab_b[256];

int main()
{
   for (int x=-8; x<8; ++x)
   {
      for (int y=-8; y<8; ++y)
      {
         int a, b = 0;
         if (x || y)
         {
            a = ((y*y-x*x)*255)/(x*x+y*y);   // A11
            b = ((-2*x*y)*255)/(x*x+y*y);    // A12

            a = (a>>1) & 0xFF;
            b = (b>>1) & 0xFF;
         }

         //printf("(%d,%d) -> (0x%02x,0x%02x)\n", x, y, a, b);

         int idx = ((x>=0) ? x : x+16)*16 + ((y>=0) ? y : y+16);
         printf("%d -> (%d, %d)\n", idx, a, b);
         tab_a[idx] = a;
         tab_b[idx] = b;
      }
   }

   for (int idx=0; idx<256; idx+=8)
   {
      printf("0x%02x, ", tab_a[idx+0]);
      printf("0x%02x, ", tab_a[idx+1]);
      printf("0x%02x, ", tab_a[idx+2]);
      printf("0x%02x, ", tab_a[idx+3]);
      printf("0x%02x, ", tab_a[idx+4]);
      printf("0x%02x, ", tab_a[idx+5]);
      printf("0x%02x, ", tab_a[idx+6]);
      printf("0x%02x, \n", tab_a[idx+7]);
   }
   printf("\n");
   for (int idx=0; idx<256; idx+=8)
   {
      printf("0x%02x, ", tab_b[idx+0]);
      printf("0x%02x, ", tab_b[idx+1]);
      printf("0x%02x, ", tab_b[idx+2]);
      printf("0x%02x, ", tab_b[idx+3]);
      printf("0x%02x, ", tab_b[idx+4]);
      printf("0x%02x, ", tab_b[idx+5]);
      printf("0x%02x, ", tab_b[idx+6]);
      printf("0x%02x, \n", tab_b[idx+7]);
   }
}

