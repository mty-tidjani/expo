// Copyright 2015-present 650 Industries. All rights reserved.

#import <EXConstants/EXConstantsService+InstallationId.h>

static NSString * const kEXDeviceInstallationUUIDKey = @"EXDeviceInstallUUIDKey";

@implementation EXConstantsService (InstallationId)

- (NSString *)installationId
{
  NSString *installationId = [self fetchInstallationId];
  if (installationId) {
    return installationId;
  }
  
  installationId = [[NSUUID UUID] UUIDString];
  [self setInstallationId:installationId];
  return installationId;
}

- (nullable NSString *)fetchInstallationId
{
  NSString *installationId;
  CFTypeRef keychainResult = NULL;
  
  if (SecItemCopyMatching((__bridge CFDictionaryRef)[self installationIdGetQuery], &keychainResult) == noErr) {
    NSData *result = (__bridge_transfer NSData *)keychainResult;
    NSString *value = [[NSString alloc] initWithData:result
                                            encoding:NSUTF8StringEncoding];
    // `initWithUUIDString` returns nil if string is not a valid UUID
    if ([[NSUUID alloc] initWithUUIDString:value]) {
      installationId = value;
    }
  }
  
  if (installationId) {
    return installationId;
  }
  
  NSString *legacyUUID = [[NSUserDefaults standardUserDefaults] stringForKey:kEXDeviceInstallationUUIDKey];
  if (legacyUUID) {
    installationId = legacyUUID;
    
    NSError *error = [self setInstallationId:installationId];
    if (error) {
      NSLog(@"Could not migrate device installation UUID from legacy storage: %@", error.description);
    } else {
      // We only remove the value from old storage once it's set and saved in the new storage.
      [[NSUserDefaults standardUserDefaults] removeObjectForKey:kEXDeviceInstallationUUIDKey];
    }
  }
  
  return installationId;
}

- (nullable NSError *)setInstallationId:(NSString *)installationId
{
  // Delete existing UUID so we don't need to handle "duplicate item" error
  SecItemDelete((__bridge CFDictionaryRef)[self installationIdSearchQuery]);
  
  OSStatus status = SecItemAdd((__bridge CFDictionaryRef)[self installationIdSetQuery:installationId], NULL);
  if (status == errSecSuccess) {
    return nil;
  } else {
    return [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
  }
}

# pragma mark - Keychain dictionaries

- (NSDictionary *)installationIdSearchQueryMerging:(NSDictionary *)dictionaryToMerge
{
  NSData *encodedKey = [kEXDeviceInstallationUUIDKey dataUsingEncoding:NSUTF8StringEncoding];
  NSMutableDictionary *query = [NSMutableDictionary dictionaryWithDictionary:@{
    (__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService:[NSBundle mainBundle].bundleIdentifier,
    (__bridge id)kSecAttrGeneric:encodedKey,
    (__bridge id)kSecAttrAccount:encodedKey
  }];
  [query addEntriesFromDictionary:dictionaryToMerge];
  return query;
}

- (NSDictionary *)installationIdSearchQuery
{
  return [self installationIdSearchQueryMerging:@{}];
}

- (NSDictionary *)installationIdGetQuery
{
  return [self installationIdSearchQueryMerging:@{
    (__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitOne,
    (__bridge id)kSecReturnData:(__bridge id)kCFBooleanTrue
  }];
}

- (NSDictionary *)installationIdSetQuery:(NSString *)deviceInstallationUUID
{
  return [self installationIdSearchQueryMerging:@{
    (__bridge id)kSecValueData:[deviceInstallationUUID dataUsingEncoding:NSUTF8StringEncoding],
    (__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
  }];
}

@end
