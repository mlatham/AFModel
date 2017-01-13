#import "Foundation/Foundation.h"
#import "SystemConfiguration/SystemConfiguration.h"


#pragma mark Enumerations

typedef enum
{
	AFReachabilityStateUnknown = 0,
    AFReachabilityStateOffline,
    AFReachabilityStateOnline
	
} AFReachabilityState;

typedef enum
{
	AFNetworkTypeUnknown = 0,
	AFNetworkTypeOffline,
	AFNetworkTypeWiFi,
	AFNetworkTypeWWAN
	
} AFNetworkType;


#pragma mark - Constants

extern NSString * const AFReachability_StateKeyPath;


#pragma mark - Class Interface

@interface AFReachability : NSObject


#pragma mark - Properties

@property (nonatomic, readonly) NSString *stateString;
@property (nonatomic, readonly) AFReachabilityState state;

@property (nonatomic, readonly) NSString *networkTypeString;
@property (nonatomic, readonly) AFNetworkType networkType;


#pragma mark - Static Methods

+ (AFReachability *)reachabilityWithHostName: (NSString *)hostName; 
+ (AFReachability *)reachabilityForInternetConnection;


#pragma mark - Instance Methods

- (BOOL)start;
- (void)stop;


@end
