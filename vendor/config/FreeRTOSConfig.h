#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

#include <stdint.h>

extern uint32_t SystemCoreClock;

void vApplicationPreSleepProcessing(uint32_t *pxExpectedIdleTime);
void vApplicationPostSleepProcessing(uint32_t xExpectedIdleTime);

#define configUSE_PREEMPTION                    1
#define configSUPPORT_STATIC_ALLOCATION         1
#define configSUPPORT_DYNAMIC_ALLOCATION        0
#define configENABLE_MPU                        0
#define configUSE_PORT_OPTIMISED_TASK_SELECTION 0
#define configUSE_IDLE_HOOK                     0
#define configUSE_TICK_HOOK                     1
#define configUSE_TICKLESS_IDLE                 2
#define configTICK_USES_LSI                     1
#define configLPTIM_REF_CLOCK_HZ                37000UL
#define configLPTIM_ENABLE_PRECISION            0
#define configCPU_CLOCK_HZ                      ( SystemCoreClock )
#define configTICK_RATE_HZ                      1000UL
#define configMAX_PRIORITIES                    4
#define configMINIMAL_STACK_SIZE                ((uint16_t)96)
#define configTOTAL_HEAP_SIZE                   ((size_t)(1 * 1024))
#define configMAX_TASK_NAME_LEN                 16
#define configUSE_16_BIT_TICKS                  0
#define configIDLE_SHOULD_YIELD                 1
#define configUSE_MUTEXES                        1
#define configQUEUE_REGISTRY_SIZE                0
#define configCHECK_FOR_STACK_OVERFLOW           1
#define configUSE_RECURSIVE_MUTEXES              0
#define configUSE_MALLOC_FAILED_HOOK             0
#define configUSE_APPLICATION_TASK_TAG           0
#define configUSE_COUNTING_SEMAPHORES            0
#define configGENERATE_RUN_TIME_STATS            0
#define configUSE_TRACE_FACILITY                 0
#define configUSE_STATS_FORMATTING_FUNCTIONS     0

#define configUSE_CO_ROUTINES                    0
#define configMAX_CO_ROUTINE_PRIORITIES          1

#define configUSE_TIMERS                         0
#define configTIMER_TASK_PRIORITY                2
#define configTIMER_QUEUE_LENGTH                 5
#define configTIMER_TASK_STACK_DEPTH             (configMINIMAL_STACK_SIZE)
#define configUSE_TASK_NOTIFICATIONS             1
#define configTICK_INTERRUPT_PRIORITY           configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY
uint8_t sleep_mgr_get_mode(void);
#define configPRE_SUPPRESS_TICKS_AND_SLEEP_PROCESSING(xExpectedIdleTime) \
    do { \
        if (sleep_mgr_get_mode() == 2) { \
            (xExpectedIdleTime) = 0; \
        } \
    } while (0)
#define configPRE_SLEEP_PROCESSING(xIdleTime)   vApplicationPreSleepProcessing(&(xIdleTime))
#define configPOST_SLEEP_PROCESSING(xIdleTime)  vApplicationPostSleepProcessing((uint32_t)(xIdleTime))

#define INCLUDE_vTaskPrioritySet                 0
#define INCLUDE_uxTaskPriorityGet                0
#define INCLUDE_vTaskDelete                      0
#define INCLUDE_vTaskCleanUpResources            0
#define INCLUDE_vTaskSuspend                     0
#define INCLUDE_vTaskDelayUntil                  0
#define INCLUDE_vTaskDelay                       1
#define INCLUDE_xTaskGetSchedulerState           1
#define INCLUDE_uxTaskGetStackHighWaterMark      1

#define configPRIO_BITS                          2
#define configLIBRARY_LOWEST_INTERRUPT_PRIORITY  3
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY 1

#define configKERNEL_INTERRUPT_PRIORITY          (configLIBRARY_LOWEST_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))
#define configMAX_SYSCALL_INTERRUPT_PRIORITY     (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))

void vAssertCalled(const char *file, int line);

#ifdef NDEBUG
#define configASSERT(x) ((void)0)
#else
void vAssertCalled(const char *file, int line);
#define configASSERT(x) if ((x) == 0) { vAssertCalled(__FILE__, __LINE__); }
#endif

#endif /* FREERTOS_CONFIG_H */
