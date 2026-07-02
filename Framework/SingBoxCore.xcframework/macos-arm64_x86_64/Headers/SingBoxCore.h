#import <Foundation/Foundation.h>

FOUNDATION_EXPORT void SingBoxSetHomeDir(NSString * _Nullable dir);
FOUNDATION_EXPORT void SingBoxSetLogFile(NSString * _Nullable path);

/// Start sing-box with a prebuilt JSON config string.
/// socksPort: SOCKS5 inbound port (127.0.0.1)
/// dnsPort:   DNS inbound port (127.0.0.1)
/// controllerAddr: "127.0.0.1:port" for clash_api
/// secret: clash_api secret (可为空字符串)
/// configJSON: 完整的 sing-box JSON 配置（由 SingBoxConfigBuilder 生成）
FOUNDATION_EXPORT BOOL SingBoxStartWithConfig(
    int32_t socksPort,
    int32_t dnsPort,
    NSString * _Nonnull controllerAddr,
    NSString * _Nullable secret,
    NSString * _Nonnull configJSON,
    NSError * _Nullable * _Nullable error
);

FOUNDATION_EXPORT void SingBoxStop(void);
FOUNDATION_EXPORT BOOL SingBoxIsRunning(void);

FOUNDATION_EXPORT int32_t SingBoxGetSocksPort(void);
FOUNDATION_EXPORT int32_t SingBoxGetDNSPort(void);
FOUNDATION_EXPORT NSString * _Nullable SingBoxGetExternalControllerAddr(void);

FOUNDATION_EXPORT BOOL SingBoxValidateConfig(NSString * _Nonnull configJSON, NSError * _Nullable * _Nullable error);
FOUNDATION_EXPORT void SingBoxUpdateLogLevel(NSString * _Nullable level);

FOUNDATION_EXPORT int64_t SingBoxGetUploadTraffic(void);
FOUNDATION_EXPORT int64_t SingBoxGetDownloadTraffic(void);

FOUNDATION_EXPORT void SingBoxForceGC(void);
FOUNDATION_EXPORT NSString * _Nonnull SingBoxVersion(void);
