#include <stdint.h>

extern const uint8_t myMacAddress[6];
extern const uint8_t myIpAddress[4];

#define ntoh16(x) (((x & 0xFF)<<8) | (x>>8))
#define hton16(x) (((x & 0xFF)<<8) | (x>>8))

void processFrame(uint8_t *rdPtr, uint16_t frmLen);
void processARP(uint8_t *rdPtr, uint16_t frmLen);
void processICMP(uint8_t *rdPtr, uint16_t frmLen);
void processIP(uint8_t *rdPtr, uint16_t frmLen);
void processUDP(uint8_t *rdPtr, uint16_t frmLen);
void processTCP(uint8_t *rdPtr, uint16_t frmLen);
uint16_t calcChecksum(uint16_t *ptr, uint16_t len);
void txFrame(uint8_t *pkt);

