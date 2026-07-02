#import "SingBoxCore.h"
#include <stdbool.h>

// C FFI declarations (from Go c-archive)
extern void bridge_set_home_dir(const char *dir);
extern int32_t bridge_set_log_file(const char *path);
extern int32_t bridge_start_with_config(int32_t socks_port, int32_t dns_port,
                                         const char *controller_addr,
                                         const char *secret,
                                         const char *config_json);
extern void bridge_stop_proxy(void);
extern bool bridge_is_running(void);
extern int32_t bridge_get_socks_port(void);
extern int32_t bridge_get_dns_port(void);
extern char *bridge_get_external_controller_addr(void);
extern int32_t bridge_validate_config(const char *config_json);
extern void bridge_update_log_level(const char *level);
extern int64_t bridge_get_upload_traffic(void);
extern int64_t bridge_get_download_traffic(void);
extern void bridge_force_gc(void);
extern const char *bridge_version(void);
extern void bridge_free_string(char *ptr);
extern const char *bridge_get_last_error(void);

static NSError *makeSingBoxError(void) {
    const char *msg = bridge_get_last_error();
    NSString *desc = msg ? [NSString stringWithUTF8String:msg] : @"Unknown error";
    return [NSError errorWithDomain:@"SingBoxCore" code:-1
                           userInfo:@{NSLocalizedDescriptionKey: desc}];
}

void SingBoxSetHomeDir(NSString * _Nullable dir) {
    bridge_set_home_dir([dir UTF8String]);
}

void SingBoxSetLogFile(NSString * _Nullable path) {
    bridge_set_log_file([path UTF8String]);
}

BOOL SingBoxStartWithConfig(int32_t socksPort, int32_t dnsPort,
                             NSString * _Nonnull controllerAddr,
                             NSString * _Nullable secret,
                             NSString * _Nonnull configJSON,
                             NSError * _Nullable * _Nullable error) {
    int32_t rc = bridge_start_with_config(
        socksPort,
        dnsPort,
        [controllerAddr UTF8String],
        [secret UTF8String],
        [configJSON UTF8String]
    );
    if (rc != 0) {
        if (error) *error = makeSingBoxError();
        return NO;
    }
    return YES;
}

void SingBoxStop(void) {
    bridge_stop_proxy();
}

BOOL SingBoxIsRunning(void) {
    return bridge_is_running() ? YES : NO;
}

int32_t SingBoxGetSocksPort(void) {
    return bridge_get_socks_port();
}

int32_t SingBoxGetDNSPort(void) {
    return bridge_get_dns_port();
}

NSString * _Nullable SingBoxGetExternalControllerAddr(void) {
    char *cstr = bridge_get_external_controller_addr();
    if (cstr == NULL) return nil;
    NSString *str = [NSString stringWithUTF8String:cstr];
    bridge_free_string(cstr);
    return str;
}

BOOL SingBoxValidateConfig(NSString * _Nonnull configJSON, NSError * _Nullable * _Nullable error) {
    int32_t rc = bridge_validate_config([configJSON UTF8String]);
    if (rc != 0) {
        if (error) *error = makeSingBoxError();
        return NO;
    }
    return YES;
}

void SingBoxUpdateLogLevel(NSString * _Nullable level) {
    bridge_update_log_level([level UTF8String]);
}

int64_t SingBoxGetUploadTraffic(void) {
    return bridge_get_upload_traffic();
}

int64_t SingBoxGetDownloadTraffic(void) {
    return bridge_get_download_traffic();
}

void SingBoxForceGC(void) {
    bridge_force_gc();
}

NSString * _Nonnull SingBoxVersion(void) {
    const char *v = bridge_version();
    return v ? [NSString stringWithUTF8String:v] : @"unknown";
}
