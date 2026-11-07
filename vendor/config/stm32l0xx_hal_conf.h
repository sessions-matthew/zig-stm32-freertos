#ifndef STM32L0XX_HAL_CONF_H
#define STM32L0XX_HAL_CONF_H

#ifdef __cplusplus
extern "C" {
#endif

#define HAL_MODULE_ENABLED
#define HAL_CORTEX_MODULE_ENABLED
#define HAL_FLASH_MODULE_ENABLED
#define HAL_GPIO_MODULE_ENABLED
#define HAL_ADC_MODULE_ENABLED
#define HAL_PWR_MODULE_ENABLED
#define HAL_RCC_MODULE_ENABLED
#define HAL_DMA_MODULE_ENABLED
#define HAL_SPI_MODULE_ENABLED
#define HAL_I2C_MODULE_ENABLED
#define HAL_UART_MODULE_ENABLED

#define HSE_VALUE    ((uint32_t)8000000U)
#define HSI_VALUE    ((uint32_t)16000000U)
#define MSI_VALUE    ((uint32_t)2097000U)
#define LSI_VALUE    ((uint32_t)37000U)
#define LSE_VALUE    ((uint32_t)32768U)

#define VDD_VALUE                    ((uint32_t)3300U)
#define TICK_INT_PRIORITY            ((uint32_t)3U)
#define USE_RTOS                     0U
#define PREFETCH_ENABLE              1U
#define INSTRUCTION_CACHE_ENABLE     1U
#define DATA_CACHE_ENABLE            0U

#define HSE_STARTUP_TIMEOUT          ((uint32_t)100U)
#define LSE_STARTUP_TIMEOUT          ((uint32_t)5000U)

#define USE_HAL_ADC_REGISTER_CALLBACKS         0U
#define USE_HAL_COMP_REGISTER_CALLBACKS        0U
#define USE_HAL_CRC_REGISTER_CALLBACKS         0U
#define USE_HAL_CRYP_REGISTER_CALLBACKS        0U
#define USE_HAL_DAC_REGISTER_CALLBACKS         0U
#define USE_HAL_I2C_REGISTER_CALLBACKS         0U
#define USE_HAL_IRDA_REGISTER_CALLBACKS        0U
#define USE_HAL_LPTIM_REGISTER_CALLBACKS       0U
#define USE_HAL_OPAMP_REGISTER_CALLBACKS       0U
#define USE_HAL_PCD_REGISTER_CALLBACKS         0U
#define USE_HAL_RNG_REGISTER_CALLBACKS         0U
#define USE_HAL_RTC_REGISTER_CALLBACKS         0U
#define USE_HAL_SMARTCARD_REGISTER_CALLBACKS   0U
#define USE_HAL_SPI_REGISTER_CALLBACKS         0U
#define USE_HAL_TIM_REGISTER_CALLBACKS         0U
#define USE_HAL_TSC_REGISTER_CALLBACKS         0U
#define USE_HAL_UART_REGISTER_CALLBACKS        0U
#define USE_HAL_USART_REGISTER_CALLBACKS       0U
#define USE_HAL_WWDG_REGISTER_CALLBACKS        0U

#include "stm32l0xx_hal_rcc.h"
#include "stm32l0xx_hal_cortex.h"
#include "stm32l0xx_hal_flash.h"
#include "stm32l0xx_hal_pwr.h"
#include "stm32l0xx_hal_gpio.h"
#include "stm32l0xx_hal_dma.h"
#include "stm32l0xx_hal_adc.h"
#include "stm32l0xx_hal_spi.h"
#include "stm32l0xx_hal_i2c.h"
#include "stm32l0xx_hal_uart.h"

#if defined(USE_FULL_ASSERT)
void assert_failed(uint8_t *file, uint32_t line);
#else
#define assert_param(expr) ((void)0U)
#endif

#ifdef __cplusplus
}
#endif

#endif
