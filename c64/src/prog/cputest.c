// This test is mainly for simulation.
// It tests the correct functionality of the individual instructions.

/*
 * Define some zero-page variables
 */


/*
 * Memory Map:
 * 0x8000 - 0x83FF : Chars Memory
 * 0x8400 - 0x85FF : Bitmap Memory
 * 0x8600 - 0x87FF : Config and Status
 */



// Entry point after CPU reset
void __fastcall__ reset(void)
{
   // We assume that JMP works as expected.

   // First we test conditional branching forward
   __asm__("LDA #$00");
   __asm__("BNE %g", error1);    // Should not jump
   __asm__("BMI %g", error1);    // Should not jump
   __asm__("BEQ %g", noError1);  // Should jump
error1:
   __asm__("JMP %g", error1);
noError1:
   __asm__("BPL %g", noError1a); // Should jump
   __asm__("JMP %g", error1);

noError1a:
   __asm__("LDA #$FF");
   __asm__("BEQ %g", error2);    // Should not jump
   __asm__("BPL %g", error2);    // Should not jump
   __asm__("BNE %g", noError2);  // Should jump
error2:
   __asm__("JMP %g", error2);
noError2:
   __asm__("BMI %g", noError2a); // Should jump
   __asm__("JMP %g", error2);
noError2a:

   __asm__("CLC");
   __asm__("BCS %g", error3);    // Should not jump
   __asm__("BCC %g", noError3);  // Should jump
error3:
   __asm__("JMP %g", error3);
noError3:
   __asm__("SEC");
   __asm__("BCC %g", error4);    // Should not jump
   __asm__("BCS %g", noError4);  // Should jump
error4:
   __asm__("JMP %g", error4);

   // Next we test conditional branching backward
noError4c:
   __asm__("LDA #$FF");
   __asm__("BNE %g", noError5);  // Should jump
   __asm__("JMP %g", error5);
noError4b:
   __asm__("LDA #$00");
   __asm__("BEQ %g", noError4c); // Should jump
   __asm__("JMP %g", error5);
noError4a:
   __asm__("SEC");
   __asm__("BCS %g", noError4b); // Should jump
   __asm__("JMP %g", error5);
noError4:
   __asm__("CLC");
   __asm__("BCC %g", noError4a); // Should jump
   __asm__("JMP %g", error5);
error5:
   __asm__("JMP %g", error5);

noError5:




   // Loop forever doing nothing
here:
   goto here;  // Just do an endless loop. Everything is run from the IRQ.
} // end of reset


// The interrupt service routine.
void __fastcall__ irq(void)
{
   __asm__("RTI");
} // end of irq


// Non-maskable interrupt
void __fastcall__ nmi(void)
{
   // Not used.
   __asm__("RTI");
} // end of nmi

