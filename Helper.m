#import <Foundation/Foundation.h>
#import <unistd.h>
#import <stdint.h>

extern int reboot3(uint64_t flags, ...);
static const uint64_t BCXUserSpaceReboot = 0x2000000000000000ULL;

int main(void) {
    @autoreleasepool {
        if (setuid(0) != 0 || setgid(0) != 0) return 12;
        sync();
        return reboot3(BCXUserSpaceReboot);
    }
}
