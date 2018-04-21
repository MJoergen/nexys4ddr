// Adapted from https://stackoverflow.com/questions/14519267/algorithm-for-generating-a-3d-hilbert-space-filling-curve-in-python
#include <stdio.h>

int red[8*8*8];
int green[8*8*8];
int blue[8*8*8];
int m;

void hilbertC(int s, int x, int y, int z,
                     int dx, int dy, int dz,
                     int dx2, int dy2, int dz2,
                     int dx3, int dy3, int dz3)
{
   if(s==1)
   {
      red[m] = x;
      green[m] = y;
      blue[m] = z;
      m++;
   }
   else
   {
      s/=2;
      if(dx<0) x-=s*dx;
      if(dy<0) y-=s*dy;
      if(dz<0) z-=s*dz;
      if(dx2<0) x-=s*dx2;
      if(dy2<0) y-=s*dy2;
      if(dz2<0) z-=s*dz2;
      if(dx3<0) x-=s*dx3;
      if(dy3<0) y-=s*dy3;
      if(dz3<0) z-=s*dz3;
      hilbertC(s, x, y, z, dx2, dy2, dz2, dx3, dy3, dz3, dx, dy, dz);
      hilbertC(s, x+s*dx, y+s*dy, z+s*dz, dx3, dy3, dz3, dx, dy, dz, dx2, dy2, dz2);
      hilbertC(s, x+s*dx+s*dx2, y+s*dy+s*dy2, z+s*dz+s*dz2, dx3, dy3, dz3, dx, dy, dz, dx2, dy2, dz2);
      hilbertC(s, x+s*dx2, y+s*dy2, z+s*dz2, -dx, -dy, -dz, -dx2, -dy2, -dz2, dx3, dy3, dz3);
      hilbertC(s, x+s*dx2+s*dx3, y+s*dy2+s*dy3, z+s*dz2+s*dz3, -dx, -dy, -dz, -dx2, -dy2, -dz2, dx3, dy3, dz3);
      hilbertC(s, x+s*dx+s*dx2+s*dx3, y+s*dy+s*dy2+s*dy3, z+s*dz+s*dz2+s*dz3, -dx3, -dy3, -dz3, dx, dy, dz, -dx2, -dy2, -dz2);
      hilbertC(s, x+s*dx+s*dx3, y+s*dy+s*dy3, z+s*dz+s*dz3, -dx3, -dy3, -dz3, dx, dy, dz, -dx2, -dy2, -dz2);
      hilbertC(s, x+s*dx3, y+s*dy3, z+s*dz3, dx2, dy2, dz2, -dx3, -dy3, -dz3, -dx, -dy, -dz);
   }
}

int trans[256];

int main()
{
   m=0;
   hilbertC(8,0,0,0,1,0,0,0,1,0,0,0,1);

   for (m=0; m<4*8*8-1; m++)
   {
      int val_before = (red[m]<<5) + (green[m]<<2) + blue[m];
      int val_after  = (red[m+1]<<5) + (green[m+1]<<2) + blue[m+1];
      trans[val_before] = val_after;
   }

   for (m=0; m<4*8*8-1; m+=8)
   {
      printf("0x%02x, ", trans[m]);
      printf("0x%02x, ", trans[m+1]);
      printf("0x%02x, ", trans[m+2]);
      printf("0x%02x, ", trans[m+3]);
      printf("0x%02x, ", trans[m+4]);
      printf("0x%02x, ", trans[m+5]);
      printf("0x%02x, ", trans[m+6]);
      printf("0x%02x\n", trans[m+7]);
   }
} // end of main
