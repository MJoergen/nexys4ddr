#include <stdint.h>
#include <conio.h>

// For now, we just ignore the file descriptor fd.
int read (int fd, uint8_t* buf, const unsigned count)
{
   unsigned cnt = count;
   (void) fd;                // Hack to avoid warning about unused variable.

   while (cnt--)
   {
      *buf = cgetc();
      buf++;
   }
   
   return count;
} // end of read

