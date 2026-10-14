#include <mach-o/dyld.h>
#include <stdio.h>
int main(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) puts(_dyld_get_image_name(i));
    return 0;
}
