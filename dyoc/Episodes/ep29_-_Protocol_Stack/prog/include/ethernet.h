#include <stdint.h>

extern const uint8_t myMacAddress[6];
extern const uint8_t myIpAddress[4];

typedef struct
{
   uint8_t  destMac[6]; // destination mac address
   uint8_t  srcMac[6];  // source mac address
   uint16_t typeLen;    // type / length
} macheader_t;

typedef struct
{
   uint16_t htype;      // hardware type
   uint16_t ptype;      // protocol type
   uint8_t  hlen;       // hardware address length
   uint8_t  plen;       // protocol address length
   uint16_t oper;       // operation
   uint8_t  sha[6];     // sender hardware address
   uint8_t  spa[4];     // sender protocol address
   uint8_t  tha[6];     // target hardware address
   uint8_t  tpa[4];     // target protocol address
} arpheader_t;

typedef struct
{
   uint8_t  verIHL;     // version / header length
   uint8_t  dscp;       // type of service
   uint16_t totLen;     // total length
   uint16_t id;         // identification
   uint16_t frag;       // fragment offset
   uint8_t  ttl;        // time to live
   uint8_t  protocol;   // protocol
   uint16_t chksum;     // header checksum
   uint8_t  srcIP[4];   // source address
   uint8_t  destIP[4];  // destination address
} ipheader_t;

typedef struct
{
   uint8_t  type;
   uint8_t  code;
   uint16_t chksum;
   uint16_t id;
   uint16_t seq;
} icmpheader_t;

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

