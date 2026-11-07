#include <stdint.h>
#include "system_stm32l0xx.h"

/*
 * Firmware targets HSI16 as SYSCLK for deterministic UART timing.
 */
uint32_t SystemCoreClock = 16000000UL;

void SystemInit(void)
{
    SystemCoreClock = 16000000UL;
}

void SystemCoreClockUpdate(void)
{
    SystemCoreClock = 16000000UL;
}
