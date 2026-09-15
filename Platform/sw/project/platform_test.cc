#include "platform_test.h"

#include <stdint.h>
#include <stdio.h>

#include "cbo.h"
#include "cfu.h"

namespace
{

    const uint32_t kGolden[] = {
        0x00000000u,
        0xffffffffu,
        0x55555555u,
        0xaaaaaaaau,
        0x00000001u,
        0x80000000u,
        0x01234567u,
        0x89abcdefu,
        0x13579bdfu,
        0x2468ace0u,
        0x00ff00ffu,
        0xff00ff00u,
        0x0000ffffu,
        0xffff0000u,
        0x55aa1234u,
        0xcafe9999u,
    };
    const unsigned kWordCount = sizeof(kGolden) / sizeof(kGolden[0]);

    alignas(32) volatile uint32_t test_words[kWordCount];

    unsigned check_word(const char* operation, unsigned index, uint32_t actual,
                        uint32_t golden)
    {
        const bool pass = actual == golden;
        printf("[%s] CPU Load/Store Test %s[%u]: actual=0x%08x golden=0x%08x\n",
               pass ? "PASS" : "FAIL", operation, index,
               (unsigned)actual, (unsigned)golden);
        return pass ? 0 : 1;
    }

} // namespace

void platform_test(void)
{
    printf("\n=== CPU Load/Store Test (NPU stub) ===\n");
    printf("[CPU] Testing basic load/store on %u words.\n", kWordCount);
    unsigned failures = 0;

    // write golden values using CPU stores.
    for (unsigned i = 0; i < kWordCount; ++i)
    {
        test_words[i] = kGolden[i];
    }

    // read and verify using CPU loads.
    for (unsigned i = 0; i < kWordCount; ++i)
    {
        const uint32_t actual = test_words[i];
        failures += check_word("load", i, actual, kGolden[i]);
    }

    printf("[NPU] Stub check: Testing NPU Scalar Compute:\n");

    uint32_t sum = cfu_op0_hw(CFU_FUNCT7_SCALAR_COMPUTE, 100, 200);
    if (sum == 305)
    {
        printf("PASS\n");
    }
    else
    {
        printf("FAIL (%u)\n", (unsigned)sum);
        failures++;
    }

    if (failures == 0)
    {
        printf("[CPU] ALL PASS (%u checks).\n", 2 * kWordCount);
    }
    else
    {
        printf("[CPU] FAIL (%u/%u checks).\n", failures, 2 * kWordCount);
    }
}