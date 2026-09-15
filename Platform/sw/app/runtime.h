#ifndef PLATFORM_SW_APP_RUNTIME_H_
#define PLATFORM_SW_APP_RUNTIME_H_

#ifdef __cplusplus
extern "C" {
#endif

void uart_putc(char c);
char uart_getc(void);

#ifdef __cplusplus
}
#endif



#endif  // PLATFORM_SW_APP_RUNTIME_H_
